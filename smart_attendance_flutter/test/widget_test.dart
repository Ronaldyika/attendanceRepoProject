import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_attendance/controllers/auth_controller.dart';
import 'package:smart_attendance/views/auth/splash_view.dart';

void main() {
  testWidgets('SplashView shows app title', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthController()),
        ],
        child: const MaterialApp(home: SplashView()),
      ),
    );
    await tester.pump();

    expect(find.text('Smart Attendance'), findsOneWidget);
    expect(find.textContaining('Offline-Capable'), findsOneWidget);
    expect(find.textContaining('NAHPI'), findsOneWidget);

    // Allow splash navigation timer to complete (skip pumpAndSettle — repeating animations)
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump();
  });
}
