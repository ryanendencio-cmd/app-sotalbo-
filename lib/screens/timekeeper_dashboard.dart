import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'timesheet_screen.dart';
import 'reports_screen.dart';
import 'timekeeper_profile_screen.dart';
import '../widgets/app_sidebar.dart';
import '../services/api_service.dart';

class TimekeeperDashboard extends StatefulWidget {
  const TimekeeperDashboard({super.key});

  @override
  State<TimekeeperDashboard> createState() => _TimekeeperDashboardState();
}

class _TimekeeperDashboardState extends State<TimekeeperDashboard> {
  int _currentNavIndex = 0;

  DateTime _selectedTrendDate = DateTime.now();

  List<String> _currentCounts = ['55', '58', '48', '53', '56', '38'];
  List<double> _currentFactors = [0.85, 0.90, 0.75, 0.82, 0.88, 0.60];

  final List<Map<String, dynamic>> _recentLogs = [];
  List<Map<String, dynamic>> _allWorkers = [];
  bool _isLoadingWorkers = false;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    setState(() => _isLoadingWorkers = true);
    try {
      final workersList = await ApiService.getWorkers();
      if (mounted) {
        setState(() {
          _allWorkers = List<Map<String, dynamic>>.from(workersList);
          _isLoadingWorkers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingWorkers = false);
      }
    }
  }

  Future<void> _pickTrendDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedTrendDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
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

