import 'package:flutter/material.dart';

import 'package:bimobondapp/app/ar_camera/ar_camera_bridge.dart';

import '../../../../../core/utils/app_sizes.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/utils/app_text_styles.dart';
import 'ar_live_camera_preview.dart';

/// Beauty controls shown above the live setup actions.
class BeautifyPanel extends StatefulWidget {
  const BeautifyPanel({super.key});

  static const double height = 208;

  @override
  State<BeautifyPanel> createState() => _BeautifyPanelState();
}

class _BeautifyPanelState extends State<BeautifyPanel> {
  static const List<String> _tabs = ['تحسين', 'الجمال', 'المكياج', 'الفلاتر'];

  static const List<List<_BeautyControl>> _controlsByTab = [
    [
      _BeautyControl('الشكل', Icons.face_retouching_natural),
      _BeautyControl('العين', Icons.visibility_outlined),
      _BeautyControl('الأنف', Icons.face),
      _BeautyControl('التباين', Icons.contrast),
      _BeautyControl('كريم أساس', Icons.circle_outlined),
      _BeautyControl('كريم أساس', Icons.circle_outlined),
      _BeautyControl('كريم أساس', Icons.circle_outlined),
      _BeautyControl('كريم أساس', Icons.circle_outlined),
      _BeautyControl('كريم أساس', Icons.circle_outlined),
      _BeautyControl('كريم أساس', Icons.circle_outlined),
      _BeautyControl('كريم أساس', Icons.circle_outlined),
      _BeautyControl('كريم أساس', Icons.circle_outlined),
      _BeautyControl('كريم أساس', Icons.circle_outlined),
      _BeautyControl('كريم أساس', Icons.circle_outlined),
      _BeautyControl('كريم أساس', Icons.circle_outlined),
    ],
    [
      _BeautyControl('تنعيم', Icons.blur_on),
      _BeautyControl('لون البشرة', Icons.palette_outlined),
      _BeautyControl('الوجه', Icons.face_retouching_natural),
      _BeautyControl('الذقن', Icons.face),
      _BeautyControl('توهج', Icons.wb_sunny_outlined),
      _BeautyControl('توهج', Icons.wb_sunny_outlined),
      _BeautyControl('توهج', Icons.wb_sunny_outlined),
      _BeautyControl('توهج', Icons.wb_sunny_outlined),
      _BeautyControl('توهج', Icons.wb_sunny_outlined),
      _BeautyControl('توهج', Icons.wb_sunny_outlined),
      _BeautyControl('توهج', Icons.wb_sunny_outlined),
      _BeautyControl('توهج', Icons.wb_sunny_outlined),
    ],
    [
      _BeautyControl('أحمر الشفاه', Icons.favorite_border),
      _BeautyControl('الرموش', Icons.remove_red_eye_outlined),
      _BeautyControl('الحواجب', Icons.face),
      _BeautyControl('الآيلاينر', Icons.edit_outlined),
      _BeautyControl('ظلال', Icons.brush_outlined),
      _BeautyControl('ظلال', Icons.brush_outlined),
      _BeautyControl('ظلال', Icons.brush_outlined),
      _BeautyControl('ظلال', Icons.brush_outlined),
      _BeautyControl('ظلال', Icons.brush_outlined),
      _BeautyControl('ظلال', Icons.brush_outlined),
      _BeautyControl('ظلال', Icons.brush_outlined),
      _BeautyControl('ظلال', Icons.brush_outlined),
    ],
    [
      _BeautyControl('أصلي', Icons.filter_none),
      _BeautyControl('طبيعي', Icons.filter_vintage),
      _BeautyControl('دافئ', Icons.wb_sunny_outlined),
      _BeautyControl('بارد', Icons.ac_unit_outlined),
      _BeautyControl('سينمائي', Icons.movie_filter_outlined),
      _BeautyControl('سينمائي', Icons.movie_filter_outlined),
      _BeautyControl('سينمائي', Icons.movie_filter_outlined),
      _BeautyControl('سينمائي', Icons.movie_filter_outlined),
      _BeautyControl('سينمائي', Icons.movie_filter_outlined),
      _BeautyControl('سينمائي', Icons.movie_filter_outlined),
      _BeautyControl('سينمائي', Icons.movie_filter_outlined),
      _BeautyControl('سينمائي', Icons.movie_filter_outlined),
      _BeautyControl('سينمائي', Icons.movie_filter_outlined),
    ],
  ];

  int _selectedTab = 0;
  int _selectedControl = 0;
  /// UI preview only until the host moves the slider (then Magic turns On).
  double _intensity = 0;

