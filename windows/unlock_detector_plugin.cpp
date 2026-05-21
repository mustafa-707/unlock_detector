#include "unlock_detector_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>

namespace unlock_detector {

// static
void UnlockDetectorPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "unlock_detector",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<UnlockDetectorPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

UnlockDetectorPlugin::UnlockDetectorPlugin() {}

UnlockDetectorPlugin::~UnlockDetectorPlugin() {}

// Seconds since the last system-wide keyboard or mouse input.
static int SystemIdleSeconds() {
  LASTINPUTINFO last_input;
  last_input.cbSize = sizeof(LASTINPUTINFO);
  if (!GetLastInputInfo(&last_input)) {
    return 0;
  }
  DWORD idle_ms = GetTickCount() - last_input.dwTime;
  return static_cast<int>(idle_ms / 1000);
}

void UnlockDetectorPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("get_system_idle_seconds") == 0) {
    result->Success(flutter::EncodableValue(SystemIdleSeconds()));
  } else {
    result->NotImplemented();
  }
}

}  // namespace unlock_detector
