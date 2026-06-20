import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/promotions/data/datasources/promotions_remote_data_source.dart';
import 'package:bimobondapp/app/promotions/domain/entities/promotion_entities.dart';
import 'package:bimobondapp/app/promotions/presentation/widgets/promote_post_widgets.dart';
import 'package:bimobondapp/core/data/user_location_store.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PromotePostScreen extends StatefulWidget {
  const PromotePostScreen({super.key, required this.post});

  final PostEntity post;

  @override
  State<PromotePostScreen> createState() => _PromotePostScreenState();
}

class _PromotePostScreenState extends State<PromotePostScreen> {
  final _remote = sl<PromotionsRemoteDataSource>();

  PromotionOptionsEntity? _options;
  List<PromotionPackageEntity> _packages = const [];
  PromoteStep _step = PromoteStep.goal;
  String? _objective;
  String? _selectedPackageId;
  bool _useCustomAudience = false;
  final Set<String> _genders = {};
  final Set<String> _languages = {};
  final Set<String> _categoryIds = {};
  int _ageMin = 18;
  int _ageMax = 34;
  int _radiusKm = 50;
  bool _useGeo = true;
  bool _loading = true;
  bool _submitting = false;
  String? _pendingCampaignId;

  static const int _totalSteps = 4;

  int get _stepNumber => _step.index + 1;

