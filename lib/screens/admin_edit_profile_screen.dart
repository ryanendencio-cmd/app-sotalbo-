import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/admin_service.dart';
import '../services/api_service.dart';
import '../services/psgc_service.dart';
import '../services/semaphore_service.dart';
import '../widgets/admin_mobile_chrome.dart';

class AdminEditProfileScreen extends StatefulWidget {
  final int adminId;
  final String initialFirstName;
  final String initialMiddleName;
  final String initialLastName;
  final String initialUsername;
  final String initialBirthday;
  final String initialAge;
  final String initialEmail;
  final String initialPhone;
  final String initialAddress;
  final String initialDepartment;
  final String initialSite;
  final String initialTerminalId;
  final String status;
  final bool pushNotificationsEnabled;

  const AdminEditProfileScreen({
    super.key,
    required this.adminId,
    required this.initialFirstName,
    required this.initialMiddleName,
    required this.initialLastName,
    required this.initialUsername,
    required this.initialBirthday,
    required this.initialAge,
    required this.initialEmail,
    required this.initialPhone,
    required this.initialAddress,
    required this.initialDepartment,
    required this.initialSite,
    required this.initialTerminalId,
    required this.status,
    required this.pushNotificationsEnabled,
  });

  @override
  State<AdminEditProfileScreen> createState() => _AdminEditProfileScreenState();
}

