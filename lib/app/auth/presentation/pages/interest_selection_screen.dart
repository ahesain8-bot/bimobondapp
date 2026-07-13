import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_event.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/onboarding/interest_selection_view.dart';
import 'package:bimobondapp/app/categories/domain/entities/category_entity.dart';
import 'package:bimobondapp/app/categories/domain/usecases/get_categories_usecase.dart';
import 'package:bimobondapp/app/categories/presentation/di/categories_injector.dart'
    as categories_di;
import 'package:bimobondapp/app/interests/domain/usecases/get_my_interests_usecase.dart';
import 'package:bimobondapp/app/interests/domain/usecases/set_my_interests_usecase.dart';
import 'package:bimobondapp/app/interests/presentation/di/interests_injector.dart'
    as interests_di;
import 'package:bimobondapp/core/theme/cubit/locale_cubit.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class InterestSelectionScreen extends StatefulWidget {
  const InterestSelectionScreen({
    this.pendingVerificationEmail,
    this.isEditMode = false,
    super.key,
  });

  final String? pendingVerificationEmail;
  final bool isEditMode;

  @override
  State<InterestSelectionScreen> createState() =>
      _InterestSelectionScreenState();
}

class _InterestSelectionScreenState extends State<InterestSelectionScreen> {
  final Set<String> _interestedIds = {};
  final Set<String> _notInterestedIds = {};
  List<CategoryEntity> _categories = [];
  bool _isLoadingCategories = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoadingCategories = true;
      _errorMessage = null;
    });

    final categoriesResult =
        await categories_di.sl<GetCategoriesUseCase>()(NoParams());

    if (!mounted) return;

    final failureMessage = categoriesResult.fold(
      (failure) => failure.message,
      (categories) {
        _categories = categories;
        return null;
      },
    );

    if (failureMessage != null) {
      setState(() {
        _isLoadingCategories = false;
        _errorMessage = failureMessage;
      });
      return;
    }

    if (widget.isEditMode) {
      final interestsResult =
          await interests_di.sl<GetMyInterestsUseCase>()(NoParams());

      if (!mounted) return;

      interestsResult.fold(
        (failure) {
          // Categories loaded; allow picking even if preload fails.
          setState(() {
            _isLoadingCategories = false;
            _errorMessage = null;
          });
          PopupDialogs.showErrorDialog(context, failure.message);
        },
        (result) {
          _interestedIds
            ..clear()
            ..addAll(result.interests.map((e) => e.categoryId));
          _notInterestedIds
            ..clear()
            ..addAll(result.notInterests.map((e) => e.categoryId));
          setState(() {
            _isLoadingCategories = false;
            _errorMessage = null;
          });
        },
      );
      return;
    }

    setState(() {
      _isLoadingCategories = false;
      _errorMessage = null;
    });
  }

  bool get _canSkip {
    if (widget.isEditMode) return false;
    final authState = context.read<AuthBloc>().state;
    return authState is AuthSuccess && authState.user.needsInterests != true;
  }

  void _cycleCategory(String categoryId) {
    setState(() {
      if (_interestedIds.contains(categoryId)) {
        _interestedIds.remove(categoryId);
        if (_notInterestedIds.length <
            InterestSelectionView.maxNotInterestedCount) {
          _notInterestedIds.add(categoryId);
        }
      } else if (_notInterestedIds.contains(categoryId)) {
        _notInterestedIds.remove(categoryId);
      } else {
        if (_interestedIds.length < InterestSelectionView.maxInterestedCount) {
          _interestedIds.add(categoryId);
        }
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

  void _onBackPressed() {
    if (context.canPop()) {
      context.pop();
    }
  }

  Future<void> _onContinuePressed() async {
    if (_interestedIds.length < InterestSelectionView.minSelectionCount ||
        _interestedIds.length > InterestSelectionView.maxInterestedCount ||
        _notInterestedIds.length > InterestSelectionView.maxNotInterestedCount) {
      return;
    }

    setState(() => _isSaving = true);

    final result = await interests_di.sl<SetMyInterestsUseCase>()(
      SetMyInterestsParams(
        categoryIds: _interestedIds.toList(growable: false),
        notInterestedCategoryIds: _notInterestedIds.isEmpty
            ? null
            : _notInterestedIds.toList(growable: false),
      ),
    );

    if (!mounted) return;

    await result.fold(
      (failure) async {
        setState(() => _isSaving = false);
        PopupDialogs.showErrorDialog(context, failure.message);
      },
      (_) async {
        context.read<AuthBloc>().add(const FetchProfileEvent());
        setState(() => _isSaving = false);
        if (widget.isEditMode) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.goNamed('home');
          }
        } else {
          _navigateNext();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocaleCubit, Locale>(
      builder: (context, locale) {
        final l10n = AppLocalizations.of(context)!;
        final isArabic = locale.languageCode == 'ar';
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return InterestSelectionView(
          l10n: l10n,
          isArabic: isArabic,
          isDark: isDark,
          categories: _categories,
          interestedIds: _interestedIds,
          notInterestedIds: _notInterestedIds,
          isLoadingCategories: _isLoadingCategories,
          isSaving: _isSaving,
          errorMessage: _errorMessage,
          showSkip: _canSkip,
          isEditMode: widget.isEditMode,
          onCategoryCycled: _cycleCategory,
          onRetryPressed: _loadInitialData,
          onSkipPressed: _onSkipPressed,
          onContinuePressed: _onContinuePressed,
          onBackPressed: widget.isEditMode ? _onBackPressed : null,
        );
      },
    );
  }
}
