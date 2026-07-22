import 'dart:io';

import 'package:bimobondapp/app/seller_verification/domain/entities/seller_verification_entities.dart';
import 'package:bimobondapp/app/seller_verification/domain/usecases/seller_verification_usecases.dart';
import 'package:bimobondapp/app/seller_verification/presentation/di/seller_verification_injector.dart'
    as seller_di;
import 'package:bimobondapp/app/seller_verification/presentation/widgets/seller_verification_widgets.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_button.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/custom_text_field.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Seller verification: national ID number + passport photo only.
class SellerVerificationScreen extends StatefulWidget {
  const SellerVerificationScreen({super.key});

  @override
  State<SellerVerificationScreen> createState() =>
      _SellerVerificationScreenState();
}

class _SellerVerificationScreenState extends State<SellerVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nationalIdController = TextEditingController();

  File? _passportFile;
  String? _passportFrontKey;
  String? _rejectionReason;
  bool _loading = true;
  bool _submitting = false;
  bool _uploading = false;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _nationalIdController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final result = await seller_di.sl<GetSellerVerificationMeUseCase>()(
      NoParams(),
    );
    if (!mounted) return;

    result.fold(
      (_) => setState(() => _loading = false),
      (status) {
        final record = status.verification;
        if (record != null) {
          _nationalIdController.text = record.nationalIdNumber ?? '';
          _passportFrontKey = record.passportFrontUrl;
        }
        setState(() {
          _rejectionReason =
              status.rejectionReason ?? record?.rejectionReason;
          _loading = false;
        });
      },
    );
  }

  Future<void> _pickAndUploadPassport() async {
    final l10n = AppLocalizations.of(context)!;
    final source = await GlassBottomSheet.showActions<ImageSource>(
      context,
      title: l10n.sellerVerificationPassportPhoto,
      children: [
        GlassBottomSheetListTile(
          icon: LucideIcons.camera,
          label: l10n.takePhoto,
          onTap: () => Navigator.pop(context, ImageSource.camera),
        ),
        GlassBottomSheetListTile(
          icon: LucideIcons.image,
          label: l10n.uploadFromLibrary,
          onTap: () => Navigator.pop(context, ImageSource.gallery),
        ),
      ],
    );
    if (source == null || !mounted) return;

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final file = File(picked.path);
    setState(() {
      _uploading = true;
      _passportFile = file;
    });

    final result = await seller_di.sl<UploadSellerDocumentUseCase>()(file);
    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _uploading = false;
          _passportFile = null;
        });
        PopupDialogs.showErrorDialog(context, failure.message);
      },
      (key) {
        setState(() {
          _uploading = false;
          _passportFrontKey = key;
        });
      },
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    if (_passportFrontKey == null || _passportFrontKey!.isEmpty) {
      PopupDialogs.showErrorDialog(
        context,
        l10n.sellerVerificationPassportFrontRequired,
      );
      return;
    }

    setState(() => _submitting = true);
    final result = await seller_di.sl<SubmitSellerVerificationUseCase>()(
      SubmitSellerVerificationInput(
        nationalIdNumber: _nationalIdController.text.trim(),
        passportFrontUrl: _passportFrontKey!,
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      (failure) => PopupDialogs.showErrorDialog(context, failure.message),
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sellerVerificationSubmitted)),
        );
        context.pop(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final uploaded =
        _passportFrontKey != null && _passportFrontKey!.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => context.pop(false),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        title: CustomText(
          l10n.sellerVerificationTitle,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: _loading
          ? const CustomLoadingWidget(isFullScreen: true, size: 100)
          : SafeArea(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSizes.p16,
                          AppSizes.p8,
                          AppSizes.p16,
                          AppSizes.p24,
                        ),
                        children: [
                          CustomText(
                            l10n.sellerVerificationSubtitleSimple,
                            fontSize: 14,
                            variant: TextVariant.secondary,
                          ),
                          if (_rejectionReason != null &&
                              _rejectionReason!.trim().isNotEmpty) ...[
                            const SizedBox(height: AppSizes.p12),
                            SellerVerificationRejectionBanner(
                              reason: _rejectionReason!,
                            ),
                          ],
                          const SizedBox(height: AppSizes.p24),
                          CustomText(
                            l10n.sellerVerificationNationalId,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          const SizedBox(height: AppSizes.p8),
                          CustomTextField(
                            controller: _nationalIdController,
                            hintText: l10n.sellerVerificationNationalId,
                            icon: LucideIcons.idCard,
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty || text.length > 40) {
                                return l10n
                                    .sellerVerificationNationalIdRequired;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSizes.p20),
                          CustomText(
                            l10n.sellerVerificationPassportPhoto,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          const SizedBox(height: AppSizes.p8),
                          SellerVerificationPassportPicker(
                            file: _passportFile,
                            uploaded: uploaded,
                            loading: _uploading,
                            onTap: _pickAndUploadPassport,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSizes.p16,
                        AppSizes.p8,
                        AppSizes.p16,
                        AppSizes.p16,
                      ),
                      child: CustomButton(
                        text: l10n.sellerVerificationSubmit,
                        isLoading: _submitting,
                        onPressed: _uploading || _submitting ? null : _submit,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
