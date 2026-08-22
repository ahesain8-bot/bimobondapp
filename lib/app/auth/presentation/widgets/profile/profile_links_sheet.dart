import 'package:bimobondapp/app/auth/domain/entities/profile_enums.dart';
import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/profile/social_brand_icon.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileLinksSheet extends StatelessWidget {
  const ProfileLinksSheet({
    required this.user,
    this.extraLinks = const [],
    super.key,
  });

  final UserEntity user;
  final List<ProfileLinkEntity> extraLinks;

  static void show(
    BuildContext context, {
    required UserEntity user,
    List<ProfileLinkEntity> extraLinks = const [],
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfileLinksSheet(user: user, extraLinks: extraLinks),
    );
  }

  Future<void> _openUrl(BuildContext context, String rawUrl) async {
    var url = rawUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final allItems = <Map<String, String>>[];

    if (user.websiteUrl != null && user.websiteUrl!.isNotEmpty) {
      allItems.add({'label': 'Website', 'url': user.websiteUrl!});
    }
    if (user.instagramUrl != null && user.instagramUrl!.isNotEmpty) {
      allItems.add({'label': 'Instagram', 'url': user.instagramUrl!});
    }
    if (user.youtubeUrl != null && user.youtubeUrl!.isNotEmpty) {
      allItems.add({'label': 'YouTube', 'url': user.youtubeUrl!});
    }
    if (user.tiktokUrl != null && user.tiktokUrl!.isNotEmpty) {
      allItems.add({'label': 'TikTok', 'url': user.tiktokUrl!});
    }
    if (user.twitterUrl != null && user.twitterUrl!.isNotEmpty) {
      allItems.add({'label': 'Twitter / X', 'url': user.twitterUrl!});
    }
    if (user.snapchatUrl != null && user.snapchatUrl!.isNotEmpty) {
      allItems.add({'label': 'Snapchat', 'url': user.snapchatUrl!});
    }
    if (user.spotifyUrl != null && user.spotifyUrl!.isNotEmpty) {
      allItems.add({'label': 'Spotify', 'url': user.spotifyUrl!});
    }

    for (final extra in extraLinks) {
      allItems.add({
        'label': extra.label ?? 'Link',
        'url': extra.url,
      });
    }

    if (user.profileLinks != null) {
      for (final pl in user.profileLinks!) {
        if (!allItems.any((item) => item['url'] == pl.url)) {
          allItems.add({
            'label': pl.label ?? 'Link',
            'url': pl.url,
          });
        }
      }
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      padding: EdgeInsets.only(
        left: AppSizes.p20,
        right: AppSizes.p20,
        top: AppSizes.p16,
        bottom: MediaQuery.of(context).padding.bottom + AppSizes.p20,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSizes.p16),
          Row(
            children: [
              const Icon(Icons.link_rounded, size: 20),
              const SizedBox(width: 8),
              CustomText(
                l10n.profileLinksTitle,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          if (allItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: CustomText(
                l10n.noLinksAddedYet,
                variant: TextVariant.secondary,
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: allItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = allItems[index];
                  final label = item['label']!;
                  final url = item['url']!;

                  return Material(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openUrl(context, url),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            SocialBrandIcon(
                              brandKey: label.isNotEmpty ? label : url,
                              size: 32,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CustomText(
                                    label,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    url,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurface.withValues(alpha: 0.6),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.open_in_new_rounded,
                              size: 16,
                              color: cs.onSurface.withValues(alpha: 0.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
