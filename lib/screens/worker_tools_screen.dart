import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/worker_app_header.dart';

class WorkerToolsScreen extends StatefulWidget {
  const WorkerToolsScreen({super.key});

  @override
  State<WorkerToolsScreen> createState() => _WorkerToolsScreenState();
}

class _WorkerToolsScreenState extends State<WorkerToolsScreen>
    with SingleTickerProviderStateMixin {
  /// Normalises any backend action / status label to the
  /// user-facing "Borrowed" or "Returned" terminology.
  String _normalizeAction(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Returned';
    final lower = raw.trim().toLowerCase();
    // All variants that mean "currently borrowed / out"
    if (lower == 'in use' ||
        lower == 'borrowed' ||
        lower == 'check-in' ||
        lower == 'checked in' ||
        lower == 'checked out' ||
        lower == 'check-out' ||
        lower == 'checkout' ||
        lower == 'checkin') {
      return 'Borrowed';
    }
    // All variants that mean "returned / back in storage"
    if (lower == 'returned' ||
        lower == 'available' ||
        lower == 'in storage' ||
        lower == 'check-out completed' ||
        lower == 'return') {
      return 'Returned';
    }
    // Fallback: keep original value
    return raw.trim();
  }

  late TabController _tabController;
  final TextEditingController _availableSearchController =
      TextEditingController();
  final TextEditingController _historySearchController =
      TextEditingController();
  bool _isLoading = false;
  String _historyStatusFilter = 'All';
  List<Map<String, dynamic>> _allTools = [];
  List<Map<String, dynamic>> _activeTools = [];
  List<Map<String, dynamic>> _historyTools = [];

  int get _allToolQuantity => _allTools.fold<int>(
    0,
    (total, tool) => total + _quantityOf(tool['quantity']),
  );

  int _quantityOf(dynamic quantity) {
    if (quantity is num) return quantity.toInt();
    return int.tryParse(quantity?.toString() ?? '') ?? 1;
  }

  String _normalizeIdentity(dynamic value) {
    return (value ?? '').toString().trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadToolsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _availableSearchController.dispose();
    _historySearchController.dispose();
    super.dispose();
  }

  String _toolType(Map<String, dynamic> tool) {
    return (tool['type'] ?? tool['category'] ?? tool['tool_type'] ?? '')
        .toString()
        .trim();
  }

  List<Map<String, dynamic>> get _filteredAvailableTools {
    final query = _availableSearchController.text.trim().toLowerCase();
    return _allTools.where((tool) {
      if (query.isEmpty) return true;
      final searchableText = [
        tool['name'],
        tool['tool_name'],
        tool['condition'],
        tool['project_name'],
        _toolType(tool),
      ].join(' ').toLowerCase();
      return searchableText.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredHistoryTools {
    final query = _historySearchController.text.trim().toLowerCase();
    return _historyTools.where((tool) {
      final status = _normalizeAction(tool['status']?.toString());
      if (_historyStatusFilter != 'All' && status != _historyStatusFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final searchableText = [
        tool['tool_name'],
        tool['name'],
        tool['borrower'],
        tool['borrower_name'],
        tool['condition'],
        status,
      ].join(' ').toLowerCase();
      return searchableText.contains(query);
    }).toList();
  }

  Future<void> _loadToolsData() async {
    setState(() => _isLoading = true);
    try {
      final user = ApiService.currentUser;
      final userIds =
          {
                user?['id'],
                user?['worker_id'],
                user?['workerId'],
                user?['employee_id'],
              }
              .where(
                (value) => value != null && value.toString().trim().isNotEmpty,
              )
              .map((value) => value.toString().trim())
              .toSet();
      final userNames = {
        user?['full_name'],
        user?['name'],
        '${user?['first_name'] ?? ''} ${user?['last_name'] ?? ''}',
      }.map(_normalizeIdentity).where((value) => value.isNotEmpty).toSet();
      bool matchesUser(String? name) {
        if (name == null || name.trim().isEmpty) return false;
        return userNames.contains(_normalizeIdentity(name));
      }

      List<dynamic> projects = [];
      try {
        projects = await ApiService.getProjects();
      } catch (_) {
        // Inventory remains available even if project names cannot be loaded.
      }
      final projectNames = {
        for (final project in projects)
          project['id']?.toString() ?? '': (project['name'] ?? 'Project')
              .toString(),
      };
      final inventory = await ApiService.getAllAssets();
      final normalizedTools = inventory.map((raw) {
        final asset = Map<String, dynamic>.from(raw as Map);
        final condition = (asset['condition'] ?? asset['type'] ?? 'Good')
            .toString();
        final projectId = asset['project_id']?.toString() ?? '';
        final assignedTo = (asset['assigned_to'] ?? '').toString().trim();
        final assetStatus = _inventoryStatus(
          asset['status']?.toString(),
          condition,
        );
        return {
          ...asset,
          'display_status': assignedTo.isNotEmpty && assetStatus == 'In Storage'
              ? 'Borrowed'
              : assetStatus,
          'condition': condition,
          'project_name':
              projectNames[projectId] ??
              asset['project_name']?.toString() ??
              'Unassigned',
          'quantity': _quantityOf(asset['quantity'] ?? asset['qty']),
        };
      }).toList();

      final groupedInventory = <String, Map<String, dynamic>>{};
      for (final tool in normalizedTools.where(
        (tool) =>
            tool['display_status'] == 'In Storage' &&
            (tool['assigned_to'] ?? '').toString().trim().isEmpty,
      )) {
        final key = [
          (tool['name'] ?? 'Unnamed Tool').toString().trim().toLowerCase(),
          _toolType(tool).toLowerCase(),
          (tool['condition'] ?? '').toString().trim().toLowerCase(),
          (tool['project_name'] ?? '').toString().trim().toLowerCase(),
          (tool['display_status'] ?? '').toString().trim().toLowerCase(),
          (tool['assigned_to'] ?? '').toString().trim().toLowerCase(),
        ].join('|');
        if (groupedInventory.containsKey(key)) {
          final existing = groupedInventory[key]!;
          existing['quantity'] =
              _quantityOf(existing['quantity']) + _quantityOf(tool['quantity']);
        } else {
          groupedInventory[key] = Map<String, dynamic>.from(tool);
        }
      }
      final allTools = groupedInventory.values.toList()
        ..sort(
          (a, b) =>
              (a['name'] ?? 'Unnamed Tool').toString().toLowerCase().compareTo(
                (b['name'] ?? 'Unnamed Tool').toString().toLowerCase(),
              ),
        );

      // 1. Build currently borrowed tools from the complete inventory
      final List<Map<String, dynamic>> borrowedAssets = [];

      for (final asset in normalizedTools) {
        final status = (asset['display_status'] ?? '').toString();
        final borrower = asset['assigned_to']?.toString();
        final assignedWorkerId =
            asset['assigned_worker_id'] ??
            asset['worker_id'] ??
            asset['assigned_to_id'];
        final belongsToUser = assignedWorkerId != null
            ? userIds.contains(assignedWorkerId.toString().trim())
            : matchesUser(borrower);
        final isOut =
            status == 'Borrowed' ||
            (borrower != null &&
                borrower.trim().isNotEmpty &&
                status != 'In Storage' &&
                status != 'Needs Repair');
        if (isOut && belongsToUser) {
          borrowedAssets.add({
            'id': asset['id']?.toString(),
            'name': (asset['name'] ?? 'Unnamed Tool').toString(),
            'tool_name': (asset['name'] ?? 'Unnamed Tool').toString(),
            'borrower': borrower ?? 'Unknown',
            'borrower_name': borrower ?? 'Unknown',
            'borrow_date': asset['borrow_at'],
            'condition': asset['condition'],
            'status': 'In Use',
            'project_id': asset['project_id']?.toString(),
          });
        }
      }

      // Group identical currently borrowed tools
      final Map<String, Map<String, dynamic>> groupedActive = {};
      for (final t in borrowedAssets) {
        final key = [
          t['name'].toString().trim().toLowerCase(),
          t['borrower'].toString().trim().toLowerCase(),
          t['condition'].toString().trim().toLowerCase(),
        ].join('|');
        final existing = groupedActive.putIfAbsent(
          key,
          () => {...t, 'quantity': 0},
        );
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
        final bName =
            (rec['borrower_name'] ??
                    rec['borrower'] ??
                    rec['worker_name'] ??
                    '')
                .toString();
        final rawWorkerId =
            rec['worker_id'] ?? rec['workerId'] ?? rec['employee_id'];
        final recordWorkerId = rawWorkerId?.toString().trim() ?? '';
        final matchesWorker = recordWorkerId.isNotEmpty
            ? userIds.contains(recordWorkerId)
            : userNames.contains(_normalizeIdentity(bName));
        if (!matchesWorker) continue;

        final rawAction = (rec['action'] ?? rec['status'] ?? 'Returned')
            .toString();
        historyList.add({
          'name': (rec['tool_name'] ?? rec['name'] ?? 'Tool').toString(),
          'tool_name': (rec['tool_name'] ?? rec['name'] ?? 'Tool').toString(),
          'borrower': bName,
          'borrower_name': bName,
          'borrow_date': rec['date_time'] ?? rec['created_at'],
          'status': _normalizeAction(rawAction),
          'condition': (rec['condition_status'] ?? rec['condition'] ?? 'Good')
              .toString(),
          'quantity': rec['quantity'] ?? 1,
        });
      }

      if (mounted) {
        setState(() {
          _allTools = allTools;
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
        final dt = DateTime.fromMillisecondsSinceEpoch(
          (secs * 1000).toInt(),
        ).toLocal();
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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} $h:$m $ampm';
  }

  String _inventoryStatus(String? rawStatus, String condition) {
    final status = (rawStatus ?? '').trim().toLowerCase();
    if (status == 'in use' || status == 'checked out' || status == 'borrowed') {
      return 'Borrowed';
    }

    final normalizedCondition = condition.toLowerCase();
    if (status == 'maintenance' ||
        status == 'needs repair' ||
        status == 'under repair' ||
        normalizedCondition.contains('repair') ||
        normalizedCondition.contains('broken') ||
        normalizedCondition.contains('damag') ||
        normalizedCondition.contains('maint')) {
      return 'Needs Repair';
    }
    return 'In Storage';
  }

  @override
  Widget build(BuildContext context) {
    final position = (ApiService.currentUser?['position'] ?? '')
        .toString()
        .toLowerCase();
    final isCustodian =
        position.contains('tool') ||
        position.contains('admin') ||
        ApiService.currentUserRole?.toLowerCase() == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      appBar: WorkerAppHeader(
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
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                tabs: [
                  Tab(text: 'Tools ($_allToolQuantity)'),
                  Tab(text: 'Accountability (${_activeTools.length})'),
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
              label: Text(
                'Manage All Tools',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            )
          : null,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFA63228)),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final double hp = constraints.maxWidth > 600 ? 20.0 : 12.0;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // --- TAB 1: AVAILABLE TOOLS ---
                        RefreshIndicator(
                          color: const Color(0xFFA63228),
                          onRefresh: _loadToolsData,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: EdgeInsets.fromLTRB(hp, 10, hp, 80),
                            children: [
                              TextField(
                                controller: _availableSearchController,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'Search available tools...',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon:
                                      _availableSearchController.text.isEmpty
                                      ? null
                                      : IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            _availableSearchController.clear();
                                            setState(() {});
                                          },
                                        ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                style: GoogleFonts.inter(fontSize: 12),
                              ),
                              const SizedBox(height: 10),
                              const SizedBox(height: 10),
                              if (_allTools.isEmpty)
                                _buildEmpty(
                                  Icons.build_circle_outlined,
                                  'No available tools',
                                  'There are no tools currently available to borrow.',
                                )
                              else if (_filteredAvailableTools.isEmpty)
                                _buildEmpty(
                                  Icons.search_off_rounded,
                                  'No matching tools',
                                  'Try a different search.',
                                )
                              else
                                ..._filteredAvailableTools.expand(
                                  (tool) => [
                                    _buildInventoryCard(tool),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                            ],
                          ),
                        ),

                        // --- TAB 2: CURRENTLY BORROWED ---
                        RefreshIndicator(
                          color: const Color(0xFFA63228),
                          onRefresh: _loadToolsData,
                          child: _activeTools.isEmpty
                              ? _buildEmpty(
                                  Icons.handyman_outlined,
                                  'No tools currently issued',
                                  'Tools issued to you will appear here.',
                                )
                              : ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  padding: EdgeInsets.fromLTRB(hp, 10, hp, 80),
                                  itemCount: _activeTools.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (ctx, i) => _buildToolCard(
                                    _activeTools[i],
                                    isCurrentlyBorrowed: true,
                                  ),
                                ),
                        ),

                        // --- TAB 3: BORROW HISTORY ---
                        _buildHistoryTab(hp),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildHistoryTab(double horizontalPadding) {
    final filteredTools = _filteredHistoryTools;
    return RefreshIndicator(
      color: const Color(0xFFA63228),
      onRefresh: _loadToolsData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          10,
          horizontalPadding,
          80,
        ),
        children: [
          TextField(
            controller: _historySearchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search tool, borrower, or condition...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _historySearchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _historySearchController.clear();
                        setState(() {});
                      },
                    ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            style: GoogleFonts.inter(fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: ['All', 'Borrowed', 'Returned'].map((status) {
              final selected = _historyStatusFilter == status;
              return ChoiceChip(
                label: Text(status),
                selected: selected,
                onSelected: (_) => setState(() {
                  _historyStatusFilter = status;
                }),
                selectedColor: const Color(0xFFA63228).withValues(alpha: 0.12),
                labelStyle: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? const Color(0xFFA63228)
                      : Colors.grey.shade700,
                ),
                side: BorderSide(
                  color: selected
                      ? const Color(0xFFA63228)
                      : Colors.grey.shade300,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          if (_historyTools.isEmpty)
            _buildHistoryEmpty(
              Icons.history_rounded,
              'No tool history yet',
              'Past tool records will appear here.',
            )
          else if (filteredTools.isEmpty)
            _buildHistoryEmpty(
              Icons.search_off_rounded,
              'No matching records',
              'Try changing your search or status filter.',
            )
          else
            ...filteredTools.expand(
              (tool) => [
                _buildToolCard(tool, isCurrentlyBorrowed: false),
                const SizedBox(height: 8),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryEmpty(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Column(
        children: [
          Icon(icon, size: 32, color: const Color(0xFFA63228)),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> tool) {
    final name = (tool['name'] ?? 'Unnamed Tool').toString();
    final status = (tool['display_status'] ?? 'In Storage').toString();
    final isBorrowed = status == 'Borrowed';
    final needsRepair = status == 'Needs Repair';
    final statusColor = isBorrowed
        ? Colors.orange.shade800
        : needsRepair
        ? Colors.red.shade800
        : Colors.green.shade800;
    final statusBackground = isBorrowed
        ? Colors.orange.shade50
        : needsRepair
        ? Colors.red.shade50
        : Colors.green.shade50;
    final statusBorder = isBorrowed
        ? Colors.orange.shade200
        : needsRepair
        ? Colors.red.shade200
        : Colors.green.shade200;
    final assignedTo = (tool['assigned_to'] ?? '').toString().trim();

    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFA63228).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.build_circle_outlined,
              size: 20,
              color: Color(0xFFA63228),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Qty: ${tool['quantity']} • Cond: ${tool['condition']}',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (assignedTo.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Assigned: $assignedTo',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusBackground,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: statusBorder),
            ),
            child: Text(
              status,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(
    Map<String, dynamic> tool, {
    required bool isCurrentlyBorrowed,
  }) {
    final rawStatus =
        tool['status']?.toString() ??
        (isCurrentlyBorrowed ? 'Borrowed' : 'Returned');
    final status = _normalizeAction(rawStatus);
    final isBorrowed = isCurrentlyBorrowed || status == 'Borrowed';
    final isReturned = !isCurrentlyBorrowed && status == 'Returned';

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

    final borrower = (tool['borrower'] ?? tool['borrower_name'] ?? '')
        .toString();

    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFA63228).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.build_circle_outlined,
              size: 20,
              color: Color(0xFFA63228),
            ),
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
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Qty: ${tool['quantity'] ?? 1} • Cond: ${tool['condition'] ?? 'Good'} • ${_formatDate(tool['borrow_date'] ?? tool['date_time'] ?? tool['created_at'])}',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (borrower.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Borrower: $borrower',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
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
              isBorrowed ? 'Borrowed' : status,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: statusText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(IconData icon, String title, String subtitle) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
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
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
