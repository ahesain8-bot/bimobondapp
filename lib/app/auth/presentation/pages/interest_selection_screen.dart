import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_event.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/auth/presentation/utils/auth_message_localizer.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/onboarding/interest_selection_view.dart';
import 'package:bimobondapp/app/categories/domain/entities/category_entity.dart';
import 'package:bimobondapp/app/categories/domain/usecases/get_categories_usecase.dart';
import 'package:bimobondapp/app/categories/presentation/di/categories_injector.dart'
    as categories_di;
import 'package:bimobondapp/core/theme/cubit/locale_cubit.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class InterestSelectionScreen extends StatefulWidget {
  const InterestSelectionScreen({this.pendingVerificationEmail, super.key});

  final String? pendingVerificationEmail;

  @override
  State<InterestSelectionScreen> createState() => _InterestSelectionScreenState();
}

class _InterestSelectionScreenState extends State<InterestSelectionScreen> {
  final Set<String> _selectedCategoryIds = {};
  List<CategoryEntity> _categories = [];
  bool _isLoadingCategories = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
      _errorMessage = null;
    });

    final result = await categories_di.sl<GetCategoriesUseCase>()(NoParams());

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _isLoadingCategories = false;
        _errorMessage = failure.message;
      }),
      (categories) => setState(() {
        _isLoadingCategories = false;
        _categories = categories;
      }),
    );
  }

  void _toggleCategory(String categoryId) {
    setState(() {
      if (_selectedCategoryIds.contains(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
      } else {
        _selectedCategoryIds.add(categoryId);
      }
    });
  }

  void _navigateNext() {
    final email = widget.pendingVerificationEmail?.trim();
    if (email != null && email.isNotEmpty) {
      context.goNamed(
        'email_verification',
        queryParameters: {'email': email},
      );
      return;
    }

    context.goNamed('home');
  }

  void _onSkipPressed() {
    _navigateNext();
  }

  void _onContinuePressed() {
    if (_selectedCategoryIds.length < InterestSelectionView.minSelectionCount) {
      return;
    }

    setState(() => _isSaving = true);
    context.read<AuthBloc>().add(
      UpdateProfileRequestedEvent({
        'categoryIds': _selectedCategoryIds.toList(growable: false),
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocaleCubit, Locale>(
      builder: (context, locale) {
        final l10n = AppLocalizations.of(context)!;
        final isArabic = locale.languageCode == 'ar';
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return BlocListener<AuthBloc, AuthState>(
          listenWhen: (previous, current) =>
              current is AuthSuccess || current is AuthFailure,
          listener: (context, state) {
            if (!_isSaving) return;

            if (state is AuthSuccess) {
              setState(() => _isSaving = false);
              _navigateNext();
            } else if (state is AuthFailure) {
              setState(() => _isSaving = false);
              final message = state.messageKey != null
                  ? localizeAuthMessage(l10n, state.messageKey!)
                  : state.message;
              PopupDialogs.showErrorDialog(context, message);
            }
          },
          child: InterestSelectionView(
            l10n: l10n,
            isArabic: isArabic,
            isDark: isDark,
            categories: _categories,
            selectedCategoryIds: _selectedCategoryIds,
            isLoadingCategories: _isLoadingCategories,
            isSaving: _isSaving,
            errorMessage: _errorMessage,
            onCategoryToggled: _toggleCategory,
            onRetryPressed: _loadCategories,
            onSkipPressed: _onSkipPressed,
            onContinuePressed: _onContinuePressed,
          ),
        );
      },
    );
  }
}
