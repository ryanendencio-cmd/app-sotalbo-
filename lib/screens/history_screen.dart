import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  final List<Map<String, String>> _attendanceLogs = [];
  final List<Map<String, String>> _toolLogs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    try {
      final user = ApiService.currentUser;
      final userId = user?['id']?.toString();
      final userName = (user?['full_name'] ?? user?['name'] ?? '${user?['first_name'] ?? ''} ${user?['last_name'] ?? ''}').toString().trim().toLowerCase();

      final rawAttendance = await ApiService.getAttendance('ALL');
      final rawTools = await ApiService.getBorrowHistory('ALL');

      final List<Map<String, String>> attendanceList = [];
      for (final r in rawAttendance) {
        final wId = r['worker_id']?.toString();
        final wName = (r['worker_name'] ?? r['name'] ?? '').toString().trim().toLowerCase();

        if (userId != null && wId != null && wId != userId) continue;
        if (userId == null && userName.isNotEmpty && wName.isNotEmpty && !wName.contains(userName) && !userName.contains(wName)) continue;

        final dateStr = (r['date'] ?? '').toString();
        final dt = DateTime.tryParse(dateStr);
        final dayName = dt != null ? ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][dt.weekday - 1] : 'Log';
        final monthDay = dt != null ? '${_monthAbbr(dt.month)} ${dt.day}, ${dt.year}' : dateStr;

        final inTime = (r['morningIn'] ?? r['timeIn'] ?? r['afternoonIn'] ?? '—').toString();
        final outTime = (r['afternoonOut'] ?? r['timeOut'] ?? r['morningOut'] ?? '—').toString();

        attendanceList.add({
          'day': dayName,
          'date': monthDay,
          'in': inTime,
          'out': outTime,
          'hours': r['hours'] != null ? '${r['hours']} hrs' : '8 hrs',
          'ot': r['ot'] != null && r['ot'] != 0 ? '${r['ot']} hrs' : '0 hr',
        });
      }

      final List<Map<String, String>> toolList = [];
      for (final t in rawTools) {
        final bId = t['worker_id']?.toString();
        final bName = (t['borrower_name'] ?? t['borrower'] ?? '').toString().trim().toLowerCase();

        if (userId != null && bId != null && bId != userId) continue;
        if (userId == null && userName.isNotEmpty && bName.isNotEmpty && !bName.contains(userName) && !userName.contains(bName)) continue;

        final rawDate = (t['date_time'] ?? t['created_at'] ?? '').toString();
        final status = (t['action'] ?? (t['status'] == 'In Use' ? 'Borrowed' : 'Returned')).toString();
        final idStr = (t['id'] ?? '').toString();

        toolList.add({
          'name': (t['tool_name'] ?? t['name'] ?? 'Tool').toString(),
          'code': idStr.isNotEmpty ? 'T-${idStr.substring(0, idStr.length < 4 ? idStr.length : 4).toUpperCase()}' : 'T-000',
          'date': rawDate.contains('T') ? rawDate.split('T')[0] : rawDate,
          'status': status,
        });
      }

      if (mounted) {
        setState(() {
          _attendanceLogs.clear();
          _attendanceLogs.addAll(attendanceList);
          _toolLogs.clear();
          _toolLogs.addAll(toolList);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _monthAbbr(int m) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return (m >= 1 && m <= 12) ? months[m - 1] : '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Activity History',
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _isLoading ? null : _fetchLogs,
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
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                tabs: const [
                  Tab(text: 'Attendance Logs'),
                  Tab(text: 'Tools History'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFA63228)))
          : LayoutBuilder(
              builder: (context, constraints) {
                final double horizontalPadding = constraints.maxWidth > 600 ? 20.0 : 12.0;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // TAB 1: ATTENDANCE LOGS
                        _attendanceLogs.isEmpty
                            ? Center(
                                child: Text('No attendance logs found.',
                                    style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13)))
                            : RefreshIndicator(
                                onRefresh: _fetchLogs,
                                color: const Color(0xFFA63228),
                                child: ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10),
                                  itemCount: _attendanceLogs.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final item = _attendanceLogs[index];
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withValues(alpha: 0.015), blurRadius: 4, offset: const Offset(0, 1)),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFA63228).withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  item['day']!,
                                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: const Color(0xFFA63228)),
                                                ),
                                                Text(
                                                  item['date']!.split(' ').length > 1 ? item['date']!.split(' ')[1].replaceAll(',', '') : '',
                                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black87),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['date']!,
                                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.black87),
                                                ),
                                                const SizedBox(height: 1),
                                                Text(
                                                  'In: ${item['in']}  •  Out: ${item['out']}',
                                                  style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade600),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                item['hours']!,
                                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.green.shade700),
                                              ),
                                              if (item['ot'] != '0 hr')
                                                Text(
                                                  'OT: ${item['ot']}',
                                                  style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFFA63228), fontWeight: FontWeight.bold),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),

                        // TAB 2: TOOLS HISTORY
                        _toolLogs.isEmpty
                            ? Center(
                                child: Text('No tool history logs found.',
                                    style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13)))
                            : RefreshIndicator(
                                onRefresh: _fetchLogs,
                                color: const Color(0xFFA63228),
                                child: ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10),
                                  itemCount: _toolLogs.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final tool = _toolLogs[index];
                                    final bool isInUse = tool['status'] == 'Borrowed' || tool['status'] == 'In Use';
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withValues(alpha: 0.015), blurRadius: 4, offset: const Offset(0, 1)),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  tool['name']!,
                                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.black87),
                                                ),
                                                const SizedBox(height: 1),
                                                Text(
                                                  '${tool['code']} • ${tool['date']}',
                                                  style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade600),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isInUse ? Colors.orange.shade50 : Colors.green.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: isInUse ? Colors.orange.shade200 : Colors.green.shade200),
                                            ),
                                            child: Text(
                                              tool['status']!,
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isInUse ? Colors.orange.shade800 : Colors.green.shade800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}