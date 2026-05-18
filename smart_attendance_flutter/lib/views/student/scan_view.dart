import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../controllers/attendance_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_theme.dart';
import '../../core/utils/connectivity_service.dart';
import '../../core/utils/qr_utils.dart';
import '../../services/session_service.dart';

class ScanView extends StatefulWidget {
  const ScanView({super.key});

  @override
  State<ScanView> createState() => _ScanViewState();
}

class _ScanViewState extends State<ScanView>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _scanCtrl = MobileScannerController();
  final _sessionService = SessionService();
  bool _isProcessing = false;
  bool _torchOn = false;
  late AnimationController _successAnim;

  @override
  void initState() {
    super.initState();
    _successAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _successAnim.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    // Quick local format check
    final parsed = QrUtils.parseQrPayload(raw);
    if (parsed == null) {
      _showSnack('Invalid QR code. Please scan the code shown by your lecturer.', isError: true);
      return;
    }

    setState(() => _isProcessing = true);
    _scanCtrl.stop();

    final auth = context.read<AuthController>();
    final attCtrl = context.read<AttendanceController>();
    final deviceUuid = auth.deviceUuid ?? '';
    final studentId = auth.user!.id;
    final isOnline = await ConnectivityService().checkConnection();

    bool success = false;
    String? errorMsg;

    if (isOnline) {
      success = await attCtrl.scanQrOnline(
        sessionId: parsed.sessionId,
        qrPayload: raw,
        deviceUuid: deviceUuid,
      );
      errorMsg = attCtrl.scanError;
    } else {
      // Offline: load session from local cache for HMAC verification
      final session = await _sessionService.getLocalSession(parsed.sessionId);
      if (session == null) {
        errorMsg = 'Session not found locally. Connect to the internet to validate this QR code.';
      } else {
        success = await attCtrl.scanQrOffline(
          session: session,
          qrPayload: raw,
          deviceUuid: deviceUuid,
          studentId: studentId,
        );
        if (attCtrl.scanState == AttendanceScanState.duplicate) {
          errorMsg = attCtrl.scanError;
        } else {
          errorMsg = attCtrl.scanError;
        }
      }
    }

    if (!mounted) return;

    if (success) {
      _successAnim.forward(from: 0);
      await _showSuccessSheet(
          isOnline: isOnline, sessionId: parsed.sessionId);
    } else if (attCtrl.scanState == AttendanceScanState.duplicate) {
      _showDuplicateSheet();
    } else {
      _showSnack(errorMsg ?? 'Scan failed. Please try again.', isError: true);
    }

    setState(() => _isProcessing = false);
    attCtrl.resetScanState();
    _scanCtrl.start();
  }

  Future<void> _showSuccessSheet({required bool isOnline, required String sessionId}) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => _ScanResultSheet(
        isSuccess: true,
        isOnline: isOnline,
        onDismiss: () => Navigator.pop(context),
      ),
    );
  }

  void _showDuplicateSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScanResultSheet(
        isSuccess: false,
        isDuplicate: true,
        isOnline: true,
        onDismiss: () => Navigator.pop(context),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attCtrl = context.watch<AttendanceController>();

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Scan QR Code',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() => _torchOn = !_torchOn);
              _scanCtrl.toggleTorch();
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera
          MobileScanner(
            controller: _scanCtrl,
            onDetect: _onDetect,
          ),

          // Scanner overlay
          _ScannerOverlay(isProcessing: _isProcessing),

          // Status bar at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomStatusBar(attCtrl: attCtrl),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  final bool isProcessing;
  const _ScannerOverlay({required this.isProcessing});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 80),
            // Scan frame
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isProcessing ? AppTheme.warning : Colors.white,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  // Corner decorators
                  ..._buildCorners(),
                  if (isProcessing)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 12),
                            Text('Verifying...',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Point camera at the QR code',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCorners() {
    const size = 20.0;
    const thickness = 3.0;
    final color = isProcessing ? AppTheme.warning : AppTheme.accent;

    return [
      _Corner(top: 0, left: 0, size: size, thickness: thickness, color: color),
      _Corner(top: 0, right: 0, size: size, thickness: thickness, color: color, flipH: true),
      _Corner(bottom: 0, left: 0, size: size, thickness: thickness, color: color, flipV: true),
      _Corner(bottom: 0, right: 0, size: size, thickness: thickness, color: color, flipH: true, flipV: true),
    ];
  }
}

