import 'dart:math';
import 'dart:ui';
import 'package:bimobondapp/app/gifts/domain/usecases/get_gift_inventory_usecase.dart';
import 'package:bimobondapp/app/gifts/presentation/di/gifts_injector.dart'
    as gifts_di;
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CoinPackage {
  final int coins;
  final double priceUsd;
  final String? badge;

  const CoinPackage({required this.coins, required this.priceUsd, this.badge});
}

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  final GetGiftInventoryUseCase _getInventory = gifts_di
      .sl<GetGiftInventoryUseCase>();
  final SharedPreferences _prefs = gifts_di.sl<SharedPreferences>();

  int _coinBalance = 0;
  bool _loading = true;
  String? _errorMessage;

  static const List<CoinPackage> _packages = [
    CoinPackage(coins: 100, priceUsd: 0.99),
    CoinPackage(coins: 500, priceUsd: 4.99, badge: 'POPULAR'),
    CoinPackage(coins: 1000, priceUsd: 9.99, badge: 'RECOMMENDED'),
    CoinPackage(coins: 2000, priceUsd: 19.99),
    CoinPackage(coins: 5000, priceUsd: 49.99, badge: 'BEST VALUE'),
    CoinPackage(coins: 10000, priceUsd: 99.99),
  ];

  int _selectedPackageIndex = 2; // Default to 1000 Coins
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _loadBalance();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final result = await _getInventory(NoParams());

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _loading = false;
        _errorMessage = failure.message;
      }),
      (inventory) => setState(() {
        _coinBalance = inventory.coinBalance;
        _loading = false;
      }),
    );
  }

  Future<void> _topUp(CoinPackage package) async {
    final l10n = AppLocalizations.of(context)!;
    final success = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => _PaymentSheet(package: package, l10n: l10n),
    );

    if (success == true && mounted) {
      final currentOffset = _prefs.getInt('MOCK_COIN_PURCHASED_OFFSET') ?? 0;
      await _prefs.setInt(
        'MOCK_COIN_PURCHASED_OFFSET',
        currentOffset + package.coins,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.walletPurchaseSuccess(package.coins)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade600,
        ),
      );

      _loadBalance();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(title: l10n.walletTitle, showBackButton: true),
      body: Stack(
        children: [
          // Background Glow Blobs
          Positioned(
            top: -100,
            right: -100,
            child: _buildGlowBlob(
              color: theme.colorScheme.primary.withValues(
                alpha: isDark ? 0.15 : 0.08,
              ),
              size: 300,
            ),
          ),
          Positioned(
            bottom: 50,
            left: -120,
            child: _buildGlowBlob(
              color: Colors.amber.withValues(alpha: isDark ? 0.08 : 0.04),
              size: 280,
            ),
          ),

          _loading && _coinBalance == 0
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadBalance,
                  color: theme.colorScheme.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.p16,
                      vertical: AppSizes.p12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBalanceCard(theme, isDark, l10n),
                        const SizedBox(height: AppSizes.p20),
                        Padding(
                          padding: const EdgeInsets.only(left: 4, right: 4),
                          child: CustomText(
                            l10n.walletChoosePackage,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSizes.p10),
                        _buildPackagesGrid(theme, isDark),
                        const SizedBox(height: AppSizes.p20),
                        _buildTopUpButton(theme, l10n),
                        const SizedBox(height: AppSizes.p24),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildGlowBlob({required Color color, required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildBalanceCard(
    ThemeData theme,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final goldColor = Colors.amber.shade500;
    final primaryColor = theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  primaryColor.withValues(alpha: 0.15),
                  theme.cardColor.withValues(alpha: 0.2),
                ]
              : [
                  primaryColor.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.7),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryColor.withValues(alpha: isDark ? 0.25 : 0.15),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: (isDark ? Colors.black : Colors.white).withValues(
              alpha: isDark ? 0.1 : 0.05,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p16,
            vertical: 20,
          ),
          child: Column(
            children: [
              CustomText(
                l10n.walletBalanceLabel.toUpperCase(),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                // letterSpacing: 1.2,
                color: (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(height: AppSizes.p10),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final glowScale = 1.0 + (_pulseController.value * 0.08);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Transform.scale(
                        scale: glowScale,
                        child: Icon(
                          Icons.monetization_on_rounded,
                          color: goldColor,
                          size: 32,
                          shadows: [
                            Shadow(
                              color: goldColor.withValues(alpha: 0.5),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSizes.p10),
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            theme.textTheme.bodyLarge?.color ?? Colors.white,
                            theme.textTheme.bodyLarge?.color?.withValues(
                                  alpha: 0.8,
                                ) ??
                                Colors.white,
                          ],
                        ).createShader(bounds),
                        child: CustomText(
                          '$_coinBalance',
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          // letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSizes.p16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackagesGrid(ThemeData theme, bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.4,
        crossAxisSpacing: AppSizes.p10,
        mainAxisSpacing: AppSizes.p10,
      ),
      itemCount: _packages.length,
      itemBuilder: (context, index) {
        final package = _packages[index];
        final isSelected = _selectedPackageIndex == index;
        final primaryColor = theme.colorScheme.primary;

        return GestureDetector(
          onTap: () => setState(() => _selectedPackageIndex = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        primaryColor.withValues(alpha: isDark ? 0.25 : 0.12),
                        primaryColor.withValues(alpha: isDark ? 0.1 : 0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected
                  ? null
                  : theme.cardColor.withValues(alpha: isDark ? 0.6 : 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? primaryColor
                    : isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                width: isSelected ? 2.2 : 1.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.15 : 0.03,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.monetization_on_rounded,
                            color: Colors.amber.shade500,
                            size: 16,
                            shadows: const [
                              Shadow(color: Colors.amber, blurRadius: 4),
                            ],
                          ),
                          const SizedBox(width: AppSizes.p6),
                          CustomText(
                            '${package.coins}',
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.p4),
                      CustomText(
                        '\$${package.priceUsd.toStringAsFixed(2)}',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        variant: TextVariant.secondary,
                      ),
                    ],
                  ),
                ),
                if (package.badge != null)
                  Positioned(
                    top: -8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.shade600,
                              Colors.orange.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          package.badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (isSelected)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 8,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopUpButton(ThemeData theme, AppLocalizations l10n) {
    final selectedPackage = _packages[_selectedPackageIndex];
    final primaryColor = theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
        ),
        onPressed: () => _topUp(selectedPackage),
        child: CustomText(
          '${l10n.walletTopUpButton} (\$${selectedPackage.priceUsd.toStringAsFixed(2)})',
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          // letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _PaymentSheet extends StatefulWidget {
  final CoinPackage package;
  final AppLocalizations l10n;

  const _PaymentSheet({required this.package, required this.l10n});

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final _formKey = GlobalKey<FormState>();

  final FocusNode _cardNumberNode = FocusNode();
  final FocusNode _expiryNode = FocusNode();
  final FocusNode _cvvNode = FocusNode();
  final FocusNode _holderNode = FocusNode();

  String _cardNumber = '';
  String _expiry = '';
  String _cvv = '';
  String _holder = '';

  bool _isFlipped = false;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _cvvNode.addListener(() {
      setState(() {
        _isFlipped = _cvvNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _cardNumberNode.dispose();
    _expiryNode.dispose();
    _cvvNode.dispose();
    _holderNode.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _processing = true);

      // Simulate payment delay
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() => _processing = false);
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.04),
          width: 1.2,
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSizes.p16,
        AppSizes.p12,
        AppSizes.p16,
        AppSizes.p16 + keyboardHeight,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white30 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.p12),
              CustomText(
                widget.l10n.walletTopUpButton,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.p16),

              // Visual 3D-Like Flipping Credit Card
              _buildFlippingCreditCard(),
              const SizedBox(height: AppSizes.p16),

              // Card number
              TextFormField(
                focusNode: _cardNumberNode,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                  _CardNumberFormatter(),
                ],
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: widget.l10n.walletCardNumber,
                  prefixIcon: const Icon(LucideIcons.creditCard),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().length < 19) {
                    return widget.l10n.enterSixDigitCode;
                  }
                  return null;
                },
                onChanged: (val) => setState(() => _cardNumber = val),
              ),
              const SizedBox(height: AppSizes.p12),

              // Expiry & CVV Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      focusNode: _expiryNode,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                        _ExpiryDateFormatter(),
                      ],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: widget.l10n.walletExpiry,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.dividerColor.withValues(alpha: 0.5),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 5) {
                          return '';
                        }
                        return null;
                      },
                      onChanged: (val) => setState(() => _expiry = val),
                    ),
                  ),
                  const SizedBox(width: AppSizes.p12),
                  Expanded(
                    child: TextFormField(
                      focusNode: _cvvNode,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      obscureText: true,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: widget.l10n.walletCvv,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.dividerColor.withValues(alpha: 0.5),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 3) {
                          return '';
                        }
                        return null;
                      },
                      onChanged: (val) => setState(() => _cvv = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.p12),

              // Card Holder
              TextFormField(
                focusNode: _holderNode,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: widget.l10n.walletCardHolder,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '';
                  }
                  return null;
                },
                onChanged: (val) => setState(() => _holder = val.toUpperCase()),
              ),
              const SizedBox(height: AppSizes.p20),

              // Confirm Pay Button
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(23),
                    ),
                  ),
                  onPressed: _processing ? null : _submit,
                  child: _processing
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: AppSizes.p12),
                            CustomText(
                              widget.l10n.walletProcessing,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ],
                        )
                      : CustomText(
                          widget.l10n.walletPayButton(
                            '\$${widget.package.priceUsd.toStringAsFixed(2)}',
                          ),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 3D Credit Card Flip view builder
  Widget _buildFlippingCreditCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: _isFlipped ? pi : 0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      builder: (context, rotationVal, child) {
        // Decide which face to show
        final isFrontSide = rotationVal < pi / 2;
        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateY(rotationVal),
          alignment: Alignment.center,
          child: isFrontSide
              ? _buildCardFront()
              : Transform(
                  transform: Matrix4.identity()..rotateY(pi),
                  alignment: Alignment.center,
                  child: _buildCardBack(),
                ),
        );
      },
    );
  }

  Widget _buildCardFront() {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF280B45), Color(0xFF6B1D8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B1D8C).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSizes.p16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CustomText(
                'BIMO BOND',
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.9),
                // letterSpacing: 1.2,
              ),
              const Icon(LucideIcons.nfc, color: Colors.white70, size: 20),
            ],
          ),
          const Spacer(),
          CustomText(
            _cardNumber.isEmpty ? '•••• •••• •••• ••••' : _cardNumber,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            // letterSpacing: 2,
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CustomText(
                    'CARDHOLDER',
                    fontSize: 8,
                    color: Colors.white60,
                    fontWeight: FontWeight.w600,
                    // letterSpacing: 1,
                  ),
                  const SizedBox(height: 4),
                  CustomText(
                    _holder.isEmpty ? 'YOUR NAME' : _holder,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const CustomText(
                    'EXPIRES',
                    fontSize: 8,
                    color: Colors.white60,
                    fontWeight: FontWeight.w600,
                    // letterSpacing: 1,
                  ),
                  const SizedBox(height: 4),
                  CustomText(
                    _expiry.isEmpty ? 'MM/YY' : _expiry,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack() {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B072E), Color(0xFF421257)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF421257).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Magnetic strip
          Container(
            height: 32,
            width: double.infinity,
            color: Colors.black.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 16),
          // Signature and CVV box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 28,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 44,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: CustomText(
                    _cvv.isEmpty ? '•••' : _cvv,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (newValue.selection.baseOffset == 0) return newValue;

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      final nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
        buffer.write(' ');
      }
    }

    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (newValue.selection.baseOffset == 0) return newValue;

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      final nonZeroIndex = i + 1;
      if (nonZeroIndex == 2 && nonZeroIndex != text.length) {
        buffer.write('/');
      }
    }

    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
