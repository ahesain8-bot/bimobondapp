import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/fan_club.dart';
import '../bloc/fan_club/fan_club_state.dart';

/// Viewer-facing membership block: the tiers a creator sells, the viewer's own
/// membership and loyalty badge, and the club emotes with their tier lock.
///
/// Every coin figure shown here came from the server. A tier without a price
/// is rendered as unavailable — the app never derives one from another tier.
class FanClubMembershipSection extends StatelessWidget {
  const FanClubMembershipSection({
    required this.ready,
    required this.onSubscribe,
    super.key,
  });

  final FanClubReady ready;

  /// Called with the chosen tier slug after the viewer confirmed the charge.
  final void Function(String tierSlug) onSubscribe;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final club = ready.club;
    final membership = club.membership;
    final tiers = club.tiers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (membership != null && membership.isActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _MembershipBadge(membership: membership),
          ),
        if (ready.unresolvedTierSlug != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _Notice(
              icon: Icons.hourglass_bottom,
              text: l.liveFanClubAwaitingConfirmation,
            ),
          ),
        if (tiers.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Text(
              l.liveFanClubTiers,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
          for (final tier in tiers)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: _TierCard(
                tier: tier,
                isCurrent: club.alreadyCovers(tier.slug),
                busy: ready.busy,
                blocked: ready.unresolvedTierSlug != null,
                onJoin: () => _confirmAndSubscribe(context, tier),
              ),
            ),
        ] else if (club.hasUnpricedOffer)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: _Notice(
              icon: Icons.info_outline,
              text: l.liveFanClubPriceUnavailable,
            ),
          ),
        if (club.emotes.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
            child: Text(
              l.liveFanClubEmotes,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final emote in club.emotes)
                  _EmoteChip(
                    emote: emote,
                    unlocked: emote.unlockedFor(club.myTierSlug),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmAndSubscribe(
    BuildContext context,
    FanClubTier tier,
  ) async {
    final l = AppLocalizations.of(context)!;
    final price = tier.priceCoins;
    if (price == null || price <= 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.liveFanClubConfirmTitle),
        content: Text(
          l.liveFanClubConfirmBody(price, tier.displayName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.liveFanClubConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed == true) onSubscribe(tier.slug);
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.tier,
    required this.isCurrent,
    required this.busy,
    required this.blocked,
    required this.onJoin,
  });

  final FanClubTier tier;
  final bool isCurrent;
  final bool busy;

  /// True while an earlier purchase is still unresolved: no new charge starts.
  final bool blocked;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final price = tier.priceCoins;
    final canBuy = !isCurrent && !busy && !blocked && tier.isPurchasable;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFFF6F6F6) : Colors.white,
        border: Border.all(
          color: isCurrent ? Colors.black : const Color(0xFFE5E5E5),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  price != null
                      ? l.liveFanClubPriceCoins(price)
                      : l.liveFanClubPriceUnavailable,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF777777),
                  ),
                ),
              ],
            ),
          ),
          if (isCurrent)
            Text(
              l.liveFanClubCurrentTier,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            )
          else
            ElevatedButton(
              onPressed: canBuy ? onJoin : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                l.liveFanClubJoinTier(tier.displayName),
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _MembershipBadge extends StatelessWidget {
  const _MembershipBadge({required this.membership});

  final FanClubMembership membership;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final loyalty = membership.loyalty;
    return Row(
      children: [
        const Icon(Icons.workspace_premium, size: 18, color: Colors.black),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            loyalty == null || loyalty.isEmpty
                ? '${l.liveFanClubCurrentTier}: ${membership.tierSlug}'
                : '${l.liveFanClubCurrentTier}: ${membership.tierSlug} · '
                      '${l.liveFanClubLoyalty(loyalty)}',
            style: const TextStyle(fontSize: 12, color: Colors.black),
          ),
        ),
      ],
    );
  }
}

class _EmoteChip extends StatelessWidget {
  const _EmoteChip({required this.emote, required this.unlocked});

  final FanClubEmote emote;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final url = emote.imageUrl;
    return Opacity(
      opacity: unlocked ? 1 : 0.45,
      child: Tooltip(
        message: unlocked
            ? emote.code
            : l.liveFanClubEmoteLocked(emote.minTier ?? ''),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F3F3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (url != null && url.startsWith('http'))
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: Image.network(
                    url,
                    width: 18,
                    height: 18,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.emoji_emotions_outlined, size: 16),
                  ),
                ),
              Text(
                emote.code,
                style: const TextStyle(fontSize: 12, color: Colors.black),
              ),
              if (!unlocked)
                const Padding(
                  padding: EdgeInsetsDirectional.only(start: 4),
                  child: Icon(Icons.lock, size: 12, color: Color(0xFF777777)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF8A6100)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A6100)),
            ),
          ),
        ],
      ),
    );
  }
}
