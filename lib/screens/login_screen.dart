import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

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
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remembered = prefs.getString('remembered_username_or_phone');
      if (remembered != null && remembered.isNotEmpty && mounted) {
        setState(() {
          _usernameController.text = remembered;
          _rememberMe = true;
        });
      }
    } catch (_) {}
  }

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

      // Persist or remove remembered credentials
      try {
        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setString('remembered_username_or_phone', _usernameController.text.trim());
        } else {
          await prefs.remove('remembered_username_or_phone');
        }
      } catch (_) {}

      if (mounted) {
        final role = (response['role'] ?? response['user']?['role'] ?? '').toString();
        final username = _usernameController.text.trim().toLowerCase();

        final userObj = Map<String, dynamic>.from(response['user'] ?? response['admin'] ?? response['worker'] ?? response);
        final assignedRole = (role.toLowerCase() == 'admin' || username == 'admin') ? 'admin' : 'worker';
        final token = (response['token'] is String) ? response['token'] as String : ApiService.authToken;

        await ApiService.saveSession(
          user: userObj,
          role: assignedRole,
          token: token,
        );
        NotificationService.syncTokenAfterLogin();

        if (!mounted) return;
        if (assignedRole == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin_dashboard');
        } else {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      }
    } catch (e) {
      if (mounted) {
        final raw = e.toString().replaceAll('Exception: ', '');
        if (raw.contains('pending_approval')) {
          _showPendingApprovalDialog(_usernameController.text.trim());
        } else {
          String displayMsg = raw;
          if (raw.toLowerCase().contains('failed host lookup') ||
              raw.toLowerCase().contains('connection refused') ||
              raw.toLowerCase().contains('clientexception')) {
            displayMsg = 'Unable to connect to server. Please check your network connection.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                displayMsg,
                style: GoogleFonts.inter(fontSize: 13),
              ),
              backgroundColor: const Color(0xFFA63228),
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
                    Colors.black.withValues(alpha: 0.5),
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ),

          // 2. MAIN CONTENT
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isShort = constraints.maxHeight < 680;
                final logoHeight = isShort ? 50.0 : 70.0;
                final cardPaddingVertical = isShort ? 28.0 : 42.0;

                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            const Spacer(flex: 1),
                            // Top area with centered logo
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              child: Image.asset(
                                'assets/logo.png',
                                height: logoHeight,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(flex: 1),

                            // Floating Glassmorphism Card
                            Container(
                              margin: EdgeInsets.only(
                                bottom: isShort ? 16 : 24,
                              ),
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
                                  filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: cardPaddingVertical,
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
                                            inputFormatters: [
                                              LengthLimitingTextInputFormatter(20),
                                            ],
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                            decoration: InputDecoration(
                                              isDense: true,
                                              hintText: 'Username/Phone:',
                                              hintStyle: GoogleFonts.inter(
                                                color: Colors.grey.shade400,
                                                fontSize: 13.5,
                                              ),
                                              prefixIcon: Icon(
                                                Icons.person,
                                                color: Colors.grey.shade400,
                                                size: 20,
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(
                                                vertical: 18,
                                                horizontal: 20,
                                              ),
                                              filled: true,
                                              fillColor: Colors.white,
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(30),
                                                borderSide: BorderSide(
                                                  color: Colors.grey.shade300,
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(30),
                                                borderSide: BorderSide(
                                                  color: Colors.grey.shade300,
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(30),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFA63228),
                                                  width: 1.5,
                                                ),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(30),
                                                borderSide: const BorderSide(
                                                  color: Colors.red,
                                                  width: 1.2,
                                                ),
                                              ),
                                              focusedErrorBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(30),
                                                borderSide: const BorderSide(
                                                  color: Colors.red,
                                                  width: 1.5,
                                                ),
                                              ),
                                            ),
                                            validator: (value) {
                                              if (value == null || value.trim().isEmpty) {
                                                return 'Please enter your username or phone';
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 20),

                                          // PASSWORD
                                          TextFormField(
                                            controller: _passwordController,
                                            obscureText: _obscurePassword,
                                            inputFormatters: [
                                              LengthLimitingTextInputFormatter(20),
                                            ],
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                            decoration: InputDecoration(
                                              isDense: true,
                                              hintText: 'Password:',
                                              hintStyle: GoogleFonts.inter(
                                                color: Colors.grey.shade400,
                                                fontSize: 13.5,
                                              ),
                                              prefixIcon: Icon(
                                                Icons.lock,
                                                color: Colors.grey.shade400,
                                                size: 20,
                                              ),
                                              suffixIcon: IconButton(
                                                icon: Icon(
                                                  _obscurePassword
                                                      ? Icons.visibility_off_outlined
                                                      : Icons.visibility_outlined,
                                                  color: Colors.grey.shade400,
                                                  size: 20,
                                                ),
                                                onPressed: () => setState(
                                                  () => _obscurePassword = !_obscurePassword,
                                                ),
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(
                                                vertical: 18,
                                                horizontal: 20,
                                              ),
                                              filled: true,
                                              fillColor: Colors.white,
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(30),
                                                borderSide: BorderSide(
                                                  color: Colors.grey.shade300,
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(30),
                                                borderSide: BorderSide(
                                                  color: Colors.grey.shade300,
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(30),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFA63228),
                                                  width: 1.5,
                                                ),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(30),
                                                borderSide: const BorderSide(
                                                  color: Colors.red,
                                                  width: 1.2,
                                                ),
                                              ),
                                              focusedErrorBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(30),
                                                borderSide: const BorderSide(
                                                  color: Colors.red,
                                                  width: 1.5,
                                                ),
                                              ),
                                            ),
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
                                                return 'Please enter your password';
                                              }
                                              return null;
                                            },
                                          ),

                                          // REMEMBER ME & FORGOT PASSWORD ROW
                                          const SizedBox(height: 14),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Flexible(
                                                child: InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  onTap: () => setState(
                                                    () => _rememberMe = !_rememberMe,
                                                  ),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 4,
                                                        ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        SizedBox(
                                                          height: 18,
                                                          width: 18,
                                                          child: Checkbox(
                                                            value: _rememberMe,
                                                            onChanged: (val) =>
                                                                setState(
                                                                  () => _rememberMe =
                                                                      val ?? false,
                                                                ),
                                                            activeColor:
                                                                const Color(0xFFA63228),
                                                            checkColor: Colors.white,
                                                            side: BorderSide(
                                                              color: Colors.white
                                                                  .withValues(
                                                                    alpha: 0.85,
                                                                  ),
                                                              width: 1.5,
                                                            ),
                                                            shape:
                                                                RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        4,
                                                                      ),
                                                                ),
                                                            materialTapTargetSize:
                                                                MaterialTapTargetSize
                                                                    .shrinkWrap,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Flexible(
                                                          child: Text(
                                                            'Remember me',
                                                            overflow:
                                                                TextOverflow.ellipsis,
                                                            style: GoogleFonts.inter(
                                                              fontSize: 12.5,
                                                              fontWeight:
                                                                  FontWeight.w500,
                                                              color: Colors.white
                                                                  .withValues(
                                                                    alpha: 0.9,
                                                                  ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              TextButton(
                                                onPressed: () => Navigator.pushNamed(
                                                  context,
                                                  '/forgot_password',
                                                ),
                                                style: TextButton.styleFrom(
                                                  padding: EdgeInsets.zero,
                                                  minimumSize: Size.zero,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize.shrinkWrap,
                                                ),
                                                child: Text(
                                                  'Forgot password?',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.white.withValues(
                                                      alpha: 0.9,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 24),

                                          // LOGIN BUTTON
                                          SizedBox(
                                            width: double.infinity,
                                            height: 52,
                                            child: ElevatedButton(
                                              onPressed:
                                                  _isLoading ? null : _handleLogin,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFFA63228),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(30),
                                                ),
                                                elevation: 0,
                                              ),
                                              child: _isLoading
                                                  ? const SizedBox(
                                                      width: 22,
                                                      height: 22,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2.5,
                                                            valueColor:
                                                                AlwaysStoppedAnimation(
                                                                  Colors.white,
                                                                ),
                                                          ),
                                                    )
                                                  : Text(
                                                      'Log in',
                                                      style: GoogleFonts.inter(
                                                        color: Colors.white,
                                                        fontSize: 15.5,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                            ),
                                          ),

                                          const SizedBox(height: 24),

                                          // REGISTER LINK
                                          Center(
                                            child: Wrap(
                                              alignment: WrapAlignment.center,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                Text(
                                                  "Don't have an account? ",
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12.5,
                                                    color: Colors.white.withValues(
                                                      alpha: 0.9,
                                                    ),
                                                  ),
                                                ),
                                                GestureDetector(
                                                  onTap: () => Navigator.pushNamed(
                                                    context,
                                                    '/register',
                                                  ),
                                                  child: Text(
                                                    'Register here',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: const Color(0xFFFF5252),
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
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}