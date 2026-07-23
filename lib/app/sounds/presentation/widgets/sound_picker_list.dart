import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_list_tile.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Catalog body: loading, error, empty, or sound rows.
class SoundPickerList extends StatelessWidget {
  const SoundPickerList({
    super.key,
    required this.loading,
    required this.sounds,
    required this.selectedId,
    required this.favoriteIds,
    required this.error,
    required this.showError,
    required this.onRetry,
    required this.onSoundTap,
    required this.onScissorsTap,
    required this.onFavoriteTap,
    this.scrollController,
  });

  final bool loading;
  final List<SoundEntity> sounds;
  final String? selectedId;
  final Set<String> favoriteIds;
  final String? error;
  final bool showError;
  final VoidCallback onRetry;
  final ValueChanged<SoundEntity> onSoundTap;
  final ValueChanged<SoundEntity> onScissorsTap;
  final ValueChanged<SoundEntity> onFavoriteTap;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    if (loading) {
      return ListView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 180, child: Center(child: CustomLoadingWidget(size: 40))),
        ],
      );
    }

    if (showError && error != null) {
      return ListView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 220,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.p24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomText(
                      error!,
                      variant: TextVariant.secondary,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: onRetry,
                      child: Text(l10n.liveGiftRetry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (sounds.isEmpty) {
      return ListView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 180,
            child: Center(
              child: CustomText(
                l10n.soundPickerEmpty,
                variant: TextVariant.secondary,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: sounds.length,
      separatorBuilder: (_, index) => Divider(
        height: 1,
        indent: 84,
        color: onSurface.withValues(alpha: 0.06),
      ),
      itemBuilder: (context, index) {
        final sound = sounds[index];
        return SoundListTile(
          sound: sound,
          isSelected: selectedId == sound.id,
          isFavorite: favoriteIds.contains(sound.id),
          onTap: () => onSoundTap(sound),
          onScissorsTap: () => onScissorsTap(sound),
          onFavoriteTap: () => onFavoriteTap(sound),
        );
      },
    );
  }
}
