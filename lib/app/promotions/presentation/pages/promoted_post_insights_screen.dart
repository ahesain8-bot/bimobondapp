import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart';
import 'package:bimobondapp/app/promotions/data/datasources/promotions_remote_data_source.dart';
import 'package:bimobondapp/app/promotions/domain/entities/promotion_entities.dart';
import 'package:bimobondapp/app/promotions/presentation/utils/promoted_post_loader.dart';
import 'package:bimobondapp/app/promotions/presentation/widgets/promoted_post_insights_widgets.dart';
import 'package:bimobondapp/core/error/error_message_resolver.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class PromotedPostInsightsScreen extends StatefulWidget {
  const PromotedPostInsightsScreen({
    super.key,
    required this.postId,
    this.initialCampaignId,
  });

  final String postId;
  final String? initialCampaignId;

  @override
  State<PromotedPostInsightsScreen> createState() =>
      _PromotedPostInsightsScreenState();
}

class _PromotedPostInsightsScreenState
    extends State<PromotedPostInsightsScreen> {
  final _remote = sl<PromotionsRemoteDataSource>();

  PromotedPostStatsEntity? _stats;
  PostEntity? _fetchedPost;
  String? _selectedCampaignId;
  bool _loading = true;
  bool _actionLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedCampaignId = widget.initialCampaignId;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _remote.getPromotedPostStats(
          widget.postId,
          campaignId: _selectedCampaignId,
        ),
        PromotedPostLoader.fetch(widget.postId),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as PromotedPostStatsEntity;
        _fetchedPost = results[1] as PostEntity?;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = _message(error);
      });
    }
  }

  String _message(Object error) => ErrorMessageResolver.resolve(error);

  Future<void> _toggleCampaignStatus() async {
    final campaign = _stats?.primaryCampaign;
    if (campaign == null || _actionLoading) return;

    setState(() => _actionLoading = true);
    try {
      if (campaign.status.toUpperCase() == 'ACTIVE') {
        await _remote.pauseCampaign(campaign.id);
      } else if (campaign.status.toUpperCase() == 'PAUSED') {
        await _remote.resumeCampaign(campaign.id);
      }
      await _load();
    } catch (error) {
      if (!mounted) return;
      PopupDialogs.showErrorDialog(context, _message(error));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  void _selectCampaign(String? campaignId) {
    if (_selectedCampaignId == campaignId) return;
    setState(() => _selectedCampaignId = campaignId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: l10n.promoteInsightsTitle,
        showBackButton: true,
      ),
      body: _loading && _stats == null
          ? const PromotedPostInsightsSkeleton()
          : _errorMessage != null && _stats == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: Text(l10n.notificationsRetry),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _stats == null
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [SizedBox(height: 200)],
                        )
                      : PromotedPostInsightsBody(
                          stats: _stats!,
                          fetchedPost: _fetchedPost,
                          selectedCampaignId: _selectedCampaignId,
                          actionLoading: _actionLoading,
                          onCampaignSelected: _selectCampaign,
                          onToggleStatus: _toggleCampaignStatus,
                        ),
                ),
    );
  }
}
