import 'dart:io';

import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_event.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/auth/presentation/utils/auth_message_localizer.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/change_avatar/change_avatar_view.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/personal_info/personal_info_utils.dart';
import 'package:bimobondapp/app/posts/domain/usecases/upload_media_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class ChangeAvatarScreen extends StatefulWidget {
  const ChangeAvatarScreen({super.key});

  @override
  State<ChangeAvatarScreen> createState() => _ChangeAvatarScreenState();
}

class _ChangeAvatarScreenState extends State<ChangeAvatarScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;
  File? _selectedFile;

  Future<void> _pickAndUpload(ImageSource source) async {
    if (_isUploading) return;

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      setState(() => _selectedFile = file);

      await _uploadAvatar(file);
    } on PlatformException catch (e) {
      if (!mounted) return;
      PopupDialogs.showErrorDialog(
        context,
        'Unable to pick image: ${e.message ?? 'unexpected error'}',
      );
    } catch (e) {
      if (!mounted) return;
      PopupDialogs.showErrorDialog(
        context,
        'Unable to pick image. Please restart the app and try again.',
      );
    }
  }

  Future<void> _uploadAvatar(File file) async {
    setState(() => _isUploading = true);

    final uploadResult = await sl<UploadMediaUseCase>().call(file);
    if (!mounted) return;

    uploadResult.fold(
      (failure) {
        setState(() => _isUploading = false);
        PopupDialogs.showErrorDialog(context, 'Failed to upload avatar');
      },
      (uploadedUrl) {
        context.read<AuthBloc>().add(
          UpdateProfileRequestedEvent({'avatarUrl': uploadedUrl}),
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

  String _fallbackName(AuthState state) {
    if (state is AuthSuccess) {
      final name = state.user.fullName?.trim();
      if (name != null && name.isNotEmpty) return name;
      final username = state.user.username?.trim();
      if (username != null && username.isNotEmpty) return username;
    }
    return 'User';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          current is AuthSuccess || current is AuthFailure,
      listener: (context, state) {
        if (!_isUploading) return;

        if (state is AuthSuccess) {
          setState(() => _isUploading = false);
          PopupDialogs.showSuccessDialog(
            context,
            l10n.profileUpdatedSuccessfully,
          );
          Future.microtask(() {
            if (context.mounted) context.pop();
          });
        } else if (state is AuthFailure) {
          setState(() => _isUploading = false);
          final message = state.messageKey != null
              ? localizeAuthMessage(l10n, state.messageKey!)
              : state.message;
          PopupDialogs.showErrorDialog(context, message);
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          return ChangeAvatarView(
            l10n: l10n,
            avatarUrl: resolvePersonalInfoAvatarUrl(state: state),
            fallbackName: _fallbackName(state),
            selectedFile: _selectedFile,
            isUploading: _isUploading || state is AuthLoading,
            onTakePhotoTap: () => _pickAndUpload(ImageSource.camera),
            onGalleryTap: () => _pickAndUpload(ImageSource.gallery),
            onRemoveTap: _removeCurrentPhoto,
          );
        },
      ),
    );
  }
}
