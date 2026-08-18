import 'package:bimobondapp/app/calls/domain/entities/call_entity.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_bloc.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_event.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class IncomingCallScreen extends StatefulWidget {
  final CallEntity call;

  const IncomingCallScreen({super.key, required this.call});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _acceptWithCameraOff = false;
  bool _isProcessingAction = false;
  bool _isAccepting = false;
  bool _isDeclining = false;


  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final caller = widget.call.initiatedBy;
    final displayName = caller.fullName?.isNotEmpty == true
        ? caller.fullName!
        : caller.username;
    final isVideo = widget.call.isVideo;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Ambient Radial Gradient Background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 1.2,
                    colors: isDark
                        ? [
                            const Color(0x406366F1),
                            const Color(0xFF090D16),
                          ]
                        : [
                            const Color(0x186366F1),
                            Colors.white,
                          ],
                  ),
                ),
              ),
            ),

            // Top Header & Center Caller Details
            Positioned.fill(
              child: Column(
                children: [
                  // Top Header Bar
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.05),
                            ),
                            child: Icon(
                              LucideIcons.chevronDown,
                              color: isDark ? Colors.white : Colors.black87,
                              size: 22,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : Colors.black.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  width: 18,
                                  height: 18,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Image.asset(
                                    'assets/images/app_icon.png',
                                    width: 18,
                                    height: 18,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isVideo
                                    ? LucideIcons.video
                                    : LucideIcons.phoneCall,
                                color: isDark ? Colors.white : Colors.black87,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                Localizations.localeOf(context).languageCode ==
                                        'ar'
                                    ? (isVideo
                                        ? 'Bimo-Bond مكالمة فيديو'
                                        : 'Bimo-Bond مكالمة صوتية')
                                    : (isVideo
                                        ? 'Bimo-Bond Video Call'
                                        : 'Bimo-Bond Audio Call'),
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                  ),

                  // Center Caller Profile Details with Pulsing Aura
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: child,
                            );
                          },
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.45 : 0.25),
                                  blurRadius: 36,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: SafeNetworkAvatar(
                                imageUrl: caller.avatarUrl,
                                radius: 60,
                                fallbackText: displayName,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          displayName,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '@${caller.username}',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.6)
                                : Colors.black54,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        // Video Call Option: Accept with Camera Off toggle
                        if (isVideo) ...[
                          const SizedBox(height: 24),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _acceptWithCameraOff = !_acceptWithCameraOff;
                              });
                            },
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: _acceptWithCameraOff
                                    ? (isDark
                                        ? Colors.white.withValues(alpha: 0.22)
                                        : Colors.black.withValues(alpha: 0.12))
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.04)),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.18)
                                      : Colors.black.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _acceptWithCameraOff
                                        ? LucideIcons.videoOff
                                        : LucideIcons.video,
                                    color: _acceptWithCameraOff
                                        ? Colors.amber
                                        : (isDark ? Colors.white70 : Colors.black87),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _acceptWithCameraOff
                                        ? 'Accept with Camera Off'
                                        : 'Accept with Camera On',
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black87,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 100), // Bottom bar clearance
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Action Bar (Decline & Accept)
            Positioned(
              bottom: 44,
              left: 40,
              right: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Decline Button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _isProcessingAction
                            ? null
                            : () {
                                setState(() {
                                  _isProcessingAction = true;
                                  _isDeclining = true;
                                });
                                context.read<CallBloc>().add(
                                      RejectCallEvent(callId: widget.call.id),
                                    );
                              },
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isProcessingAction
                                ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                                : const Color(0xFFEF4444),
                            boxShadow: _isProcessingAction
                                ? []
                                : [
                                    BoxShadow(
                                      color: const Color(0xFFEF4444)
                                          .withValues(alpha: 0.45),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                          ),
                          child: _isDeclining
                              ? const Padding(
                                  padding: EdgeInsets.all(18),
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Icon(
                                  LucideIcons.phone,
                                  color: Colors.white,
                                  size: 28,
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        Localizations.localeOf(context).languageCode == 'ar' ? 'رفض' : 'Decline',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // Accept Button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _isProcessingAction
                            ? null
                            : () {
                                setState(() {
                                  _isProcessingAction = true;
                                  _isAccepting = true;
                                });
                                if (_acceptWithCameraOff) {
                                  context.read<CallBloc>().add(
                                        const ToggleCameraEvent(),
                                      );
                                }
                                context.read<CallBloc>().add(
                                      AcceptCallEvent(callId: widget.call.id),
                                    );
                              },
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isProcessingAction
                                ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                : const Color(0xFF10B981),
                            boxShadow: _isProcessingAction
                                ? []
                                : [
                                    BoxShadow(
                                      color: const Color(0xFF10B981)
                                          .withValues(alpha: 0.45),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                          ),
                          child: _isAccepting
                              ? const Padding(
                                  padding: EdgeInsets.all(18),
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Icon(
                                  isVideo
                                      ? (_acceptWithCameraOff
                                          ? LucideIcons.videoOff
                                          : LucideIcons.video)
                                      : LucideIcons.phoneCall,
                                  color: Colors.white,
                                  size: 28,
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        Localizations.localeOf(context).languageCode == 'ar' ? 'قبول' : 'Accept',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
