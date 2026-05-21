#include "include/unlock_detector/unlock_detector_plugin.h"

#include <flutter_linux/flutter_linux.h>
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

// Seconds since the last system-wide input, via the X11 screensaver extension.
// Returns 0 when X11 is unavailable (e.g. a pure Wayland session).
FlMethodResponse* get_system_idle_seconds() {
  int64_t seconds = 0;
  Display* display = XOpenDisplay(nullptr);
  if (display != nullptr) {
    XScreenSaverInfo* info = XScreenSaverAllocInfo();
    if (info != nullptr) {
      if (XScreenSaverQueryInfo(display, DefaultRootWindow(display), info)) {
        seconds = static_cast<int64_t>(info->idle) / 1000;
      }
      XFree(info);
    }
    XCloseDisplay(display);
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