    if (picked != null && picked != _selectedTrendDate) {
      if (!mounted) return;
      setState(() {
        _selectedTrendDate = picked;
        _currentCounts = ['0', '0', '0', '0', '0', '0'];
        _currentFactors = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Graph updated for week of ${picked.month}/${picked.day}/${picked.year}'),
          backgroundColor: Colors.black87,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _openScannerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 24),
              Text('Scan ID Barcode / QR', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 8),
              Text('Itapat ang ID ng worker sa camera', style: GoogleFonts.inter(color: Colors.grey.shade600)),
              const Spacer(),
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black87, width: 2),
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.grey.shade100,
                ),
                child: const Center(
                  child: Icon(Icons.qr_code_scanner_outlined, size: 60, color: Colors.black54),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: GoogleFonts.inter(color: Colors.black87, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openManualEntryDialog() {
    TextEditingController? autocompleteNameController;
    final roleController = TextEditingController();
    String selectedType = 'IN';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text('Manual Entry', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Autocomplete<Map<String, dynamic>>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<Map<String, dynamic>>.empty();
                          }
                          return _allWorkers.where((worker) {
                            final name = '${worker['first_name'] ?? ''} ${worker['last_name'] ?? ''}'.trim();
                            return name.toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        displayStringForOption: (Map<String, dynamic> option) {
                          return '${option['first_name'] ?? ''} ${option['last_name'] ?? ''}'.trim();
                        },
                        onSelected: (Map<String, dynamic> selection) {
                          roleController.text = selection['role']?.toString() ?? 'Mason';
                        },
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          autocompleteNameController = controller;
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            style: GoogleFonts.inter(color: Colors.black87),
                            decoration: InputDecoration(
                              labelText: 'Worker Name',
                              labelStyle: GoogleFonts.inter(color: Colors.grey.shade600),
                              border: const OutlineInputBorder(),
                              focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.black87)),
                            ),
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(10),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: 200,
                                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                                ),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (BuildContext context, int index) {
                                    final option = options.elementAt(index);
                                    final name = '${option['first_name'] ?? ''} ${option['last_name'] ?? ''}'.trim();
                                    final role = option['role'] ?? '';
                                    return ListTile(
                                      title: Text(name, style: GoogleFonts.inter(color: Colors.black87)),
                                      subtitle: Text(role, style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 12)),
                                      onTap: () {
                                        onSelected(option);
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: roleController,
                        style: GoogleFonts.inter(color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'Role (e.g. Mason, Laborer)',
                          labelStyle: GoogleFonts.inter(color: Colors.grey.shade600),
                          border: const OutlineInputBorder(),
                          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.black87)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ChoiceChip(
                            label: Text('TIME IN', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: selectedType == 'IN' ? Colors.white : Colors.black87)),
                            selected: selectedType == 'IN',
                            onSelected: (val) => setDialogState(() => selectedType = 'IN'),
                            selectedColor: Colors.black87,
                            backgroundColor: Colors.grey.shade200,
                            showCheckmark: false,
                          ),
                          ChoiceChip(
                            label: Text('TIME OUT', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: selectedType == 'OUT' ? Colors.white : Colors.black87)),
                            selected: selectedType == 'OUT',
                            onSelected: (val) => setDialogState(() => selectedType = 'OUT'),
                            selectedColor: Colors.black87,
                            backgroundColor: Colors.grey.shade200,
                            showCheckmark: false,
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, elevation: 0),
                    onPressed: () {
                      final workerName = autocompleteNameController?.text.trim() ?? '';
                      if (workerName.isNotEmpty && roleController.text.isNotEmpty) {
                        final now = TimeOfDay.now();
                        final timeString = now.format(context);

                        setState(() {
                          _recentLogs.insert(0, {
                            'name': workerName,
                            'role': roleController.text,
                            'time': timeString,
                            'status': 'Manual',
                            'type': selectedType,
                          });
                        });
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$workerName successfully logged $selectedType!', style: GoogleFonts.inter()),
                            backgroundColor: Colors.black87,
                          ),
                        );
                      }
                    },
                    child: Text('Save Log', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildScannerTab(),
      const TimesheetScreen(),
      const ReportsScreen(),
      const TimekeeperProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Image.asset('assets/logo.png', height: 30),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_outlined, color: Colors.black87),
            onPressed: _openScannerModal,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentNavIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          setState(() {
            _currentNavIndex = index;
          });
        },
        selectedItemColor: const Color(0xFFA63228),
        unselectedItemColor: Colors.grey.shade500,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.document_scanner_outlined), activeIcon: Icon(Icons.document_scanner_rounded), label: 'Scanner'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline_rounded), activeIcon: Icon(Icons.people_rounded), label: 'Timesheet'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), activeIcon: Icon(Icons.assignment_rounded), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: MAIN SCANNER DASHBOARD + ANALYTICS
  // ==========================================
  Widget _buildScannerTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double horizontalPadding = constraints.maxWidth > 600 ? constraints.maxWidth * 0.15 : 16.0;

        return Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // GREETING (TANGGAL NA ANG TIMEKEEPER BADGE SA KANAN)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance Terminal',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hello, Admin Mark',
                      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // LIVE HEADCOUNT SUMMARY
                Row(
                  children: [
                    Expanded(child: _buildStatCard('Present', '0')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatCard('Late', '0')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatCard('Absent', '0')),
                  ],
                ),
                const SizedBox(height: 12),

                // ==========================================
                // WEEKLY ATTENDANCE ANALYTICS GRAPH
                // ==========================================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Weekly Attendance Trend',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.edit_calendar_rounded, size: 20, color: Color(0xFFA63228)),
                            tooltip: 'Pick Date to Filter Trend',
                            onPressed: () => _pickTrendDate(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildBarItem('Mon', _currentFactors[0], _currentCounts[0]),
                          _buildBarItem('Tue', _currentFactors[1], _currentCounts[1]),
                          _buildBarItem('Wed', _currentFactors[2], _currentCounts[2]),
                          _buildBarItem('Thu', _currentFactors[3], _currentCounts[3]),
                          _buildBarItem('Fri', _currentFactors[4], _currentCounts[4]),
                          _buildBarItem('Sat', _currentFactors[5], _currentCounts[5]),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // MAIN SCANNER BUTTON
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openScannerModal,
                    borderRadius: BorderRadius.circular(20),
                    splashColor: Colors.white.withValues(alpha: 0.2),
                    highlightColor: Colors.white.withValues(alpha: 0.1),
                    child: Ink(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 26),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA63228),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFA63228).withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.qr_code_scanner_outlined, size: 56, color: Colors.white),
                          const SizedBox(height: 10),
                          Text(
                            'SCAN WORKER ID',
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.0),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap to open camera for Time In / Out',
                            style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white70, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // RECENT LOGS HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Logs (Today)',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black87),
                    ),
                    TextButton.icon(
                      onPressed: _openManualEntryDialog,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      icon: const Icon(Icons.edit_note_rounded, size: 18, color: Colors.black87),
                      label: Text(
                        'Manual Entry',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // LOGS LIST DYNAMIC BUILDER
                _recentLogs.isEmpty
                    ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text("No records yet.", style: GoogleFonts.inter(color: Colors.grey)),
                  ),
                )
                    : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentLogs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final log = _recentLogs[index];

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Center(
                              child: Text(
                                log['type'],
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black87
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  log['name'],
                                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  log['role'],
                                  style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                log['time'],
                                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w900, color: Colors.black87),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                log['status'],
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBarItem(String day, double heightFactor, String count) {
    const double maxHeight = 85.0;
    return Column(
      children: [
        Text(
          count,
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Container(
          width: 26,
          height: maxHeight,
          alignment: Alignment.bottomCenter,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: FractionallySizedBox(
            heightFactor: heightFactor,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFA63228),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          day,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}