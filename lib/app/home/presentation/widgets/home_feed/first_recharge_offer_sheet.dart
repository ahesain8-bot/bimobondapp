import 'package:bimobondapp/app/wallets/domain/entities/wallet_entity.dart';
import 'package:bimobondapp/app/wallets/domain/usecases/wallet_usecases.dart';
import 'package:bimobondapp/app/wallets/presentation/di/wallets_injector.dart'
    as wallets_di;
import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/utils/money_format_utils.dart';
import 'package:bimobondapp/core/widgets/app_coin_icon.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// TikTok-style first recharge offer opened from the gift sheet Recharge CTA.
/// Returns `true` when the user navigated to complete a top-up.
class FirstRechargeOfferSheet {
  FirstRechargeOfferSheet._();

  static Future<bool?> show(BuildContext context) {
    return GlassBottomSheet.open<bool>(
      context,
      isScrollControlled: true,
      builder: (_) => const _FirstRechargeOfferBody(),
    );
  }
}

class _FirstRechargeOfferBody extends StatefulWidget {
  const _FirstRechargeOfferBody();

  @override
  State<_FirstRechargeOfferBody> createState() =>
      _FirstRechargeOfferBodyState();
}

class _FirstRechargeOfferBodyState extends State<_FirstRechargeOfferBody> {
  final _getPackages = wallets_di.sl<GetCoinPackagesUseCase>();

  List<CoinPackageEntity> _packages = [];
  int _selectedIndex = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _getPackages(NoParams());
    if (!mounted) return;
    result.fold(
      (failure) {
        setState(() {
          _loading = false;
          _error = failure.message;
        });
      },
      (packages) {
        final active = packages.where((p) => p.isActive).toList();
        setState(() {
          _packages = active;
          _selectedIndex = 0;
          _loading = false;
        });
      },
    );
  }

  CoinPackageEntity? get _selected {
    if (_packages.isEmpty) return null;
    if (_selectedIndex < 0 || _selectedIndex >= _packages.length) {
      return _packages.first;
    }
    return _packages[_selectedIndex];
  }

  Future<void> _continue() async {
    final pack = _selected;
    if (pack == null) {
      Navigator.pop(context, false);
      context.push('/settings/wallet?tab=0');
      return;
    }
    Navigator.pop(context, true);
    context.push('/settings/wallet?tab=0');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.62;
    final selected = _selected;

    return Material(
      color: scheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height.clamp(420.0, 640.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                children: [
                  Text(
                    l10n.firstRechargeTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.firstRechargeSubtitle(6),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.55),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _RewardRow(
                    icon: LucideIcons.flower2,
                    iconColor: AppTheme.primaryColor,
                    title: l10n.firstRechargeRoseTitle,
                    body: l10n.firstRechargeRoseBody,
                  ),
                  const SizedBox(height: 14),
                  _RewardRow(
                    iconWidget: const AppCoinIcon(size: 28),
                    title: l10n.firstRechargeBonusTitle,
                    body: l10n.firstRechargeBonusBody,
                  ),
                  const SizedBox(height: 22),
                  Text(
                    l10n.firstRechargeGetCoins,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.firstRechargeGetCoinsHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          TextButton(
                            onPressed: _load,
                            child: Text(l10n.liveGiftRetry),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      height: 78,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _packages.length.clamp(0, 6),
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final pack = _packages[index];
                          return _PackageCard(
                            package: pack,
                            selected: index == _selectedIndex,
                            onTap: () => setState(() => _selectedIndex = index),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.firstRechargePolicy,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.45),
                      height: 1.4,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottomInset),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: selected == null && !_loading
                      ? () {
                          PopupDialogs.showErrorDialog(
                            context,
                            l10n.coinsInsufficientBalance,
                          );
                        }
                      : _continue,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    elevation: 0,
                    shape: const StadiumBorder(),
                  ),
                  child: selected == null
                      ? Text(
                          l10n.liveGiftRecharge,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        )
                      : Builder(
                          builder: (context) {
                            final locale = Localizations.localeOf(context);
                            final coinsLabel =
                                LocaleFormatUtils.localizeDigits(
                              selected.totalCoins.toString(),
                              locale,
                            );
                            final priceLabel = MoneyFormatUtils.formatMoney(
                              selected.price,
                              selected.currencyCode,
                              locale: locale,
                            );
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const AppCoinIcon(
                                  size: 18,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    l10n.firstRechargeCta(
                                      coinsLabel,
                                      priceLabel,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({
    required this.title,
    required this.body,
    this.icon,
    this.iconColor,
    this.iconWidget,
  });

  final IconData? icon;
  final Color? iconColor;
  final Widget? iconWidget;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: iconWidget ??
              Icon(
                icon ?? LucideIcons.gift,
                size: 28,
                color: iconColor ?? scheme.primary,
              ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.55),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.selected,
    required this.onTap,
  });

  final CoinPackageEntity package;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context);
    final coins = LocaleFormatUtils.localizeDigits(
      package.coinAmount.toString(),
      locale,
    );
    final bonus = package.bonusCoins > 0
        ? '+${LocaleFormatUtils.localizeDigits(package.bonusCoins.toString(), locale)}'
        : '';
    final price = MoneyFormatUtils.formatMoney(
      package.price,
      package.currencyCode,
      locale: locale,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 108,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.14),
              width: selected ? 1.6 : 1,
            ),
            color: selected
                ? scheme.primary.withValues(alpha: 0.06)
                : scheme.surface,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppCoinIcon(size: 14),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: coins,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          if (bonus.isNotEmpty)
                            TextSpan(
                              text: bonus,
                              style: TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                price,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
