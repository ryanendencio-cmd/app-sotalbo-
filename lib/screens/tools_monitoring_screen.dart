import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/admin_mobile_chrome.dart';
import '../widgets/paginated_list_view.dart';

class ToolsMonitoringScreen extends StatefulWidget {
  final Map<String, String>? initialUserData;
  final bool hideAppBar;

  const ToolsMonitoringScreen({
    super.key,
    this.initialUserData,
    this.hideAppBar = false,
  });

  @override
  State<ToolsMonitoringScreen> createState() => _ToolsMonitoringScreenState();
}

class _ToolsMonitoringScreenState extends State<ToolsMonitoringScreen> {
  int _currentNavIndex = 0;
  final String _selectedCategory = 'All';
  String _selectedStatusFilter = 'All';

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _toolsData = [];
  List<Map<String, dynamic>> _workers = [];
  List<Map<String, dynamic>> _borrowHistory = [];
  bool _isLoading = true;
  bool _isHistoryLoading = true;
  String? _loadError;
  String? _historyLoadError;

  @override
  void initState() {
    super.initState();
    _fetchTools();
    _fetchBorrowHistory();
    _fetchWorkers();
  }

  String _workerName(Map<String, dynamic> w) {
    final full = (w['full_name'] ?? w['name'])?.toString().trim() ?? '';
    if (full.isNotEmpty) return full;
    return '${w['first_name'] ?? ''} ${w['last_name'] ?? ''}'.trim();
  }

  Future<void> _fetchWorkers() async {
    try {
      final list = await ApiService.getWorkers();
      if (!mounted) return;
      setState(() {
        _workers = list
            .map((w) => Map<String, dynamic>.from(w as Map))
            .where((w) => _workerName(w).isNotEmpty)
            .toList();
      });
    } catch (_) {
      // Autocomplete is optional; manual typing still works.
    }
  }

  // ── Firestore (via backend API) integration ──

