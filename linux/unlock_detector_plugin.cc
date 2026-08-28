#include "include/unlock_detector/unlock_detector_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gio/gio.h>
#include <gtk/gtk.h>
#include <X11/Xlib.h>
#include <X11/extensions/scrnsaver.h>

#include <cstring>

#include "unlock_detector_plugin_private.h"

#define UNLOCK_DETECTOR_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), unlock_detector_plugin_get_type(), \
                              UnlockDetectorPlugin))

struct _UnlockDetectorPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(UnlockDetectorPlugin, unlock_detector_plugin, g_object_get_type())

// Called when a method call is received from Flutter.
static void unlock_detector_plugin_handle_method_call(
    UnlockDetectorPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "get_system_idle_seconds") == 0) {
    response = get_system_idle_seconds();
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

// Sentinel for "this backend could not answer".
static const int64_t kIdleUnavailable = -1;

// Seconds since the last input as reported by the X11 screensaver extension.
//
// The display is opened once and kept: the idle time is polled every few
// seconds, and a connect/disconnect round trip per poll is pure overhead.
static int64_t x11_idle_seconds() {
  static Display* display = nullptr;
  static gboolean tried = FALSE;
  if (!tried) {
    tried = TRUE;
    display = XOpenDisplay(nullptr);
  }
  if (display == nullptr) {
    return kIdleUnavailable;
  }

  XScreenSaverInfo* info = XScreenSaverAllocInfo();
  if (info == nullptr) {
    return kIdleUnavailable;
  }
  int64_t seconds = kIdleUnavailable;
  if (XScreenSaverQueryInfo(display, DefaultRootWindow(display), info)) {
    seconds = static_cast<int64_t>(info->idle) / 1000;
  }
  XFree(info);
  return seconds;
}

// Seconds since the last input, from a session-bus idle monitor.
//
// Under Wayland the X11 screensaver extension only ever sees XWayland input,
// so it reports an idle time that never grows. The compositor owns the real
// figure and exposes it over D-Bus: Mutter (GNOME) and the freedesktop
// screensaver interface (KDE and others) are both tried.
static int64_t dbus_idle_seconds(const gchar* name, const gchar* object_path,
                                 const gchar* interface, const gchar* method,
                                 const GVariantType* reply_type) {
  static GDBusConnection* bus = nullptr;
  static gboolean tried = FALSE;
  if (!tried) {
    tried = TRUE;
    bus = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, nullptr);
  }
  if (bus == nullptr) {
    return kIdleUnavailable;
  }

  g_autoptr(GVariant) reply = g_dbus_connection_call_sync(
      bus, name, object_path, interface, method, nullptr, reply_type,
      G_DBUS_CALL_FLAGS_NO_AUTO_START, 1000, nullptr, nullptr);
  if (reply == nullptr) {
    return kIdleUnavailable;
  }

  // Mutter answers with (t) — milliseconds; the freedesktop interface with
  // (u), also milliseconds.
  g_autoptr(GVariant) value = g_variant_get_child_value(reply, 0);
  guint64 idle_ms = 0;
  if (g_variant_is_of_type(value, G_VARIANT_TYPE_UINT64)) {
    idle_ms = g_variant_get_uint64(value);
  } else if (g_variant_is_of_type(value, G_VARIANT_TYPE_UINT32)) {
    idle_ms = g_variant_get_uint32(value);
  } else {
    return kIdleUnavailable;
  }
  return static_cast<int64_t>(idle_ms / 1000);
}

static int64_t mutter_idle_seconds() {
  return dbus_idle_seconds("org.gnome.Mutter.IdleMonitor",
                           "/org/gnome/Mutter/IdleMonitor/Core",
                           "org.gnome.Mutter.IdleMonitor", "GetIdletime",
                           G_VARIANT_TYPE("(t)"));
}

static int64_t screensaver_idle_seconds() {
  return dbus_idle_seconds("org.freedesktop.ScreenSaver",
                           "/org/freedesktop/ScreenSaver",
                           "org.freedesktop.ScreenSaver",
                           "GetSessionIdleTime", G_VARIANT_TYPE("(u)"));
}

// Seconds since the last system-wide input. Returns 0 when no backend on this
// session can supply it.
FlMethodResponse* get_system_idle_seconds() {
  const gchar* session_type = g_getenv("XDG_SESSION_TYPE");
  const gboolean is_wayland =
      session_type != nullptr && g_strcmp0(session_type, "wayland") == 0;

  // On X11 the screensaver extension is the cheapest and most widely
  // supported source; on Wayland it is the one source that is always wrong.
  int64_t seconds = is_wayland ? kIdleUnavailable : x11_idle_seconds();
  if (seconds < 0) {
    seconds = mutter_idle_seconds();
  }
  if (seconds < 0) {
    seconds = screensaver_idle_seconds();
  }
  if (seconds < 0) {
    seconds = 0;
  }

  g_autoptr(FlValue) result = fl_value_new_int(seconds);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static void unlock_detector_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(unlock_detector_plugin_parent_class)->dispose(object);
}

static void unlock_detector_plugin_class_init(UnlockDetectorPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = unlock_detector_plugin_dispose;
}

static void unlock_detector_plugin_init(UnlockDetectorPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  UnlockDetectorPlugin* plugin = UNLOCK_DETECTOR_PLUGIN(user_data);
  unlock_detector_plugin_handle_method_call(plugin, method_call);
}

void unlock_detector_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  UnlockDetectorPlugin* plugin = UNLOCK_DETECTOR_PLUGIN(
      g_object_new(unlock_detector_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "unlock_detector",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
