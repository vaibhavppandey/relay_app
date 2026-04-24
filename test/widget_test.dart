import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_app/src/feat/onboarding/presentation/widgets/splash_loading.dart';

void main() {
  testWidgets('SplashLoadingWidget shows spinner and message', (
    WidgetTester tester,
  ) async {
    const msg = 'Creating secure session...';

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(360, 690),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return const MaterialApp(
            home: Scaffold(body: SplashLoadingWidget(message: msg)),
          );
        },
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(msg), findsOneWidget);
  });
}
