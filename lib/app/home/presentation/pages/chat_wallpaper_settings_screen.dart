import 'package:bimobondapp/core/constants/settings_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/theme/chat_wallpaper_preset.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_wallpaper_pattern_layer.dart';
import 'package:bimobondapp/core/theme/cubit/chat_wallpaper_cubit.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChatWallpaperSettingsScreen extends StatelessWidget {
  const ChatWallpaperSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    final selected = context.watch<ChatWallpaperCubit>().state;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: l10n.chatWallpaperTitle,
        showBackButton: true,
        showBottomDivider: true,
        onBackPressed: () => Navigator.of(context).pop(),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: SettingsLayoutConstants.horizontalPadding,
          vertical: SettingsLayoutConstants.bodyVerticalPadding,
        ),
        children: [
          CustomText(
            l10n.chatWallpaperSubtitle,
            variant: TextVariant.secondary,
            fontSize: SettingsLayoutConstants.trailingFontSize,
          ),
          const SizedBox(height: SettingsLayoutConstants.groupSpacing),
          ...ChatWallpaperPresets.all.map((preset) {
            final isSelected = selected == preset.id;
            return Padding(
              padding: const EdgeInsets.only(
                bottom: SettingsLayoutConstants.sheetItemSpacing,
              ),
              child: Material(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(
                  SettingsLayoutConstants.groupRadius,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                    SettingsLayoutConstants.groupRadius,
                  ),
                  onTap: () => context
                      .read<ChatWallpaperCubit>()
                      .setWallpaper(preset.id),
                  child: Padding(
                    padding: const EdgeInsets.all(
                      SettingsLayoutConstants.tileHorizontalPadding,
                    ),
                    child: Row(
                      children: [
                        ChatWallpaperPreview(
                          preset: preset,
                          backgroundColor: chatTheme.chatBackgroundColor,
                        ),
                        const SizedBox(
                          width: SettingsLayoutConstants.sheetItemSpacing,
                        ),
                        Expanded(
                          child: CustomText(
                            preset.label(l10n),
                            fontSize: SettingsLayoutConstants.itemTitleFontSize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            LucideIcons.circleCheck,
                            color: theme.colorScheme.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class ChatWallpaperPreview extends StatelessWidget {
  const ChatWallpaperPreview({
    required this.preset,
    required this.backgroundColor,
    super.key,
  });

  final ChatWallpaperPreset preset;
  final Color backgroundColor;

  static const double _previewSize = 72;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(
        SettingsLayoutConstants.iconContainerRadius,
      ),
      child: SizedBox(
        width: _previewSize,
        height: _previewSize,
        child: ChatWallpaperPatternLayer(
          preset: preset,
          backgroundColor: backgroundColor,
        ),
      ),
    );
  }
}
