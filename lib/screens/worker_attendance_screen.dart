import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class WorkerAttendanceScreen extends StatefulWidget {
  const WorkerAttendanceScreen({super.key});

  @override
  State<WorkerAttendanceScreen> createState() => _WorkerAttendanceScreenState();
}

class _WorkerAttendanceScreenState extends State<WorkerAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<Map<String, dynamic>> _attendanceLogs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAttendance();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAttendance() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getAttendance(1);
      final userId = ApiService.currentUser?['id']?.toString();
      if (mounted) {
        setState(() {
          _attendanceLogs = List<Map<String, dynamic>>.from(data)
              .where((r) => r['worker_id']?.toString() == userId || userId == null)
              .toList();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEarlyOutDialog() {
    final TextEditingController reasonController = TextEditingController();
    String selectedReason = 'Medical / Health';
    final List<String> reasons = [
      'Medical / Health',
      'Family Emergency',
      'Personal Errand',
      'Doctor Appointment',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Request Early Out',
                            style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87),
                          ),
                          Text(
                            'Requires admin approval',
                            style: GoogleFonts.inter(
                                fontSize: 10, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Reason',
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: reasons.map((r) {
                      final isSelected = selectedReason == r;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedReason = r),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFA63228)
                                : const Color(0xFFF5F3EF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFA63228)
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            r,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color:
                                  isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    style: GoogleFonts.inter(fontSize: 12),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFFAF8F5),
                      isDense: true,
                      hintText: 'Additional details (optional)',
                      hintStyle: GoogleFonts.inter(
                          color: Colors.grey.shade400, fontSize: 11),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFFA63228), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel',
                              style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA63228),
                            elevation: 0,
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Early-out request submitted: $selectedReason',
                                  style: GoogleFonts.inter(fontSize: 12),
                                ),
                                backgroundColor: const Color(0xFFA63228),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            );
                          },
                          child: Text('Submit Request',
                              style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null) return '—';
    try {
      final datePart =
          raw.contains('T') ? raw.split('T')[0] : raw.split(' ')[0];
      final parts = datePart.split('-');
      if (parts.length < 3) return raw;
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (m == null || d == null) return raw;
      return '${months[m - 1]} $d, ${parts[0]}';
    } catch (_) {
      return raw;
    }
  }

  String _dayOfWeek(String? raw) {
    if (raw == null) return '—';
    try {
      final datePart =
          raw.contains('T') ? raw.split('T')[0] : raw.split(' ')[0];
      final dt = DateTime.parse(datePart);
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Attendance',
          style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _showEarlyOutDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA63228),
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.exit_to_app_rounded,
                  size: 14, color: Colors.white),
              label: Text(
                'Early Out',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFFA63228),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFFA63228),
                indicatorWeight: 2.5,
                labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.bold, fontSize: 12),
                tabs: const [
                  Tab(text: 'Attendance History'),
                  Tab(text: 'Requests'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: Color(0xFFA63228)))
          : LayoutBuilder(
              builder: (context, constraints) {
                final double hp = constraints.maxWidth > 600 ? 20.0 : 12.0;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // --- TAB 1: ATTENDANCE HISTORY ---
                        RefreshIndicator(
                          color: const Color(0xFFA63228),
                          onRefresh: _loadAttendance,
                          child: _attendanceLogs.isEmpty
                              ? _buildEmpty(
                                  Icons.event_note_outlined,
                                  'No attendance records yet',
                                  'Your attendance logs will appear here once recorded by the timekeeper.',
                                )
                              : ListView.separated(
                                  physics:
                                      const BouncingScrollPhysics(),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: hp, vertical: 10),
                                  itemCount: _attendanceLogs.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, i) {
                                    final record = _attendanceLogs[i];
                                    final dateStr = _formatDate(
                                        record['date']?.toString());
                                    final day = _dayOfWeek(
                                        record['date']?.toString());
                                    final timeIn =
                                        record['time_in']?.toString() ??
                                            '—';
                                    final timeOut =
                                        record['time_out']?.toString() ??
                                            '—';
                                    final hours =
                                        record['hours_worked']
                                            ?.toString() ??
                                            '—';
                                    final ot =
                                        record['overtime_hours']
                                            ?.toString() ??
                                            '0';

                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.015),
                                              blurRadius: 4,
                                              offset:
                                                  const Offset(0, 1)),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFA63228)
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(day,
                                                    style: GoogleFonts.inter(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 11,
                                                        color: const Color(
                                                            0xFFA63228))),
                                                Text(
                                                    dateStr.split(
                                                        ' ')[1].replaceAll(
                                                        ',', ''),
                                                    style: GoogleFonts.inter(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors
                                                            .black87)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(dateStr,
                                                    style: GoogleFonts.inter(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12.5,
                                                        color:
                                                            Colors.black87)),
                                                const SizedBox(height: 2),
                                                Text(
                                                    'In: $timeIn  •  Out: $timeOut',
                                                    style: GoogleFonts.inter(
                                                        fontSize: 10.5,
                                                        color: Colors
                                                            .grey.shade600)),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text('$hours hrs',
                                                  style: GoogleFonts.inter(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                      color: Colors
                                                          .green.shade700)),
                                              if (ot != '0' &&
                                                  ot.isNotEmpty)
                                                Text('OT: $ot hr',
                                                    style: GoogleFonts.inter(
                                                        fontSize: 9.5,
                                                        color: const Color(
                                                            0xFFA63228),
                                                        fontWeight:
                                                            FontWeight
                                                                .bold)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),

                        // --- TAB 2: REQUESTS ---
                        _buildEmpty(
                          Icons.inbox_outlined,
                          'No pending requests',
                          'Your early-out requests will appear here once submitted.',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmpty(IconData icon, String title, String subtitle) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFA63228).withValues(alpha: 0.07),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon,
                    size: 32, color: const Color(0xFFA63228)),
              ),
              const SizedBox(height: 14),
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const SizedBox(height: 6),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 11.5, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ],
    );
  }
}
