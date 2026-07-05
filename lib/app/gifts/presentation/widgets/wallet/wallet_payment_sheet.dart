import 'dart:math';

import 'package:bimobondapp/app/gifts/presentation/widgets/wallet/wallet_glass_style.dart';
import 'package:bimobondapp/app/wallets/domain/utils/wallet_coin_pricing.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/money_format_utils.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_surface.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class WalletPaymentSheet extends StatefulWidget {
  const WalletPaymentSheet({
    required this.quote,
    required this.l10n,
    super.key,
  });

  final WalletTopUpQuote quote;
  final AppLocalizations l10n;

  @override
  State<WalletPaymentSheet> createState() => _WalletPaymentSheetState();
}

class _WalletPaymentSheetState extends State<WalletPaymentSheet> {
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

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _processing = true);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _processing = false);
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = WalletGlassStyle.of(context);
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return LiquidGlassSurface(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      blurSigma: 24,
      backgroundColor: glass.sheetFill,
      borderColor: glass.sheetBorder,
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
                child: LiquidGlassSurface(
                  borderRadius: BorderRadius.circular(2),
                  blurSigma: 8,
                  backgroundColor: glass.surfaceFill,
                  borderColor: glass.surfaceBorder,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 2,
                  ),
                  child: const SizedBox(width: 44, height: 4),
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
              _WalletFlippingCreditCard(
                cardNumber: _cardNumber,
                expiry: _expiry,
                cvv: _cvv,
                holder: _holder,
                isFlipped: _isFlipped,
              ),
              const SizedBox(height: AppSizes.p16),
              WalletGlassTextField(
                focusNode: _cardNumberNode,
                labelText: widget.l10n.walletCardNumber,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                  WalletCardNumberFormatter(),
                ],
                prefixIcon: Icon(
                  LucideIcons.creditCard,
                  color: glass.secondaryText,
                  size: 20,
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
              Row(
                children: [
                  Expanded(
                    child: WalletGlassTextField(
                      focusNode: _expiryNode,
                      labelText: widget.l10n.walletExpiry,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                        WalletExpiryDateFormatter(),
                      ],
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
                    child: WalletGlassTextField(
                      focusNode: _cvvNode,
                      labelText: widget.l10n.walletCvv,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
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
              WalletGlassTextField(
                focusNode: _holderNode,
                labelText: widget.l10n.walletCardHolder,
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '';
                  }
                  return null;
                },
                onChanged: (val) => setState(() => _holder = val.toUpperCase()),
              ),
              const SizedBox(height: AppSizes.p20),
              WalletGlassPrimaryButton(
                enabled: !_processing,
                height: 46,
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
                            MoneyFormatUtils.formatMoney(
                              widget.quote.price,
                              widget.quote.currencyCode,
                            ),
                          ),
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontSize: 14,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletFlippingCreditCard extends StatelessWidget {
  const _WalletFlippingCreditCard({
    required this.cardNumber,
    required this.expiry,
    required this.cvv,
    required this.holder,
    required this.isFlipped,
  });

  final String cardNumber;
  final String expiry;
  final String cvv;
  final String holder;
  final bool isFlipped;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: isFlipped ? pi : 0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      builder: (context, rotationVal, child) {
        final isFrontSide = rotationVal < pi / 2;
        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(rotationVal),
          alignment: Alignment.center,
          child: isFrontSide
              ? _WalletCreditCardFront(
                  cardNumber: cardNumber,
                  expiry: expiry,
                  holder: holder,
                )
              : Transform(
                  transform: Matrix4.identity()..rotateY(pi),
                  alignment: Alignment.center,
                  child: _WalletCreditCardBack(cvv: cvv),
                ),
        );
      },
    );
  }
}

class _WalletCreditCardFront extends StatelessWidget {
  const _WalletCreditCardFront({
    required this.cardNumber,
    required this.expiry,
    required this.holder,
  });

  final String cardNumber;
  final String expiry;
  final String holder;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B1D8C).withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LiquidGlassSurface(
        borderRadius: BorderRadius.circular(16),
        blurSigma: 12,
        backgroundColor: const Color(0xFF280B45).withValues(alpha: 0.92),
        borderColor: Colors.white.withValues(alpha: 0.15),
        padding: const EdgeInsets.all(AppSizes.p16),
        child: SizedBox(
          height: 118,
          width: double.infinity,
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
                  ),
                  const Icon(LucideIcons.nfc, color: Colors.white70, size: 20),
                ],
              ),
              const Spacer(),
              CustomText(
                cardNumber.isEmpty ? '•••• •••• •••• ••••' : cardNumber,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
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
                      ),
                      const SizedBox(height: 4),
                      CustomText(
                        holder.isEmpty ? 'YOUR NAME' : holder,
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
                      ),
                      const SizedBox(height: 4),
                      CustomText(
                        expiry.isEmpty ? 'MM/YY' : expiry,
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
        ),
      ),
    );
  }
}

class _WalletCreditCardBack extends StatelessWidget {
  const _WalletCreditCardBack({required this.cvv});

  final String cvv;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassSurface(
      borderRadius: BorderRadius.circular(16),
      blurSigma: 12,
      backgroundColor: const Color(0xFF1B072E).withValues(alpha: 0.92),
      borderColor: Colors.white.withValues(alpha: 0.12),
      child: SizedBox(
        height: 150,
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Container(
              height: 32,
              width: double.infinity,
              color: Colors.black.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 16),
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
                      cvv.isEmpty ? '•••' : cvv,
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
      ),
    );
  }
}

class WalletCardNumberFormatter extends TextInputFormatter {
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

class WalletExpiryDateFormatter extends TextInputFormatter {
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
