#ifndef FLUTTER_PLUGIN_UNLOCK_DETECTOR_PLUGIN_H_
#define FLUTTER_PLUGIN_UNLOCK_DETECTOR_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace unlock_detector {

class UnlockDetectorPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  UnlockDetectorPlugin();

  virtual ~UnlockDetectorPlugin();

  // Disallow copy and assign.
  UnlockDetectorPlugin(const UnlockDetectorPlugin&) = delete;
  UnlockDetectorPlugin& operator=(const UnlockDetectorPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace unlock_detector

#endif  // FLUTTER_PLUGIN_UNLOCK_DETECTOR_PLUGIN_H_