class _Corner extends StatelessWidget {
  final double? top, left, right, bottom, size, thickness;
  final Color color;
  final bool flipH, flipV;

  const _Corner({
    this.top, this.left, this.right, this.bottom,
    required this.size, required this.thickness, required this.color,
    this.flipH = false, this.flipV = false,
  });

  @override
  Widget build(BuildContext context) => Positioned(
    top: top, left: left, right: right, bottom: bottom,
    child: Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..scale(flipH ? -1.0 : 1.0, flipV ? -1.0 : 1.0),
      child: SizedBox(
        width: size, height: size,
        child: CustomPaint(painter: _CornerPainter(color: color, thickness: thickness!)),
      ),
    ),
  );
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  _CornerPainter({required this.color, required this.thickness});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = thickness..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(0, 0), Offset(size.width, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.55);
    final frameSize = 260.0;
    final left = (size.width - frameSize) / 2;
    final top = (size.height - frameSize) / 2 + 40;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, frameSize, frameSize),
      const Radius.circular(20),
    );
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..addRect(fullRect)
      ..addRRect(rect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _BottomStatusBar extends StatelessWidget {
  final AttendanceController attCtrl;
  const _BottomStatusBar({required this.attCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (attCtrl.pendingCount > 0) ...[
            const Icon(Icons.cloud_upload_outlined,
                color: AppTheme.warning, size: 16),
            const SizedBox(width: 6),
            Text(
              '${attCtrl.pendingCount} record${attCtrl.pendingCount > 1 ? 's' : ''} pending sync',
              style: const TextStyle(color: AppTheme.warning, fontSize: 12),
            ),
          ] else ...[
            const Icon(Icons.security, color: Colors.white54, size: 14),
            const SizedBox(width: 6),
            const Text('HMAC-SHA256 verified scanning',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _ScanResultSheet extends StatelessWidget {
  final bool isSuccess, isDuplicate, isOnline;
  final VoidCallback onDismiss;

  const _ScanResultSheet({
    required this.isSuccess,
    this.isDuplicate = false,
    required this.isOnline,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isDuplicate
                  ? AppTheme.warning.withOpacity(0.1)
                  : isSuccess
                      ? AppTheme.success.withOpacity(0.1)
                      : AppTheme.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDuplicate
                  ? Icons.warning_amber_rounded
                  : isSuccess
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
              size: 40,
              color: isDuplicate
                  ? AppTheme.warning
                  : isSuccess
                      ? AppTheme.success
                      : AppTheme.error,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isDuplicate
                ? 'Already Registered'
                : isSuccess
                    ? 'Attendance Recorded!'
                    : 'Scan Failed',
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            isDuplicate
                ? 'You have already marked attendance for this session.'
                : isSuccess && !isOnline
                    ? 'Saved locally. Will sync automatically when online.'
                    : isSuccess
                        ? 'Your attendance has been recorded on the server.'
                        : 'Could not record attendance.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary),
          ),
          if (isSuccess && !isOnline) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off, color: AppTheme.warning, size: 16),
                  SizedBox(width: 6),
                  Text('Offline mode – syncing later',
                      style: TextStyle(
                          color: AppTheme.warning, fontSize: 12)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDismiss,
              style: ElevatedButton.styleFrom(
                backgroundColor: isSuccess ? AppTheme.success : AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Continue',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
