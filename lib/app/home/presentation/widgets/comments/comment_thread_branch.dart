import 'package:bimobondapp/app/home/presentation/widgets/comments/comment_layout_constants.dart';
import 'package:flutter/material.dart';

class CommentThreadBranch extends StatelessWidget {
  const CommentThreadBranch({
    required this.child,
    required this.isLast,
    required this.lineColor,
    super.key,
  });

  final Widget child;
  final bool isLast;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: CommentLayout.threadIndent,
      ),
      child: IntrinsicHeight(
        child: Row(
          textDirection: textDirection,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 22,
              child: CustomPaint(
                painter: CommentThreadPainter(
                  color: lineColor,
                  isLast: isLast,
                  avatarCenterY: CommentLayout.replyAvatarRadius + 12,
                  textDirection: textDirection,
                ),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class CommentThreadPainter extends CustomPainter {
  const CommentThreadPainter({
    required this.color,
    required this.isLast,
    required this.avatarCenterY,
    required this.textDirection,
  });

  final Color color;
  final bool isLast;
  final double avatarCenterY;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (textDirection == TextDirection.rtl) {
      canvas.save();
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
      _paintBranch(canvas, size, paint);
      canvas.restore();
      return;
    }

    _paintBranch(canvas, size, paint);
  }

  void _paintBranch(Canvas canvas, Size size, Paint paint) {
    final branchY = avatarCenterY.clamp(12.0, size.height);
    const cornerRadius = 10.0;
    final path = Path();

    if (isLast) {
      path.moveTo(0, 0);
      path.lineTo(0, branchY - cornerRadius);
      path.quadraticBezierTo(0, branchY, cornerRadius, branchY);
      path.lineTo(size.width, branchY);
    } else {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.moveTo(0, branchY - cornerRadius);
      path.quadraticBezierTo(0, branchY, cornerRadius, branchY);
      path.lineTo(size.width, branchY);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CommentThreadPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isLast != isLast ||
        oldDelegate.avatarCenterY != avatarCenterY ||
        oldDelegate.textDirection != textDirection;
  }
}