  String _errorMessage(Object error) {
    if (error is AppException) {
      return error.message ?? 'Something went wrong';
    }
    return error.toString();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _remote.getOptions(),
        _remote.getPackages(),
      ]);
      if (!mounted) return;
      final options = results[0] as PromotionOptionsEntity;
      setState(() {
        _options = options;
        _packages = results[1] as List<PromotionPackageEntity>;
        _objective = options.objectives.isNotEmpty
            ? options.objectives.first.value
            : 'VIEWS';
        _selectedPackageId = _packages.isNotEmpty ? _packages.first.id : null;
        _ageMin = options.ageMin;
        _ageMax = options.ageMax.clamp(options.ageMin + 1, 100);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      PopupDialogs.showErrorDialog(context, _errorMessage(error));
    }
  }

  PromotionPackageEntity? get _selectedPackage {
    if (_selectedPackageId == null) return null;
    for (final pkg in _packages) {
      if (pkg.id == _selectedPackageId) return pkg;
    }
    return null;
  }

  String? _objectiveLabel(AppLocalizations l10n) {
    for (final item in _options?.objectives ?? const []) {
      if (item.value == _objective) return item.label;
    }
    return _objective;
  }

  String _audienceSummary(AppLocalizations l10n) {
    if (!_useCustomAudience) return l10n.promoteAudienceDefault;
    final parts = <String>[];
    if (_genders.isEmpty) {
      parts.add(l10n.promoteAudienceAllGenders);
    } else {
      parts.add(_genders.join(', '));
    }
    parts.add('$_ageMin–$_ageMax');
    if (_useGeo) parts.add(l10n.promoteAudienceNearby);
    return parts.join(' · ');
  }

  void _onBack() {
    if (_step == PromoteStep.goal) {
      context.pop();
      return;
    }
    setState(() {
      _step = PromoteStep.values[_step.index - 1];
    });
  }

  void _handlePopInvoked(bool didPop) {
    if (didPop) return;
    _onBack();
  }

  void _goToStep(PromoteStep step) => setState(() => _step = step);

  void _onNext() {
    switch (_step) {
      case PromoteStep.goal:
        setState(() => _step = PromoteStep.audience);
      case PromoteStep.audience:
        setState(() => _step = PromoteStep.budget);
      case PromoteStep.budget:
        setState(() => _step = PromoteStep.overview);
      case PromoteStep.overview:
        _submit();
    }
  }

  Future<void> _payCampaign(String campaignId) async {
    final payResult = await _remote.payCampaign(campaignId);
    if (!mounted) return;

    setState(() => _pendingCampaignId = null);
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          l10n.promotePostSuccess(
            payResult.newBalance.toStringAsFixed(2),
          ),
        ),
        action: SnackBarAction(
          label: l10n.promoteInsightsViewInsights,
          onPressed: () {
            context.pushNamed(
              'promoted_post_insights',
              pathParameters: {'postId': widget.post.id},
            );
          },
        ),
      ),
    );
    context.pop(true);
  }

  Future<void> _showPayFailureDialog(String message) async {
    final l10n = AppLocalizations.of(context)!;
    await PopupDialogs.showConfirmDialog(
      context,
      title: l10n.promotePayFailedTitle,
      message: message,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.promoteRetryPay,
      onConfirm: () async {
        if (_pendingCampaignId == null) return;
        setState(() => _submitting = true);
        try {
          await _payCampaign(_pendingCampaignId!);
        } catch (error) {
          if (!mounted) return;
          PopupDialogs.showErrorDialog(context, _errorMessage(error));
        } finally {
          if (mounted) setState(() => _submitting = false);
        }
      },
    );
  }

  Future<void> _submit() async {
    if (_submitting || _objective == null || _selectedPackage == null) return;

    setState(() => _submitting = true);
    try {
      if (_pendingCampaignId != null) {
        await _payCampaign(_pendingCampaignId!);
        return;
      }

      final store = sl<UserLocationStore>();
      final body = <String, dynamic>{
        'postId': widget.post.id,
        'packageId': _selectedPackage!.id,
        'objective': _objective,
      };

      if (_useCustomAudience) {
        if (_genders.isNotEmpty) body['targetGenders'] = _genders.toList();
        body['targetAgeMin'] = _ageMin;
        body['targetAgeMax'] = _ageMax;
        if (_languages.isNotEmpty) {
          body['targetLanguages'] = _languages.toList();
        }
        if (_categoryIds.isNotEmpty) {
          body['targetCategoryIds'] = _categoryIds.toList();
        }
        if (_useGeo && store.hasLocation) {
          body['targetLatitude'] = store.latitude;
          body['targetLongitude'] = store.longitude;
          body['targetRadiusKm'] = _radiusKm;
        }
      }

      final campaign = await _remote.createCampaign(body);
      setState(() => _pendingCampaignId = campaign.id);
      await _payCampaign(campaign.id);
    } catch (error) {
      if (!mounted) return;
      final message = _errorMessage(error);
      if (_pendingCampaignId != null) {
        await _showPayFailureDialog(message);
      } else {
        PopupDialogs.showErrorDialog(context, message);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final progress = _stepNumber / _totalSteps;

    return PopScope(
      canPop: _step == PromoteStep.goal,
      onPopInvokedWithResult: (didPop, _) => _handlePopInvoked(didPop),
      child: Scaffold(
        backgroundColor: scheme.surface,
        appBar: CustomAppBar(
          title: l10n.promotionScreenTitle,
          showBackButton: true,
          onBackPressed: _onBack,
          showBottomDivider: false,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: scheme.primary,
                  ),
                  PromoteStepHeader(
                    stepLabel: l10n.promoteStepOf(_stepNumber, _totalSteps),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: switch (_step) {
                        PromoteStep.goal => PromoteGoalStep(
                            key: const ValueKey('goal'),
                            options: _options,
                            selected: _objective,
                            packages: _packages,
                            onSelected: (v) => setState(() => _objective = v),
                            onQuickPack: () {
                              if (_packages.length > 1) {
                                setState(() {
                                  _selectedPackageId = _packages[1].id;
                                  _step = PromoteStep.budget;
                                });
                              }
                            },
                          ),
                        PromoteStep.audience => PromoteAudienceStep(
                            key: const ValueKey('audience'),
                            options: _options,
                            useCustom: _useCustomAudience,
                            genders: _genders,
                            languages: _languages,
                            categoryIds: _categoryIds,
                            ageMin: _ageMin,
                            ageMax: _ageMax,
                            useGeo: _useGeo,
                            radiusKm: _radiusKm,
                            onModeChanged: (custom) =>
                                setState(() => _useCustomAudience = custom),
                            onGenderToggle: (v, s) => setState(() {
                              if (s) {
                                _genders.add(v);
                              } else {
                                _genders.remove(v);
                              }
                            }),
                            onLanguageToggle: (v, s) => setState(() {
                              if (s) {
                                _languages.add(v);
                              } else {
                                _languages.remove(v);
                              }
                            }),
                            onCategoryToggle: (id, s) => setState(() {
                              if (s) {
                                _categoryIds.add(id);
                              } else {
                                _categoryIds.remove(id);
                              }
                            }),
                            onAgeChanged: (min, max) => setState(() {
                              _ageMin = min;
                              _ageMax = max;
                            }),
                            onGeoChanged: (v) => setState(() => _useGeo = v),
                            onRadiusChanged: (v) =>
                                setState(() => _radiusKm = v),
                          ),
                        PromoteStep.budget => PromoteBudgetStep(
                            key: const ValueKey('budget'),
                            packages: _packages,
                            selectedId: _selectedPackageId,
                            onSelected: (id) =>
                                setState(() => _selectedPackageId = id),
                          ),
                        PromoteStep.overview => PromoteOverviewStep(
                            key: const ValueKey('overview'),
                            goalLabel: _objectiveLabel(l10n) ?? '—',
                            audienceLabel: _audienceSummary(l10n),
                            package: _selectedPackage,
                            onEditGoal: () => _goToStep(PromoteStep.goal),
                            onEditAudience: () =>
                                _goToStep(PromoteStep.audience),
                            onEditBudget: () => _goToStep(PromoteStep.budget),
                          ),
                      },
                    ),
                  ),
                  PromoteBottomBar(
                    label: _bottomLabel(l10n),
                    isLoading: _submitting,
                    onPressed: _submitting ? null : _onNext,
                  ),
                ],
              ),
      ),
    );
  }

  String _bottomLabel(AppLocalizations l10n) {
    if (_submitting) return l10n.promoteProcessing;
    if (_pendingCampaignId != null) return l10n.promoteRetryPay;
    if (_step == PromoteStep.overview) {
      return l10n.promotePayStart;
    }
    return l10n.promoteNext;
  }
}
