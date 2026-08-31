import 'package:flutter/material.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/network/live_api_client.dart';
import '../../../../../core/utils/app_assets.dart';
import '../../../../../core/utils/app_sizes.dart';
import '../../../../../core/utils/app_text_styles.dart';

/// Top status bar: three circular icons on the left and the close button.
class StatusBarArea extends StatelessWidget {
  const StatusBarArea({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _StatusButton(iconPath: AppAssets.shield, onPressed: () {}),
                  const SizedBox(width: AppSpacing.sm),
                  _StatusButton(iconPath: AppAssets.home, onPressed: () {}),
                  const SizedBox(width: AppSpacing.sm),
                  _StatusButton(iconPath: AppAssets.money, onPressed: () {}),
                  const SizedBox(width: AppSpacing.sm),
                  const _LiveRewardsButton(),
                ],
              ),
              _StatusButton(iconData: Icons.close, onPressed: onClose),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({required this.onPressed, this.iconPath, this.iconData});

  final String? iconPath;
  final IconData? iconData;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSizes.circularButton,
      height: AppSizes.circularButton,
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: iconData != null
                ? Icon(iconData, color: Colors.white, size: AppSizes.closeIcon)
                : Image.asset(
                    iconPath!,
                    width: AppSizes.circularIcon,
                    height: AppSizes.circularIcon,
                  ),
          ),
        ),
      ),
    );
  }
}

class _LiveRewardsButton extends StatefulWidget {
  const _LiveRewardsButton();

  @override
  State<_LiveRewardsButton> createState() => _LiveRewardsButtonState();
}

class _LiveRewardsButtonState extends State<_LiveRewardsButton> {
  int? _balance;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  /// GET /auth/me → user.wallet.balanceCoins (مكافآت البث المتزايدة).
  Future<void> _loadBalance() async {
    try {
      final res = await LiveApiClient().get('/auth/me');
      if (!mounted) return;
      if (res is Map && res['wallet'] is Map) {
        final coins = res['wallet']['balanceCoins'];
        if (coins != null) {
          setState(
            () => _balance = (coins is num)
                ? coins.toInt()
                : int.tryParse('$coins'),
          );
        }
      }
    } catch (_) {
      // Keep the default label when the balance cannot be loaded.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.rewardsButtonHeight,
      padding: const EdgeInsets.only(
        left: AppSpacing.smd,
        right: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppSizes.radiusButton),
      ),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                _balance != null ? '$_balance' : 'مكافآت البث المتزايدة',
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                maxLines: 1,
                style: AppTextStyles.statusRewardLabel,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Image.asset(
            AppAssets.money,
            width: AppSizes.rewardsIcon,
            height: AppSizes.rewardsIcon,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}

class _ProgressHint extends StatelessWidget {
  const _ProgressHint();

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Colors.black.withValues(alpha: 0.2);

    return SizedBox(
      height: AppSizes.progressHintHeight + AppSizes.progressHintArrowHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left:
                AppSizes.circularButton / 2 -
                AppSizes.progressHintArrowWidth / 2,
            child: CustomPaint(
              size: const Size(
                AppSizes.progressHintArrowWidth,
                AppSizes.progressHintArrowHeight,
              ),
              painter: _ProgressHintArrowPainter(color: backgroundColor),
            ),
          ),
          Positioned(
            top: AppSizes.progressHintArrowHeight,
            left: 0,
            right: AppSpacing.xl,
            child: Container(
              height: AppSizes.progressHintHeight,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(AppSizes.radiusCard),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    AppAssets.go,
                    width: AppSizes.progressHintIcon,
                    height: AppSizes.progressHintIcon,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Flexible(
                    fit: FlexFit.loose,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'تابع التقدم واحصل على تجربة البث الكاملة',
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        style: AppTextStyles.progressHintLabel,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            top: AppSpacing.xs,
            left: AppSpacing.smd,
            child: Icon(Icons.close, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ProgressHintArrowPainter extends CustomPainter {
  const _ProgressHintArrowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ProgressHintArrowPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'إغلاق',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: AppSizes.circularButton,
          height: AppSizes.circularButton,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.close,
            color: Colors.white,
            size: AppSizes.closeIcon,
          ),
        ),
      ),
    );
  }
}
