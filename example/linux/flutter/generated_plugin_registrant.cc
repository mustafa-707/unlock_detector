//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <unlock_detector/unlock_detector_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) unlock_detector_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "UnlockDetectorPlugin");
  unlock_detector_plugin_register_with_registrar(unlock_detector_registrar);
}
