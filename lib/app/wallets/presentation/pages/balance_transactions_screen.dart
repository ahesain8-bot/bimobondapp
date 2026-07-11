import 'package:bimobondapp/app/wallets/domain/entities/balance_entity.dart';
import 'package:bimobondapp/app/wallets/presentation/data/balance_mock_data.dart';
import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/utils/money_format_utils.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/directional_chevron_icon.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class BalanceTransactionsScreen extends StatefulWidget {
  const BalanceTransactionsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<BalanceTransactionsScreen> createState() =>
      _BalanceTransactionsScreenState();
}

class _BalanceTransactionsScreenState extends State<BalanceTransactionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _filters = BalanceTransactionFilter.values;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _filters.length,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, _filters.length - 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _tabLabel(AppLocalizations l10n, BalanceTransactionFilter filter) {
    return switch (filter) {
      BalanceTransactionFilter.all => l10n.balanceTabAll,
      BalanceTransactionFilter.revenue => l10n.balanceTabRevenue,
      BalanceTransactionFilter.expense => l10n.balanceTabExpense,
      BalanceTransactionFilter.payout => l10n.balanceTabPayout,
      BalanceTransactionFilter.refund => l10n.balanceTabRefund,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: CustomAppBar(
        title: l10n.balanceTransactionHistory,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.slidersHorizontal, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: theme.scaffoldBackgroundColor,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: theme.colorScheme.onSurface,
              unselectedLabelColor:
                  theme.colorScheme.onSurface.withValues(alpha: 0.45),
              indicatorColor: AppTheme.primaryColor,
              indicatorWeight: 2.5,
              dividerHeight: 0,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              tabs: _filters
                  .map((filter) => Tab(text: _tabLabel(l10n, filter)))
                  .toList(),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _filters.map((filter) {
                return _TransactionList(filter: filter);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionList extends StatelessWidget {
  const _TransactionList({required this.filter});

  final BalanceTransactionFilter filter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final items = BalanceMockData.filteredTransactions(filter);
    final grouped = <String, List<BalanceTransactionEntity>>{};

    for (final item in items) {
      final key = DateFormat('MMM yyyy', l10n.localeName).format(item.date);
      grouped.putIfAbsent(key, () => []).add(item);
    }

    if (items.isEmpty) {
      return Center(
        child: Text(
          l10n.balanceNoTransactions,
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.45),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: grouped.length,
      itemBuilder: (context, sectionIndex) {
        final month = grouped.keys.elementAt(sectionIndex);
        final sectionItems = grouped[month]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                month,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            ...sectionItems.map((tx) {
              final amount = MoneyFormatUtils.formatMoney(
                tx.amountUsd,
                BalanceMockData.currencyCode,
                locale: locale,
              );
              final dateText = LocaleFormatUtils.localizeDigits(
                DateFormat('M/d', l10n.localeName).format(tx.date),
                locale,
              );

              return Material(
                color: Colors.white,
                child: ListTile(
                  onTap: () => context.pushNamed(
                    'balance_transaction_detail',
                    pathParameters: {'id': tx.id},
                  ),
                  title: Text(
                    tx.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('$dateText | ${tx.subtitle ?? ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tx.amountCoins != null) ...[
                        Text(
                          LocaleFormatUtils.localizeDigits(
                            tx.amountCoins.toString(),
                            locale,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          LucideIcons.circle,
                          size: 10,
                          color: Color(0xFFFACC15),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        amount,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const DirectionalChevronIcon(size: 16),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
