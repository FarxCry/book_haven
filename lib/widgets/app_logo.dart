import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// Kitaab Ghar logo: an open book under a roof ("book house").
/// [light] = white tile with teal pages, for use on dark teal backgrounds.
class AppLogo extends StatelessWidget {
  final double size;
  final bool light;
  const AppLogo({super.key, this.size = 40, this.light = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter(light)),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final bool light;
  _LogoPainter(this.light);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final tile = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, s, s), Radius.circular(s * 0.26));

    final bg = Paint();
    if (light) {
      bg.color = Colors.white;
    } else {
      bg.shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.teal, AppColors.tealDark])
          .createShader(Rect.fromLTWH(0, 0, s, s));
    }
    canvas.drawRRect(tile, bg);

    final pageColor = light ? AppColors.teal : Colors.white;
    final lineColor = light ? Colors.white : AppColors.teal;
    final pages = Paint()..color = pageColor;

    Path left() => Path()
      ..moveTo(0.485 * s, 0.37 * s)
      ..quadraticBezierTo(0.32 * s, 0.30 * s, 0.17 * s, 0.36 * s)
      ..lineTo(0.17 * s, 0.75 * s)
      ..quadraticBezierTo(0.32 * s, 0.69 * s, 0.485 * s, 0.78 * s)
      ..close();
    Path right() => Path()
      ..moveTo(0.515 * s, 0.37 * s)
      ..quadraticBezierTo(0.68 * s, 0.30 * s, 0.83 * s, 0.36 * s)
      ..lineTo(0.83 * s, 0.75 * s)
      ..quadraticBezierTo(0.68 * s, 0.69 * s, 0.515 * s, 0.78 * s)
      ..close();
    canvas.drawPath(left(), pages);
    canvas.drawPath(right(), pages);

    final line = Paint()
      ..color = tint(lineColor, 0.4)
      ..strokeWidth = s * 0.022
      ..strokeCap = StrokeCap.round;
    for (final y in [0.49, 0.59]) {
      canvas.drawLine(Offset(0.25 * s, (y + 0.015) * s), Offset(0.43 * s, (y + 0.035) * s), line);
      canvas.drawLine(Offset(0.57 * s, (y + 0.035) * s), Offset(0.75 * s, (y + 0.015) * s), line);
    }

    final roof = Paint()
      ..color = AppColors.marigold
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final roofPath = Path()
      ..moveTo(0.20 * s, 0.30 * s)
      ..lineTo(0.5 * s, 0.12 * s)
      ..lineTo(0.80 * s, 0.30 * s);
    canvas.drawPath(roofPath, roof);
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.light != light;
}
