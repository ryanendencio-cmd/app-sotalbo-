import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:buildtrack/widgets/currency_text_field.dart';

void main() {
  group('CurrencyInputFormatter', () {
    const formatter = CurrencyInputFormatter();

    test('keeps an empty amount empty', () {
      expect(CurrencyInputFormatter.formatEditing(''), '');
      expect(CurrencyInputFormatter.formatComplete(''), '');
      expect(CurrencyInputFormatter.parse(''), isNull);
    });

    test('groups thousands while editing and pads cents when complete', () {
      expect(CurrencyInputFormatter.formatEditing('1'), '1');
      expect(CurrencyInputFormatter.formatComplete('1'), '1.00');
      expect(CurrencyInputFormatter.formatEditing('1000'), '1,000');
      expect(CurrencyInputFormatter.formatComplete('1000'), '1,000.00');
      expect(CurrencyInputFormatter.formatComplete('1000.5'), '1,000.50');
    });

    test('limits decimal input and preserves numeric parsing', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(),
        const TextEditingValue(
          text: '1000.567',
          selection: TextSelection.collapsed(offset: 8),
        ),
      );

      expect(result.text, '1,000.56');
      expect(CurrencyInputFormatter.parse(result.text), 1000.56);
    });
  });

  testWidgets('formats input on blur while preserving an empty default', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              CurrencyTextField(
                controller: controller,
                decoration: const InputDecoration(),
              ),
              const Text('Outside field'),
            ],
          ),
        ),
      ),
    );

    expect(controller.text, isEmpty);
    await tester.enterText(find.byType(TextField), '1000.5');
    await tester.pump();
    expect(controller.text, '1,000.5');

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(controller.text, '1,000.50');
    controller.dispose();
  });
}
