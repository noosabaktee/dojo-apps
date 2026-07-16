import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class DojoLogoMark extends StatelessWidget {
  const DojoLogoMark({
    this.size = 88,
    this.darkColor = AppColors.primaryDark,
    this.primaryColor = AppColors.primary,
    this.accentColor = AppColors.accent,
    super.key,
  });

  final double size;
  final Color darkColor;
  final Color primaryColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logo Dojo',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: _DojoLogoPainter(
          darkColor: darkColor,
          primaryColor: primaryColor,
          accentColor: accentColor,
        ),
      ),
    );
  }
}

class _DojoLogoPainter extends CustomPainter {
  const _DojoLogoPainter({
    required this.darkColor,
    required this.primaryColor,
    required this.accentColor,
  });

  final Color darkColor;
  final Color primaryColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    final framePaint = Paint()
      ..color = darkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * .085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final frame = Path()
      ..moveTo(unit * .18, unit * .67)
      ..lineTo(unit * .18, unit * .32)
      ..quadraticBezierTo(unit * .18, unit * .16, unit * .34, unit * .16)
      ..lineTo(unit * .72, unit * .16);
    canvas.drawPath(frame, framePaint);

    final accentFramePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * .085
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(unit * .81, unit * .28),
      Offset(unit * .81, unit * .59),
      accentFramePaint,
    );

    void drawBar({
      required double left,
      required double top,
      required Color color,
    }) {
      final rect = Rect.fromLTRB(
        unit * left,
        unit * top,
        unit * (left + .12),
        unit * .72,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(unit * .025)),
        Paint()..color = color,
      );
    }

    drawBar(left: .29, top: .53, color: darkColor);
    drawBar(left: .47, top: .40, color: primaryColor);
    drawBar(left: .65, top: .29, color: accentColor);

    final leaf = Path()
      ..moveTo(unit * .14, unit * .79)
      ..quadraticBezierTo(unit * .43, unit * .74, unit * .84, unit * .60)
      ..quadraticBezierTo(unit * .76, unit * .82, unit * .49, unit * .87)
      ..quadraticBezierTo(unit * .27, unit * .90, unit * .14, unit * .79)
      ..close();
    final leafPaint = Paint()
      ..shader = LinearGradient(
        colors: [accentColor, primaryColor],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, unit * .58, unit, unit * .34));
    canvas.drawPath(leaf, leafPaint);
  }

  @override
  bool shouldRepaint(covariant _DojoLogoPainter oldDelegate) {
    return darkColor != oldDelegate.darkColor ||
        primaryColor != oldDelegate.primaryColor ||
        accentColor != oldDelegate.accentColor;
  }
}
