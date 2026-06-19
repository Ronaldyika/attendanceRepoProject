import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';

/// Animated laser scan line inside the QR scanner frame.
class AnimatedScanLine extends StatefulWidget {
  final double frameSize;
  final bool isProcessing;

  const AnimatedScanLine({
    super.key,
    required this.frameSize,
    this.isProcessing = false,
  });

  @override
  State<AnimatedScanLine> createState() => _AnimatedScanLineState();
}

class _AnimatedScanLineState extends State<AnimatedScanLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _position;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _position = Tween<double>(begin: 0.08, end: 0.92).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isProcessing) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _position,
      builder: (context, _) {
        final top = widget.frameSize * _position.value;
        return Positioned(
          left: 16,
          right: 16,
          top: top,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppTheme.accent.withOpacity(0.9),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withOpacity(0.6),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
