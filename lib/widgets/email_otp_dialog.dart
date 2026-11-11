import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

Future<String?> showEmailOtpDialog({
  required BuildContext context,
  required String email,
  required String purpose,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _EmailOtpDialog(email: email, purpose: purpose),
  );
}

class _EmailOtpDialog extends StatefulWidget {
  const _EmailOtpDialog({required this.email, required this.purpose});

  final String email;
  final String purpose;

  @override
  State<_EmailOtpDialog> createState() => _EmailOtpDialogState();
}

class _EmailOtpDialogState extends State<_EmailOtpDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _resendCode() async {
    try {
      await ApiService.sendEmailOtp(
        email: widget.email,
        purpose: widget.purpose,
      );
      if (mounted) setState(() => _errorMessage = 'A new code was sent.');
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    }
  }

  Future<void> _verifyCode() async {
    if (_controller.text.trim().length != 6) {
      setState(() => _errorMessage = 'Enter all 6 digits.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });
    try {
      final token = await ApiService.verifyEmailOtp(
        email: widget.email,
        purpose: widget.purpose,
        code: _controller.text.trim(),
      );
      if (mounted) Navigator.pop(context, token);
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.toString();
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Verify email'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Enter the 6-digit code sent to ${widget.email}.'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Verification code',
              errorText: _errorMessage,
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsOverflowButtonSpacing: 4,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      semanticLabel: 'Email verification',
      actions: [
        TextButton(
          onPressed: _isVerifying ? null : _resendCode,
          child: const Text('Resend code'),
        ),
        TextButton(
          onPressed: _isVerifying ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isVerifying ? null : _verifyCode,
          child: _isVerifying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Verify'),
        ),
      ],
    );
  }
}
