import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/admin_service.dart';
import '../services/api_service.dart';
import '../widgets/admin_mobile_chrome.dart';
import 'admin_edit_profile_screen.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  bool _isLoading = true;

  // Profile Data
  final int _adminId = 1;
  String _firstName = 'Aldrich';
  String _middleName = '';
  String _lastName = 'Sotalbo';
  String _username = '';
  String _birthday = '';
  String _age = '';
  String _email = 'ajsotalbo@gmail.com';
  String _phone = '09068135609';
  String _homeAddress =
      '012 Camillo Lirio Street, Brgy. Poblacion II (Pob.), Nagcarlan, Laguna, Region IV-A - CALABARZON';
  String _employeeId = 'SCON-ADMIN-001';
  String _department = 'Management';
  String _role = 'Administrator';
  String _assignedProjectSite = 'RYAN';
  String _terminalId = '';
  String _status = 'Active Duty';

  // Settings
  bool _pushNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await AdminService.getAdminProfile(_adminId);
      if (profile['id'] != null ||
          profile['fullName'] != null ||
          profile['firstName'] != null) {
        setState(() {
          _firstName =
              profile['firstName'] ??
              profile['fullName']?.split(' ').first ??
              _firstName;
          _lastName =
              profile['lastName'] ??
              (profile['fullName'] != null && profile['fullName'].contains(' ')
                  ? profile['fullName'].split(' ').sublist(1).join(' ')
                  : _lastName);
          _middleName = profile['middleName'] ?? _middleName;
          _username = profile['username'] ?? _username;
          _birthday = profile['birthday']?.toString() ?? _birthday;
          _age = profile['age']?.toString() ?? _age;
          _email = profile['email'] ?? _email;
          _phone = profile['phone'] ?? _phone;
          _homeAddress =
              profile['homeAddress'] ?? profile['address'] ?? _homeAddress;
          _employeeId =
              profile['employeeId'] ??
              profile['employee_id'] ??
              (profile['terminalId'] != null &&
                      profile['terminalId'].toString().isNotEmpty
                  ? profile['terminalId']
                  : _employeeId);
          _department = profile['department'] ?? profile['dept'] ?? _department;
          _role = profile['role'] ?? 'Administrator';
          _assignedProjectSite =
              profile['assignedProjectSite'] ?? _assignedProjectSite;
          _terminalId = profile['terminalId'] ?? _terminalId;
          _status = profile['status'] ?? 'Active Duty';
          _pushNotifications =
              profile['pushNotificationsEnabled'] ?? _pushNotifications;
        });
      }
    } catch (e) {
      debugPrint('Failed to load admin profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getInitials(String first, String last) {
    if (first.length >= 2) {
      return first.substring(0, 2).toUpperCase();
    }
    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    if (first.isNotEmpty) return first[0].toUpperCase();
    return 'AL';
  }

  Future<void> _navigateToEditProfile() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AdminEditProfileScreen(
          adminId: _adminId,
          initialFirstName: _firstName,
          initialMiddleName: _middleName,
          initialLastName: _lastName,
          initialUsername: _username,
          initialBirthday: _birthday,
          initialAge: _age,
          initialEmail: _email,
          initialPhone: _phone,
          initialAddress: _homeAddress,
          initialDepartment: _department,
          initialSite: _assignedProjectSite,
          initialTerminalId: _terminalId.isNotEmpty ? _terminalId : _employeeId,
          status: _status,
          pushNotificationsEnabled: _pushNotifications,
        ),
      ),
    );

    if (updated == true) {
      _loadProfile();
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName =
        '$_firstName ${_middleName.isNotEmpty ? '$_middleName ' : ''}$_lastName'
            .trim();
    final initials = _getInitials(_firstName, _lastName);

    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      appBar: AdminMobileAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              color: Color(0xFFA63228),
              size: 20,
            ),
            tooltip: 'Edit Profile',
            onPressed: _navigateToEditProfile,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFA63228)),
            )
          : RefreshIndicator(
              color: const Color(0xFFA63228),
              onRefresh: _loadProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Information Card (Matching Web/Dashboard Card Design)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title & Status Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Profile Information',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.green.shade200,
                                  ),
                                ),
                                child: Text(
                                  _status,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Avatar + Info Details
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth > 400;

                              return isWide
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Avatar Circle
                                        _buildAvatarCircle(initials),
                                        const SizedBox(width: 20),
                                        // Tabular Info
                                        Expanded(
                                          child: _buildInfoTable(fullName),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        Center(
                                          child: _buildAvatarCircle(initials),
                                        ),
                                        const SizedBox(height: 18),
                                        _buildInfoTable(fullName),
                                      ],
                                    );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // App Settings Card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: SwitchListTile(
                        title: Text(
                          'Push Notifications',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          'Receive system alerts and activity updates',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        value: _pushNotifications,
                        activeThumbColor: const Color(0xFFA63228),
                        onChanged: (val) async {
                          setState(() => _pushNotifications = val);
                          try {
                            await AdminService.updateAdminSettings(
                              adminId: _adminId,
                              pushNotificationsEnabled: val,
                              biometricLoginEnabled: false,
                              assignedProjectSite: _assignedProjectSite,
                            );
                          } catch (_) {}
                        },
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Action Buttons
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
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: Text(
                          'Edit Profile',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        onPressed: _navigateToEditProfile,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFA63228)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: Color(0xFFA63228),
                          size: 18,
                        ),
                        label: Text(
                          'Log Out',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFA63228),
                          ),
                        ),
                        onPressed: _logout,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: AdminMobileBottomNavigationBar(
        currentIndex: 0,
        onTap: (index) => navigateAdminMobileSection(context, index),
      ),
    );
  }

  Widget _buildAvatarCircle(String initials) {
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        color: const Color(0xFFA63228).withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFA63228),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTable(String fullName) {
    return Column(
      children: [
        _buildInfoRow('FULL NAME', fullName),
        _buildDivider(),
        _buildInfoRow('EMAIL ADDRESS', _email),
        _buildDivider(),
        _buildInfoRow('ROLE', _role),
        _buildDivider(),
        _buildInfoRow('PHONE NUMBER', _phone),
        _buildDivider(),
        _buildInfoRow('HOME ADDRESS', _homeAddress),
        _buildDivider(),
        _buildInfoRow('EMPLOYEE ID', _employeeId),
        _buildDivider(),
        _buildInfoRow('DEPARTMENT', _department),
      ],
    );
  }

  Widget _buildDivider() {
    return Divider(height: 20, thickness: 0.7, color: Colors.grey.shade100);
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 115,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : '—',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
