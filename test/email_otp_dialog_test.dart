import 'package:buildtrack/widgets/email_otp_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('closing the focused email OTP dialog does not throw', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await showEmailOtpDialog(
                  context: context,
                  email: 'worker@gmail.com',
                  purpose: 'registration',
                );
              },
              child: const Text('Open OTP'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open OTP'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
