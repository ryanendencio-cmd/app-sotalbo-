import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_sidebar.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  int _currentStep = 0;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _handleSendOtp() {
    if (_phoneController.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit phone number (e.g. 9XXXXXXXXX)')),
      );
      return;
    }
    setState(() => _currentStep = 1);
  }

  void _handleVerifyOtp() {
    String enteredOtp = _otpControllers.map((c) => c.text).join();
    if (enteredOtp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the full 6-digit OTP')),
      );
      return;
    }
    setState(() => _currentStep = 2);
  }

  void _handleResetPassword() {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 44),
              ),
              const SizedBox(height: 16),
              Text(
                'Password Reset Complete',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                'Your password has been updated successfully. You can now use your new password to sign in.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA63228),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: Text('Back to Login', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildStepIndicator(double screenWidth) {
    final double circleSize = screenWidth < 360 ? 24.0 : 28.0;
    final double lineWidth = screenWidth < 360 ? 24.0 : 32.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        bool isActive = index <= _currentStep;
        return Row(
          children: [
            Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFA63228) : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.inter(
                    fontSize: screenWidth < 360 ? 11 : 12,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
            if (index < 2)
              Container(
                width: lineWidth,
                height: 2,
                color: index < _currentStep ? const Color(0xFFA63228) : Colors.grey.shade300,
              ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;
    final double screenHeight = size.height;
    final bool isSmall = screenHeight < 700;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.06,
                vertical: screenHeight * 0.01,
              ),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/logo.png',
                        height: screenHeight * (isSmall ? 0.065 : 0.075),
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.018),

                    _buildStepIndicator(screenWidth),
                    SizedBox(height: screenHeight * 0.025),

                    // STEP 1: PHONE NUMBER
                    if (_currentStep == 0) ...[
                      Text(
                        'Forgot Password?',
                        style: GoogleFonts.inter(
                          fontSize: screenWidth < 360 ? 18 : 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enter your registered phone number to receive a verification OTP code.',
                        style: GoogleFonts.inter(
                          fontSize: screenWidth < 360 ? 12 : 13,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.025),

                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(fontSize: screenWidth < 360 ? 13 : 14, color: Colors.black87),
                        inputFormatters: [
                          PhilippinePhoneFormatter(),
                        ],
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: '9XXXXXXXXX',
                          hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: screenWidth < 360 ? 12 : 13),
                          prefixText: '+63 ',
                          prefixStyle: GoogleFonts.inter(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: screenWidth < 360 ? 13 : 14),
                          prefixIcon: Icon(Icons.phone_outlined, color: Colors.grey, size: screenWidth < 360 ? 18 : 20),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: screenHeight * 0.015,
                            horizontal: 14,
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFA63228), width: 1.5),
                          ),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.025),

                      SizedBox(
                        width: double.infinity,
                        height: screenHeight * (isSmall ? 0.055 : 0.058),
                        child: ElevatedButton(
                          onPressed: _handleSendOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA63228),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: Text(
                            'Send OTP Code',
                            style: GoogleFonts.inter(
                              fontSize: screenWidth < 360 ? 14 : 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],

                    // STEP 2: OTP VERIFICATION
                    if (_currentStep == 1) ...[
                      Text(
                        'Verification Code',
                        style: GoogleFonts.inter(
                          fontSize: screenWidth < 360 ? 18 : 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enter the 6-digit code sent to ${_phoneController.text}',
                        style: GoogleFonts.inter(
                          fontSize: screenWidth < 360 ? 12 : 13,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.025),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          final double fieldWidth = (constraints.maxWidth - (5 * 8)) / 6;
                          final double finalWidth = fieldWidth.clamp(36.0, 48.0);

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(6, (index) {
                              return SizedBox(
                                width: finalWidth,
                                height: finalWidth * 1.15,
                                child: TextFormField(
                                  controller: _otpControllers[index],
                                  focusNode: _otpFocusNodes[index],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: screenWidth < 360 ? 16 : 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(1),
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: InputDecoration(
                                    contentPadding: EdgeInsets.zero,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFA63228), width: 2),
                                    ),
                                  ),
                                  onChanged: (val) {
                                    if (val.isNotEmpty && index < 5) {
                                      _otpFocusNodes[index + 1].requestFocus();
                                    } else if (val.isEmpty && index > 0) {
                                      _otpFocusNodes[index - 1].requestFocus();
                                    }
                                  },
                                ),
                              );
                            }),
                          );
                        },
                      ),
                      SizedBox(height: screenHeight * 0.025),

                      SizedBox(
                        width: double.infinity,
                        height: screenHeight * (isSmall ? 0.055 : 0.058),
                        child: ElevatedButton(
                          onPressed: _handleVerifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA63228),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: Text(
                            'Verify Code',
                            style: GoogleFonts.inter(
                              fontSize: screenWidth < 360 ? 14 : 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('OTP code resent to your number')),
                            );
                          },
                          child: Text(
                            'Resend OTP Code',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFA63228),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // STEP 3: NEW PASSWORD
                    if (_currentStep == 2) ...[
                      Text(
                        'Reset Password',
                        style: GoogleFonts.inter(
                          fontSize: screenWidth < 360 ? 18 : 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create a strong new password for your account.',
                        style: GoogleFonts.inter(
                          fontSize: screenWidth < 360 ? 12 : 13,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.025),

                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNewPass,
                        style: GoogleFonts.inter(fontSize: screenWidth < 360 ? 13 : 14, color: Colors.black87),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'New Password',
                          hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: screenWidth < 360 ? 12 : 13),
                          prefixIcon: Icon(Icons.lock_outline, color: Colors.grey, size: screenWidth < 360 ? 18 : 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNewPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: Colors.grey,
                              size: 18,
                            ),
                            onPressed: () => setState(() => _obscureNewPass = !_obscureNewPass),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: screenHeight * 0.015,
                            horizontal: 14,
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFA63228), width: 1.5),
                          ),
                        ),
                        inputFormatters: [LengthLimitingTextInputFormatter(20)],
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (value.length < 8 || value.length > 20) return 'Must be 8 to 20 characters';
                          if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Needs capital letter (A-Z)';
                          if (!RegExp(r'[a-z]').hasMatch(value)) return 'Needs small letter (a-z)';
                          if (!RegExp(r'[0-9]').hasMatch(value)) return 'Needs number (0-9)';
                          return null;
                        },
                      ),
                      SizedBox(height: screenHeight * 0.012),

                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPass,
                        style: GoogleFonts.inter(fontSize: screenWidth < 360 ? 13 : 14, color: Colors.black87),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Confirm New Password',
                          hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: screenWidth < 360 ? 12 : 13),
                          prefixIcon: Icon(Icons.lock_outline, color: Colors.grey, size: screenWidth < 360 ? 18 : 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: Colors.grey,
                              size: 18,
                            ),
                            onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: screenHeight * 0.015,
                            horizontal: 14,
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFA63228), width: 1.5),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (value != _newPasswordController.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                      SizedBox(height: screenHeight * 0.025),

                      SizedBox(
                        width: double.infinity,
                        height: screenHeight * (isSmall ? 0.055 : 0.058),
                        child: ElevatedButton(
                          onPressed: _handleResetPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA63228),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: Text(
                            'Update Password',
                            style: GoogleFonts.inter(
                              fontSize: screenWidth < 360 ? 14 : 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PhilippinePhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text;
    if (text.isEmpty) return newValue;

    // Remove any non-digits
    text = text.replaceAll(RegExp(r'\D'), '');

    // Strip country code 63 if present
    if (text.startsWith('63')) {
      text = text.substring(2);
    }
    // Strip leading 0
    if (text.startsWith('0')) {
      text = text.substring(1);
    }

    if (text.length > 10) {
      text = text.substring(0, 10);
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}