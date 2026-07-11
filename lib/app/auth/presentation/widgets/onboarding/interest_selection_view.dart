import 'package:bimobondapp/app/auth/presentation/widgets/onboarding/interest_category_chip.dart';
import 'package:bimobondapp/app/categories/domain/entities/category_entity.dart';
import 'package:bimobondapp/app/categories/presentation/utils/category_icons.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_auth_widgets.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InterestSelectionView extends StatelessWidget {
  const InterestSelectionView({
    required this.l10n,
    required this.isArabic,
    required this.isDark,
    required this.categories,
    required this.selectedCategoryIds,
    required this.isLoadingCategories,
    required this.isSaving,
    required this.errorMessage,
    required this.onCategoryToggled,
    required this.onRetryPressed,
    required this.onSkipPressed,
    required this.onContinuePressed,
    super.key,
  });

  static const int minSelectionCount = 3;

  final AppLocalizations l10n;
  final bool isArabic;
  final bool isDark;
  final List<CategoryEntity> categories;
  final Set<String> selectedCategoryIds;
  final bool isLoadingCategories;
  final bool isSaving;
  final String? errorMessage;
  final ValueChanged<String> onCategoryToggled;
  final VoidCallback onRetryPressed;
  final VoidCallback onSkipPressed;
  final VoidCallback onContinuePressed;

  bool get _canContinue =>
      selectedCategoryIds.length >= minSelectionCount && !isSaving;

  @override
  Widget build(BuildContext context) {
    final textDirection = isArabic ? TextDirection.rtl : TextDirection.ltr;
    final scaffoldColor = Theme.of(context).scaffoldBackgroundColor;

    return Directionality(
      textDirection: textDirection,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: scaffoldColor,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.p8,
                    AppSizes.p8,
                    AppSizes.p16,
                    0,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: isSaving ? null : onSkipPressed,
                      child: CustomText(
                        l10n.interestSelectionSkip,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.p24,
                      AppSizes.p8,
                      AppSizes.p24,
                      AppSizes.p24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomText(
                          l10n.interestSelectionTitle,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                        const SizedBox(height: AppSizes.p12),
                        CustomText(
                          l10n.interestSelectionSubtitle,
                          variant: TextVariant.secondary,
                          fontSize: 16,
                          textAlign: TextAlign.start,
                        ),
                        const SizedBox(height: AppSizes.p8),
                        CustomText(
                          l10n.interestSelectionMinHint(minSelectionCount),
                          variant: TextVariant.secondary,
                          fontSize: 14,
                          textAlign: TextAlign.start,
                        ),
                        const SizedBox(height: AppSizes.p24),
                        if (isLoadingCategories)
                          const Center(child: CustomLoadingWidget())
                        else if (errorMessage != null)
                          _ErrorState(
                            message: errorMessage!,
                            retryLabel: l10n.retry,
                            onRetryPressed: onRetryPressed,
                          )
                        else
                          Wrap(
                            spacing: AppSizes.p10,
                            runSpacing: AppSizes.p10,
                            children: [
                              for (final category in categories)
                                InterestCategoryChip(
                                  label: category.name,
                                  icon: categoryIconForSlug(category.slug),
                                  isSelected: selectedCategoryIds.contains(
                                    category.id,
                                  ),
                                  onTap: () => onCategoryToggled(category.id),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.p24,
                    0,
                    AppSizes.p24,
                    AppSizes.p16,
                  ),
                  child: LiquidGlassAuthPrimaryButton(
                    onPressed: _canContinue ? onContinuePressed : null,
                    enabled: _canContinue,
                    child: isSaving
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : CustomText(
                            l10n.interestSelectionContinue,
                            color: Colors.white,
                            fontSize: AppSizes.authControlFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.retryLabel,
    required this.onRetryPressed,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetryPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomText(
          message,
          variant: TextVariant.secondary,
          fontSize: 15,
        ),
        const SizedBox(height: AppSizes.p16),
        TextButton(
          onPressed: onRetryPressed,
          child: CustomText(
            retryLabel,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
