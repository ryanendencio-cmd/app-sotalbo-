import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/psgc_service.dart';
import '../services/semaphore_service.dart';
import '../widgets/app_sidebar.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeTerms = false;

  // Mobile app registration is strictly for Workers
  final String _selectedRole = 'Worker';

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bdayController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPhoneVerified = false;
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _bdayController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Terms & Conditions',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'By accessing BuildTrack, you agree to submit accurate attendance logs, report equipment issues responsibly, and adhere to site safety and administrative policies as supervised by S-CON management.',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, height: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Data Privacy Consent:',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                'You also consent to the collection, processing, and secure storage of your personal information strictly for employment verification, payroll, and administrative purposes in accordance with the Data Privacy Act.',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, height: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Additional Responsibilities:',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                '• You confirm that all submitted personal details are true and accurate.\n'
                '• You are responsible for keeping your login credentials secure and confidential.\n'
                '• You will not use this application for any fraudulent activities or unauthorized access.',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFFA63228)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddressPicker() {
    int step = 0;
    String regionCode = '';
    String regionName = '';
    String provinceCode = '';
    String provinceName = '';
    String cityCode = '';
    String cityName = '';
    String searchQuery = '';

    List<Map<String, dynamic>> items = [];
    bool isLoading = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            void loadStepData() async {
              setModalState(() {
                isLoading = true;
                items = [];
              });

              List<Map<String, dynamic>> data = [];
              if (step == 0) {
                data = await PsgcService.getRegions();
              } else if (step == 1) {
                data = await PsgcService.getProvinces(regionCode);
              } else if (step == 2) {
                data = await PsgcService.getCitiesMunicipalities(regionCode, provinceCode);
              } else if (step == 3) {
                data = await PsgcService.getBarangays(cityCode);
              }

              setModalState(() {
                items = data;
                isLoading = false;
              });
            }

            if (isLoading && items.isEmpty) {
              loadStepData();
            }

            String stepTitle = step == 0
                ? "Select Region"
                : step == 1
                    ? "Select Province"
                    : step == 2
                        ? "Select City/Municipality"
                        : "Select Barangay";

            final filteredItems = items.where((item) {
              if (searchQuery.isEmpty) return true;
              String name = step == 0 ? PsgcService.formatRegionLabel(item) : (item['name'] ?? '').toString();
              return name.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      children: [
                        if (step > 0)
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.black87),
                            onPressed: () {
                              setModalState(() {
                                step--;
                                searchQuery = '';
                              });
                              loadStepData();
                            },
                          )
                        else
                          const SizedBox(width: 48),
                        Expanded(
                          child: Text(
                            stepTitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black87),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey.shade300),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: TextField(
                      onChanged: (val) {
                        setModalState(() {
                          searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search $stepTitle...',
                        hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  Expanded(
                    child: isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: Color(0xFFA63228)),
                          )
                        : filteredItems.isEmpty
                            ? Center(
                                child: Text('No results found', style: GoogleFonts.inter(color: Colors.grey)),
                              )
                            : ListView.separated(
                                itemCount: filteredItems.length,
                                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                                itemBuilder: (context, index) {
                                  final item = filteredItems[index];
                                  String displayName = step == 0
                                      ? PsgcService.formatRegionLabel(item)
                                      : (item['name'] ?? '').toString();

                                  return ListTile(
                                    title: Text(displayName, style: GoogleFonts.inter(fontSize: 14)),
                                    trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                                    onTap: () {
                                      if (step == 0) {
                                        regionCode = (item['code'] ?? '').toString();
                                        regionName = displayName;
                                        step = 1;
                                        searchQuery = '';
                                        loadStepData();
                                      } else if (step == 1) {
                                        provinceCode = (item['code'] ?? '').toString();
                                        provinceName = displayName;
                                        step = 2;
                                        searchQuery = '';
                                        loadStepData();
                                      } else if (step == 2) {
                                        cityCode = (item['code'] ?? '').toString();
                                        cityName = displayName;
                                        step = 3;
                                        searchQuery = '';
                                        loadStepData();
                                      } else if (step == 3) {
                                        String barangayName = displayName;
                                        _addressController.text = "$regionName, $provinceName, $cityName, $barangayName";
                                        Navigator.pop(context);
                                      }
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final today = DateTime.now();
    final minDate = DateTime(today.year - 60, today.month, today.day + 1);
    final maxDate = DateTime(today.year - 18, today.month, today.day);
    DateTime initial = DateTime(today.year - 25, today.month, today.day);
    if (initial.isBefore(minDate)) initial = minDate;
    if (initial.isAfter(maxDate)) initial = maxDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: minDate,
      lastDate: maxDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFA63228),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      int age = today.year - picked.year;
      if (today.month < picked.month || (today.month == picked.month && today.day < picked.day)) {
        age--;
      }

      setState(() {
        _bdayController.text = "${picked.month}/${picked.day}/${picked.year}";
        _ageController.text = "$age";
      });
    }
  }

  // DIALOG PARA SA ADMIN APPROVAL
  void _showApprovalPendingDialog() {
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
            const Icon(Icons.hourglass_empty, color: Color(0xFFE8C547), size: 48),
            const SizedBox(height: 16),
            Text(
              'Registration Submitted',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              'Your phone number has been verified. Your account registration is sent to the Admin for approval before you can log in.',
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
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: Text('Understood', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOtpVerificationDialog() async {
    for (var c in _otpControllers) {
      c.clear();
    }

    final phone = '+63${_phoneController.text.trim()}';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sending OTP via Semaphore SMS to $phone...', style: GoogleFonts.inter(fontSize: 12)),
        duration: const Duration(seconds: 2),
      ),
    );

    final result = await SemaphoreService.sendOtp(phone);
    final String activeOtp = result['otp'] ?? '123456';
    final bool isSimulated = result['isSimulated'] ?? true;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFA63228).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_read_outlined, color: Color(0xFFA63228), size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                'Semaphore OTP Verification',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit verification code sent to $phone',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12.5, color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSimulated ? Colors.amber.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isSimulated ? Colors.amber.shade300 : Colors.green.shade300),
                ),
                child: Text(
                  isSimulated
                      ? 'Demo OTP Code: $activeOtp (or 123456)'
                      : 'SMS Sent via Semaphore Gateway ✓',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isSimulated ? Colors.amber.shade900 : Colors.green.shade800,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 38,
                    height: 46,
                    child: TextFormField(
                      controller: _otpControllers[index],
                      focusNode: _otpFocusNodes[index],
                      autofocus: index == 0,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFA63228), width: 2),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          _otpFocusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _otpFocusNodes[index - 1].requestFocus();
                        }
                      },
                    ),
                  );
                }),
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
                  onPressed: () {
                    String enteredOtp = _otpControllers.map((c) => c.text).join();
                    bool isValid = SemaphoreService.verifyOtp(phone, enteredOtp) || enteredOtp == activeOtp;

                    if (isValid) {
                      setState(() {
                        _isPhoneVerified = true;
                      });
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Phone number verified successfully! ✓', style: GoogleFonts.inter(fontSize: 13)),
                          backgroundColor: Colors.green.shade700,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Invalid OTP code. Please enter the correct code.', style: GoogleFonts.inter(fontSize: 12)),
                          backgroundColor: const Color(0xFFA63228),
                        ),
                      );
                    }
                  },
                  child: Text('Verify OTP', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  final res = await SemaphoreService.sendOtp(phone);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('OTP code resent to $phone', style: GoogleFonts.inter(fontSize: 12)),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Text(
                  'Resend OTP Code via Semaphore',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isPhoneVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please verify your phone number with OTP first.', style: GoogleFonts.inter(fontSize: 13)),
          backgroundColor: const Color(0xFFA63228),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _showOtpVerificationDialog();
      return;
    }

    if (!_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please agree to the terms and conditions to proceed.',
            style: GoogleFonts.inter(fontSize: 13),
          ),
          backgroundColor: const Color(0xFFA63228),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Convert birthday from mm/dd/yyyy to yyyy-mm-dd
      final bdayParts = _bdayController.text.split('/');
      final birthday = bdayParts.length == 3 
          ? '${bdayParts[2]}-${bdayParts[0].padLeft(2, '0')}-${bdayParts[1].padLeft(2, '0')}'
          : null;

      await ApiService.register({
        'firstName': _firstNameController.text.trim(),
        'middleName': _middleNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'birthday': birthday,
        'age': int.tryParse(_ageController.text) ?? 0,
        'phone': _phoneController.text.trim().startsWith('+63')
            ? _phoneController.text.trim()
            : '+63${_phoneController.text.trim()}',
        'address': _addressController.text.trim(),
        'role': 'Worker',
        'position': 'Worker',
        'password': _passwordController.text,
      });

      if (mounted) {
        _showApprovalPendingDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildDropdown({
    required String hintText,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 16),
        style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
        isExpanded: true,
        hint: Text(hintText, style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13), overflow: TextOverflow.ellipsis),
        decoration: InputDecoration(
          isDense: true,
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 18),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          errorStyle: GoogleFonts.inter(fontSize: 10, height: 1),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFA63228), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
        items: items.map((String val) {
          return DropdownMenuItem<String>(
            value: val,
            child: Text(val, style: GoogleFonts.inter(fontSize: 14)),
          );
        }).toList(),
        onChanged: onChanged,
        validator: validator ?? ((val) => val == null || val.isEmpty ? 'Required' : null),
      ),
    );
  }

  Widget _buildTextField({
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    bool isNumber = false,
    bool? obscureText,
    VoidCallback? onToggleVisibility,
    TextEditingController? controller,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    double textFontSize = 14,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? prefixText,
    Widget? suffixWidget,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        obscureText: obscureText ?? false,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        validator: validator,
        style: GoogleFonts.inter(fontSize: textFontSize, color: Colors.black87),
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13),
          prefixText: prefixText,
          prefixStyle: GoogleFonts.inter(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: textFontSize),
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 18),
          suffixIconConstraints: (isPassword || suffixWidget != null) ? const BoxConstraints(minWidth: 36, minHeight: 36) : null,
          suffixIcon: isPassword
              ? IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              obscureText! ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.grey.shade500,
              size: 18,
            ),
            onPressed: onToggleVisibility,
          )
              : suffixWidget,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          errorStyle: GoogleFonts.inter(fontSize: 10, height: 1),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFA63228), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Image.asset(
                          'assets/logo.png',
                          height: screenHeight < 700 ? 36 : 48,
                        ),
                      ),
                      SizedBox(height: screenHeight < 700 ? 12 : 20),

                      Text(
                        'Account Registration',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Please fill out the information below.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: screenHeight < 700 ? 12 : 16),

                      // FIRST NAME
                      _buildTextField(
                        hintText: 'First Name',
                        icon: Icons.person_outline,
                        controller: _firstNameController,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(50),
                          CapitalizeWordsInputFormatter(),
                        ],
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) return 'Required';
                          if (RegExp(r'[^a-zA-Z\s]').hasMatch(value!)) return 'Letters only';
                          final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
                          for (final word in words) {
                            if (word.length < 2) return 'Each word must be at least 2 letters';
                            if (word.length > 30) return 'Each word maximum 30 letters';
                          }
                          return null;
                        },
                      ),

                      // MIDDLE NAME
                      _buildTextField(
                        hintText: 'Middle Name (Optional)',
                        icon: Icons.person_outline,
                        controller: _middleNameController,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(50),
                          CapitalizeWordsInputFormatter(),
                        ],
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            final trimmed = value.trim();
                            if (RegExp(r'[^a-zA-Z\s]').hasMatch(value)) return 'Letters only';
                            final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
                            for (final word in words) {
                              if (word.length < 2) return 'Each word must be at least 2 letters';
                              if (word.length > 30) return 'Each word maximum 30 letters';
                            }
                          }
                          return null;
                        },
                      ),

                      // LAST NAME
                      _buildTextField(
                        hintText: 'Last Name',
                        icon: Icons.person_outline,
                        controller: _lastNameController,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(50),
                          CapitalizeWordsInputFormatter(),
                        ],
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) return 'Required';
                          if (RegExp(r'[^a-zA-Z\s]').hasMatch(value!)) return 'Letters only';
                          final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
                          for (final word in words) {
                            if (word.length < 2) return 'Each word must be at least 2 letters';
                            if (word.length > 30) return 'Each word maximum 30 letters';
                          }
                          return null;
                        },
                      ),


                      // BIRTHDAY & AGE
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildTextField(
                              hintText: 'B-Day',
                              icon: Icons.calendar_today_outlined,
                              controller: _bdayController,
                              readOnly: true,
                              onTap: () => _selectDate(context),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Required';
                                int? currentAge = int.tryParse(_ageController.text);
                                if (currentAge != null && (currentAge < 18 || currentAge > 59)) {
                                  return 'Must be 18 to 59 years old';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: _buildTextField(
                              hintText: 'Age',
                              icon: Icons.cake_outlined,
                              controller: _ageController,
                              readOnly: true,
                            ),
                          ),
                        ],
                      ),

                      // PHONE NUMBER WITH OTP VERIFICATION
                      _buildTextField(
                        controller: _phoneController,
                        hintText: '9XXXXXXXXX',
                        icon: Icons.phone_outlined,
                        isNumber: true,
                        readOnly: _isPhoneVerified,
                        prefixText: '+63 ',
                        inputFormatters: [
                          PhilippinePhoneFormatter(),
                        ],
                        suffixWidget: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: _isPhoneVerified
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.green, size: 18),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Verified',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                )
                              : TextButton(
                                  onPressed: () {
                                    if (_phoneController.text.trim().length < 10) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Please enter a valid 10-digit phone number first', style: GoogleFonts.inter(fontSize: 12)),
                                          backgroundColor: const Color(0xFFA63228),
                                        ),
                                      );
                                      return;
                                    }
                                    _showOtpVerificationDialog();
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Send OTP',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFA63228),
                                    ),
                                  ),
                                ),
                        ),
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) return 'Required';
                          if (trimmed.length < 10) return 'Must be 10 digits (e.g. 9XXXXXXXXX)';
                          if (!trimmed.startsWith('9')) return 'Must start with 9';
                          if (!_isPhoneVerified) return 'OTP verification required';
                          return null;
                        },
                      ),

                      // ADDRESS PICKER
                      _buildTextField(
                        hintText: 'Select Address (Region, Prov, City, Brgy)',
                        icon: Icons.map_outlined,
                        controller: _addressController,
                        readOnly: true,
                        onTap: _showAddressPicker,
                        textFontSize: 11.5,
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),

                      // USERNAME
                      _buildTextField(
                        hintText: 'Username',
                        icon: Icons.alternate_email_outlined,
                        controller: _usernameController,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(20),
                          FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9]')),
                        ],
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) return 'Required';
                          if (trimmed.length < 8) return 'Must be 8 to 20 characters';
                          if (!RegExp(r'^[a-z0-9]+$').hasMatch(trimmed)) {
                            return 'Small letters and numbers only';
                          }
                          return null;
                        },
                      ),

                      // PASSWORD
                      _buildTextField(
                        hintText: 'Password',
                        icon: Icons.lock_outline,
                        isPassword: true,
                        obscureText: _obscurePassword,
                        controller: _passwordController,
                        inputFormatters: [LengthLimitingTextInputFormatter(20)],
                        onToggleVisibility: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (value.length < 8 || value.length > 20) return 'Must be 8 to 20 characters';
                          if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Needs capital letter (A-Z)';
                          if (!RegExp(r'[a-z]').hasMatch(value)) return 'Needs small letter (a-z)';
                          if (!RegExp(r'[0-9]').hasMatch(value)) return 'Needs number (0-9)';
                          return null;
                        },
                      ),

                      // CONFIRM PASSWORD
                      _buildTextField(
                        hintText: 'Confirm Password',
                        icon: Icons.lock_outline,
                        isPassword: true,
                        obscureText: _obscureConfirmPassword,
                        inputFormatters: [LengthLimitingTextInputFormatter(20)],
                        onToggleVisibility: () {
                          setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (value != _passwordController.text) return 'Passwords do not match';
                          return null;
                        },
                      ),

                      const Expanded(child: SizedBox(height: 12)),

                      // TERMS AND CONDITIONS CHECKBOX
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Transform.scale(
                            scale: 0.7,
                            child: Checkbox(
                              value: _agreeTerms,
                              activeColor: const Color(0xFFA63228),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              onChanged: (value) {
                                setState(() {
                                  _agreeTerms = value ?? false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _agreeTerms = !_agreeTerms;
                                });
                              },
                              child: Text.rich(
                                TextSpan(
                                  text: 'I agree to the ',
                                  style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600),
                                  children: [
                                    WidgetSpan(
                                      child: GestureDetector(
                                        onTap: _showTermsDialog,
                                        child: Text(
                                          'terms and conditions',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: Colors.black87,
                                            fontWeight: FontWeight.bold,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: screenHeight * 0.016),

                      // SUBMIT BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitRegistration,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA63228),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : Text(
                                  'Submit Request',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // LOGIN LINK
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already have an account? ",
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Text(
                              'Log in here',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFA63228),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CapitalizeWordsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final words = newValue.text.split(' ');
    final capitalizedWords = words.map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');

    return newValue.copyWith(
      text: capitalizedWords,
      selection: newValue.selection,
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