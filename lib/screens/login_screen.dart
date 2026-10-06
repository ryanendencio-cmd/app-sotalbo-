import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showPendingApprovalDialog(String identifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFFE8C547), size: 48),
            const SizedBox(height: 16),
            Text(
              'Pending Admin Approval',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              'Your account ($identifier) has been registered but is currently awaiting verification and approval from the Site Admin.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA63228),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: Text('Understood', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        final role = (response['role'] ?? response['user']?['role'] ?? '').toString();
        final position = (response['position'] ?? response['user']?['position'] ?? '').toString();
        final username = _usernameController.text.trim().toLowerCase();

        ApiService.currentUser = response['user'] ?? response['admin'] ?? response['worker'] ?? response;

        if (role.toLowerCase() == 'admin' || username == 'admin') {
          ApiService.currentUserRole = 'admin';
          Navigator.pushReplacementNamed(context, '/admin_dashboard');
        } else {
          ApiService.currentUserRole = 'worker';
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString();
        if (errorMsg.contains('pending_approval')) {
          _showPendingApprovalDialog(_usernameController.text.trim());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorMsg.replaceAll('Exception: ', ''),
                style: GoogleFonts.inter(fontSize: 13),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. FULL SCREEN CONSTRUCTION BACKGROUND
          Positioned.fill(
            child: Image.asset(
              'assets/construction_bg.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  ),
                ),
              ),
            ),
          ),

          // Dark Gradient Overlay for better contrast
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.5),
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),
          ),

          // 2. MAIN CONTENT
          SafeArea(
            child: Column(
              children: [
                // Top area with centered logo
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Image.asset(
                        'assets/logo.png',
                        height: 75,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                // Floating Glassmorphism Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 30,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0), // Reduced blur to see the background more clearly
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15), // Made it more transparent
                        ),
                        child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24, // Less padding = wider inputs
                      vertical: 64,   // Increased vertical padding to make the box even taller
                    ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // USERNAME / PHONE
                            TextFormField(
                              controller: _usernameController,
                              inputFormatters: [LengthLimitingTextInputFormatter(20)],
                              style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Username/Phone:',
                                hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13.5),
                                prefixIcon: Icon(Icons.person, color: Colors.grey.shade400, size: 20),
                                contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20), // Taller input
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(color: Color(0xFFA63228), width: 1.5),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(color: Colors.red, width: 1.2),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(color: Colors.red, width: 1.5),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your username or phone';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24), // Increased gap

                            // PASSWORD
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              inputFormatters: [LengthLimitingTextInputFormatter(20)],
                              style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Password:',
                                hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13.5),
                                prefixIcon: Icon(Icons.lock, color: Colors.grey.shade400, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: Colors.grey.shade400,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20), // Taller input
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(color: Color(0xFFA63228), width: 1.5),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(color: Colors.red, width: 1.2),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(color: Colors.red, width: 1.5),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                            ),

                            // FORGOT PASSWORD
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => Navigator.pushNamed(context, '/forgot_password'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Forgot password?',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.9), // Changed to white for better contrast
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 32), // Increased gap

                            // LOGIN BUTTON
                            SizedBox(
                              width: double.infinity,
                              height: 56, // Taller button
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFA63228),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation(Colors.white),
                                        ),
                                      )
                                    : Text(
                                        'Log in',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 32), // Increased gap

                            // REGISTER LINK
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Don't have an account? ",
                                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.9)), // Changed to white
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.pushNamed(context, '/register'),
                                    child: Text(
                                      'Register here',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFFF5252), // Bright red for better visibility on dark glass
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
            ),
          ),
        ],
      ),
    );
  }
}