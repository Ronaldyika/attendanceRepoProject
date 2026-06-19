import 'dart:math';
import 'package:flutter/material.dart';

class FloatingOrbsBackground extends StatefulWidget {
  final List<Color> colors;
  const FloatingOrbsBackground({super.key, required this.colors});

  @override
  State<FloatingOrbsBackground> createState() => _FloatingOrbsBackgroundState();
}

class _FloatingOrbsBackgroundState extends State<FloatingOrbsBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _OrbsPainter(
          progress: _ctrl.value,
          colors: widget.colors,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _OrbsPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;

  _OrbsPainter({required this.progress, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final orbs = [
      _Orb(0.15, 0.2, 80, 0),
      _Orb(0.75, 0.15, 60, 1),
      _Orb(0.85, 0.7, 100, 2),
      _Orb(0.1, 0.75, 70, 0),
      _Orb(0.5, 0.5, 50, 1),
    ];

    for (final orb in orbs) {
      final dx = orb.x * size.width +
          sin((progress + orb.phase) * 2 * pi) * 18;
      final dy = orb.y * size.height +
          cos((progress + orb.phase) * 2 * pi) * 14;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            colors[orb.colorIndex % colors.length].withValues(alpha: 0.25),
            colors[orb.colorIndex % colors.length].withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(dx, dy),
          radius: orb.radius,
        ));
      canvas.drawCircle(Offset(dx, dy), orb.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbsPainter old) =>
      old.progress != progress;
}

class _Orb {
  final double x, y, radius, phase;
  final int colorIndex;
  _Orb(this.x, this.y, this.radius, this.colorIndex) : phase = x + y;
}
