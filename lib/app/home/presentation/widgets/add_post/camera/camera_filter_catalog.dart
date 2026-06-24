import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_preset.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';

enum CameraFilterCategory { trending, newFilters, portrait, vibe, landscape }

/// All CamerAwesome GPU preset filters, grouped for the filter strip UI.
class CameraFilterCatalog {
  CameraFilterCatalog._();

  static const _thumbnailByFilterName = <String, String>{
    'Reyes': 'assets/images/camera_filters/flash_vintage.png',
    'Aden': 'assets/images/camera_filters/beauty_glow.png',
    'Lark': 'assets/images/camera_filters/natural_bright.png',
    'Juno': 'assets/images/camera_filters/golden_hour.png',
  };

  static const _customLabelByFilterName = <String, String>{
    'Reyes': 'Flash',
    'Aden': 'Glow',
    'Lark': 'Natural',
    'Juno': 'Golden',
  };

  static final CameraFilterPreset original = _preset(AwesomeFilter.None);

  static final CameraFilterPreset beautyFilter = _preset(AwesomeFilter.Aden);

  static final List<AwesomeFilter> allGpuFilters = awesomePresetFiltersList;

  static AwesomeFilter filterByName(String name) {
    for (final filter in allGpuFilters) {
      if (filter.name == name) return filter;
    }
    return AwesomeFilter.None;
  }

  static final List<CameraFilterPreset> trending = [
    AwesomeFilter.None,
    AwesomeFilter.Amaro,
    AwesomeFilter.Juno,
    AwesomeFilter.Lark,
    AwesomeFilter.AddictiveRed,
    AwesomeFilter.Clarendon,
    AwesomeFilter.Reyes,
    AwesomeFilter.Aden,
  ].map(_preset).toList(growable: false);

  static final List<CameraFilterPreset> newFilters = [
    AwesomeFilter.None,
    AwesomeFilter.Aden,
    AwesomeFilter.Perpetua,
    AwesomeFilter.Walden,
    AwesomeFilter.Ginza,
    AwesomeFilter.Sierra,
    AwesomeFilter.Hefe,
  ].map(_preset).toList(growable: false);

  static final List<CameraFilterPreset> portrait = [
    AwesomeFilter.None,
    AwesomeFilter.Aden,
    AwesomeFilter.Lark,
    AwesomeFilter.Juno,
    AwesomeFilter.Reyes,
    AwesomeFilter.Inkwell,
    AwesomeFilter.Moon,
    AwesomeFilter.Willow,
    AwesomeFilter.Brannan,
    AwesomeFilter.Stinson,
  ].map(_preset).toList(growable: false);

  static final List<CameraFilterPreset> vibe = [
    AwesomeFilter.None,
    AwesomeFilter.Sutro,
    AwesomeFilter.Hudson,
    AwesomeFilter.LoFi,
    AwesomeFilter.Slumber,
    AwesomeFilter.Dogpatch,
    AwesomeFilter.AddictiveBlue,
  ].map(_preset).toList(growable: false);

  static final List<CameraFilterPreset> landscape = [
    AwesomeFilter.None,
    AwesomeFilter.Brooklyn,
    AwesomeFilter.Gingham,
    AwesomeFilter.XProII,
    AwesomeFilter.Ludwig,
    AwesomeFilter.Crema,
    AwesomeFilter.Ashby,
  ].map(_preset).toList(growable: false);

  static List<CameraFilterPreset> forCategory(CameraFilterCategory category) {
    return switch (category) {
      CameraFilterCategory.trending => trending,
      CameraFilterCategory.newFilters => newFilters,
      CameraFilterCategory.portrait => portrait,
      CameraFilterCategory.vibe => vibe,
      CameraFilterCategory.landscape => landscape,
    };
  }

  static CameraFilterPreset _preset(AwesomeFilter filter) {
    return CameraFilterPreset(
      filter: filter,
      thumbnailAsset: _thumbnailByFilterName[filter.name],
      customLabel: _customLabelByFilterName[filter.name],
    );
  }

  static Color previewColor(AwesomeFilter filter) {
    return switch (filter.name) {
      'Original' => const Color(0xFFE8D5C4),
      'Addictive Red' => const Color(0xFFE07A7A),
      'Addictive Blue' => const Color(0xFF7EB8DA),
      'Amaro' => const Color(0xFFE8A87C),
      'Aden' => const Color(0xFFF4A6C7),
      'Inkwell' => const Color(0xFF9E9E9E),
      'Moon' => const Color(0xFF6B705C),
      'Brooklyn' => const Color(0xFFC9A66B),
      'Juno' => const Color(0xFFFFD166),
      'Lark' => const Color(0xFF90CAF9),
      'Reyes' => const Color(0xFFD4A574),
      'Clarendon' => const Color(0xFF5C9EAD),
      'Hefe' => const Color(0xFFCD853F),
      'Hudson' => const Color(0xFF4682B4),
      'LoFi' => const Color(0xFF8B7355),
      'Sutro' => const Color(0xFF4A5568),
      'Walden' => const Color(0xFF2E8B57),
      'XProII' => const Color(0xFFBC8F8F),
      _ => const Color(0xFF7A7A7A),
    };
  }
}
