import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/home/presentation/utils/story_message_flow.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_shared_preview.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Send a direct message about a story (not a public comment).
class StoryMessageSheet extends StatefulWidget {
  const StoryMessageSheet({
    required this.story,
    super.key,
  });

  final PostEntity story;

  static Future<void> show(BuildContext context, {required PostEntity story}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: StoryMessageSheet(story: story),
      ),
    );
  }

  @override
  State<StoryMessageSheet> createState() => _StoryMessageSheetState();
}

class _StoryMessageSheetState extends State<StoryMessageSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    final chat = await resolveStoryOwnerChat(
      context,
      storyOwnerId: widget.story.userId,
    );
    if (!mounted) return;

    if (chat == null) {
      setState(() => _sending = false);
      PopupDialogs.showErrorDialog(
        context,
        AppLocalizations.of(context)!.storyMessageSendFailed,
      );
      return;
    }

    final ok = await sendStoryReplyMessage(
      story: widget.story,
      chatId: chat.id,
      text: text,
    );
    if (!mounted) return;

    setState(() => _sending = false);
    if (!ok) {
      PopupDialogs.showErrorDialog(
        context,
        AppLocalizations.of(context)!.storyMessageSendFailed,
      );
      return;
    }

    Navigator.pop(context);
    final l10n = AppLocalizations.of(context)!;
    final username = widget.story.user?.username.trim() ?? '';
    final name = username.isNotEmpty ? username : 'User';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.storyMessageSent(name))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSizes.p16),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.p16,
            AppSizes.p10,
            AppSizes.p16,
            AppSizes.p16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.p12),
              Text(
                l10n.storySendMessageTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSizes.p12),
              StorySharedPreview(post: widget.story),
              const SizedBox(height: AppSizes.p12),
              TextField(
                controller: _controller,
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: l10n.storySendMessageHint,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.p12),
              FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.send, size: 18),
                label: Text(l10n.profileMessageButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
