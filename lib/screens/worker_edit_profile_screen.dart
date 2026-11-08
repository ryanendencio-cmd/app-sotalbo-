import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/worker_app_header.dart';
import '../services/api_service.dart';
import '../services/psgc_service.dart';
import '../services/semaphore_service.dart';

class WorkerEditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> workerData;

  const WorkerEditProfileScreen({super.key, required this.workerData});

  @override
  State<WorkerEditProfileScreen> createState() =>
      _WorkerEditProfileScreenState();
}

class _WorkerEditProfileScreenState extends State<WorkerEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _verifiedOtpPhone;
  String _originalPhone = '';

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bdayController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    final user = widget.workerData;
    final displayName =
        (user['name'] ?? user['full_name'] ?? user['fullName'] ?? '')
            .toString();
    final fullNameParts = displayName.isNotEmpty
        ? displayName.split(RegExp(r'\s+'))
        : <String>[];
    final firstName =
        _firstValue(user, ['firstName', 'first_name']) ??
        (fullNameParts.isNotEmpty ? fullNameParts.first : '');
    final lastName =
        _firstValue(user, ['lastName', 'last_name']) ??
        (fullNameParts.length > 1 ? fullNameParts.last : '');
    final middleName =
        _firstValue(user, ['middleName', 'middle_name']) ??
        (fullNameParts.length > 2
            ? fullNameParts.sublist(1, fullNameParts.length - 1).join(' ')
            : '');

    _firstNameController.text = firstName;
    _middleNameController.text = middleName;
    _lastNameController.text = lastName;
    _usernameController.text = (user['username'] ?? user['user_name'] ?? '')
        .toString();
    _addressController.text = (user['address'] ?? '').toString();
    _originalPhone = (user['phone'] ?? user['contact_number'] ?? '').toString();
    _phoneController.text = _normalizePhoneForField(_originalPhone);

    final birthday = _firstValue(user, ['birthday', 'date_of_birth']) ?? '';
    if (birthday.isNotEmpty) {
      _bdayController.text = _formatBirthdayDisplay(birthday);
      final parsedAge = _calculateAgeFromBirthday(birthday);
      if (parsedAge != null) {
        _ageController.text = parsedAge.toString();
      }
    } else {
      final age = (user['age'] ?? '').toString();
      if (age.isNotEmpty) {
        _ageController.text = age;
      }
    }
  }

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
    _confirmPasswordController.dispose();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  String? _firstValue(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  String _normalizePhoneForField(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('63')) {
      final withoutCountryCode = digits.substring(2);
      if (withoutCountryCode.startsWith('0')) {
        return withoutCountryCode.substring(1);
      }
      return withoutCountryCode;
    }
    if (digits.startsWith('0')) {
      return digits.substring(1);
    }
    if (digits.length >= 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  String _normalizePhoneForStorage(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits.length == 10) {
      return '+63$digits';
    }
    if (digits.length == 11 && digits.startsWith('63')) {
      return '+$digits';
    }
    if (digits.length > 10) {
      return '+63${digits.substring(digits.length - 10)}';
    }
    return '+63$digits';
  }

  String _formatBirthdayDisplay(String birthday) {
    if (birthday.trim().isEmpty) return '';
    final cleanValue = birthday.contains('T')
        ? birthday.split('T').first
        : birthday;
    final slashParts = cleanValue.split('/');
    if (slashParts.length == 3) {
      final month = int.tryParse(slashParts[0]);
      final day = int.tryParse(slashParts[1]);
      final year = int.tryParse(slashParts[2]);
      if (month != null && day != null && year != null) {
        return '${month.toString().padLeft(2, '0')}/${day.toString().padLeft(2, '0')}/$year';
      }
    }
    final hyphenParts = cleanValue.split('-');
    if (hyphenParts.length == 3) {
      final year = hyphenParts[0];
      final month = hyphenParts[1];
      final day = hyphenParts[2];
      if (year.isNotEmpty && month.isNotEmpty && day.isNotEmpty) {
        return '$month/$day/$year';
      }
    }
    return cleanValue;
  }

  String _formatBirthdayForApi(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split('/');
    if (parts.length == 3) {
      final month = parts[0].padLeft(2, '0');
      final day = parts[1].padLeft(2, '0');
      final year = parts[2];
      return '$year-$month-$day';
    }
    return trimmed;
  }

  int? _calculateAgeFromBirthday(String birthday) {
    final cleanValue = birthday.contains('T')
        ? birthday.split('T').first
        : birthday;
    final parts = cleanValue.split('-');
    if (parts.length != 3) {
      return null;
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return null;
    }

    final now = DateTime.now();
    var age = now.year - year;
    if (now.month < month || (now.month == month && now.day < day)) {
      age--;
    }
    return age;
  }

  bool get _phoneChanged =>
      _normalizePhoneForStorage(_phoneController.text) !=
      _normalizePhoneForStorage(_originalPhone);
  String get _otpTargetPhone => _normalizePhoneForStorage(
    _phoneChanged ? _phoneController.text : _originalPhone,
  );
  bool get _requiresOtp =>
      _phoneChanged || _passwordController.text.trim().isNotEmpty;
  bool get _isOtpVerifiedForCurrentChanges =>
      _otpTargetPhone.isNotEmpty && _verifiedOtpPhone == _otpTargetPhone;

  String _getInitials(String firstName, String middleName, String lastName) {
    final names = [
      firstName.trim(),
      middleName.trim(),
      lastName.trim(),
    ].where((value) => value.isNotEmpty).toList();
    if (names.isEmpty) return 'W';
    if (names.length == 1) {
      final value = names.first;
      return value.length >= 2
          ? value.substring(0, 2).toUpperCase()
          : value.toUpperCase();
    }
    return '${names[0][0]}${names[names.length - 1][0]}'.toUpperCase();
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
            Future<void> loadStepData() async {
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
                data = await PsgcService.getCitiesMunicipalities(
                  regionCode,
                  provinceCode,
                );
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

            final stepTitle = step == 0
                ? 'Select Region'
                : step == 1
                ? 'Select Province'
                : step == 2
                ? 'Select City/Municipality'
                : 'Select Barangay';

            final filteredItems = items.where((item) {
              if (searchQuery.isEmpty) return true;
              final String name = step == 0
                  ? PsgcService.formatRegionLabel(item)
                  : (item['name'] ?? '').toString();
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    child: Row(
                      children: [
                        if (step > 0)
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.black87,
                            ),
                            onPressed: () {
                              setModalState(() {
                                if (step == 1) {
                                  regionCode = '';
                                } else if (step == 2) {
                                  provinceCode = '';
                                  cityCode = '';
                                } else if (step == 3) {
                                  cityCode = '';
                                }
                                step -= 1;
                                searchQuery = '';
                              });
                              loadStepData();
                            },
                          ),
                        Expanded(
                          child: Text(
                            stepTitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black87),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: TextField(
                      onChanged: (value) =>
                          setModalState(() => searchQuery = value),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search $stepTitle...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFA63228),
                            ),
                          )
                        : filteredItems.isEmpty
                        ? Center(
                            child: Text(
                              'No results found',
                              style: GoogleFonts.inter(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredItems.length,
                            separatorBuilder: (_, __) =>
                                Divider(height: 1, color: Colors.grey.shade200),
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              final displayName = step == 0
                                  ? PsgcService.formatRegionLabel(item)
                                  : (item['name'] ?? '').toString();

                              return ListTile(
                                title: Text(
                                  displayName,
                                  style: GoogleFonts.inter(fontSize: 14),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                onTap: () {
                                  if (step == 0) {
                                    regionCode = (item['code'] ?? '')
                                        .toString();
                                    regionName = displayName;
                                    step = 1;
                                    searchQuery = '';
                                    loadStepData();
                                  } else if (step == 1) {
                                    provinceCode = (item['code'] ?? '')
                                        .toString();
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
                                    final fullAddress =
                                        '$regionName, $provinceName, $cityName, $displayName';
                                    _addressController.text = fullAddress;
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

    final picked = await showDatePicker(
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

    if (picked == null) return;

    final age = _calculateAgeFromBirthday(
      '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
    );

    setState(() {
      _bdayController.text =
          '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
      _ageController.text = age?.toString() ?? '';
    });
  }

  void _showOtpVerificationDialog() {
    final phone = _otpTargetPhone;
    if (phone.isEmpty || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a valid 10-digit phone number first.',
            style: GoogleFonts.inter(fontSize: 12),
          ),
          backgroundColor: const Color(0xFFA63228),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    unawaited(_sendOtpAndShowDialog(phone));
  }

  Future<void> _sendOtpAndShowDialog(String phone) async {
    try {
      final result = await SemaphoreService.sendOtp(phone);
      final activeOtp = result['otp'] ?? '123456';

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Verify Account',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter the 6-digit verification code sent to $phone',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 38,
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _otpFocusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(1),
                        ],
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFA63228),
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty && index < 5) {
                            FocusScope.of(
                              context,
                            ).requestFocus(_otpFocusNodes[index + 1]);
                          }
                          if (value.isEmpty && index > 0) {
                            FocusScope.of(
                              context,
                            ).requestFocus(_otpFocusNodes[index - 1]);
                          }
                        },
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                if (result['isSimulated'] == true && activeOtp.isNotEmpty)
                  Text(
                    'Demo OTP: $activeOtp',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final enteredOtp = _otpControllers
                      .map((controller) => controller.text)
                      .join();
                  final isValid = await SemaphoreService.verifyOtp(
                    phone,
                    enteredOtp,
                  );

                  if (!mounted) return;

                  if (isValid) {
                    setState(() => _verifiedOtpPhone = phone);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'OTP verified successfully! ✓',
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                        backgroundColor: Colors.green.shade700,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Invalid OTP code. Please enter the correct code.',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                        backgroundColor: const Color(0xFFA63228),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: Text(
                  'Verify OTP',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFA63228),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(color: Colors.grey.shade700),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to send OTP: $e',
              style: GoogleFonts.inter(fontSize: 12),
            ),
            backgroundColor: const Color(0xFFA63228),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final phoneValue = _phoneController.text.trim();
    final normalizedPhone = _normalizePhoneForStorage(phoneValue);
    if (_requiresOtp && !_isOtpVerifiedForCurrentChanges) {
      _showOtpVerificationDialog();
      return;
    }

    final id = widget.workerData['id'];
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Worker ID not found'),
          backgroundColor: Color(0xFFA63228),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final firstName = _firstNameController.text.trim();
    final middleName = _middleNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final address = _addressController.text.trim();
    final birthday = _formatBirthdayForApi(_bdayController.text);
    final age = int.tryParse(_ageController.text) ?? 0;
    final password = _passwordController.text.trim();
    final role =
        (widget.workerData['role'] ?? widget.workerData['position'] ?? 'Worker')
            .toString();
    final position = (widget.workerData['position'] ?? role).toString();

    setState(() => _isSaving = true);

    try {
      final payload = <String, dynamic>{
        'first_name': firstName,
        'middle_name': middleName,
        'last_name': lastName,
        'full_name':
            '$firstName ${middleName.isNotEmpty ? '$middleName ' : ''}$lastName'
                .trim(),
        'birthday': birthday,
        'age': age,
        'phone': normalizedPhone,
        'address': address,
        'role': role,
        'position': position,
        'approval_status': widget.workerData['approval_status'] ?? 'Approved',
        'status': widget.workerData['status'] ?? 'Active',
        if (widget.workerData['project_id'] != null)
          'project_id': widget.workerData['project_id'],
        if (password.isNotEmpty) 'password': password,
        'firstName': firstName,
        'middleName': middleName,
        'lastName': lastName,
        'fullName':
            '$firstName ${middleName.isNotEmpty ? '$middleName ' : ''}$lastName'
                .trim(),
      };

      await ApiService.updateWorker(id, payload);

      final updated = Map<String, dynamic>.from(widget.workerData);
      updated['first_name'] = firstName;
      updated['middle_name'] = middleName;
      updated['last_name'] = lastName;
      updated['firstName'] = firstName;
      updated['middleName'] = middleName;
      updated['lastName'] = lastName;
      updated['full_name'] = payload['full_name'];
      updated['fullName'] = payload['full_name'];
      updated['name'] = payload['full_name'];
      updated['birthday'] = birthday;
      updated['age'] = age;
      updated['phone'] = normalizedPhone;
      updated['contact_number'] = normalizedPhone;
      updated['address'] = address;
      updated['role'] = role;
      updated['position'] = position;

      ApiService.currentUser = {...ApiService.currentUser ?? {}, ...updated};

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile updated successfully',
              style: GoogleFonts.inter(fontSize: 12),
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to update profile: $e',
              style: GoogleFonts.inter(fontSize: 12),
            ),
            backgroundColor: const Color(0xFFA63228),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(
      _firstNameController.text,
      _middleNameController.text,
      _lastNameController.text,
    );
    final workerId =
        (widget.workerData['worker_code'] ?? widget.workerData['id'])
            ?.toString() ??
        '—';
    final position =
        widget.workerData['position'] ?? widget.workerData['role'] ?? 'Worker';

    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      appBar: WorkerAppHeader(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context, false),
          tooltip: 'Back',
        ),
        actions: const [SizedBox(width: 4)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: const Color(
                        0xFFA63228,
                      ).withValues(alpha: 0.12),
                      child: Text(
                        initials,
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFA63228),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA63228),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Personal Information',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              _buildInput(
                label: 'First Name',
                controller: _firstNameController,
                icon: Icons.person_outline,
                formatter: [
                  LengthLimitingTextInputFormatter(50),
                  CapitalizeWordsInputFormatter(),
                ],
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return 'Required';
                  if (RegExp(r'[^a-zA-Z\s]').hasMatch(value!)) {
                    return 'Letters only';
                  }
                  final words = trimmed
                      .split(RegExp(r'\s+'))
                      .where((w) => w.isNotEmpty)
                      .toList();
                  for (final word in words) {
                    if (word.length < 2) {
                      return 'Each word must be at least 2 letters';
                    }
                    if (word.length > 30) return 'Each word maximum 30 letters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildInput(
                label: 'Middle Name (Optional)',
                controller: _middleNameController,
                icon: Icons.person_outline,
                formatter: [
                  LengthLimitingTextInputFormatter(50),
                  CapitalizeWordsInputFormatter(),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final trimmed = value.trim();
                  if (RegExp(r'[^a-zA-Z\s]').hasMatch(value)) {
                    return 'Letters only';
                  }
                  final words = trimmed
                      .split(RegExp(r'\s+'))
                      .where((w) => w.isNotEmpty)
                      .toList();
                  for (final word in words) {
                    if (word.length < 2) {
                      return 'Each word must be at least 2 letters';
                    }
                    if (word.length > 30) return 'Each word maximum 30 letters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildInput(
                label: 'Last Name',
                controller: _lastNameController,
                icon: Icons.person_outline,
                formatter: [
                  LengthLimitingTextInputFormatter(50),
                  CapitalizeWordsInputFormatter(),
                ],
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return 'Required';
                  if (RegExp(r'[^a-zA-Z\s]').hasMatch(value!)) {
                    return 'Letters only';
                  }
                  final words = trimmed
                      .split(RegExp(r'\s+'))
                      .where((w) => w.isNotEmpty)
                      .toList();
                  for (final word in words) {
                    if (word.length < 2) {
                      return 'Each word must be at least 2 letters';
                    }
                    if (word.length > 30) return 'Each word maximum 30 letters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildInput(
                      label: 'B-Day',
                      controller: _bdayController,
                      icon: Icons.calendar_today_outlined,
                      readOnly: true,
                      onTap: () => _selectDate(context),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        final age = int.tryParse(_ageController.text);
                        if (age != null && (age < 18 || age > 59)) {
                          return 'Must be 18 to 59 years old';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: _buildInput(
                      label: 'Age',
                      controller: _ageController,
                      icon: Icons.cake_outlined,
                      readOnly: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInput(
                label: 'Phone Number',
                controller: _phoneController,
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                formatter: [PhilippinePhoneFormatter()],
                prefixText: '+63 ',
                onChanged: (_) {
                  if (_phoneChanged) _verifiedOtpPhone = null;
                  setState(() {});
                },
                suffix: !_requiresOtp || _isOtpVerifiedForCurrentChanges
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 18,
                          ),
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
                                content: Text(
                                  'Please enter a valid 10-digit phone number first',
                                  style: GoogleFonts.inter(fontSize: 12),
                                ),
                                backgroundColor: const Color(0xFFA63228),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          _showOtpVerificationDialog();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
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
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return 'Required';
                  if (trimmed.length < 10) {
                    return 'Must be 10 digits (e.g. 9XXXXXXXXX)';
                  }
                  if (!trimmed.startsWith('9')) return 'Must start with 9';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildInput(
                label: 'Select Address (Region, Province, City, Brgy)',
                controller: _addressController,
                icon: Icons.map_outlined,
                readOnly: true,
                onTap: _showAddressPicker,
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _buildInput(
                label: 'Username (cannot be changed)',
                controller: _usernameController,
                icon: Icons.alternate_email_outlined,
                readOnly: true,
                suffix: const Icon(
                  Icons.lock_outline,
                  color: Colors.grey,
                  size: 18,
                ),
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
              const SizedBox(height: 12),
              _buildInput(
                label: 'Password (leave blank to keep current)',
                controller: _passwordController,
                icon: Icons.lock_outline,
                isPassword: true,
                obscureText: _obscurePassword,
                onChanged: (_) {
                  _verifiedOtpPhone = null;
                  setState(() {});
                },
                onToggleVisibility: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                formatter: [LengthLimitingTextInputFormatter(20)],
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty && _passwordController.text.isEmpty) {
                    return null;
                  }
                  if (trimmed.isEmpty) return 'Required';
                  if (trimmed.length < 8 || trimmed.length > 20) {
                    return 'Must be 8 to 20 characters';
                  }
                  if (!RegExp(r'[A-Z]').hasMatch(trimmed)) {
                    return 'Needs capital letter (A-Z)';
                  }
                  if (!RegExp(r'[a-z]').hasMatch(trimmed)) {
                    return 'Needs small letter (a-z)';
                  }
                  if (!RegExp(r'[0-9]').hasMatch(trimmed)) {
                    return 'Needs number (0-9)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildInput(
                label: 'Confirm Password',
                controller: _confirmPasswordController,
                icon: Icons.lock_outline,
                isPassword: true,
                obscureText: _obscureConfirmPassword,
                formatter: [LengthLimitingTextInputFormatter(20)],
                onToggleVisibility: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty && _passwordController.text.isEmpty) {
                    return null;
                  }
                  if (trimmed.isEmpty) return 'Required';
                  if (trimmed != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              Text(
                'Work Information (Protected)',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Employee ID',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          workerId,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Role / Position',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          position,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA63228),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: _isSaving
                      ? const SizedBox.shrink()
                      : const Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                          size: 18,
                        ),
                  label: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Save Changes',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                  onPressed: _isSaving ? null : _handleSave,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.pop(context, false),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? prefixText,
    Widget? suffix,
    bool isPassword = false,
    bool readOnly = false,
    bool obscureText = false,
    VoidCallback? onTap,
    VoidCallback? onToggleVisibility,
    ValueChanged<String>? onChanged,
    List<TextInputFormatter>? formatter,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      keyboardType: keyboardType,
      obscureText: isPassword ? obscureText : false,
      inputFormatters: formatter,
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
        suffixIcon: isPassword
            ? IconButton(
                onPressed: onToggleVisibility,
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey.shade600,
                  size: 18,
                ),
              )
            : suffix != null
            ? Padding(padding: const EdgeInsets.only(right: 8.0), child: suffix)
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
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
          (value) => (value == null || value.trim().isEmpty)
              ? 'This field is required'
              : null,
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
    final capitalizedWords = words
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');

    return newValue.copyWith(
      text: capitalizedWords,
      selection: newValue.selection,
    );
  }
}

class PhilippinePhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;
    if (text.isEmpty) return newValue;

    text = text.replaceAll(RegExp(r'\D'), '');

    if (text.startsWith('63')) {
      text = text.substring(2);
    }
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
