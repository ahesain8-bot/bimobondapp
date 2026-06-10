# Plugin registration for Windows.
# Keep FLUTTER_*_PLUGIN_LIST in sync with flutter/generated_plugins.cmake after
# `flutter pub get` when dependencies change.

set(FLUTTER_PLUGIN_LIST
  cloud_firestore
  file_selector_windows
  firebase_auth
  firebase_core
  geolocator_windows
  permission_handler_windows
  record_windows
  url_launcher_windows
)

set(FLUTTER_FFI_PLUGIN_LIST
  flutter_local_notifications_windows
  jni
)

set(PLUGIN_BUNDLED_LIBRARIES)

foreach(plugin ${FLUTTER_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${plugin}/windows plugins/${plugin})
  target_link_libraries(${BINARY_NAME} PRIVATE ${plugin}_plugin)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:${plugin}_plugin>)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${plugin}_bundled_libraries})
endforeach(plugin)

# Use short CMake binary-dir names for FFI plugins to avoid Windows MAX_PATH errors.
foreach(ffi_plugin ${FLUTTER_FFI_PLUGIN_LIST})
  if(ffi_plugin STREQUAL "flutter_local_notifications_windows")
    set(_ffi_build_dir "fln")
  else()
    set(_ffi_build_dir "${ffi_plugin}")
  endif()

  add_subdirectory(
    flutter/ephemeral/.plugin_symlinks/${ffi_plugin}/windows
    plugins/${_ffi_build_dir}
  )
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${ffi_plugin}_bundled_libraries})
endforeach(ffi_plugin)
