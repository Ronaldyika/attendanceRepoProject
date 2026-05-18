import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';

class ConnectivityBanner extends StatelessWidget {
  final bool isOnline;
  const ConnectivityBanner({super.key, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      height: isOnline ? 0 : 36,
      color: AppTheme.warning,
      child: isOnline
          ? null
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Offline mode – scans saved locally',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ],
            ),
    );
  }
}
