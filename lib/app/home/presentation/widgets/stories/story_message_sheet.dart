import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/home/presentation/utils/story_message_flow.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_shared_preview.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
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
    return GlassBottomSheet.showContent<void>(
      context,
      isScrollControlled: true,
      adaptTheme: true,
      title: AppLocalizations.of(context)!.storySendMessageTitle,
      child: StoryMessageSheet(story: story),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.p16,
        0,
        AppSizes.p16,
        AppSizes.p16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.p12),
              FilledButton.icon(
                onPressed: _sending ? null : _send,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                  foregroundColor: Colors.white,
                ),
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
        );
  }
}
