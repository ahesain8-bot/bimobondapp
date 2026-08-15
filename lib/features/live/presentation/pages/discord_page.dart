import 'package:flutter/material.dart';

import '../../../../core/utils/app_colors.dart';
import '../../../../core/utils/app_assets.dart';
import '../../../../core/utils/app_sizes.dart';

/// Discord connection page opened from the fans community header.
class DiscordPage extends StatefulWidget {
  const DiscordPage({super.key, required this.discordName, this.onConnected});

  final String discordName;

  /// Invoked when the user confirms the connection. Returning `false`
  /// (e.g. the fan-club PATCH failed) keeps the switch disconnected.
  final Future<bool> Function(String discordName)? onConnected;

  @override
  State<DiscordPage> createState() => _DiscordPageState();
}

class _DiscordPageState extends State<DiscordPage> {
  bool _connected = false;
  bool _connecting = false;

  Future<void> _toggleConnection(bool value) async {
    if (_connecting) return;
    if (!value) {
      setState(() => _connected = false);
      return;
    }

    final shouldConnect = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width * 0.72,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'هل تريد الاتصال بـ Discord؟',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'لإنشاء قناة خاصة على Discord تضم\nمعجبيك، تحتاج إلى الاتصال بـ Discord.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFE5E5E5),
                ),
                SizedBox(
                  height: 64,
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.black,
                              minimumSize: Size.zero,
                              padding: EdgeInsets.zero,
                              shape: const RoundedRectangleBorder(),
                            ),
                            child: const Text(
                              'اتصال',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: Color(0xFFE5E5E5),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF777777),
                              minimumSize: Size.zero,
                              padding: EdgeInsets.zero,
                              shape: const RoundedRectangleBorder(),
                            ),
                            child: const Text(
                              'إلغاء',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!mounted || shouldConnect != true) return;
    setState(() => _connecting = true);
    final ok = await widget.onConnected?.call(widget.discordName) ?? true;
    if (!mounted) return;
    setState(() {
      _connecting = false;
      _connected = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              SizedBox(
                height: 72,
                child: Stack(
                  children: [
                    const Positioned(
                      left: 28,
                      top: 16,
                      child: Icon(
                        Icons.help_outline,
                        color: Colors.black,
                        size: 36,
                      ),
                    ),
                    const Center(
                      child: Text(
                        'Discord',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 21,
                      top: 13,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: const Icon(
                          Icons.chevron_left,
                          color: Colors.black,
                          size: 38,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  height: 76,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        AppAssets.discord,
                        width: 45,
                        height: 45,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ربط Discord',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'السماح بالاتصال بمجتمع Discord الخاص بك.',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Color(0xFF8A8A8A),
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _DiscordSwitch(
                        value: _connected,
                        busy: _connecting,
                        onChanged: _connecting ? null : _toggleConnection,
                      ),
                    ],
                  ),
                ),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscordSwitch extends StatelessWidget {
  const _DiscordSwitch({
    required this.value,
    required this.onChanged,
    this.busy = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: AppSizes.optionsToggleWidth,
            height: AppSizes.optionsToggleHeight,
            padding: const EdgeInsets.all(2),
            alignment: value
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            decoration: BoxDecoration(
              color: value
                  ? AppColors.optionsToggleActive
                  : AppColors.optionsToggleInactive,
              borderRadius: BorderRadius.circular(AppSizes.optionsToggleHeight),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: AppSizes.optionsToggleHeight - 4,
              height: AppSizes.optionsToggleHeight - 4,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
          if (busy)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}
