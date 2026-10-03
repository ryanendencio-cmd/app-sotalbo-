import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/admin_service.dart';


class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  
  final _formKey = GlobalKey<FormState>();
  
  // Profile Data
  int _adminId = 1;
  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _phone = '';
  String _assignedProjectSite = '';
  String _terminalId = '';
  String _status = 'Active Duty';
  
  // Settings
  bool _pushNotifications = true;
  bool _biometricLogin = false;

  // Controllers
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _siteCtrl;
  late TextEditingController _terminalCtrl;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController();
    _lastNameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _siteCtrl = TextEditingController();
    _terminalCtrl = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _siteCtrl.dispose();
    _terminalCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await AdminService.getAdminProfile(_adminId);
      if (profile['id'] != null) {
        setState(() {
          _firstName = profile['firstName'] ?? profile['fullName']?.split(' ').first ?? '';
          _lastName = profile['lastName'] ?? profile['fullName']?.split(' ').last ?? '';
          _email = profile['email'] ?? '';
          _phone = profile['phone'] ?? '';
          _assignedProjectSite = profile['assignedProjectSite'] ?? '';
          _terminalId = profile['terminalId'] ?? '';
          _status = profile['status'] ?? 'Active Duty';
          _pushNotifications = profile['pushNotificationsEnabled'] ?? true;
          _biometricLogin = profile['biometricLoginEnabled'] ?? false;

          _firstNameCtrl.text = _firstName;
          _lastNameCtrl.text = _lastName;
          _emailCtrl.text = _email;
          _phoneCtrl.text = _phone;
          _siteCtrl.text = _assignedProjectSite;
          _terminalCtrl.text = _terminalId;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    try {
      final result = await AdminService.saveAdminProfile(
        adminId: _adminId,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        assignedProjectSite: _siteCtrl.text.trim(),
        terminalId: _terminalCtrl.text.trim(),
        pushNotificationsEnabled: _pushNotifications,
        biometricLoginEnabled: _biometricLogin,
        status: _status,
      );

      if (mounted) {
        if (result['success'] != false) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Failed to update profile'),
              backgroundColor: const Color(0xFFA63228),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFA63228),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: Text(
          'Admin Profile',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFA63228)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: const Color(0xFFA63228).withValues(alpha: 0.1),
                            child: Text(
                              _firstName.isNotEmpty ? _firstName[0].toUpperCase() : 'A',
                              style: GoogleFonts.inter(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFA63228),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '$_firstName $_lastName',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _status,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Personal Information
                    Text(
                      'Personal Information',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField('First Name', _firstNameCtrl, Icons.person_outline),
                    const SizedBox(height: 12),
                    _buildTextField('Last Name', _lastNameCtrl, Icons.person_outline),
                    const SizedBox(height: 12),
                    _buildTextField('Email Address', _emailCtrl, Icons.email_outlined, isEmail: true),
                    const SizedBox(height: 12),
                    _buildTextField('Phone Number', _phoneCtrl, Icons.phone_outlined, isPhone: true),
                    
                    const SizedBox(height: 24),

                    // Work Information
                    Text(
                      'Work Information',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField('Assigned Project Site', _siteCtrl, Icons.location_on_outlined),
                    const SizedBox(height: 12),
                    _buildTextField('Terminal ID', _terminalCtrl, Icons.computer_outlined),

                    const SizedBox(height: 24),

                    // Settings
                    Text(
                      'App Settings',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: Text('Push Notifications', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: Text('Receive alerts for new expenses and requests', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
                            value: _pushNotifications,
                            activeColor: const Color(0xFFA63228),
                            onChanged: (val) => setState(() => _pushNotifications = val),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            title: Text('Biometric Login', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: Text('Use fingerprint or face ID to login', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
                            value: _biometricLogin,
                            activeColor: const Color(0xFFA63228),
                            onChanged: (val) => setState(() => _biometricLogin = val),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA63228),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isSaving ? null : _saveProfile,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                'Save Changes',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(
    String label, 
    TextEditingController controller, 
    IconData icon, 
    {bool isEmail = false, bool isPhone = false}
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: isEmail ? TextInputType.emailAddress : (isPhone ? TextInputType.phone : TextInputType.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFA63228)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'This field is required';
        }
        if (isEmail && !value.contains('@')) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }
}