  String _uiStatus(String? backendStatus, String? condition) {
    if (backendStatus == 'In Use' ||
        backendStatus == 'Checked Out' ||
        backendStatus == 'Borrowed') {
      return 'Borrowed';
    }
    final cond = (condition ?? '').toLowerCase();
    final isRepair =
        backendStatus == 'Maintenance' ||
        backendStatus == 'Needs Repair' ||
        backendStatus == 'Under Repair' ||
        cond.contains('repair') ||
        cond.contains('broken') ||
        cond.contains('damag') ||
        cond.contains('maint');
    if (isRepair) {
      return 'Needs Repair';
    }
    return 'In Storage';
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v)?.toLocal();
    if (v is Map) {
      final secs = v['_seconds'] ?? v['seconds'];
      if (secs is num) {
        return DateTime.fromMillisecondsSinceEpoch((secs * 1000).toInt());
      }
    }
    return null;
  }

  TimeOfDay? _parseTimeOfDay(dynamic value) {
    if (value is! String) return null;
    final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(value);
    if (match == null) return null;
    return TimeOfDay(
      hour: int.parse(match.group(1)!),
      minute: int.parse(match.group(2)!),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '—';
    final now = DateTime.now();
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    final time = '$h:$m $ampm';
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today $time';
    if (diff == 1) return 'Yesterday $time';
    return '${dt.month}/${dt.day}/${dt.year} $time';
  }

  bool _isOverdue(DateTime? dueDate, TimeOfDay? dueTime) {
    if (dueDate == null) return false;
    final now = DateTime.now();
    if (dueTime != null) {
      return now.isAfter(
        DateTime(
          dueDate.year,
          dueDate.month,
          dueDate.day,
          dueTime.hour,
          dueTime.minute,
        ),
      );
    }
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return today.isAfter(dueDay);
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _fetchTools() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      List<dynamic> projectList = [];
      try {
        projectList = await ApiService.getProjects();
      } catch (_) {
        projectList = [];
      }
      final Map<String, String> projectNames = {
        for (final project in projectList)
          (project['id']?.toString() ?? '').trim():
              (project['name'] ?? 'Project').toString(),
      }..removeWhere((key, value) => key.isEmpty);

      final List<dynamic> assets = await ApiService.getAllAssets();
      final List<Map<String, dynamic>> tools = [];

      for (final a in assets) {
        final asset = Map<String, dynamic>.from(a as Map);
        final projectId = (asset['project_id'] ?? 'all').toString();
        final projectName =
            projectNames[projectId] ??
            (asset['project_name'] ?? 'Project').toString();
        final id = asset['id'].toString();
        final condition = (asset['condition'] ?? asset['type'] ?? 'Good')
            .toString();
        final rawStatus = asset['status']?.toString();
        final status = _uiStatus(rawStatus, condition);
        final borrowAt = _parseDate(asset['borrow_at']);
        final expectedReturnDate = _parseDate(asset['expected_return_date']);
        final expectedReturnTime = _parseTimeOfDay(
          asset['expected_return_time'],
        );
        final borrower = asset['assigned_to']?.toString();
        final isOut = status == 'Borrowed' || status == 'Checked Out';
        final dynamic rawQty = asset['quantity'] ?? asset['qty'];
        final int quantity = rawQty != null
            ? (int.tryParse(rawQty.toString()) ?? 1)
            : 1;
        tools.add({
          'id': id,
          'projectId': projectId,
          'projectName': projectName,
          'name': (asset['name'] ?? 'Unnamed Tool').toString(),
          'category': projectName,
          'quantity': quantity,
          'status': status,
          'condition': condition,
          'borrower': isOut && borrower != null && borrower.isNotEmpty
              ? borrower
              : null,
          'checkoutTime': isOut ? _formatTime(borrowAt) : null,
          'borrowTime': isOut ? _formatTime(borrowAt) : null,
          'expectedReturnDate': expectedReturnDate,
          'expectedReturnTime': expectedReturnTime,
          'isOverdue':
              isOut && _isOverdue(expectedReturnDate, expectedReturnTime),
        });
      }

      tools.sort(
        (a, b) => a['name'].toString().toLowerCase().compareTo(
          b['name'].toString().toLowerCase(),
        ),
      );

      if (!mounted) return;
      setState(() {
        _toolsData = tools;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Unable to load tools from the database.\n$e';
      });
    }
  }

  Future<void> _fetchBorrowHistory() async {
    if (mounted) {
      setState(() {
        _isHistoryLoading = true;
        _historyLoadError = null;
      });
    }
    try {
      final records = await ApiService.getBorrowHistory('ALL');
      final history = records
          .map((record) => Map<String, dynamic>.from(record as Map))
          .toList();
      history.sort((a, b) {
        final dateA = _parseDate(a['date_time'] ?? a['created_at']);
        final dateB = _parseDate(b['date_time'] ?? b['created_at']);
        if (dateA == null) return dateB == null ? 0 : 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });
      if (!mounted) return;
      setState(() {
        _borrowHistory = history;
        _isHistoryLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historyLoadError = 'Unable to load borrowed history.\n$e';
        _isHistoryLoading = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_fetchTools(), _fetchBorrowHistory()]);
  }

  Future<bool> _saveAsset(
    Map<String, dynamic> tool, {
    required String status,
    required String condition,
    String? assignedTo,
    String? borrowAt,
    String? expectedReturnDate,
    String? expectedReturnTime,
  }) async {
    try {
      await ApiService.updateAssetDoc(tool['id'], {
        'name': tool['name'],
        'condition': condition,
        'status': status,
        'assigned_to': assignedTo,
        'borrow_at': borrowAt,
        'expected_return_date': expectedReturnDate,
        'expected_return_time': expectedReturnTime,
      });
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update tool: $e')));
      }
      return false;
    }
  }

  Future<void> _logHistory(
    Map<String, dynamic> tool,
    String borrower,
    String action,
    String condition,
  ) async {
    try {
      await ApiService.logBorrowHistory({
        'project_id': tool['projectId'],
        'tool_name': tool['name'],
        'borrower_name': borrower,
        'quantity': 1,
        'action': action,
        'condition_status': condition,
        'date_time': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // History logging is best-effort; asset status is already saved.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredTools {
    return _toolsData.where((t) {
      final matchesCat =
          _selectedCategory == 'All' || t['category'] == _selectedCategory;
      final cond = t['condition'].toString().toLowerCase();
      final isToolNeedsRepair =
          t['status'] == 'Needs Repair' ||
          cond.contains('repair') ||
          cond.contains('broken') ||
          cond.contains('damag') ||
          cond.contains('maint');

      bool matchesStatus;
      if (_selectedStatusFilter == 'All') {
        matchesStatus = true;
      } else if (_selectedStatusFilter == 'Overdue') {
        matchesStatus = t['isOverdue'] == true;
      } else if (_selectedStatusFilter == 'Needs Repair') {
        matchesStatus = isToolNeedsRepair;
      } else if (_selectedStatusFilter == 'Borrowed') {
        matchesStatus =
            t['status'] == 'Borrowed' || t['status'] == 'Checked Out';
      } else {
        matchesStatus = t['status'] == _selectedStatusFilter;
      }

      final query = _searchController.text.trim().toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          t['name'].toString().toLowerCase().contains(query) ||
          t['condition'].toString().toLowerCase().contains(query) ||
          t['status'].toString().toLowerCase().contains(query) ||
          (t['borrower'] != null &&
              t['borrower'].toString().toLowerCase().contains(query));
      return matchesCat && matchesStatus && matchesQuery;
    }).toList();
  }

  /// Merges tools that have identical details, including return deadlines.
  /// The merged entry keeps the underlying records in `items` and exposes
  /// their count as `quantity`.
  List<Map<String, dynamic>> _groupTools(List<Map<String, dynamic>> tools) {
    final Map<String, Map<String, dynamic>> groups = {};
    for (final t in tools) {
      final key = [
        t['name'].toString().trim().toLowerCase(),
        t['status'],
        t['condition'].toString().trim().toLowerCase(),
        t['borrower'] ?? '',
        t['borrowTime'] ?? t['checkoutTime'] ?? '',
        t['expectedReturnDate'] ?? '',
        t['expectedReturnTime']?.toString() ?? '',
        t['isOverdue'] == true,
      ].join('|');
      final group = groups.putIfAbsent(
        key,
        () => <String, dynamic>{
          ...t,
          'groupKey': key,
          'items': <Map<String, dynamic>>[],
        },
      );
      final items = group['items'] as List<Map<String, dynamic>>;
      items.add(t);
      group['quantity'] = items.length;
    }
    return groups.values.toList();
  }

  List<Map<String, dynamic>> get _displayTools => _groupTools(_filteredTools);

  List<Map<String, dynamic>> get _filteredBorrowHistory {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _borrowHistory;
    return _borrowHistory.where((record) {
      final searchableValues = [
        record['tool_name'],
        record['name'],
        record['borrower_name'],
        record['borrower'],
        record['condition_status'],
        record['condition'],
        record['action'],
        record['status'],
      ];
      return searchableValues.any(
        (value) => value?.toString().toLowerCase().contains(query) ?? false,
      );
    }).toList();
  }

  Widget _buildBorrowHistoryView(double screenWidth) {
    if (_isHistoryLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFA63228)),
      );
    }

    if (_historyLoadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: screenWidth * 0.1,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              Text(
                _historyLoadError!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: screenWidth * 0.028,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final history = _filteredBorrowHistory;
    return RefreshIndicator(
      color: const Color(0xFFA63228),
      onRefresh: _fetchBorrowHistory,
      child: history.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: screenWidth * 0.45),
                Icon(
                  _borrowHistory.isEmpty
                      ? Icons.history_outlined
                      : Icons.search_off_rounded,
                  size: screenWidth * 0.1,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 8),
                Text(
                  _borrowHistory.isEmpty
                      ? 'No borrowed history available.'
                      : 'No history records match your search.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: screenWidth * 0.03,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            )
          : PaginatedListView.separated(
              padding: EdgeInsets.fromLTRB(
                screenWidth * 0.03,
                6,
                screenWidth * 0.03,
                80,
              ),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final record = history[index];
                final action =
                    (record['action'] ?? record['status'] ?? 'Borrowed')
                        .toString();
                final isReturned = action.toLowerCase().contains('return');
                final statusColor = isReturned
                    ? Colors.green.shade800
                    : Colors.orange.shade800;
                final statusBackground = isReturned
                    ? Colors.green.shade50
                    : Colors.orange.shade50;
                final statusBorder = isReturned
                    ? Colors.green.shade200
                    : Colors.orange.shade200;
                final toolName =
                    (record['tool_name'] ?? record['name'] ?? 'Tool')
                        .toString();
                final borrower =
                    (record['borrower_name'] ?? record['borrower'] ?? 'Unknown')
                        .toString();
                final condition =
                    (record['condition_status'] ??
                            record['condition'] ??
                            'Good')
                        .toString();
                final quantity = record['quantity'] ?? 1;
                final dateTime = _parseDate(
                  record['date_time'] ?? record['created_at'],
                );

                return Container(
                  padding: EdgeInsets.all(screenWidth * 0.03),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFA63228,
                          ).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.construction_outlined,
                          color: Color(0xFFA63228),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              toolName,
                              style: GoogleFonts.inter(
                                fontSize: screenWidth * 0.032,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Qty: $quantity • Cond: $condition • ${_formatTime(dateTime)}',
                              style: GoogleFonts.inter(
                                fontSize: screenWidth * 0.026,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Worker: $borrower',
                              style: GoogleFonts.inter(
                                fontSize: screenWidth * 0.028,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusBorder),
                        ),
                        child: Text(
                          isReturned ? 'Returned' : 'Borrowed',
                          style: GoogleFonts.inter(
                            fontSize: screenWidth * 0.024,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildQtyStepper({
    required int value,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    final canDecrease = value > 1;
    final canIncrease = value < max;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: canDecrease ? () => onChanged(value - 1) : null,
          child: Icon(
            Icons.remove_circle_outline,
            size: 22,
            color: canDecrease ? Colors.black87 : Colors.grey.shade400,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '$value',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
        InkWell(
          onTap: canIncrease ? () => onChanged(value + 1) : null,
          child: Icon(
            Icons.add_circle_outline,
            size: 22,
            color: canIncrease ? Colors.black87 : Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  void _returnTool(Map<String, dynamic> tool) {
    String selectedCondition = 'Good';
    final int maxQty = (tool['items'] as List?)?.length ?? 1;
    int returnQty = maxQty;

    showDialog(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Return Equipment',
            style: GoogleFonts.inter(
              fontSize: screenWidth * 0.04,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: StatefulBuilder(
            builder: (context, setDialogState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Returning: ${tool['name']}',
                  style: GoogleFonts.inter(
                    fontSize: screenWidth * 0.032,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Borrower: ${tool['borrower'] ?? "Unknown"}',
                  style: GoogleFonts.inter(
                    fontSize: screenWidth * 0.028,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (maxQty > 1) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quantity to return (of $maxQty):',
                        style: GoogleFonts.inter(
                          fontSize: screenWidth * 0.03,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _buildQtyStepper(
                        value: returnQty,
                        max: maxQty,
                        onChanged: (v) => setDialogState(() => returnQty = v),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Equipment Condition:',
                  style: GoogleFonts.inter(
                    fontSize: screenWidth * 0.03,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedCondition,
                  isDense: true,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'Good',
                      child: Text(
                        'Good / Working',
                        style: GoogleFonts.inter(fontSize: screenWidth * 0.03),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Broken / Damaged',
                      child: Text(
                        'Broken / Damaged',
                        style: GoogleFonts.inter(fontSize: screenWidth * 0.03),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Needs Repair',
                      child: Text(
                        'Needs Repair',
                        style: GoogleFonts.inter(fontSize: screenWidth * 0.03),
                      ),
                    ),
                  ],
                  onChanged: (val) =>
                      setDialogState(() => selectedCondition = val ?? 'Good'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: Colors.grey.shade600,
                  fontSize: screenWidth * 0.03,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA63228),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                final good = selectedCondition == 'Good';
                final borrower = (tool['borrower'] ?? 'Unknown').toString();
                final items = ((tool['items'] as List?) ?? [tool])
                    .cast<Map<String, dynamic>>()
                    .take(returnQty)
                    .toList();
                Navigator.pop(context);
                int returned = 0;
                for (final item in items) {
                  final ok = await _saveAsset(
                    item,
                    status: good ? 'Available' : 'Needs Repair',
                    condition: selectedCondition,
                    assignedTo: null,
                    borrowAt: null,
                    expectedReturnDate: null,
                    expectedReturnTime: null,
                  );
                  if (!ok) continue;
                  returned++;
                  await _logHistory(
                    item,
                    borrower,
                    'Returned',
                    selectedCondition,
                  );
                }
                await _refreshAll();
                if (!mounted || returned == 0) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      returned > 1
                          ? '$returned ${tool['name']} successfully returned and stored.'
                          : '${tool['name']} successfully returned and stored.',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                    backgroundColor: Colors.black87,
                  ),
                );
              },
              child: Text(
                'Confirm Return',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: screenWidth * 0.03,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showBorrowDialog() {
    final available = _groupTools(
      _toolsData.where((t) => t['status'] == 'In Storage').toList(),
    );
    final Map<String, int> selectedQty = {};
    String toolSearchQuery = '';
    DateTime? expectedReturnDate;
    TimeOfDay? expectedReturnTime;

    TextEditingController? workerCtrl;

    showDialog(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: screenWidth > 500 ? 400 : screenWidth * 0.9,
              ),
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
                          Text(
                            'Borrow Tool',
                            style: GoogleFonts.inter(
                              fontSize: screenWidth * 0.04,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                          child: Text(
                            'No tools available in storage.',
                            style: GoogleFonts.inter(
                              fontSize: screenWidth * 0.03,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        )
                      else ...[
                        TextField(
                          onChanged: (value) => setDialogState(
                            () => toolSearchQuery = value.trim().toLowerCase(),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search tools...',
                            prefixIcon: const Icon(Icons.search),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          style: GoogleFonts.inter(
                            fontSize: screenWidth * 0.03,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'If no time is set, the tool is due by the end of that date.',
                            style: GoogleFonts.inter(
                              fontSize: screenWidth * 0.024,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Select Tools (${selectedQty.length} selected)',
                              style: GoogleFonts.inter(
                                fontSize: screenWidth * 0.03,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setDialogState(() {
                                if (selectedQty.length == available.length) {
                                  selectedQty.clear();
                                } else {
                                  for (final g in available) {
                                    selectedQty[g['groupKey'] as String] =
                                        g['quantity'] as int;
                                  }
                                }
                              }),
                              child: Text(
                                selectedQty.length == available.length
                                    ? 'Clear all'
                                    : 'Select all',
                                style: GoogleFonts.inter(
                                  fontSize: screenWidth * 0.028,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFA63228),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 220),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Builder(
                            builder: (context) {
                              final visibleTools = available.where((tool) {
                                final name = (tool['name'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                final condition = (tool['condition'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                return name.contains(toolSearchQuery) ||
                                    condition.contains(toolSearchQuery);
                              }).toList();
                              if (visibleTools.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    'No matching tools found.',
                                    style: GoogleFonts.inter(
                                      fontSize: screenWidth * 0.028,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                );
                              }
                              return ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: visibleTools.length,
                                itemBuilder: (context, index) {
                                  final g = visibleTools[index];
                                  final key = g['groupKey'] as String;
                                  final groupQty = g['quantity'] as int;
                                  final isSelected = selectedQty.containsKey(
                                    key,
                                  );
                                  return CheckboxListTile(
                                    dense: true,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    activeColor: const Color(0xFFA63228),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    value: isSelected,
                                    onChanged: (checked) => setDialogState(() {
                                      if (checked == true) {
                                        selectedQty[key] = 1;
                                      } else {
                                        selectedQty.remove(key);
                                      }
                                    }),
                                    secondary: isSelected && groupQty > 1
                                        ? _buildQtyStepper(
                                            value: selectedQty[key]!,
                                            max: groupQty,
                                            onChanged: (v) => setDialogState(
                                              () => selectedQty[key] = v,
                                            ),
                                          )
                                        : null,
                                    title: Text(
                                      '${g['name']}',
                                      style: GoogleFonts.inter(
                                        fontSize: screenWidth * 0.03,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Qty: $groupQty • Cond: ${g['condition']}',
                                      style: GoogleFonts.inter(
                                        fontSize: screenWidth * 0.026,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Borrower Worker Name',
                          style: GoogleFonts.inter(
                            fontSize: screenWidth * 0.03,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        LayoutBuilder(
                          builder: (context, constraints) =>
                              Autocomplete<Map<String, dynamic>>(
                                optionsBuilder: (TextEditingValue value) {
                                  final q = value.text.trim().toLowerCase();
                                  if (q.isEmpty) {
                                    return const Iterable<
                                      Map<String, dynamic>
                                    >.empty();
                                  }
                                  return _workers.where(
                                    (w) => _workerName(
                                      w,
                                    ).toLowerCase().contains(q),
                                  );
                                },
                                displayStringForOption: _workerName,
                                fieldViewBuilder:
                                    (
                                      context,
                                      controller,
                                      focusNode,
                                      onFieldSubmitted,
                                    ) {
                                      workerCtrl = controller;
                                      return TextField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        style: GoogleFonts.inter(
                                          fontSize: screenWidth * 0.032,
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          hintText: 'e.g., Juan Dela Cruz',
                                          hintStyle: GoogleFonts.inter(
                                            fontSize: screenWidth * 0.03,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 8,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                optionsViewBuilder:
                                    (context, onSelected, options) {
                                      return Align(
                                        alignment: Alignment.topLeft,
                                        child: Material(
                                          elevation: 4,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          color: Colors.white,
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxHeight: 180,
                                              maxWidth: constraints.maxWidth,
                                            ),
                                            child: ListView.builder(
                                              padding: EdgeInsets.zero,
                                              shrinkWrap: true,
                                              itemCount: options.length,
                                              itemBuilder: (context, index) {
                                                final option = options
                                                    .elementAt(index);
                                                final role =
                                                    (option['role'] ??
                                                            option['position'] ??
                                                            '')
                                                        .toString();
                                                return ListTile(
                                                  dense: true,
                                                  title: Text(
                                                    _workerName(option),
                                                    style: GoogleFonts.inter(
                                                      fontSize:
                                                          screenWidth * 0.031,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                  subtitle: role.isEmpty
                                                      ? null
                                                      : Text(
                                                          role,
                                                          style:
                                                              GoogleFonts.inter(
                                                                fontSize:
                                                                    screenWidth *
                                                                    0.026,
                                                                color: Colors
                                                                    .grey
                                                                    .shade600,
                                                              ),
                                                        ),
                                                  onTap: () =>
                                                      onSelected(option),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                              ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Expected Return Date *',
                          style: GoogleFonts.inter(
                            fontSize: screenWidth * 0.03,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final today = DateTime.now();
                            final selected = await showDatePicker(
                              context: context,
                              initialDate:
                                  expectedReturnDate ??
                                  DateTime(
                                    today.year,
                                    today.month,
                                    today.day + 1,
                                  ),
                              firstDate: DateTime(
                                today.year,
                                today.month,
                                today.day,
                              ),
                              lastDate: DateTime(today.year + 5),
                            );
                            if (selected != null) {
                              setDialogState(
                                () => expectedReturnDate = selected,
                              );
                            }
                          },
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(
                            expectedReturnDate == null
                                ? 'Choose return date'
                                : _dateOnly(expectedReturnDate!),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: expectedReturnDate == null
                                  ? null
                                  : () async {
                                      final selected = await showTimePicker(
                                        context: context,
                                        initialTime:
                                            expectedReturnTime ??
                                            const TimeOfDay(
                                              hour: 17,
                                              minute: 0,
                                            ),
                                      );
                                      if (selected != null) {
                                        setDialogState(
                                          () => expectedReturnTime = selected,
                                        );
                                      }
                                    },
                              icon: const Icon(Icons.access_time),
                              label: Text(
                                expectedReturnTime == null
                                    ? 'Add time (optional)'
                                    : expectedReturnTime!.format(context),
                              ),
                            ),
                            if (expectedReturnTime != null)
                              IconButton(
                                tooltip: 'Remove return time',
                                onPressed: () => setDialogState(
                                  () => expectedReturnTime = null,
                                ),
                                icon: const Icon(Icons.clear),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFA63228),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () async {
                              final borrowerName =
                                  workerCtrl?.text.trim() ?? '';
                              final returnDateValue = expectedReturnDate;
                              final returnTimeValue = expectedReturnTime;
                              if (selectedQty.isEmpty ||
                                  borrowerName.isEmpty ||
                                  returnDateValue == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      returnDateValue == null
                                          ? 'Please choose an expected return date.'
                                          : 'Please select at least one tool and enter the borrower name.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              if (returnTimeValue != null &&
                                  DateTime(
                                    returnDateValue.year,
                                    returnDateValue.month,
                                    returnDateValue.day,
                                    returnTimeValue.hour,
                                    returnTimeValue.minute,
                                  ).isBefore(DateTime.now())) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Expected return time must be in the future.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              final targets = <Map<String, dynamic>>[];
                              for (final g in available) {
                                final qty = selectedQty[g['groupKey']];
                                if (qty == null) continue;
                                targets.addAll(
                                  (g['items'] as List<Map<String, dynamic>>)
                                      .take(qty),
                                );
                              }
                              final returnDate = _dateOnly(returnDateValue);
                              final returnTime = returnTimeValue == null
                                  ? null
                                  : '${returnTimeValue.hour.toString().padLeft(2, '0')}:'
                                        '${returnTimeValue.minute.toString().padLeft(2, '0')}';
                              Navigator.pop(context);
                              int released = 0;
                              for (final target in targets) {
                                final condition =
                                    (target['condition'] ?? 'Good').toString();
                                final ok = await _saveAsset(
                                  target,
                                  status: 'In Use',
                                  condition: condition,
                                  assignedTo: borrowerName,
                                  borrowAt: DateTime.now()
                                      .toUtc()
                                      .toIso8601String(),
                                  expectedReturnDate: returnDate,
                                  expectedReturnTime: returnTime,
                                );
                                if (!ok) continue;
                                released++;
                                await _logHistory(
                                  target,
                                  borrowerName,
                                  'Borrowed',
                                  condition,
                                );
                              }
                              await _refreshAll();
                              if (!mounted || released == 0) return;
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    released == 1
                                        ? 'Tool borrowed successfully.'
                                        : '$released tools borrowed by $borrowerName.',
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              'Confirm Borrow',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: screenWidth * 0.032,
                              ),
                            ),
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final total = _toolsData.length;
    final borrowedCount = _toolsData
        .where((t) => t['status'] == 'Borrowed' || t['status'] == 'Checked Out')
        .length;
    final inStorage = _toolsData
        .where((t) => t['status'] == 'In Storage')
        .length;
    final overdueCount = _toolsData.where((t) => t['isOverdue'] == true).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      appBar: widget.hideAppBar
          ? null
          : ApiService.currentUserRole?.toLowerCase() == 'admin'
          ? AdminMobileAppBar()
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              title: Image.asset(
                'assets/logo.png',
                height: screenHeight * 0.032 < 24 ? 24 : screenHeight * 0.032,
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            if (ApiService.currentUserRole?.toLowerCase() == 'admin')
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment<int>(
                      value: 0,
                      icon: Icon(Icons.inventory_2_outlined, size: 16),
                      label: Text('All Tools'),
                    ),
                    ButtonSegment<int>(
                      value: 1,
                      icon: Icon(Icons.history_outlined, size: 16),
                      label: Text('Borrowed History'),
                    ),
                  ],
                  selected: {_currentNavIndex},
                  onSelectionChanged: (selection) =>
                      setState(() => _currentNavIndex = selection.first),
                  style: ButtonStyle(
                    textStyle: WidgetStatePropertyAll(
                      GoogleFonts.inter(fontSize: 11),
                    ),
                  ),
                ),
              ),
            // 1. TOP SUMMARY METRICS (Responsive Box with FittedBox)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.03,
                vertical: screenHeight * 0.01,
              ),
              child: Row(
                children: [
                  _buildMetricTile(
                    'Total',
                    '$total',
                    screenWidth,
                    screenHeight,
                  ),
                  SizedBox(width: screenWidth * 0.015),
                  _buildMetricTile(
                    'Borrowed',
                    '$borrowedCount',
                    screenWidth,
                    screenHeight,
                  ),
                  SizedBox(width: screenWidth * 0.015),
                  _buildMetricTile(
                    'In Shed',
                    '$inStorage',
                    screenWidth,
                    screenHeight,
                  ),
                  SizedBox(width: screenWidth * 0.015),
                  _buildMetricTile(
                    'Overdue',
                    '$overdueCount',
                    screenWidth,
                    screenHeight,
                    isFlagged: overdueCount > 0,
                  ),
                ],
              ),
            ),

            // 2. SEARCH BAR
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.03,
                vertical: screenHeight * 0.005,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.inter(
                        fontSize: screenWidth * 0.03,
                        color: Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: _currentNavIndex == 1
                            ? 'Search tool, worker, or status...'
                            : 'Search tool or worker...',
                        hintStyle: GoogleFonts.inter(
                          color: Colors.grey.shade400,
                          fontSize: screenWidth * 0.03,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: screenWidth * 0.045,
                          color: Colors.black54,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 10,
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          borderSide: BorderSide(color: Colors.black87),
                        ),
                      ),
                    ),
                  ),
                  if (_currentNavIndex == 1)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        screenWidth * 0.01,
                        4,
                        screenWidth * 0.01,
                        0,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Past transactions; check All Tools for current status.',
                          style: GoogleFonts.inter(
                            fontSize: screenWidth * 0.024,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 3. CATEGORY CHIPS
            if (_currentNavIndex == 0)
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.03,
                    vertical: 2,
                  ),
                  children: [
                    _buildStatusChip('All', screenWidth),
                    _buildStatusChip('Borrowed', screenWidth),
                    _buildStatusChip('In Storage', screenWidth),
                    _buildStatusChip('Overdue', screenWidth),
                    _buildStatusChip('Needs Repair', screenWidth),
                  ],
                ),
              ),

            // 4. LIST VIEW WITH EMPTY STATE
            Expanded(
              child: _currentNavIndex == 1
                  ? _buildBorrowHistoryView(screenWidth)
                  : _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFA63228),
                      ),
                    )
                  : _loadError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cloud_off_rounded,
                              size: screenWidth * 0.1,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _loadError!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: screenWidth * 0.028,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFFA63228),
                      onRefresh: _fetchTools,
                      child: _filteredTools.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(height: screenHeight * 0.15),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: screenWidth * 0.1,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _toolsData.isEmpty
                                          ? 'No tools saved in the database yet.'
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
                              ],
                            )
                          : PaginatedListView.separated(
                              padding: EdgeInsets.fromLTRB(
                                screenWidth * 0.03,
                                6,
                                screenWidth * 0.03,
                                80,
                              ),
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              itemCount: _displayTools.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final tool = _displayTools[index];
                                final isBorrowed =
                                    tool['status'] == 'Borrowed' ||
                                    tool['status'] == 'Checked Out';
                                final isOverdue = tool['isOverdue'] == true;

                                return Container(
                                  padding: EdgeInsets.all(screenWidth * 0.03),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isOverdue
                                          ? const Color(
                                              0xFFA63228,
                                            ).withValues(alpha: 0.3)
                                          : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.construction_outlined,
                                              color: Colors.black87,
                                              size: screenWidth * 0.045,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  tool['name'],
                                                  style: GoogleFonts.inter(
                                                    fontSize:
                                                        screenWidth * 0.032,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Qty: ${tool['quantity'] ?? 1} • Status: ${tool['status']} • Cond: ${tool['condition']}',
                                                  style: GoogleFonts.inter(
                                                    fontSize:
                                                        screenWidth * 0.026,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isOverdue
                                                  ? const Color(
                                                      0xFFA63228,
                                                    ).withValues(alpha: 0.08)
                                                  : tool['status'] ==
                                                        'Needs Repair'
                                                  ? const Color(
                                                      0xFFD97706,
                                                    ).withValues(alpha: 0.1)
                                                  : Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isOverdue
                                                    ? const Color(
                                                        0xFFA63228,
                                                      ).withValues(alpha: 0.3)
                                                    : tool['status'] ==
                                                          'Needs Repair'
                                                    ? const Color(
                                                        0xFFD97706,
                                                      ).withValues(alpha: 0.4)
                                                    : Colors.grey.shade300,
                                              ),
                                            ),
                                            child: Text(
                                              isOverdue
                                                  ? 'Overdue Return'
                                                  : tool['status'],
                                              style: GoogleFonts.inter(
                                                fontSize: screenWidth * 0.024,
                                                fontWeight: FontWeight.bold,
                                                color: isOverdue
                                                    ? const Color(0xFFA63228)
                                                    : tool['status'] ==
                                                          'Needs Repair'
                                                    ? const Color(0xFFD97706)
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (isBorrowed) ...[
                                        const Divider(height: 14),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Borrower: ${tool['borrower'] ?? 'Unknown'}',
                                                    style: GoogleFonts.inter(
                                                      fontSize:
                                                          screenWidth * 0.028,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.black87,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    'Borrowed: ${tool['borrowTime'] ?? tool['checkoutTime'] ?? '—'}',
                                                    style: GoogleFonts.inter(
                                                      fontSize:
                                                          screenWidth * 0.024,
                                                      color:
                                                          Colors.grey.shade500,
                                                    ),
                                                  ),
                                                  if (tool['expectedReturnDate']
                                                      is DateTime)
                                                    Text(
                                                      'Due: ${_dateOnly(tool['expectedReturnDate'] as DateTime)}'
                                                      '${tool['expectedReturnTime'] is TimeOfDay ? ' • ${(tool['expectedReturnTime'] as TimeOfDay).format(context)}' : ''}',
                                                      style: GoogleFonts.inter(
                                                        fontSize:
                                                            screenWidth * 0.024,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: isOverdue
                                                            ? const Color(
                                                                0xFFA63228,
                                                              )
                                                            : Colors
                                                                  .grey
                                                                  .shade600,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (ApiService.currentUserRole
                                                    ?.toLowerCase() !=
                                                'admin')
                                              OutlinedButton(
                                                style: OutlinedButton.styleFrom(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 4,
                                                      ),
                                                  minimumSize: Size.zero,
                                                  side: const BorderSide(
                                                    color: Colors.black87,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    _returnTool(tool),
                                                child: Text(
                                                  'Return',
                                                  style: GoogleFonts.inter(
                                                    fontSize:
                                                        screenWidth * 0.028,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                ),
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
            ),
          ],
        ),
      ),
      floatingActionButton:
          (_currentNavIndex == 0 &&
              ApiService.currentUserRole?.toLowerCase() != 'admin')
          ? FloatingActionButton(
              backgroundColor: const Color(0xFFA63228),
              elevation: 2,
              onPressed: _showBorrowDialog,
              child: const Icon(Icons.add, color: Colors.white, size: 22),
            )
          : null,
      bottomNavigationBar: ApiService.currentUserRole?.toLowerCase() == 'admin'
          ? widget.hideAppBar
                ? null
                : AdminMobileBottomNavigationBar(
                    currentIndex: 1,
                    onTap: (index) =>
                        navigateAdminMobileSection(context, index),
                  )
          : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _currentNavIndex,
              selectedItemColor: const Color(0xFFA63228),
              unselectedItemColor: Colors.grey.shade500,
              backgroundColor: Colors.white,
              selectedLabelStyle: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
              onTap: (index) => setState(() => _currentNavIndex = index),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.inventory_2_outlined, size: 20),
                  activeIcon: Icon(Icons.inventory_2, size: 20),
                  label: 'All Tools',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history_outlined, size: 20),
                  activeIcon: Icon(Icons.history, size: 20),
                  label: 'Borrowed History',
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
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
        selected: isSelected,
        selectedColor: Colors.black87,
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        showCheckmark: false,
        onSelected: (val) => setState(() => _selectedStatusFilter = label),
      ),
    );
  }

  Widget _buildMetricTile(
    String label,
    String value,
    double screenWidth,
    double screenHeight, {
    bool isFlagged = false,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: screenHeight * 0.008,
          horizontal: screenWidth * 0.015,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isFlagged ? const Color(0xFFA63228) : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: screenWidth * 0.024,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: screenWidth * 0.038,
                  fontWeight: FontWeight.w900,
                  color: isFlagged ? const Color(0xFFA63228) : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
