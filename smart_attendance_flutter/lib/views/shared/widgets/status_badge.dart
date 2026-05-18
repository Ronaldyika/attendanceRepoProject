import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bg, label) = switch (status.toLowerCase()) {
      'open' => (AppTheme.success, const Color(0xFFE8F5E9), 'Open'),
      'closed' => (AppTheme.textSecondary, const Color(0xFFF5F5F5), 'Closed'),
      'expired' => (AppTheme.warning, const Color(0xFFFFF8E1), 'Expired'),
      'synced' => (AppTheme.success, const Color(0xFFE8F5E9), 'Synced'),
      'pending' => (AppTheme.warning, const Color(0xFFFFF8E1), 'Pending'),
      _ => (AppTheme.primary, AppTheme.primaryLight, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
