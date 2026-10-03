import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_sidebar.dart';
import '../services/api_service.dart';

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
    final currentId = ApiService.currentUser?['id'];
    if (currentId == null) return;
    
    final id = int.tryParse(currentId.toString());
    if (id == null) return;

    try {
      final freshData = await ApiService.getWorker(id);
      try {
        final valesData = await ApiService.getWorkerCashAdvances(id);
        if (mounted) {
          setState(() {
            _vales = List<Map<String, dynamic>>.from(valesData)
                .where((v) => v['status'] == 'Approved')
                .toList();
          });
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _userData = freshData;
          // Sync with ApiService.currentUser
          ApiService.currentUser = {
            ...ApiService.currentUser ?? {},
            ...freshData,
          };
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch profile: $e');
      // Fallback to ApiService.currentUser if network fails
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _userData ?? ApiService.currentUser;
    final fullName = user?['name'] ?? user?['full_name'] ?? 
        ((user?['firstName'] ?? user?['first_name']) != null 
            ? '${user!['firstName'] ?? user['first_name']} ${user['lastName'] ?? user['last_name']}' 
            : '—');
    final id = user?['id']?.toString() ?? '—';
    final position = user?['position'] ?? 'Worker';
    final status = user?['status'] ?? 'Active';
    final phone = user?['phone'] ?? user?['contact_number'] ?? '—';
    final address = user?['address'] ?? '—';

    // Format Birthday
    final birthdayRaw = user?['birthday']?.toString();
    String birthday = '—';
    if (birthdayRaw != null && birthdayRaw.isNotEmpty) {
      final datePart = birthdayRaw.contains('T') ? birthdayRaw.split('T')[0] : birthdayRaw;
      final parts = datePart.split('-');
      if (parts.length == 3) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);
        const months = [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];
        if (month != null && month >= 1 && month <= 12 && day != null && year != null) {
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

    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Worker Profile & Records',
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFA63228)),
            onPressed: () {
              ApiService.currentUserRole = null;
              ApiService.currentUser = null;
              ApiService.clearToken();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double horizontalPadding = constraints.maxWidth > 600 ? 20.0 : 12.0;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 550),
              child: RefreshIndicator(
                color: const Color(0xFFA63228),
                onRefresh: _fetchProfile,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10),
                  child: Column(
                    children: [
                      // 1. HEADER CARD
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.015), blurRadius: 4, offset: const Offset(0, 1)),
                          ],
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: const Color(0xFFA63228).withValues(alpha: 0.1),
                              child: const Icon(Icons.person, size: 32, color: Color(0xFFA63228)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              fullName,
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'ID: $id',
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildTag(position, const Color(0xFFA63228), Colors.white),
                                const SizedBox(width: 6),
                                _buildTag(
                                  status, 
                                  status.toLowerCase() == 'active' ? Colors.green.shade50 : Colors.grey.shade100, 
                                  status.toLowerCase() == 'active' ? Colors.green.shade700 : Colors.grey.shade700, 
                                  border: status.toLowerCase() == 'active' ? Colors.green.shade300 : Colors.grey.shade300
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 2. PERSONAL INFO
                      _buildSectionCard(
                        title: 'Personal Information',
                        icon: Icons.badge_outlined,
                        children: [
                          _buildInfoRow('Phone Number', phone),
                          _buildInfoRow('Birthdate', birthday),
                          _buildInfoRow('Age', age),
                          _buildInfoRow('Address', address),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 3. TOOLS ACCOUNTABILITY
                      _buildSectionCard(
                        title: 'Tools Accountability',
                        icon: Icons.handyman_outlined,
                        children: [
                          Center(child: Text('No tools currently issued.', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey))),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 4. ATTENDANCE CUTOFF STATS
                      _buildSectionCard(
                        title: 'Attendance Summary (This Cutoff)',
                        icon: Icons.calendar_month_outlined,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatBox('Days Worked', '—'),
                              _buildStatBox('Overtime', '—'),
                              _buildStatBox('Late / Absent', '—'),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 5. CASH ADVANCE / VALE HISTORY
                      _buildSectionCard(
                        title: 'Vale / Cash Advance Records',
                        icon: Icons.payments_outlined,
                        children: [
                          if (_vales.isEmpty)
                            Center(child: Text('No approved cash advance records.', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)))
                          else
                            ..._vales.map((vale) => Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${vale['date']?.substring(0, 10) ?? 'N/A'} - ${vale['reason']}', style: GoogleFonts.inter(fontSize: 11.5)),
                                  Text('₱${vale['amount']}', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFFA63228))),
                                ],
                              ),
                            )).toList(),
                        ],
                      ),
                      const SizedBox(height: 14),
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

  static Widget _buildTag(String text, Color bg, Color textCol, {Color? border}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: border != null ? Border.all(color: border) : null,
      ),
      child: Text(text, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: textCol)),
    );
  }

  static Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.015), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFFA63228)),
              const SizedBox(width: 6),
              Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  static Widget _buildInfoRow(String label, String value) {
    final displayValue = (value.trim().isEmpty) ? '—' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade600)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              displayValue,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildStatBox(String label, String value) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFFA63228))),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade600)),
      ],
    );
  }
}