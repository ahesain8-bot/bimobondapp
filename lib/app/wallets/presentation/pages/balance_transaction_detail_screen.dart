import 'package:bimobondapp/app/wallets/domain/entities/balance_entity.dart';
import 'package:bimobondapp/app/wallets/presentation/data/balance_mock_data.dart';
import 'package:bimobondapp/core/utils/money_format_utils.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class BalanceTransactionDetailScreen extends StatelessWidget {
  const BalanceTransactionDetailScreen({required this.transactionId, super.key});

  final String transactionId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final tx = BalanceMockData.transactionById(transactionId);

    if (tx == null) {
      return Scaffold(
        appBar: CustomAppBar(title: l10n.balanceTransactionDetails),
        body: Center(child: Text(l10n.balanceTransactionNotFound)),
      );
    }

    final amount = MoneyFormatUtils.formatMoney(
      tx.amountUsd,
      BalanceMockData.currencyCode,
      locale: locale,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: CustomAppBar(title: l10n.balanceTransactionDetails),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFECECEC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  tx.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (tx.earnedPeriod != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    tx.earnedPeriod!,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (tx.breakdown.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...tx.breakdown.entries.map(
              (entry) => _BreakdownRow(
                label: entry.key,
                amount: MoneyFormatUtils.formatMoney(
                  entry.value,
                  BalanceMockData.currencyCode,
                  locale: locale,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _DetailCard(
            children: [
              _DetailRow(
                label: l10n.balanceDetailStatus,
                value: l10n.balanceStatusCompleted,
                valueColor: const Color(0xFF22C55E),
                leading: const Icon(
                  LucideIcons.circleCheck,
                  size: 16,
                  color: Color(0xFF22C55E),
                ),
              ),
              _DetailRow(
                label: l10n.balanceDetailType,
                value: _filterLabel(l10n, tx.filter),
              ),
              if (tx.activityType != null)
                _DetailRow(
                  label: l10n.balanceDetailActivityType,
                  value: tx.activityType!,
                ),
              if (tx.paymentMethodLabel != null)
                _DetailRow(
                  label: l10n.balanceDetailPaymentMethod,
                  value: tx.paymentMethodLabel!,
                ),
              if (tx.createdAt != null)
                _DetailRow(
                  label: l10n.balanceDetailCreated,
                  value: DateFormat(
                    'MMM d, yyyy h:mm a',
                    l10n.localeName,
                  ).format(tx.createdAt!.toLocal()),
                ),
              if (tx.updatedAt != null)
                _DetailRow(
                  label: l10n.balanceDetailUpdated,
                  value: DateFormat(
                    'MMM d, yyyy h:mm a',
                    l10n.localeName,
                  ).format(tx.updatedAt!.toLocal()),
                ),
              if (tx.transactionId != null)
                _DetailRow(
                  label: l10n.balanceDetailTransactionId,
                  value: tx.transactionId!,
                  trailing: IconButton(
                    icon: const Icon(LucideIcons.copy, size: 16),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: tx.transactionId!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.balanceCopied)),
                      );
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: () {},
              child: Text(l10n.balanceNeedHelp),
            ),
          ),
        ],
      ),
    );
  }

  String _filterLabel(AppLocalizations l10n, BalanceTransactionFilter filter) {
    return switch (filter) {
      BalanceTransactionFilter.payout => l10n.balanceTabPayout,
      BalanceTransactionFilter.revenue => l10n.balanceTabRevenue,
      BalanceTransactionFilter.expense => l10n.balanceTabExpense,
      BalanceTransactionFilter.refund => l10n.balanceTabRefund,
      BalanceTransactionFilter.all => l10n.balanceTabAll,
    };
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.label, required this.amount});

  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: ListTile(
        title: Text(label),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(amount, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            Text(
              '${AppLocalizations.of(context)!.balanceView} >',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.35),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.leading,
    this.trailing,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.55),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 4)],
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: valueColor,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