class _AdminEditProfileScreenState extends State<AdminEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isPhoneVerified = false;
  String _originalPhone = '';

  late final TextEditingController _firstNameController;
  late final TextEditingController _middleNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _birthdayController;
  late final TextEditingController _ageController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _departmentController;
  late final TextEditingController _siteController;
  late final TextEditingController _terminalController;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.initialFirstName);
    _middleNameController = TextEditingController(
      text: widget.initialMiddleName,
    );
    _lastNameController = TextEditingController(text: widget.initialLastName);
    _usernameController = TextEditingController(text: widget.initialUsername);
    _birthdayController = TextEditingController(
      text: _formatBirthdayDisplay(widget.initialBirthday),
    );
    _ageController = TextEditingController(text: widget.initialAge);
    _emailController = TextEditingController(text: widget.initialEmail);
    _originalPhone = widget.initialPhone;
    _phoneController = TextEditingController(
      text: _normalizePhoneForField(_originalPhone),
    );
    _isPhoneVerified = _phoneController.text.length == 10;
    _addressController = TextEditingController(text: widget.initialAddress);
    _departmentController = TextEditingController(
      text: widget.initialDepartment,
    );
    _siteController = TextEditingController(text: widget.initialSite);
    _terminalController = TextEditingController(text: widget.initialTerminalId);

    final age = _calculateAgeFromBirthday(widget.initialBirthday);
    if (age != null) _ageController.text = age.toString();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _birthdayController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _departmentController.dispose();
    _siteController.dispose();
    _terminalController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  String _normalizePhoneForField(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('63')) {
      final nationalNumber = digits.substring(2);
      return nationalNumber.startsWith('0')
          ? nationalNumber.substring(1)
          : nationalNumber;
    }
    if (digits.startsWith('0')) return digits.substring(1);
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  String _normalizePhoneForStorage(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+63$digits';
    if (digits.length == 12 && digits.startsWith('63')) return '+$digits';
    if (digits.length > 10) return '+63${digits.substring(digits.length - 10)}';
    return digits.isEmpty ? '' : '+63$digits';
  }

  bool get _phoneChanged =>
      _normalizePhoneForStorage(_phoneController.text) !=
      _normalizePhoneForStorage(_originalPhone);

  String _formatBirthdayDisplay(String value) {
    if (value.trim().isEmpty) return '';
    final clean = value.contains('T') ? value.split('T').first : value;
    final parts = clean.split('-');
    if (parts.length == 3 && parts[0].length == 4) {
      return '${parts[1].padLeft(2, '0')}/${parts[2].padLeft(2, '0')}/${parts[0]}';
    }
    final slashParts = clean.split('/');
    if (slashParts.length == 3) {
      return '${slashParts[0].padLeft(2, '0')}/${slashParts[1].padLeft(2, '0')}/${slashParts[2]}';
    }
    return clean;
  }

  String _formatBirthdayForApi(String value) {
    final parts = value.trim().split('/');
    if (parts.length != 3) return value.trim();
    return '${parts[2]}-${parts[0].padLeft(2, '0')}-${parts[1].padLeft(2, '0')}';
  }

  int? _calculateAgeFromBirthday(String birthday) {
    if (birthday.trim().isEmpty) return null;
    final clean = birthday.contains('T') ? birthday.split('T').first : birthday;
    final parts = clean.contains('/') ? clean.split('/') : clean.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[clean.contains('/') ? 2 : 0]);
    final month = int.tryParse(parts[clean.contains('/') ? 0 : 1]);
    final day = int.tryParse(parts[clean.contains('/') ? 1 : 2]);
    if (year == null || month == null || day == null) return null;
    final today = DateTime.now();
    var age = today.year - year;
    if (today.month < month || (today.month == month && today.day < day)) age--;
    return age;
  }

  String _getInitials() {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    if (first.isNotEmpty) {
      return first[0].toUpperCase();
    }
    return 'A';
  }

  Future<void> _selectBirthday() async {
    final today = DateTime.now();
    final firstDate = DateTime(today.year - 60, today.month, today.day + 1);
    final lastDate = DateTime(today.year - 18, today.month, today.day);
    var initialDate = DateTime(today.year - 30, today.month, today.day);
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;
    final currentParts = _birthdayController.text.split('/');
    if (currentParts.length == 3) {
      final month = int.tryParse(currentParts[0]);
      final day = int.tryParse(currentParts[1]);
      final year = int.tryParse(currentParts[2]);
      if (month != null && day != null && year != null) {
        final savedDate = DateTime(year, month, day);
        if (!savedDate.isBefore(firstDate) && !savedDate.isAfter(lastDate)) {
          initialDate = savedDate;
        }
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFA63228),
            onPrimary: Colors.white,
            onSurface: Colors.black87,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _birthdayController.text =
          '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
      _ageController.text =
          (_calculateAgeFromBirthday(
                    _formatBirthdayForApi(_birthdayController.text),
                  ) ??
                  '')
              .toString();
    });
  }

  void _showAddressPicker() {
    var step = 0;
    var regionCode = '';
    var regionName = '';
    var provinceCode = '';
    var provinceName = '';
    var cityCode = '';
    var cityName = '';
    var query = '';
    var loading = true;
    var items = <Map<String, dynamic>>[];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> loadItems() async {
            setModalState(() {
              loading = true;
              items = [];
            });
            final loaded = switch (step) {
              0 => await PsgcService.getRegions(),
              1 => await PsgcService.getProvinces(regionCode),
              2 => await PsgcService.getCitiesMunicipalities(
                regionCode,
                provinceCode,
              ),
              _ => await PsgcService.getBarangays(cityCode),
            };
            if (sheetContext.mounted) {
              setModalState(() {
                items = loaded;
                loading = false;
              });
            }
          }

          if (loading && items.isEmpty) unawaited(loadItems());
          final title = [
            'Select Region',
            'Select Province',
            'Select City/Municipality',
            'Select Barangay',
          ][step];
          final filtered = items.where((item) {
            final name = step == 0
                ? PsgcService.formatRegionLabel(item)
                : (item['name'] ?? '').toString();
            return name.toLowerCase().contains(query.toLowerCase());
          }).toList();

          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              children: [
                ListTile(
                  leading: step > 0
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () {
                            setModalState(() {
                              step--;
                              query = '';
                              if (step < 3) cityCode = '';
                              if (step < 2) provinceCode = '';
                            });
                            unawaited(loadItems());
                          },
                        )
                      : const SizedBox(width: 48),
                  title: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    onChanged: (value) => setModalState(() => query = value),
                    decoration: InputDecoration(
                      hintText: 'Search $title...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFA63228),
                          ),
                        )
                      : filtered.isEmpty
                      ? const Center(child: Text('No results found'))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final name = step == 0
                                ? PsgcService.formatRegionLabel(item)
                                : (item['name'] ?? '').toString();
                            return ListTile(
                              title: Text(name),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                if (step == 0) {
                                  regionCode = (item['code'] ?? '').toString();
                                  regionName = name;
                                } else if (step == 1) {
                                  provinceCode = (item['code'] ?? '')
                                      .toString();
                                  provinceName = name;
                                } else if (step == 2) {
                                  cityCode = (item['code'] ?? '').toString();
                                  cityName = name;
                                } else {
                                  _addressController.text =
                                      '$regionName, $provinceName, $cityName, $name';
                                  Navigator.pop(sheetContext);
                                  return;
                                }
                                setModalState(() {
                                  step++;
                                  query = '';
                                });
                                unawaited(loadItems());
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showOtpVerificationDialog() {
    final phone = _normalizePhoneForStorage(_phoneController.text);
    if (phone.length < 12) {
      _showMessage('Please enter a valid 10-digit phone number.');
      return;
    }
    for (final controller in _otpControllers) {
      controller.clear();
    }
    unawaited(_sendOtpAndShowDialog(phone));
  }

  Future<void> _sendOtpAndShowDialog(String phone) async {
    try {
      final result = await SemaphoreService.sendOtp(phone);
      final activeOtp = (result['otp'] ?? '').toString();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            'Verify Phone Number',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter the 6-digit code sent to $phone',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  6,
                  (index) => SizedBox(
                    width: 38,
                    child: TextField(
                      controller: _otpControllers[index],
                      focusNode: _otpFocusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(counterText: ''),
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          _otpFocusNodes[index + 1].requestFocus();
                        }
                      },
                    ),
                  ),
                ),
              ),
              if (result['isSimulated'] == true && activeOtp.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Demo OTP: $activeOtp',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final entered = _otpControllers
                    .map((controller) => controller.text)
                    .join();
                final valid =
                    await SemaphoreService.verifyOtp(phone, entered) ||
                    (activeOtp.isNotEmpty && entered == activeOtp);
                if (!mounted) return;
                if (valid) {
                  setState(() => _isPhoneVerified = true);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _showMessage('Phone number verified successfully.');
                } else {
                  _showMessage('Invalid OTP code. Please try again.');
                }
              },
              child: const Text(
                'Verify OTP',
                style: TextStyle(color: Color(0xFFA63228)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) _showMessage('Unable to send OTP: $error', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color(0xFFA63228)
            : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_phoneChanged && !_isPhoneVerified) {
      _showOtpVerificationDialog();
      return;
    }

    setState(() => _isSaving = true);
    try {
      final firstName = _firstNameController.text.trim();
      final middleName = _middleNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final username = _usernameController.text.trim();
      final birthday = _formatBirthdayForApi(_birthdayController.text);
      final result = await AdminService.saveAdminProfile(
        adminId: widget.adminId,
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        username: username,
        birthday: birthday,
        age: int.tryParse(_ageController.text) ?? 0,
        password: _passwordController.text.trim().isEmpty
            ? null
            : _passwordController.text,
        email: _emailController.text.trim(),
        phone: _normalizePhoneForStorage(_phoneController.text),
        homeAddress: _addressController.text.trim(),
        address: _addressController.text.trim(),
        department: _departmentController.text.trim(),
        assignedProjectSite: _siteController.text.trim(),
        terminalId: _terminalController.text.trim(),
        pushNotificationsEnabled: widget.pushNotificationsEnabled,
        biometricLoginEnabled: false,
        status: widget.status,
      );
      if (!mounted) return;
      if (result['success'] == false) {
        _showMessage(
          result['error'] ?? 'Failed to update profile.',
          isError: true,
        );
        return;
      }

      ApiService.currentUser = {
        ...?ApiService.currentUser,
        'id': result['data']?['id'] ?? widget.adminId,
        'firstName': firstName,
        'middleName': middleName,
        'lastName': lastName,
        'fullName':
            '$firstName ${middleName.isNotEmpty ? '$middleName ' : ''}$lastName'
                .trim(),
        'username': username,
        'birthday': birthday,
        'age': int.tryParse(_ageController.text) ?? 0,
        'email': _emailController.text.trim(),
        'phone': _normalizePhoneForStorage(_phoneController.text),
        'homeAddress': _addressController.text.trim(),
        'department': _departmentController.text.trim(),
        'assignedProjectSite': _siteController.text.trim(),
        'terminalId': _terminalController.text.trim(),
      };
      _showMessage('Profile updated successfully.');
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        _showMessage('Unable to update profile: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _validateName(String? value, {bool optional = false}) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return optional ? null : 'Required';
    if (RegExp(r'[^a-zA-Z\s]').hasMatch(name)) return 'Letters only';
    for (final word
        in name.split(RegExp(r'\s+')).where((word) => word.isNotEmpty)) {
      if (word.length < 2) return 'Each word must be at least 2 letters';
      if (word.length > 30) return 'Each word maximum 30 letters';
    }
    return null;
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade800,
      ),
    ),
  );

  Widget _input({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? Function(String?)? validator,
    List<TextInputFormatter>? formatters,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    bool password = false,
    bool obscure = false,
    VoidCallback? onTap,
    VoidCallback? onTogglePassword,
    ValueChanged<String>? onChanged,
    String? prefixText,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      obscureText: password && obscure,
      style: GoogleFonts.inter(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          color: Colors.grey.shade600,
          fontSize: 13,
        ),
        prefixText: prefixText,
        prefixIcon: Icon(icon, color: const Color(0xFFA63228), size: 20),
        suffixIcon: password
            ? IconButton(
                onPressed: onTogglePassword,
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                ),
              )
            : suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: const Color(0xFFA63228).withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFA63228), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      validator:
          validator ??
          (value) => value == null || value.trim().isEmpty
              ? 'This field is required'
              : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      appBar: AdminMobileAppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: const Color(
                  0xFFA63228,
                ).withValues(alpha: 0.12),
                child: Text(
                  _getInitials(),
                  style: GoogleFonts.inter(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFA63228),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Personal Information'),
            _input(
              label: 'First Name',
              controller: _firstNameController,
              icon: Icons.person_outline,
              formatters: [
                LengthLimitingTextInputFormatter(50),
                _CapitalizeWordsFormatter(),
              ],
              validator: _validateName,
            ),
            const SizedBox(height: 12),
            _input(
              label: 'Middle Name (Optional)',
              controller: _middleNameController,
              icon: Icons.person_outline,
              formatters: [
                LengthLimitingTextInputFormatter(50),
                _CapitalizeWordsFormatter(),
              ],
              validator: (value) => _validateName(value, optional: true),
            ),
            const SizedBox(height: 12),
            _input(
              label: 'Last Name',
              controller: _lastNameController,
              icon: Icons.person_outline,
              formatters: [
                LengthLimitingTextInputFormatter(50),
                _CapitalizeWordsFormatter(),
              ],
              validator: _validateName,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _input(
                    label: 'B-Day',
                    controller: _birthdayController,
                    icon: Icons.calendar_today_outlined,
                    readOnly: true,
                    onTap: _selectBirthday,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      final age = int.tryParse(_ageController.text);
                      if (age == null || age < 18 || age > 59) {
                        return 'Must be 18 to 59 years old';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _input(
                    label: 'Age',
                    controller: _ageController,
                    icon: Icons.cake_outlined,
                    readOnly: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _input(
              label: 'Phone Number',
              controller: _phoneController,
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              prefixText: '+63 ',
              formatters: [_PhilippinePhoneFormatter()],
              onChanged: (_) =>
                  setState(() => _isPhoneVerified = !_phoneChanged),
              suffix: _isPhoneVerified
                  ? const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    )
                  : TextButton(
                      onPressed: _showOtpVerificationDialog,
                      child: const Text(
                        'Send OTP',
                        style: TextStyle(color: Color(0xFFA63228)),
                      ),
                    ),
              validator: (value) {
                final phone = value?.trim() ?? '';
                if (phone.isEmpty) return 'Required';
                if (phone.length != 10) {
                  return 'Must be 10 digits (e.g. 9XXXXXXXXX)';
                }
                if (!phone.startsWith('9')) {
                  return 'Must start with 9';
                }
                if (_phoneChanged && !_isPhoneVerified) {
                  return 'OTP verification required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _input(
              label: 'Email Address',
              controller: _emailController,
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return 'Required';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _input(
              label: 'Select Address (Region, Province, City, Brgy)',
              controller: _addressController,
              icon: Icons.map_outlined,
              readOnly: true,
              onTap: _showAddressPicker,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _input(
              label: 'Username',
              controller: _usernameController,
              icon: Icons.alternate_email_outlined,
              formatters: [
                LengthLimitingTextInputFormatter(20),
                FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9]')),
              ],
              validator: (value) {
                final username = value?.trim() ?? '';
                if (username.isEmpty) return 'Required';
                if (!RegExp(r'^[a-z0-9]{8,20}$').hasMatch(username)) {
                  return 'Use 8 to 20 lowercase letters or numbers';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _input(
              label: 'Password (leave blank to keep current)',
              controller: _passwordController,
              icon: Icons.lock_outline,
              password: true,
              obscure: _obscurePassword,
              onTogglePassword: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              formatters: [LengthLimitingTextInputFormatter(20)],
              validator: (value) {
                final password = value ?? '';
                if (password.isEmpty) return null;
                if (password.length < 8 || password.length > 20) {
                  return 'Must be 8 to 20 characters';
                }
                if (!RegExp(r'[A-Z]').hasMatch(password)) {
                  return 'Needs capital letter (A-Z)';
                }
                if (!RegExp(r'[a-z]').hasMatch(password)) {
                  return 'Needs small letter (a-z)';
                }
                if (!RegExp(r'[0-9]').hasMatch(password)) {
                  return 'Needs number (0-9)';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _input(
              label: 'Confirm Password',
              controller: _confirmPasswordController,
              icon: Icons.lock_outline,
              password: true,
              obscure: _obscureConfirmPassword,
              onTogglePassword: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
              formatters: [LengthLimitingTextInputFormatter(20)],
              validator: (value) {
                if (_passwordController.text.isEmpty && (value ?? '').isEmpty) {
                  return null;
                }
                if ((value ?? '').isEmpty) {
                  return 'Required';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            _sectionTitle('Work Information'),
            _input(
              label: 'Department',
              controller: _departmentController,
              icon: Icons.business_outlined,
            ),
            const SizedBox(height: 12),
            _input(
              label: 'Assigned Project Site',
              controller: _siteController,
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 12),
            _input(
              label: 'Employee / Terminal ID',
              controller: _terminalController,
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA63228),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: _isSaving ? null : _handleSave,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                        size: 18,
                      ),
                label: Text(
                  'Save Changes',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade400),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSaving
                    ? null
                    : () => Navigator.pop(context, false),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.grey,
                  size: 18,
                ),
                label: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: AdminMobileBottomNavigationBar(
        currentIndex: 0,
        onTap: (index) => navigateAdminMobileSection(context, index),
      ),
    );
  }
}

class _CapitalizeWordsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final words = newValue.text.split(' ');
    final text = words
        .map(
          (word) => word.isEmpty
              ? ''
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
    return newValue.copyWith(text: text, selection: newValue.selection);
  }
}

class _PhilippinePhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('63')) digits = digits.substring(2);
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (digits.length > 10) digits = digits.substring(0, 10);
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}
