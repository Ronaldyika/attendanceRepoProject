import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';

class AnimatedStatsCard extends StatefulWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const AnimatedStatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color = AppTheme.primary,
    this.subtitle,
  });

  @override
  State<AnimatedStatsCard> createState() => _AnimatedStatsCardState();
}

class _AnimatedStatsCardState extends State<AnimatedStatsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.1),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 20),
                ),
                if (widget.subtitle != null)
                  Flexible(
                    child: Text(widget.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: widget.value),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, val, __) => Text(
                '$val',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary),
              ),
            ),
            const SizedBox(height: 4),
            Text(widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
