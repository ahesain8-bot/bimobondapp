import 'package:bimobondapp/app/home/presentation/widgets/add_post/add_post_privacy_picker_sheet.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/custom_button.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class EditPostScreen extends StatefulWidget {
  final PostEntity post;

  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late final TextEditingController _descriptionController;

  late String _privacyStatus;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final post = widget.post;
    _descriptionController = TextEditingController(
      text: post.description ?? '',
    );
    _privacyStatus = post.privacyStatus;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    context.read<PostsBloc>().add(
      UpdatePostRequestedEvent(
        postId: widget.post.id,
        description: _descriptionController.text.trim(),
        privacyStatus: _privacyStatus,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final media = widget.post.media;

    return Scaffold(
      appBar: CustomAppBar(title: l10n.editPost, showBackButton: true),
      body: BlocListener<PostsBloc, PostsState>(
        listener: (context, state) {
          if (state is UpdatePostSuccess && state.post.id == widget.post.id) {
            setState(() => _isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.postUpdatedSuccessfully)),
            );
            context.pop(state.post);
          } else if (state is PostsFailure && _isSaving) {
            setState(() => _isSaving = false);
            PopupDialogs.showErrorDialog(context, state.message);
          }
        },
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.p16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: l10n.describePostHint,
                        border: InputBorder.none,
                      ),
                    ),
                    if (media.isNotEmpty) ...[
                      const SizedBox(height: AppSizes.p16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CustomText(
                            l10n.mediaLabel,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.p10,
                              vertical: AppSizes.p4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(AppSizes.p12),
                            ),
                            child: CustomText(
                              '${media.length}',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.p8),
                      SizedBox(
                        height: 90,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          itemCount: media.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: AppSizes.p8),
                          itemBuilder: (context, index) =>
                              _buildReadOnlyMediaTile(media[index]),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSizes.p24),
                    Divider(color: theme.colorScheme.outlineVariant),
                    _buildSettingItem(
                      icon: LucideIcons.lock,
                      title: l10n.whoCanWatchLabel,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CustomText(
                            _privacyLabel(_privacyStatus, l10n),
                            variant: TextVariant.secondary,
                            fontSize: 14,
                          ),
                          _chevronIcon(),
                        ],
                      ),
                      onTap: _showPrivacyPicker,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSizes.p16,
                AppSizes.p16,
                AppSizes.p16,
                MediaQuery.of(context).padding.bottom + AppSizes.p16,
              ),
              child: CustomButton(
                onPressed: _isSaving ? null : _save,
                text: l10n.saveButton,
                isLoading: _isSaving,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _privacyLabel(String status, AppLocalizations l10n) {
    return localizedAddPostPrivacyStatus(status, l10n);
  }

  Widget _buildReadOnlyMediaTile(PostMediaEntity media) {
    final isVideo = MediaUtils.isVideo(media.url, mediaType: media.mediaType);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: Image.network(
        media.url,
        width: 80,
        height: 90,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => SizedBox(
          width: 80,
          height: 90,
          child: ColoredBox(
            color: Colors.grey.shade800,
            child: Icon(
              isVideo ? LucideIcons.video : LucideIcons.image,
              color: Colors.white54,
            ),
          ),
        ),
      ),
    );
  }

  Icon _chevronIcon() {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Icon(
      isRtl ? LucideIcons.chevronLeft : LucideIcons.chevronRight,
      size: 16,
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSizes.p12),
            Expanded(
              child: CustomText(
                title,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  void _showPrivacyPicker() {
    AddPostPrivacyPickerSheet.show(
      context,
      selectedStatus: _privacyStatus,
      onSelected: (status) => setState(() => _privacyStatus = status),
    );
  }
}
