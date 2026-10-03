import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_sidebar.dart';
import '../services/api_service.dart';
class ToolsMonitoringScreen extends StatefulWidget {
  final Map<String, String>? initialUserData;

  const ToolsMonitoringScreen({super.key, this.initialUserData});

  @override
  State<ToolsMonitoringScreen> createState() => _ToolsMonitoringScreenState();
}

class _ToolsMonitoringScreenState extends State<ToolsMonitoringScreen> {
  int _currentNavIndex = 0; // 0: All Tools, 1: Borrowed, 2: Profile
  final String _selectedCategory = 'All';
  String _selectedStatusFilter = 'All';

  final TextEditingController _searchController = TextEditingController();

  late Map<String, String> _userProfile;
  late List<Map<String, dynamic>> _toolsData;

  @override
  void initState() {
    super.initState();
    _userProfile = {
      'fullName': widget.initialUserData?['fullName'] ?? 'Ryan Breganza Endencio',
      'role': widget.initialUserData?['role'] ?? 'Tool Keeper / Warehouse Custodian',
      'phone': widget.initialUserData?['phone'] ?? '09123456789',
      'site': widget.initialUserData?['site'] ?? 'S-CON Residential Phase 2 (Santa Cruz)',
      'emergencyContact': widget.initialUserData?['emergencyContact'] ?? '09987654321',
      'idNumber': widget.initialUserData?['idNumber'] ?? 'SCON-STF-2026-08',
      'status': 'Verified / Approved by Admin',
    };

    _toolsData = [];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredTools {
    return _toolsData.where((t) {
      if (_currentNavIndex == 1 && t['status'] != 'Checked Out') {
        return false;
      }
      final matchesCat = _selectedCategory == 'All' || t['category'] == _selectedCategory;
      final matchesStatus = _selectedStatusFilter == 'All' ||
          (_selectedStatusFilter == 'Overdue' ? t['isOverdue'] == true : t['status'] == _selectedStatusFilter);
      final query = _searchController.text.trim().toLowerCase();
      final matchesQuery = query.isEmpty ||
          t['name'].toString().toLowerCase().contains(query) ||
          t['code'].toString().toLowerCase().contains(query) ||
          (t['borrower'] != null && t['borrower'].toString().toLowerCase().contains(query));
      return matchesCat && matchesStatus && matchesQuery;
    }).toList();
  }

  void _checkInTool(Map<String, dynamic> tool) {
    String selectedCondition = 'Good';

    showDialog(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Check-In Equipment',
            style: GoogleFonts.inter(fontSize: screenWidth * 0.04, fontWeight: FontWeight.bold),
          ),
          content: StatefulBuilder(
            builder: (context, setDialogState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Returning: ${tool['name']}',
                    style: GoogleFonts.inter(fontSize: screenWidth * 0.032, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Borrower: ${tool['borrower']} (${tool['role'] ?? "Worker"})',
                    style: GoogleFonts.inter(fontSize: screenWidth * 0.028, color: Colors.grey.shade600)),
                const SizedBox(height: 12),
                Text('Equipment Condition:',
                    style: GoogleFonts.inter(fontSize: screenWidth * 0.03, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedCondition,
                  isDense: true,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'Good',
                      child: Text('Good / Working', style: GoogleFonts.inter(fontSize: screenWidth * 0.03)),
                    ),
                    DropdownMenuItem(
                      value: 'Broken / Damaged',
                      child: Text('Broken / Damaged', style: GoogleFonts.inter(fontSize: screenWidth * 0.03)),
                    ),
                    DropdownMenuItem(
                      value: 'Needs Maintenance',
                      child: Text('Needs Maintenance', style: GoogleFonts.inter(fontSize: screenWidth * 0.03)),
                    ),
                  ],
                  onChanged: (val) => setDialogState(() => selectedCondition = val ?? 'Good'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: screenWidth * 0.03)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA63228),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                setState(() {
                  if (selectedCondition == 'Good') {
                    tool['status'] = 'In Storage';
                    tool['condition'] = 'Good';
                  } else {
                    tool['status'] = 'Under Repair';
                    tool['condition'] = selectedCondition;
                  }
                  tool['borrower'] = null;
                  tool['role'] = null;
                  tool['checkoutTime'] = null;
                  tool['isOverdue'] = false;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${tool['code']} successfully received and stored.',
                        style: GoogleFonts.inter(fontSize: 12)),
                    backgroundColor: Colors.black87,
                  ),
                );
              },
              child: Text('Confirm Check-In',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: screenWidth * 0.03)),
            ),
          ],
        );
      },
    );
  }

  void _showCheckOutDialog() {
    final available = _toolsData.where((t) => t['status'] == 'In Storage').toList();
    String? selectedCode = available.isNotEmpty ? available.first['code'] as String? : null;

    final workerCtrl = TextEditingController();
    final roleCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: screenWidth > 500 ? 400 : screenWidth * 0.9),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Check-Out Tool',
                              style: GoogleFonts.inter(
                                  fontSize: screenWidth * 0.04, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (available.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text('No tools available in storage.',
                              style: GoogleFonts.inter(
                                  fontSize: screenWidth * 0.03, color: Colors.grey.shade600)),
                        )
                      else ...[
                        Text('Select Tool',
                            style: GoogleFonts.inter(
                                fontSize: screenWidth * 0.03, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          initialValue: selectedCode,
                          isExpanded: true,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: available.map((t) {
                            return DropdownMenuItem<String>(
                              value: t['code'] as String,
                              child: Text('${t['code']} - ${t['name']}',
                                  style: GoogleFonts.inter(fontSize: screenWidth * 0.03),
                                  overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) => setDialogState(() => selectedCode = val),
                        ),
                        const SizedBox(height: 10),
                        Text('Borrower Worker Name',
                            style: GoogleFonts.inter(
                                fontSize: screenWidth * 0.03, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: workerCtrl,
                          style: GoogleFonts.inter(fontSize: screenWidth * 0.032),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'e.g., Juan Dela Cruz',
                            hintStyle: GoogleFonts.inter(fontSize: screenWidth * 0.03),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text('Role / Trade',
                            style: GoogleFonts.inter(
                                fontSize: screenWidth * 0.03, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: roleCtrl,
                          style: GoogleFonts.inter(fontSize: screenWidth * 0.032),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'e.g., Mason / Laborer',
                            hintStyle: GoogleFonts.inter(fontSize: screenWidth * 0.03),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFA63228),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              if (selectedCode == null || workerCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please fill out all borrower fields.')),
                                );
                                return;
                              }
                              setState(() {
                                final target = _toolsData.firstWhere((t) => t['code'] == selectedCode);
                                target['status'] = 'Checked Out';
                                target['borrower'] = workerCtrl.text.trim();
                                target['role'] =
                                roleCtrl.text.trim().isEmpty ? 'Worker' : roleCtrl.text.trim();
                                target['checkoutTime'] = 'Today 08:00 AM';
                                target['isOverdue'] = false;
                              });
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Tool released successfully.')),
                              );
                            },
                            child: Text('Confirm Check-Out',
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: screenWidth * 0.032)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Confirm Log Out',
            style: GoogleFonts.inter(
                fontSize: screenWidth * 0.04, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          content: Text(
            'Are you sure you want to end your custodian session and return to the login screen?',
            style: GoogleFonts.inter(fontSize: screenWidth * 0.03, color: Colors.grey.shade700),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(fontSize: screenWidth * 0.03, color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA63228),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context);
                ApiService.currentUserRole = null;
                ApiService.clearToken();
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: Text(
                'Log Out',
                style: GoogleFonts.inter(
                    fontSize: screenWidth * 0.03, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _userProfile['fullName']);
    final phoneCtrl = TextEditingController(text: _userProfile['phone']);
    final roleCtrl = TextEditingController(text: _userProfile['role']);
    final siteCtrl = TextEditingController(text: _userProfile['site']);
    final emgCtrl = TextEditingController(text: _userProfile['emergencyContact']);

    showDialog(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit Registered Info',
              style: GoogleFonts.inter(fontSize: screenWidth * 0.04, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEditField('Full Name', nameCtrl, screenWidth),
                _buildEditField('Phone Number', phoneCtrl, screenWidth),
                _buildEditField('Role / Designation', roleCtrl, screenWidth),
                _buildEditField('Assigned Site', siteCtrl, screenWidth),
                _buildEditField('Emergency Contact', emgCtrl, screenWidth),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: screenWidth * 0.03)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA63228),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                setState(() {
                  _userProfile['fullName'] = nameCtrl.text.trim();
                  _userProfile['phone'] = phoneCtrl.text.trim();
                  _userProfile['role'] = roleCtrl.text.trim();
                  _userProfile['site'] = siteCtrl.text.trim();
                  _userProfile['emergencyContact'] = emgCtrl.text.trim();
                });
                Navigator.pop(context);
              },
              child: Text('Save Details',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: screenWidth * 0.03)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEditField(String label, TextEditingController controller, double screenWidth) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(fontSize: screenWidth * 0.028, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          TextField(
            controller: controller,
            style: GoogleFonts.inter(fontSize: screenWidth * 0.032),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab(double screenWidth, double screenHeight) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.04, vertical: screenHeight * 0.015),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(screenWidth * 0.04),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: screenWidth * 0.08,
                  backgroundColor: const Color(0xFFA63228).withValues(alpha: 0.1),
                  child: Icon(Icons.person, color: const Color(0xFFA63228), size: screenWidth * 0.09),
                ),
                SizedBox(height: screenHeight * 0.01),
                Text(
                  _userProfile['fullName']!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: screenWidth * 0.04, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                Text(
                  _userProfile['role']!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: screenWidth * 0.028, color: Colors.grey.shade600),
                ),
                SizedBox(height: screenHeight * 0.008),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    _userProfile['status']!,
                    style: GoogleFonts.inter(
                        fontSize: screenWidth * 0.026, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: screenHeight * 0.015),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(screenWidth * 0.04),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Registered Profile Details',
                        style: GoogleFonts.inter(
                            fontSize: screenWidth * 0.032, fontWeight: FontWeight.bold, color: Colors.black87)),
                    InkWell(
                      onTap: _showEditProfileDialog,
                      child: Text('Edit',
                          style: GoogleFonts.inter(
                              fontSize: screenWidth * 0.03,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFA63228))),
                    ),
                  ],
                ),
                SizedBox(height: screenHeight * 0.01),
                _buildInfoRow('Account ID', _userProfile['idNumber']!, screenWidth),
                _buildInfoRow('Mobile Number', _userProfile['phone']!, screenWidth),
                _buildInfoRow('Assigned Site', _userProfile['site']!, screenWidth),
                _buildInfoRow('Emergency Contact', _userProfile['emergencyContact']!, screenWidth),
              ],
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFA63228)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.logout, color: Color(0xFFA63228), size: 18),
              label: Text('Log Out',
                  style: GoogleFonts.inter(
                      color: const Color(0xFFA63228), fontWeight: FontWeight.bold, fontSize: screenWidth * 0.032)),
              onPressed: _showLogoutDialog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, double screenWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: screenWidth * 0.028, color: Colors.grey.shade600)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                  fontSize: screenWidth * 0.028, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final total = _toolsData.length;
    final checkedOut = _toolsData.where((t) => t['status'] == 'Checked Out').length;
    final inStorage = _toolsData.where((t) => t['status'] == 'In Storage').length;
    final overdueCount = _toolsData.where((t) => t['isOverdue'] == true).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Image.asset('assets/logo.png', height: screenHeight * 0.032 < 24 ? 24 : screenHeight * 0.032),
      ),
      body: SafeArea(
        child: _currentNavIndex == 2
            ? _buildProfileTab(screenWidth, screenHeight)
            : Column(
          children: [
            // 1. TOP SUMMARY METRICS (Responsive Box with FittedBox)
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.03, vertical: screenHeight * 0.01),
              child: Row(
                children: [
                  _buildMetricTile('Total', '$total', screenWidth, screenHeight),
                  SizedBox(width: screenWidth * 0.015),
                  _buildMetricTile('Out', '$checkedOut', screenWidth, screenHeight),
                  SizedBox(width: screenWidth * 0.015),
                  _buildMetricTile('In Shed', '$inStorage', screenWidth, screenHeight),
                  SizedBox(width: screenWidth * 0.015),
                  _buildMetricTile('Overdue', '$overdueCount', screenWidth, screenHeight,
                      isFlagged: overdueCount > 0),
                ],
              ),
            ),

            // 2. SEARCH BAR
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.03, vertical: screenHeight * 0.005),
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.inter(fontSize: screenWidth * 0.03, color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Search tool, code, or worker...',
                    hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: screenWidth * 0.03),
                    prefixIcon: Icon(Icons.search, size: screenWidth * 0.045, color: Colors.black54),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                        borderSide: BorderSide(color: Colors.black87)),
                  ),
                ),
              ),
            ),

            // 3. CATEGORY CHIPS
            if (_currentNavIndex == 0)
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03, vertical: 2),
                  children: [
                    _buildStatusChip('All', screenWidth),
                    _buildStatusChip('Checked Out', screenWidth),
                    _buildStatusChip('In Storage', screenWidth),
                    _buildStatusChip('Overdue', screenWidth),
                    _buildStatusChip('Under Repair', screenWidth),
                  ],
                ),
              ),

            // 4. LIST VIEW WITH EMPTY STATE
            Expanded(
              child: _filteredTools.isEmpty
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _currentNavIndex == 1
                          ? Icons.task_alt_rounded
                          : Icons.inventory_2_outlined,
                      size: screenWidth * 0.1,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentNavIndex == 1
                          ? 'All tools are currently in storage.\nNo active loans.'
                          : 'No tools match your search or filter.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: screenWidth * 0.03,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.separated(
                padding: EdgeInsets.fromLTRB(
                    screenWidth * 0.03, 6, screenWidth * 0.03, 80),
                physics: const BouncingScrollPhysics(),
                itemCount: _filteredTools.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final tool = _filteredTools[index];
                  final isCheckedOut = tool['status'] == 'Checked Out';
                  final isOverdue = tool['isOverdue'] == true;

                  return Container(
                    padding: EdgeInsets.all(screenWidth * 0.03),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isOverdue
                              ? const Color(0xFFA63228).withValues(alpha: 0.3)
                              : Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.construction_outlined,
                                  color: Colors.black87, size: screenWidth * 0.045),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tool['name'],
                                      style: GoogleFonts.inter(
                                          fontSize: screenWidth * 0.032,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${tool['code']} • ${tool['category']} • Cond: ${tool['condition']}',
                                    style: GoogleFonts.inter(
                                        fontSize: screenWidth * 0.026,
                                        color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isOverdue
                                    ? const Color(0xFFA63228).withValues(alpha: 0.08)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: isOverdue
                                        ? const Color(0xFFA63228).withValues(alpha: 0.3)
                                        : Colors.grey.shade300),
                              ),
                              child: Text(
                                isOverdue ? 'Overdue Return' : tool['status'],
                                style: GoogleFonts.inter(
                                  fontSize: screenWidth * 0.024,
                                  fontWeight: FontWeight.bold,
                                  color: isOverdue ? const Color(0xFFA63228) : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isCheckedOut) ...[
                          const Divider(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Holder: ${tool['borrower']} (${tool['role']})',
                                      style: GoogleFonts.inter(
                                          fontSize: screenWidth * 0.028,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text('Out: ${tool['checkoutTime']}',
                                        style: GoogleFonts.inter(
                                            fontSize: screenWidth * 0.024,
                                            color: Colors.grey.shade500)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  minimumSize: Size.zero,
                                  side: const BorderSide(color: Colors.black87),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _checkInTool(tool),
                                child: Text('Check In',
                                    style: GoogleFonts.inter(
                                        fontSize: screenWidth * 0.028,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _currentNavIndex != 2
          ? FloatingActionButton(
        backgroundColor: const Color(0xFFA63228),
        elevation: 2,
        onPressed: _showCheckOutDialog,
        child: const Icon(Icons.add, color: Colors.white, size: 22),
      )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        selectedItemColor: const Color(0xFFA63228),
        unselectedItemColor: Colors.grey.shade500,
        backgroundColor: Colors.white,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
        onTap: (index) => setState(() => _currentNavIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined, size: 20),
            activeIcon: Icon(Icons.inventory_2, size: 20),
            label: 'All Tools',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_late_outlined, size: 20),
            activeIcon: Icon(Icons.assignment_late, size: 20),
            label: 'Borrowed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline, size: 20),
            activeIcon: Icon(Icons.person, size: 20),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, double screenWidth) {
    final isSelected = _selectedStatusFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(
          label,
          style: GoogleFonts.inter(
              fontSize: screenWidth * 0.026,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.black87),
        ),
        selected: isSelected,
        selectedColor: Colors.black87,
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade300)),
        showCheckmark: false,
        onSelected: (val) => setState(() => _selectedStatusFilter = label),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, double screenWidth, double screenHeight,
      {bool isFlagged = false}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
            vertical: screenHeight * 0.008, horizontal: screenWidth * 0.015),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isFlagged ? const Color(0xFFA63228) : Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: screenWidth * 0.024,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: GoogleFonts.inter(
                    fontSize: screenWidth * 0.038,
                    fontWeight: FontWeight.w900,
                    color: isFlagged ? const Color(0xFFA63228) : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}