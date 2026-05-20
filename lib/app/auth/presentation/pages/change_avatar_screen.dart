import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_event.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart';
import 'package:bimobondapp/app/auth/domain/usecases/upload_avatar_usecase.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChangeAvatarScreen extends StatefulWidget {
  const ChangeAvatarScreen({super.key});

  @override
  State<ChangeAvatarScreen> createState() => _ChangeAvatarScreenState();
}

class _ChangeAvatarScreenState extends State<ChangeAvatarScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;
  File? _selectedFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: CustomAppBar(title: l10n.changeProfilePhoto),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (!_isUploading) return;

          if (state is AuthSuccess) {
            _isUploading = false;
            PopupDialogs.showSuccessDialog(
              context,
              l10n.profileUpdatedSuccessfully,
            );
            Future.microtask(() => context.pop());
          } else if (state is AuthFailure) {
            _isUploading = false;
            PopupDialogs.showErrorDialog(
              context,
              state.messageKey != null
                  ? l10n.updateProfileFailed
                  : state.message,
            );
          }
        },
        child: Column(
          children: [
            const SizedBox(height: AppSizes.p32),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 100,
                    backgroundColor: theme.colorScheme.surfaceVariant,
                    backgroundImage: _selectedFile != null
                        ? FileImage(_selectedFile!)
                        : null,
                    child: _selectedFile == null
                        ? Icon(
                            LucideIcons.user,
                            size: 80,
                            color: theme.disabledColor,
                          )
                        : null,
                  ),
                  if (_isUploading)
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const CustomLoadingWidget(size: 60),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.p48),
            _buildOption(
              context,
              icon: LucideIcons.camera,
              label: l10n.takePhoto,
              onTap: () => _pickAndUpload(ImageSource.camera),
            ),
            _buildOption(
              context,
              icon: LucideIcons.image,
              label: l10n.selectFromGallery,
              onTap: () => _pickAndUpload(ImageSource.gallery),
            ),
            _buildOption(
              context,
              icon: LucideIcons.trash2,
              label: l10n.removeCurrentPhoto,
              isDestructive: true,
              onTap: () => _removeCurrentPhoto(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    if (_isUploading) return;

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      setState(() {
        _selectedFile = file;
      });

      await _uploadAvatar(file);
    } on PlatformException catch (e) {
      PopupDialogs.showErrorDialog(
        context,
        'Unable to pick image: ${e.message ?? 'unexpected error'}',
      );
    } catch (e) {
      PopupDialogs.showErrorDialog(
        context,
        'Unable to pick image. Please restart the app and try again.',
      );
    }
  }

  Future<void> _uploadAvatar(File file) async {
    setState(() {
      _isUploading = true;
    });

    final result = await sl<UploadAvatarUseCase>().call(file);
    result.fold(
      (failure) {
        setState(() {
          _isUploading = false;
        });
        PopupDialogs.showErrorDialog(context, 'Failed to upload avatar');
      },
      (uploadedUrl) {
        final normalizedUrl = _normalizeAvatarUrl(uploadedUrl);
        context.read<AuthBloc>().add(
          UpdateProfileRequestedEvent({'avatarUrl': normalizedUrl}),
        );
      },
    );
  }

  Future<void> _removeCurrentPhoto() async {
    if (_isUploading) return;
    setState(() {
      _selectedFile = null;
      _isUploading = true;
    });
    context.read<AuthBloc>().add(
      UpdateProfileRequestedEvent({'avatarUrl': null}),
    );
  }

  String _normalizeAvatarUrl(String url) {
    if (url.toLowerCase().startsWith('http')) {
      return url;
    }
    return '${ApiConstants.baseUrl}$url';
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p24,
          vertical: AppSizes.p16,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isDestructive ? Colors.red : theme.iconTheme.color,
            ),
            const SizedBox(width: AppSizes.p16),
            Expanded(
              child: CustomText(
                label,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDestructive ? Colors.red : null,
              ),
            ),
            Icon(
              isRTL ? LucideIcons.chevronLeft : LucideIcons.chevronRight,
              size: 18,
              color: theme.disabledColor.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }
}
