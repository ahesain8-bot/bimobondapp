import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_sheets.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _maxRepostQuoteLength = 100;

class RepostSheet {
  RepostSheet._();

  static Future<void> show({
    required BuildContext context,
    required void Function(String? quote) onRepost,
  }) {
    final sheetTheme = Theme.of(context);
    return GlassBottomSheet.open<void>(
      context,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) {
        return Theme(
          data: sheetTheme,
          child: _RepostComposeSheet(onRepost: onRepost),
        );
      },
    );
  }

  static void _insertMentionTrigger(
    TextEditingController controller,
    FocusNode focusNode,
  ) {
    final text = controller.text;
    final selection = controller.selection;
    final cursor = selection.isValid ? selection.baseOffset : text.length;
    final needsSpace =
        cursor > 0 && text[cursor - 1] != ' ' && text[cursor - 1] != '\n';
    final insert = needsSpace ? ' @' : '@';
    final newText = text.replaceRange(cursor, cursor, insert);
    final newOffset = cursor + insert.length;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    focusNode.requestFocus();
  }
}

class _RepostComposeSheet extends StatefulWidget {
  const _RepostComposeSheet({required this.onRepost});

  final void Function(String? quote) onRepost;

  @override
  State<_RepostComposeSheet> createState() => _RepostComposeSheetState();
}

class _RepostComposeSheetState extends State<_RepostComposeSheet> {
  final _quoteController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _quoteController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _quoteController.text.trim();
    Navigator.pop(context);
    if (raw.isEmpty) return;
    final quote = raw.substring(0, raw.length.clamp(0, _maxRepostQuoteLength));
    widget.onRepost(quote);
  }

  void _skip() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final topGap = MediaQuery.sizeOf(context).height * 0.18;

    final cardFill = theme.brightness == Brightness.dark
        ? cs.surfaceContainerHigh
        : cs.surfaceContainerHighest;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: topGap),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
            child: Material(
              color: cs.surface,
              elevation: theme.brightness == Brightness.light ? 4 : 0,
              shadowColor: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.p12,
                  AppSizes.p12,
                  AppSizes.p12,
                  AppSizes.p12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.repostComposeTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: AppSizes.p12),
                    Material(
                      color: cardFill,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSizes.p12,
                          AppSizes.p12,
                          AppSizes.p12,
                          AppSizes.p10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ComposeAvatar(),
                                const SizedBox(width: AppSizes.p10),
                                Expanded(
                                  child: TextField(
                                    controller: _quoteController,
                                    focusNode: _focusNode,
                                    maxLines: 4,
                                    minLines: 2,
                                    maxLength: _maxRepostQuoteLength,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: cs.onSurface,
                                      fontSize: 14,
                                      height: 1.35,
                                    ),
                                    cursorColor: cs.primary,
                                    decoration: InputDecoration(
                                      hintText: l10n.repostComposeHint,
                                      hintStyle:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      counterText: '',
                                      contentPadding: EdgeInsets.zero,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.p6),
                            Row(
                              children: [
                                _ComposeIconButton(
                                  icon: LucideIcons.atSign,
                                  onTap: () =>
                                      RepostSheet._insertMentionTrigger(
                                    _quoteController,
                                    _focusNode,
                                  ),
                                ),
                                _ComposeIconButton(
                                  icon: LucideIcons.smile,
                                  onTap: () {
                                    _focusNode.unfocus();
                                    ChatSheets.showEmojiPicker(
                                      context: context,
                                      messageController: _quoteController,
                                      onEmojiInserted: () {
                                        _focusNode.requestFocus();
                                      },
                                    );
                                  },
                                ),
                                const Spacer(),
                                _AddRepostButton(
                                  label: l10n.repostComposeAdd,
                                  onTap: _submit,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.p8),
          TextButton(
            onPressed: _skip,
            style: TextButton.styleFrom(
              foregroundColor: cs.onSurfaceVariant,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(l10n.cancel),
          ),
          const SizedBox(height: AppSizes.p8),
        ],
      ),
    );
  }
}

class _ComposeAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: cs.surfaceContainerHighest,
        child: Icon(LucideIcons.user, size: 18, color: cs.onSurfaceVariant),
      );
    }
    final user = authState.user;
    return SafeNetworkAvatar(
      imageUrl: user.avatarUrl,
      radius: 18,
      fallbackText: user.username ?? user.fullName,
      backgroundColor: cs.surfaceContainerHighest,
    );
  }
}

class _ComposeIconButton extends StatelessWidget {
  const _ComposeIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      icon: Icon(icon, size: 22, color: cs.onSurfaceVariant),
    );
  }
}

class _AddRepostButton extends StatelessWidget {
  const _AddRepostButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.primary.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: cs.primary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
