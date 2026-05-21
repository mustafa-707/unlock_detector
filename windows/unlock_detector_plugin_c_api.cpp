#include "include/unlock_detector/unlock_detector_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "unlock_detector_plugin.h"

void UnlockDetectorPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  unlock_detector::UnlockDetectorPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
