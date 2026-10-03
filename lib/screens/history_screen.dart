import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_sidebar.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, String>> _attendanceLogs = [];

  final List<Map<String, String>> _toolLogs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double horizontalPadding = constraints.maxWidth > 600 ? 20.0 : 12.0;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: TabBarView(
                controller: _tabController,
                children: [
                  // TAB 1: ATTENDANCE LOGS
                  ListView.separated(
                    physics: const BouncingScrollPhysics(),
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
                                    item['date']!.split(' ')[1].replaceAll(',', ''),
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

                  // TAB 2: TOOLS HISTORY
                  ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10),
                    itemCount: _toolLogs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final tool = _toolLogs[index];
                      final bool isInUse = tool['status'] == 'In Use';
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}