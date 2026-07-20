import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_grid_video_background.dart';
import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_list_tile.dart';
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_picker_theme.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/navigation/sound_navigation.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/format_count.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/directional_back_icon.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/core/widgets/video_post_preview_placeholder.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Back + search + share header.
class SoundDetailTopBar extends StatelessWidget {
  const SoundDetailTopBar({
    super.key,
    required this.searchController,
    required this.onBack,
    required this.onShare,
    this.onSearchSubmitted,
  });

  final TextEditingController searchController;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final ValueChanged<String>? onSearchSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final onSurface = scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: DirectionalBackIcon(color: onSurface, size: 22),
          ),
          Expanded(
            child: TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: onSearchSubmitted,
              style: TextStyle(
                color: onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.soundFindRelatedHint,
                hintStyle: TextStyle(
                  color: onSurface.withValues(alpha: 0.4),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Icon(
                  LucideIcons.search,
                  size: 18,
                  color: onSurface.withValues(alpha: 0.4),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 36,
                ),
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(
                  alpha: 0.55,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onShare,
            icon: Icon(
              LucideIcons.share,
              color: onSurface,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cover + title / creator / posts + Save.
class SoundDetailMetaSection extends StatelessWidget {
  const SoundDetailMetaSection({
    super.key,
    required this.sound,
    required this.isPlaying,
    required this.isSaved,
    required this.onTogglePreview,
    required this.onToggleSave,
    this.onCreatorTap,
  });

  final SoundEntity sound;
  final bool isPlaying;
  final bool isSaved;
  final VoidCallback onTogglePreview;
  final VoidCallback onToggleSave;
  final VoidCallback? onCreatorTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final onSurface = scheme.onSurface;
    final posts = sound.postCount ?? sound.useCount;
    final creatorName = sound.creator?.fullName?.trim().isNotEmpty == true
        ? sound.creator!.fullName!.trim()
        : (sound.creator?.username.trim().isNotEmpty == true
              ? sound.creator!.username.trim()
              : sound.author);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SoundDetailCover(
                coverUrl: sound.resolvedCoverUrl ??
                    (sound.creator?.avatarUrl != null
                        ? MediaUtils.resolveAbsoluteUrl(
                            sound.creator!.avatarUrl!,
                          )
                        : null),
                isPlaying: isPlaying,
                onTap: onTogglePreview,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            sound.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: onSurface,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: onTogglePreview,
                          child: Icon(
                            isPlaying ? LucideIcons.pause : LucideIcons.play,
                            size: 16,
                            color: onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: onCreatorTap,
                      borderRadius: BorderRadius.circular(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              creatorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: onSurface.withValues(alpha: 0.75),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (onCreatorTap != null) ...[
                            const SizedBox(width: 2),
                            Icon(
                              LucideIcons.chevronRight,
                              size: 16,
                              color: onSurface.withValues(alpha: 0.55),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatSoundUseCount(posts, l10n),
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.45),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SoundDetailSaveButton(
            isSaved: isSaved,
            onPressed: onToggleSave,
          ),
        ],
      ),
    );
  }
}

class SoundDetailCover extends StatelessWidget {
  const SoundDetailCover({
    super.key,
    this.coverUrl,
    required this.isPlaying,
    this.onTap,
    this.size = 88,
  });

  final String? coverUrl;
  final bool isPlaying;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: SoundPickerTheme.secondaryOf(context),
            width: 2.5,
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: ClipOval(
          child: coverUrl != null && coverUrl!.isNotEmpty
              ? SafeNetworkImage(
                  imageUrl: coverUrl!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                )
              : ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Icon(
                    isPlaying ? LucideIcons.pause : LucideIcons.music,
                    color: scheme.onSurface.withValues(alpha: 0.45),
                    size: size * 0.32,
                  ),
                ),
        ),
      ),
    );
  }
}

class SoundDetailSaveButton extends StatelessWidget {
  const SoundDetailSaveButton({
    super.key,
    required this.isSaved,
    required this.onPressed,
  });

  final bool isSaved;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final onSurface = scheme.onSurface;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: onSurface,
        side: BorderSide(color: onSurface.withValues(alpha: 0.18)),
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSaved ? Icons.bookmark : LucideIcons.bookmark,
            size: 18,
            color: isSaved
                ? SoundPickerTheme.accentOf(context)
                : onSurface,
          ),
          const SizedBox(width: 8),
          Text(
            isSaved ? l10n.soundSaved : l10n.soundSave,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sticky bottom: Add to Story + Use sound.
class SoundDetailBottomBar extends StatelessWidget {
  const SoundDetailBottomBar({
    super.key,
    required this.avatarUrl,
    required this.onAddToStory,
    required this.onUseSound,
    this.useLabel,
  });

  final String? avatarUrl;
  final VoidCallback onAddToStory;
  final VoidCallback onUseSound;
  final String? useLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final onSurface = scheme.onSurface;
    final resolvedAvatar = avatarUrl == null || avatarUrl!.isEmpty
        ? null
        : MediaUtils.resolveAbsoluteUrl(avatarUrl!);

    return Material(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onAddToStory,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: onSurface,
                    backgroundColor: scheme.surface,
                    side: BorderSide(
                      color: onSurface.withValues(alpha: 0.14),
                    ),
                    elevation: 0,
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: scheme.surfaceContainerHighest,
                        backgroundImage: resolvedAvatar != null
                            ? NetworkImage(resolvedAvatar)
                            : null,
                        child: resolvedAvatar == null
                            ? Icon(
                                LucideIcons.user,
                                size: 14,
                                color: onSurface.withValues(alpha: 0.45),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          l10n.soundAddToStory,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onUseSound,
                  style: FilledButton.styleFrom(
                    backgroundColor: SoundPickerTheme.accentOf(context),
                    foregroundColor: scheme.onPrimary,
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.video, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          useLabel ?? l10n.soundUseSoundCta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SoundDetailVideoGrid extends StatelessWidget {
  const SoundDetailVideoGrid({
    super.key,
    required this.posts,
    this.showOriginalOnFirst = false,
  });

  final List<SoundPostPreviewEntity> posts;
  final bool showOriginalOnFirst;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: ProfileLayoutConstants.gridSpacing,
        mainAxisSpacing: ProfileLayoutConstants.gridSpacing,
        childAspectRatio: ProfileLayoutConstants.gridAspectRatio,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return GestureDetector(
          onTap: () => openSoundPostsViewer(
            context,
            previews: posts,
            initialIndex: index,
          ),
          child: SoundDetailPostGridTile(
            post: post,
            showOriginalBadge: showOriginalOnFirst && index == 0,
          ),
        );
      },
    );
  }
}

class SoundDetailPostGridTile extends StatelessWidget {
  const SoundDetailPostGridTile({
    super.key,
    required this.post,
    this.showOriginalBadge = false,
  });

  final SoundPostPreviewEntity post;
  final bool showOriginalBadge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final coverUrl = post.resolvedCoverUrl;
    final videoUrl = post.resolvedVideoUrl;
    final hasCover = coverUrl != null && coverUrl.isNotEmpty;
    final hasVideo = videoUrl != null && videoUrl.isNotEmpty;
    final isVideo = post.isVideo && hasVideo;
    final placeholderColor = theme.dividerColor.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.12 : 0.06,
    );
    final showViewCount = isVideo && post.viewCount > 0;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: hasCover || !isVideo ? placeholderColor : Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasCover)
                SafeNetworkImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorIcon: Icons.image_outlined,
                  showLoadingIndicator: false,
                ),
              if (hasVideo)
                ProfileGridVideoBackground(
                  videoUrl: videoUrl,
                  posterUrl: coverUrl,
                )
              else if (!hasCover && isVideo)
                const VideoPostPreviewPlaceholder(
                  iconSize: ProfileLayoutConstants.gridPlaceholderIconSize,
                )
              else if (!hasCover)
                Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: ProfileLayoutConstants.gridPlaceholderIconSize,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
        ),
        if (!isVideo)
          const Center(
            child: Icon(
              LucideIcons.image,
              size: 18,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Color(0x99000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        if (showOriginalBadge)
          Positioned(
            left: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: SoundPickerTheme.accentOf(context),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                l10n.soundOriginalBadge,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
        if (showViewCount) ...[
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 36,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x99000000)],
                ),
              ),
            ),
          ),
          PositionedDirectional(
            start: 6,
            bottom: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.play,
                  size: ProfileLayoutConstants.gridViewCountIconSize,
                  color: Colors.white,
                ),
                const SizedBox(width: 3),
                Text(
                  formatCompactCount(post.viewCount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: ProfileLayoutConstants.gridViewCountFontSize,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    shadows: [Shadow(color: Color(0x80000000), blurRadius: 4)],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Kept for any legacy callers; prefer [SoundDetailCover] on the detail page.
class SoundSpinningDisc extends StatelessWidget {
  const SoundSpinningDisc({
    super.key,
    required this.rotation,
    required this.size,
    this.coverUrl,
    this.isPlaying = false,
    this.onTap,
  });

  final Animation<double> rotation;
  final double size;
  final String? coverUrl;
  final bool isPlaying;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SoundDetailCover(
      coverUrl: coverUrl,
      isPlaying: isPlaying,
      onTap: onTap,
      size: size,
    );
  }
}

class SoundDetailEmptyPosts extends StatelessWidget {
  const SoundDetailEmptyPosts({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(
          alpha: 0.45,
        );
    return Padding(
      padding: const EdgeInsets.all(AppSizes.p24),
      child: Center(
        child: Text(
          l10n.soundNoVideosYet,
          style: TextStyle(color: muted, fontSize: 14),
        ),
      ),
    );
  }
}
