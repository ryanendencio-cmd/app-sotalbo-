import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../widgets/worker_app_header.dart';
import 'worker_edit_profile_screen.dart';

class WorkerProfileScreen extends StatefulWidget {
  const WorkerProfileScreen({super.key});

  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _vales = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final currentId = ApiService.currentUser?['id']?.toString();
    if (currentId == null || currentId.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final freshData = await ApiService.getWorker(currentId);
      try {
        final valesData = await ApiService.getWorkerCashAdvances(currentId);
        if (mounted) {
          setState(() {
            _vales = List<Map<String, dynamic>>.from(
              valesData,
            ).where((v) => v['status'] == 'Approved').toList();
          });
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _userData = freshData;
          ApiService.currentUser = {
            ...ApiService.currentUser ?? {},
            ...freshData,
          };
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Future<void> _navigateToEditProfile() async {
    final user = _userData ?? ApiService.currentUser ?? {};
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => WorkerEditProfileScreen(workerData: user),
      ),
    );

    if (updated == true) {
      _fetchProfile();
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (name.length >= 2) {
      return name.substring(0, 2).toUpperCase();
    }
    if (name.isNotEmpty) return name[0].toUpperCase();
    return 'W';
  }

  String _formatRoles(Map<String, dynamic>? user) {
    final roles = <String>[];
    final seen = <String>{};

    void addRoles(dynamic value) {
      if (value is Iterable) {
        for (final item in value) {
          addRoles(item);
        }
        return;
      }
      if (value == null) return;

      for (final role in value.toString().split(RegExp(r'[,/|]'))) {
        final trimmed = role.trim();
        final key = trimmed.toLowerCase();
        if (trimmed.isNotEmpty && seen.add(key)) {
          roles.add(trimmed);
        }
      }
    }

    addRoles(user?['role']);
    addRoles(user?['roles']);
    addRoles(user?['position']);
    addRoles(user?['positions']);

    return roles.isEmpty ? 'Worker' : roles.join(' / ');
  }

  @override
  Widget build(BuildContext context) {
    final user = _userData ?? ApiService.currentUser;
    final fullName =
        user?['name'] ??
        user?['full_name'] ??
        ((user?['firstName'] ?? user?['first_name']) != null
            ? '${user!['firstName'] ?? user['first_name']} ${user['lastName'] ?? user['last_name']}'
            : '—');
    final id = (user?['worker_code'] ?? user?['id'])?.toString() ?? '—';
    final role = _formatRoles(user);
    final status = user?['status'] ?? 'Active';
    final phone = user?['phone'] ?? user?['contact_number'] ?? '—';
    final address = user?['address'] ?? '—';
    final department = user?['department'] ?? user?['project'] ?? 'Operations';

    // Format Birthday
    final birthdayRaw = user?['birthday']?.toString();
    String birthday = '—';
    if (birthdayRaw != null && birthdayRaw.isNotEmpty) {
      final datePart = birthdayRaw.contains('T')
          ? birthdayRaw.split('T')[0]
          : birthdayRaw;
      final parts = datePart.split('-');
      if (parts.length == 3) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);
        const months = [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ];
        if (month != null &&
            month >= 1 &&
            month <= 12 &&
            day != null &&
            year != null) {
          birthday = '${months[month - 1]} $day, $year';
        } else {
          birthday = datePart;
        }
      } else {
        birthday = datePart;
      }
    }

    // Format Age
    final ageRaw = user?['age']?.toString();
    final age = (ageRaw != null && ageRaw.isNotEmpty && ageRaw != '0')
        ? '$ageRaw yrs old'
        : '—';

    final initials = _getInitials(fullName != '—' ? fullName : 'Worker');

    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      appBar: const WorkerAppHeader(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFA63228)),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final double horizontalPadding = constraints.maxWidth > 600
                    ? 20.0
                    : 12.0;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 550),
                    child: RefreshIndicator(
                      color: const Color(0xFFA63228),
                      onRefresh: _fetchProfile,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Profile Information Card (Matching Web/Dashboard Card Design)
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
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
                                          color:
                                              status.toLowerCase() == 'active'
                                              ? Colors.green.shade50
                                              : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color:
                                                status.toLowerCase() == 'active'
                                                ? Colors.green.shade200
                                                : Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Text(
                                          status,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                status.toLowerCase() == 'active'
                                                ? Colors.green.shade700
                                                : Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  // Avatar + Tabular Info
                                  LayoutBuilder(
                                    builder: (context, cardConstraints) {
                                      final isWide =
                                          cardConstraints.maxWidth > 380;
                                      return isWide
                                          ? Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _buildAvatarCircle(initials),
                                                const SizedBox(width: 18),
                                                Expanded(
                                                  child: _buildInfoTable(
                                                    fullName: fullName,
                                                    phone: phone,
                                                    role: role,
                                                    address: address,
                                                    id: id,
                                                    department: department,
                                                    birthday: birthday,
                                                    age: age,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Column(
                                              children: [
                                                Center(
                                                  child: _buildAvatarCircle(
                                                    initials,
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                _buildInfoTable(
                                                  fullName: fullName,
                                                  phone: phone,
                                                  role: role,
                                                  address: address,
                                                  id: id,
                                                  department: department,
                                                  birthday: birthday,
                                                  age: age,
                                                ),
                                              ],
                                            );
                                    },
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 10),

                            if (id != '—')
                              _buildSectionCard(
                                title: 'Worker ID QR Code',
                                icon: Icons.qr_code_2_rounded,
                                children: [
                                  Row(
                                    children: [
                                      QrImageView(
                                        data: id,
                                        version: QrVersions.auto,
                                        size: 112,
                                        padding: const EdgeInsets.all(6),
                                        backgroundColor: Colors.white,
                                        semanticsLabel:
                                            'QR code for worker ID $id',
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              id,
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Scan to read your Worker ID.',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _saveWorkerQrCode(id),
                                              icon: const Icon(
                                                Icons.download_rounded,
                                                size: 16,
                                              ),
                                              label: Text(
                                                'Save QR image',
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(
                                                  0xFFA63228,
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                            const SizedBox(height: 10),

                            // 4. CASH ADVANCE / VALE HISTORY
                            _buildSectionCard(
                              title: 'Vale / Cash Advance Records',
                              icon: Icons.payments_outlined,
                              children: [
                                if (_vales.isEmpty)
                                  Center(
                                    child: Text(
                                      'No approved cash advance records.',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  )
                                else
                                  ..._vales.map(
                                    (vale) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 6.0,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${vale['date']?.substring(0, 10) ?? 'N/A'} - ${vale['reason']}',
                                            style: GoogleFonts.inter(
                                              fontSize: 11.5,
                                            ),
                                          ),
                                          Text(
                                            '₱${vale['amount']}',
                                            style: GoogleFonts.inter(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFFA63228),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Action Buttons
                            SizedBox(
                              width: double.infinity,
                              height: 48,
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
                                    fontSize: 14,
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
                              height: 48,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFA63228),
                                  ),
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
                                  'Logout',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFA63228),
                                  ),
                                ),
                                onPressed: _handleLogout,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _saveWorkerQrCode(String workerId) async {
    try {
      final imageData = await QrPainter(
        data: workerId,
        version: QrVersions.auto,
        gapless: true,
      ).toImageData(1024, format: ui.ImageByteFormat.png);
      if (imageData == null) {
        throw StateError('Could not generate the Worker ID QR image.');
      }

      final safeWorkerId = workerId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fileName = 'worker-$safeWorkerId-qr.png';
      await SharePlus.instance.share(
        ShareParams(
          title: 'Worker ID QR Code',
          text: 'Worker ID: $workerId',
          files: [
            XFile.fromData(
              imageData.buffer.asUint8List(),
              mimeType: 'image/png',
              name: fileName,
            ),
          ],
          fileNameOverrides: [fileName],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save QR image: $error'),
          backgroundColor: const Color(0xFFA63228),
        ),
      );
    }
  }

  Widget _buildAvatarCircle(String initials) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: const Color(0xFFA63228).withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFA63228),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTable({
    required String fullName,
    required String phone,
    required String role,
    required String address,
    required String id,
    required String department,
    required String birthday,
    required String age,
  }) {
    return Column(
      children: [
        _buildInfoRow('FULL NAME', fullName),
        _buildDivider(),
        _buildInfoRow('ROLE', role),
        _buildDivider(),
        _buildInfoRow('PHONE NUMBER', phone),
        _buildDivider(),
        _buildInfoRow('HOME ADDRESS', address),
        _buildDivider(),
        _buildInfoRow('EMPLOYEE ID', id),
        _buildDivider(),
        _buildInfoRow('DEPARTMENT', department),
        _buildDivider(),
        _buildInfoRow('BIRTHDATE', birthday),
        _buildDivider(),
        _buildInfoRow('AGE', age),
      ],
    );
  }

  Widget _buildDivider() {
    return Divider(height: 18, thickness: 0.7, color: Colors.grey.shade100);
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFFA63228)),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