  @override
  void initState() {
    super.initState();
    // Panel opens without forcing beauty — Magic stays Off until the host
    // moves the intensity slider (or taps apply controls).
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: BeautifyPanel.height,
        padding: const EdgeInsets.only(
          top: AppSpacing.xs,
          left: AppSpacing.sm,
          right: AppSpacing.sm,
        ),
        decoration: const BoxDecoration(
          color: Color(0xF20D0D0F),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSizes.radiusCard),
          ),
        ),
        child: Column(
          children: [
            _BeautyIntensitySlider(
              value: _intensity,
              onChanged: (value) {
                setState(() => _intensity = value);
                if (ArLiveCameraPreview.isSupported) {
                  final strength = (value / 100).clamp(0.0, 1.0);
                  if (strength <= 0.001) {
                    ArCameraBridge.setMagicEnabled(false);
                  } else {
                    ArCameraBridge.setMagicEnabled(true, strength: strength);
                  }
                }
              },
            ),
            _BeautyTabs(
              tabs: _tabs,
              selectedIndex: _selectedTab,
              onSelected: (index) {
                setState(() {
                  _selectedTab = index;
                  _selectedControl = 0;
                });
              },
            ),
            Expanded(
              child: _BeautyControls(
                controls: _controlsByTab[_selectedTab],
                selectedIndex: _selectedControl,
                onSelected: (index) => setState(() => _selectedControl = index),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BeautyIntensitySlider extends StatelessWidget {
  const _BeautyIntensitySlider({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          const SizedBox(
            width: 40,
            child: Icon(Icons.brightness_medium, color: Colors.white, size: 22),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => _updateValue(
                    details.localPosition.dx,
                    constraints.maxWidth,
                  ),
                  onHorizontalDragUpdate: (details) => _updateValue(
                    details.localPosition.dx,
                    constraints.maxWidth,
                  ),
                  child: SizedBox(
                    height: 54,
                    child: CustomPaint(
                      painter: _BeautySliderPainter(value: value),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: 0,
                            left: _thumbPosition(constraints.maxWidth) - 12,
                            child: Text(
                              value.round().toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                height: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _updateValue(double position, double width) {
    final trackWidth = (width - 16).clamp(1.0, double.infinity).toDouble();
    final fraction = ((position - 8) / trackWidth).clamp(0.0, 1.0).toDouble();
    onChanged((1 - fraction) * 100);
  }

  double _thumbPosition(double width) {
    final trackWidth = (width - 16).clamp(1.0, double.infinity).toDouble();
    return 8 + trackWidth * (1 - value / 100);
  }
}

class _BeautySliderPainter extends CustomPainter {
  const _BeautySliderPainter({required this.value});

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    const horizontalPadding = 8.0;
    const trackY = 31.0;
    const thumbRadius = 9.0;
    final right = size.width - horizontalPadding;
    final trackWidth = right - horizontalPadding;
    final thumbX = horizontalPadding + trackWidth * (1 - value / 100);

    final inactivePaint = Paint()
      ..color = const Color(0xFF77777C)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final activePaint = Paint()
      ..color = const Color(0xFFFF315A)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(horizontalPadding, trackY),
      Offset(thumbX, trackY),
      inactivePaint,
    );
    canvas.drawLine(Offset(thumbX, trackY), Offset(right, trackY), activePaint);
    canvas.drawCircle(
      Offset(thumbX, trackY),
      thumbRadius,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_BeautySliderPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}

class _BeautyTabs extends StatelessWidget {
  const _BeautyTabs({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.rtl,
                children: [
                  _BeautyTab(
                    label: tabs[0],
                    isSelected: selectedIndex == 0,
                    onTap: () => onSelected(0),
                  ),
                  const _BeautyTabDivider(),
                  for (var index = 1; index < tabs.length; index++)
                    _BeautyTab(
                      label: tabs[index],
                      isSelected: selectedIndex == index,
                      onTap: () => onSelected(index),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(
            width: 40,
            child: Icon(Icons.refresh, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }
}

class _BeautyTab extends StatelessWidget {
  const _BeautyTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 52,
        height: 48,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.65),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Container(
              width: isSelected ? 36 : 0,
              height: 2,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _BeautyTabDivider extends StatelessWidget {
  const _BeautyTabDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      height: 48,
      child: Center(
        child: SizedBox(
          width: 1,
          height: 20,
          child: ColoredBox(color: Color(0x55333333)),
        ),
      ),
    );
  }
}

class _BeautyControls extends StatelessWidget {
  const _BeautyControls({
    required this.controls,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_BeautyControl> controls;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      reverse: true,
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.rtl,
        children: [
          for (var index = 0; index < controls.length; index++)
            _BeautyControlButton(
              control: controls[index],
              isSelected: selectedIndex == index,
              onTap: () => onSelected(index),
            ),
        ],
      ),
    );
  }
}

class _BeautyControlButton extends StatelessWidget {
  const _BeautyControlButton({
    required this.control,
    required this.isSelected,
    required this.onTap,
  });

  final _BeautyControl control;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 64,
        height: 88,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF303033),
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: Colors.white, width: 1)
                    : null,
              ),
              child: Icon(control.icon, color: Colors.white, size: 29),
            ),
            const SizedBox(height: AppSpacing.xxs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                control.label,
                maxLines: 1,
                style: AppTextStyles.option.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BeautyControl {
  const _BeautyControl(this.label, this.icon);

  final String label;
  final IconData icon;
}
