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
  List<Map<String, dynamic>> _activeTools = [];
  List<Map<String, dynamic>> _historyTools = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadToolsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadToolsData() async {
    setState(() => _isLoading = true);
    try {
      final user = ApiService.currentUser;
      final userId = user?['id']?.toString();
      final userName = (user?['full_name'] ?? user?['name'] ?? '${user?['first_name'] ?? ''} ${user?['last_name'] ?? ''}').toString().trim().toLowerCase();
      final firstName = (user?['first_name'] ?? '').toString().trim().toLowerCase();
      final lastName = (user?['last_name'] ?? '').toString().trim().toLowerCase();
      final position = (user?['position'] ?? '').toString().toLowerCase();
      final isCustodian = position.contains('tool') || position.contains('admin') || ApiService.currentUserRole?.toLowerCase() == 'admin';

      bool matchesUser(String? name) {
        if (name == null || name.trim().isEmpty) return false;
        if (isCustodian) return true;
        if (userName.isEmpty) return true;
        final n = name.trim().toLowerCase();
        if (n == userName || n.contains(userName) || userName.contains(n)) return true;
        if (firstName.isNotEmpty && n.contains(firstName)) return true;
        if (lastName.isNotEmpty && n.contains(lastName)) return true;
        return false;
      }

      // 1. Fetch currently borrowed tools from Assets across all projects
      final projects = await ApiService.getProjects();
      final List<Map<String, dynamic>> borrowedAssets = [];

      await Future.wait(projects.map((p) async {
        final projectId = p['id']?.toString();
        if (projectId == null) return;
        List<dynamic> assets = [];
        try {
          assets = await ApiService.getProjectAssets(projectId);
        } catch (_) {
          return;
        }
        for (final a in assets) {
          final asset = Map<String, dynamic>.from(a as Map);
          final status = (asset['status'] ?? '').toString();
          final borrower = asset['assigned_to']?.toString();
          final isOut = status == 'In Use' ||
              status == 'Checked Out' ||
              (borrower != null && borrower.trim().isNotEmpty && status != 'Available' && status != 'Needs Repair');
          if (isOut && matchesUser(borrower)) {
            borrowedAssets.add({
              'id': asset['id']?.toString(),
              'name': (asset['name'] ?? 'Unnamed Tool').toString(),
              'tool_name': (asset['name'] ?? 'Unnamed Tool').toString(),
              'borrower': borrower ?? 'Unknown',
              'borrower_name': borrower ?? 'Unknown',
              'borrow_date': asset['borrow_at'],
              'condition': (asset['condition'] ?? asset['type'] ?? 'Good').toString(),
              'status': 'In Use',
              'project_id': projectId,
            });
          }
        }
      }));

      // Group identical currently borrowed tools
      final Map<String, Map<String, dynamic>> groupedActive = {};
      for (final t in borrowedAssets) {
        final key = [
          t['name'].toString().trim().toLowerCase(),
          t['borrower'].toString().trim().toLowerCase(),
          t['condition'].toString().trim().toLowerCase(),
        ].join('|');
        final existing = groupedActive.putIfAbsent(key, () => {
          ...t,
          'quantity': 0,
        });
        existing['quantity'] = (existing['quantity'] as int) + 1;
      }

      // 2. Fetch history logs from Borrow History
      List<dynamic> historyData = [];
      try {
        historyData = await ApiService.getBorrowHistory('ALL');
      } catch (_) {}

      final List<Map<String, dynamic>> historyList = [];
      for (final h in historyData) {
        final rec = Map<String, dynamic>.from(h as Map);
        final bName = (rec['borrower_name'] ?? rec['borrower'] ?? '').toString();
        if (matchesUser(bName)) {
          historyList.add({
            'name': (rec['tool_name'] ?? rec['name'] ?? 'Tool').toString(),
            'tool_name': (rec['tool_name'] ?? rec['name'] ?? 'Tool').toString(),
            'borrower': bName,
            'borrower_name': bName,
            'borrow_date': rec['date_time'] ?? rec['created_at'],
            'status': (rec['action'] ?? rec['status'] ?? 'Returned').toString(),
            'condition': (rec['condition_status'] ?? rec['condition'] ?? 'Good').toString(),
            'quantity': rec['quantity'] ?? 1,
          });
        }
      }

      if (mounted) {
        setState(() {
          _activeTools = groupedActive.values.toList();
          _historyTools = historyList;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '—';
    if (raw is Map) {
      final secs = raw['_seconds'] ?? raw['seconds'];
      if (secs is num) {
        final dt = DateTime.fromMillisecondsSinceEpoch((secs * 1000).toInt()).toLocal();
        return _formatDateTime(dt);
      }
    }
    final str = raw.toString();
    final dt = DateTime.tryParse(str)?.toLocal();
    if (dt != null) {
      return _formatDateTime(dt);
    }
    return str;
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} $h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final position = (ApiService.currentUser?['position'] ?? '').toString().toLowerCase();
    final isCustodian = position.contains('tool') || position.contains('admin') || ApiService.currentUserRole?.toLowerCase() == 'admin';

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
                  Tab(text: 'Currently Borrowed (${_activeTools.length})'),
                  const Tab(text: 'History'),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: isCustodian
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.pushNamed(context, '/tools_monitoring');
                _loadToolsData();
              },
              backgroundColor: const Color(0xFFA63228),
              icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
              label: Text('Manage All Tools',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold, color: Colors.white)),
            )
          : null,
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
                          onRefresh: _loadToolsData,
                          child: _activeTools.isEmpty
                              ? _buildEmpty(
                                  Icons.handyman_outlined,
                                  'No tools currently borrowed',
                                  'Tools issued to you will appear here.',
                                )
                              : ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(
                                      parent: BouncingScrollPhysics()),
                                  padding: EdgeInsets.fromLTRB(hp, 10, hp, 80),
                                  itemCount: _activeTools.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (ctx, i) =>
                                      _buildToolCard(_activeTools[i], isCurrentlyBorrowed: true),
                                ),
                        ),

                        // --- TAB 2: BORROW HISTORY ---
                        RefreshIndicator(
                          color: const Color(0xFFA63228),
                          onRefresh: _loadToolsData,
                          child: _historyTools.isEmpty
                              ? _buildEmpty(
                                  Icons.history_rounded,
                                  'No tool history yet',
                                  'Past tool records will appear here.',
                                )
                              : ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(
                                      parent: BouncingScrollPhysics()),
                                  padding: EdgeInsets.fromLTRB(hp, 10, hp, 80),
                                  itemCount: _historyTools.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (ctx, i) =>
                                      _buildToolCard(_historyTools[i], isCurrentlyBorrowed: false),
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

  Widget _buildToolCard(Map<String, dynamic> tool, {required bool isCurrentlyBorrowed}) {
    final status = tool['status']?.toString() ?? (isCurrentlyBorrowed ? 'In Use' : 'Returned');
    final isBorrowed = isCurrentlyBorrowed ||
        status.toLowerCase() == 'borrowed' ||
        status.toLowerCase() == 'in use';
    final isReturned = !isCurrentlyBorrowed && status.toLowerCase() == 'returned';

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

    final borrower = (tool['borrower'] ?? tool['borrower_name'] ?? '').toString();

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
                  'Qty: ${tool['quantity'] ?? 1} • Cond: ${tool['condition'] ?? 'Good'} • ${_formatDate(tool['borrow_date'] ?? tool['date_time'] ?? tool['created_at'])}',
                  style: GoogleFonts.inter(
                      fontSize: 10.5, color: Colors.grey.shade600),
                ),
                if (borrower.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Borrower: $borrower',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: statusBorder),
            ),
            child: Text(
              isBorrowed ? 'In Use' : status,
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
