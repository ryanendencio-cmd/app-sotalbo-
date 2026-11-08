import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  const CurrencyInputFormatter();

  static String formatEditing(String value) {
    final parts = value.replaceAll(',', '').split('.');
    final integer = parts.first.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final groupedInteger = integer.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    if (parts.length == 1) return groupedInteger;
    return '$groupedInteger.${parts.skip(1).join()}';
  }

  static String formatComplete(String value) {
    final normalized = value.replaceAll(',', '').trim();
    if (normalized.isEmpty) return '';
    final parts = normalized.split('.');
    final integer = parts.first.isEmpty ? '0' : parts.first;
    final fraction = parts.length > 1 ? parts[1] : '';
    final paddedFraction = fraction.padRight(2, '0').substring(0, 2);
    final groupedInteger = integer.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '$groupedInteger.$paddedFraction';
  }

  static double? parse(String value) =>
      double.tryParse(value.replaceAll(',', '').trim());

  String _normalize(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^\d.]'), '');
    final decimalIndex = sanitized.indexOf('.');
    if (decimalIndex < 0) return sanitized;
    final integer = sanitized.substring(0, decimalIndex);
    final fractionDigits = sanitized
        .substring(decimalIndex + 1)
        .replaceAll('.', '');
    final fraction = fractionDigits.substring(
      0,
      fractionDigits.length.clamp(0, 2).toInt(),
    );
    return '$integer.$fraction';
  }

  int _formattedOffset(String formatted, int characterCount) {
    if (characterCount <= 0) return 0;
    var seen = 0;
    for (var index = 0; index < formatted.length; index++) {
      if (RegExp(r'[\d.]').hasMatch(formatted[index])) seen++;
      if (seen >= characterCount) return index + 1;
    }
    return formatted.length;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = _normalize(newValue.text);
    final formatted = formatEditing(normalized);
    final startCount = _normalize(
      newValue.text.substring(
        0,
        newValue.selection.start.clamp(0, newValue.text.length),
      ),
    ).length;
    final endCount = _normalize(
      newValue.text.substring(
        0,
        newValue.selection.end.clamp(0, newValue.text.length),
      ),
    ).length;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection(
        baseOffset: _formattedOffset(formatted, startCount),
        extentOffset: _formattedOffset(formatted, endCount),
      ),
      composing: TextRange.empty,
    );
  }
}

class CurrencyTextField extends StatefulWidget {
  const CurrencyTextField({
    required this.controller,
    required this.decoration,
    this.style,
    this.textAlign = TextAlign.start,
    super.key,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  State<CurrencyTextField> createState() => _CurrencyTextFieldState();
}

class _CurrencyTextFieldState extends State<CurrencyTextField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    final text = widget.controller.text;
    final formatted = _focusNode.hasFocus
        ? text.replaceAll(',', '').replaceFirst(RegExp(r'\.00$'), '')
        : CurrencyInputFormatter.formatComplete(text);
    if (text == formatted) return;
    widget.controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.controller,
    focusNode: _focusNode,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textInputAction: TextInputAction.done,
    onEditingComplete: _focusNode.unfocus,
    onTapOutside: (_) => _focusNode.unfocus(),
    inputFormatters: const [CurrencyInputFormatter()],
    textAlign: widget.textAlign,
    style: widget.style,
    decoration: widget.decoration,
  );
}
