import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class WorkerToolsScreen extends StatefulWidget {
  const WorkerToolsScreen({super.key});

  @override
  State<WorkerToolsScreen> createState() => _WorkerToolsScreenState();
}

class _WorkerToolsScreenState extends State<WorkerToolsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<Map<String, dynamic>> _borrowHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBorrowHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBorrowHistory() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getBorrowHistory(1);
      final userId = ApiService.currentUser?['id']?.toString();
      if (mounted) {
        setState(() {
          _borrowHistory = List<Map<String, dynamic>>.from(data)
              .where((r) =>
                  r['worker_id']?.toString() == userId || userId == null)
              .toList();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    // Separate active vs returned
    final activeTools = _borrowHistory
        .where((t) =>
            (t['status']?.toString().toLowerCase() ?? '') == 'borrowed' ||
            (t['status']?.toString().toLowerCase() ?? '') == 'in use')
        .toList();
    final historyTools = _borrowHistory
        .where((t) =>
            (t['status']?.toString().toLowerCase() ?? '') != 'borrowed' &&
            (t['status']?.toString().toLowerCase() ?? '') != 'in use')
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Tools',
          style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87),
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
                labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.bold, fontSize: 12),
                tabs: [
                  Tab(text: 'Currently Borrowed (${activeTools.length})'),
                  const Tab(text: 'History'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFA63228)))
          : LayoutBuilder(
              builder: (context, constraints) {
                final double hp = constraints.maxWidth > 600 ? 20.0 : 12.0;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // --- TAB 1: CURRENTLY BORROWED ---
                        RefreshIndicator(
                          color: const Color(0xFFA63228),
                          onRefresh: _loadBorrowHistory,
                          child: activeTools.isEmpty
                              ? _buildEmpty(
                                  Icons.handyman_outlined,
                                  'No tools currently borrowed',
                                  'Tools issued to you will appear here.',
                                )
                              : ListView.separated(
                                  physics: const BouncingScrollPhysics(),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: hp, vertical: 10),
                                  itemCount: activeTools.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (ctx, i) =>
                                      _buildToolCard(activeTools[i]),
                                ),
                        ),

                        // --- TAB 2: BORROW HISTORY ---
                        RefreshIndicator(
                          color: const Color(0xFFA63228),
                          onRefresh: _loadBorrowHistory,
                          child: historyTools.isEmpty
                              ? _buildEmpty(
                                  Icons.history_rounded,
                                  'No tool history yet',
                                  'Past tool records will appear here.',
                                )
                              : ListView.separated(
                                  physics: const BouncingScrollPhysics(),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: hp, vertical: 10),
                                  itemCount: historyTools.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (ctx, i) =>
                                      _buildToolCard(historyTools[i]),
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

  Widget _buildToolCard(Map<String, dynamic> tool) {
    final status = tool['status']?.toString() ?? 'Unknown';
    final isBorrowed =
        status.toLowerCase() == 'borrowed' || status.toLowerCase() == 'in use';
    final isReturned = status.toLowerCase() == 'returned';

    Color statusBg = isReturned
        ? Colors.green.shade50
        : isBorrowed
            ? Colors.orange.shade50
            : Colors.grey.shade100;
    Color statusBorder = isReturned
        ? Colors.green.shade200
        : isBorrowed
            ? Colors.orange.shade200
            : Colors.grey.shade300;
    Color statusText = isReturned
        ? Colors.green.shade800
        : isBorrowed
            ? Colors.orange.shade800
            : Colors.grey.shade700;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.015),
              blurRadius: 4,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFA63228).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.build_circle_outlined,
                size: 20, color: Color(0xFFA63228)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tool['tool_name']?.toString() ??
                      tool['name']?.toString() ??
                      'Unknown Tool',
                  style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                const SizedBox(height: 2),
                Text(
                  '${tool['tool_code']?.toString() ?? tool['code']?.toString() ?? '—'} • ${_formatDate(tool['borrow_date']?.toString() ?? tool['date']?.toString())}',
                  style: GoogleFonts.inter(
                      fontSize: 10.5, color: Colors.grey.shade600),
                ),
                if (tool['return_date'] != null && !isBorrowed)
                  Text(
                    'Returned: ${_formatDate(tool['return_date'].toString())}',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: Colors.green.shade700),
                  ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: statusBorder),
            ),
            child: Text(
              status,
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusText),
            ),
          ),
        ],
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
                child: Icon(icon, size: 32, color: const Color(0xFFA63228)),
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
