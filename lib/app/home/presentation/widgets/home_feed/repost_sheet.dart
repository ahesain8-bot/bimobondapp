import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_surface.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _maxRepostQuoteLength = 100;

class RepostSheet {
  RepostSheet._();

  static Future<void> show({
    required BuildContext context,
    required void Function(String? quote) onRepost,
  }) {
    return GlassBottomSheet.showContent<void>(
      context,
      isScrollControlled: true,
      adaptTheme: true,
      showHandle: false,
      child: _RepostSheetBody(onRepost: onRepost),
    );
  }

  static void _insertEmoji(TextEditingController controller, String emoji) {
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final newText = text.replaceRange(start, end, emoji);
    final offset = start + emoji.length;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

class _RepostSheetBody extends StatefulWidget {
  const _RepostSheetBody({required this.onRepost});

  final void Function(String? quote) onRepost;

  @override
  State<_RepostSheetBody> createState() => _RepostSheetBodyState();
}

class _RepostSheetBodyState extends State<_RepostSheetBody> {
  final _quoteController = TextEditingController();

  @override
  void dispose() {
    _quoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return GlassBottomSheetFrame(
      showHandle: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.p20,
          0,
          AppSizes.p20,
          AppSizes.p20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
                      children: [
                        Container(
                          width: 44,
                          height: AppSizes.buttonHeightSm,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF2ECC71).withValues(alpha: 0.18),
                            border: Border.all(
                              color: const Color(0xFF2ECC71).withValues(alpha: 0.45),
                            ),
                          ),
                          child: const Icon(
                            LucideIcons.repeat2,
                            color: Color(0xFF2ECC71),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: AppSizes.p12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.repostTitle,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.repostSubtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.65),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.p16),
                    LiquidGlassSurface(
                      borderRadius: BorderRadius.circular(16),
                      child: TextField(
                        controller: _quoteController,
                        maxLines: 3,
                        maxLength: _maxRepostQuoteLength,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: const Color(0xFF2ECC71),
                        decoration: InputDecoration(
                          hintText: l10n.repostQuoteHint,
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          counterStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                          contentPadding: const EdgeInsets.all(AppSizes.p12),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.p10),
                    _RepostQuoteEmojiSuggestions(
                      onEmojiSelected: (emoji) {
                        RepostSheet._insertEmoji(_quoteController, emoji);
                      },
                    ),
                    const SizedBox(height: AppSizes.p12),
                    FilledButton.icon(
                      onPressed: () {
                        final raw = _quoteController.text.trim();
                        final quote = raw.isEmpty
                            ? null
                            : raw.substring(
                                0,
                                raw.length.clamp(0, _maxRepostQuoteLength),
                              );
                        Navigator.pop(context);
                        widget.onRepost(quote);
                      },
                      icon: const Icon(LucideIcons.repeat2, size: 18),
                      label: Text(l10n.repostAction),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2ECC71),
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        l10n.cancel,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

class _RepostQuoteEmojiSuggestions extends StatelessWidget {
  const _RepostQuoteEmojiSuggestions({required this.onEmojiSelected});

  final ValueChanged<String> onEmojiSelected;

  static const List<String> emojis = [
    '😂',
    '❤️',
    '🔥',
    '👏',
    '🙌',
    '😍',
    '💯',
    '✨',
    '👍',
    '😮',
    '🎉',
    '💪',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: emojis.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSizes.p8),
        itemBuilder: (context, index) {
          final emoji = emojis[index];
          return GestureDetector(
            onTap: () => onEmojiSelected(emoji),
            child: LiquidGlassSurface(
              borderRadius: BorderRadius.circular(12),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.p10,
                vertical: AppSizes.p4,
              ),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 20, height: 1.1),
              ),
            ),
          );
        },
      ),
    );
  }
}
