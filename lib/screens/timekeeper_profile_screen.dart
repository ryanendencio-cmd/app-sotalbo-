import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_sidebar.dart';
import '../services/api_service.dart';

class TimekeeperProfileScreen extends StatefulWidget {
  const TimekeeperProfileScreen({super.key});

  @override
  State<TimekeeperProfileScreen> createState() => _TimekeeperProfileScreenState();
}

class _TimekeeperProfileScreenState extends State<TimekeeperProfileScreen> {

  void _showChangePasswordDialog(BuildContext context) {
    final TextEditingController oldPassController = TextEditingController();
    final TextEditingController newPassController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Change Password', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPassController,
              obscureText: true,
              style: GoogleFonts.inter(fontSize: 12.5),
              decoration: InputDecoration(
                labelText: 'Current Password',
                labelStyle: GoogleFonts.inter(fontSize: 11.5),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newPassController,
              obscureText: true,
              style: GoogleFonts.inter(fontSize: 12.5),
              decoration: InputDecoration(
                labelText: 'New Password',
                labelStyle: GoogleFonts.inter(fontSize: 11.5),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA63228),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password updated successfully!')),
              );
            },
            child: Text('Save', style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFA63228)),
            onPressed: () {
              ApiService.currentUserRole = null;
              ApiService.currentUser = null;
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double screenWidth = constraints.maxWidth;
            final double horizontalPadding = screenWidth > 600 ? 20.0 : 12.0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10),
                  child: Column(
                    children: [
                      // 1. HEADER PROFILE CARD
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.015), blurRadius: 4, offset: const Offset(0, 1)),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Center(
                                child: Icon(Icons.person_outline_rounded, size: 24, color: Color(0xFFA63228)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '—',
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '— • Attendance Timekeeper',
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Text(
                                    'Active Duty',
                                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    'Terminal #04',
                                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 2. STAFF INFORMATION
                      _buildSectionCard(
                        title: 'Staff Information',
                        icon: Icons.badge_outlined,
                        children: [
                          _buildInfoRow('Assigned Project', '—'),
                          _buildInfoRow('Station Location', '—'),
                          _buildInfoRow('Contact Number', '—'),
                          _buildInfoRow('Shift Schedule', '—'),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 3. MONITORING STATS SUMMARY
                      _buildSectionCard(
                        title: 'Monitoring Summary (This Week)',
                        icon: Icons.analytics_outlined,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatBox('Scanned In', '—'),
                              _buildStatBox('Manual Entries', '—'),
                              _buildStatBox('Flagged Late', '—'),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 4. TERMINAL CONTROLS & ACTIONS
                      _buildSectionCard(
                        title: 'Terminal Controls & Security',
                        icon: Icons.settings_outlined,
                        children: [
                          _buildActionTile(
                            'Sync Attendance Database',
                            'Last synced: Today, 08:00 AM',
                            Icons.sync_rounded,
                                () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Attendance logs successfully synced to server!')),
                              );
                            },
                          ),
                          const Divider(height: 12, color: Color(0xFFEEEEEE)),
                          _buildActionTile(
                            'Change Password',
                            'Update your staff portal password',
                            Icons.lock_outline_rounded,
                                () => _showChangePasswordDialog(context),
                          ),
                          const Divider(height: 12, color: Color(0xFFEEEEEE)),
                          _buildActionTile(
                            'Log Out of Terminal',
                            'Sign out from this device',
                            Icons.logout_rounded,
                                () {
                              ApiService.currentUserRole = null;
                              ApiService.clearToken();
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            isDestructive: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.015), blurRadius: 4, offset: const Offset(0, 1)),
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
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade600)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFFA63228)),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildActionTile(String title, String subtitle, IconData icon, VoidCallback onTap, {bool isDestructive = false}) {
    final color = isDestructive ? const Color(0xFFA63228) : Colors.black87;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 1),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}