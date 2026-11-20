import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/paginated_list_view.dart';

class WorkersScreen extends StatefulWidget {
  const WorkersScreen({super.key});

  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<dynamic>> _allWorkersFuture;
  late Future<List<dynamic>> _pendingFuture;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshData() {
    setState(() {
      _allWorkersFuture = ApiService.getWorkers();
      _pendingFuture = ApiService.getPendingRegistrations();
    });
  }

  Future<String?> _showRejectReasonDialog({
    required String title,
    required String subtitle,
    required String workerName,
  }) async {
    final controller = TextEditingController();
    String? validationError;

    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.block_rounded,
                        color: Color(0xFFA63228),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLength: 100,
                    maxLines: 3,
                    autofocus: true,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(100),
                      _NoLeadingOrRepeatedSpacesFormatter(),
                    ],
                    onChanged: (_) {
                      if (validationError != null) {
                        setDialogState(() => validationError = null);
                      }
                    },
                    style: GoogleFonts.inter(fontSize: 12),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFFAF8F5),
                      isDense: true,
                      hintText:
                          'e.g. Incomplete requirements, schedule conflict, etc.',
                      hintStyle: GoogleFonts.inter(
                        color: Colors.grey.shade400,
                        fontSize: 11,
                      ),
                      errorText: validationError,
                      errorStyle: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: const Color(0xFFA63228),
                        fontWeight: FontWeight.w600,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: validationError != null
                              ? const Color(0xFFA63228)
                              : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: validationError != null
                              ? const Color(0xFFA63228)
                              : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFFA63228),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(
                              color: Colors.grey.shade300,
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA63228),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            final raw = controller.text;
                            if (raw.trim().isEmpty) {
                              setDialogState(() {
                                validationError = raw.isEmpty
                                    ? 'Rejection reason is required.'
                                    : 'Spaces only are not allowed.';
                              });
                              return;
                            }
                            Navigator.pop(ctx, raw.trim());
                          },
                          child: Text(
                            'Confirm Reject',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
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

  Future<void> _updateStatus(dynamic id, String status, {String? workerName}) async {
    String? rejectionReason;
    if (status == 'Rejected') {
      rejectionReason = await _showRejectReasonDialog(
        title: 'Reject Registration',
        subtitle:
            'Please provide a reason why you are rejecting ${workerName ?? 'Worker'}\'s registration.',
        workerName: workerName ?? 'Worker',
      );
      if (rejectionReason == null) return;
    }
    try {
      await ApiService.approveWorker(
        id,
        status,
        rejectionReason: rejectionReason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account $status successfully'),
            backgroundColor: status == 'Approved'
                ? Colors.green
                : const Color(0xFFA63228),
          ),
        );
        _refreshData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception: ', 'Unable to update account: '),
              style: GoogleFonts.inter(fontSize: 13),
            ),
            backgroundColor: const Color(0xFFA63228),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      drawer: const AppSidebar(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          'Manpower Directory',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(42),
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
                tabs: const [
                  Tab(text: 'All Manpower'),
                  Tab(text: 'Account Approvals'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search workers, roles, or phone...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey.shade400,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: Colors.grey,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: ALL MANPOWER DIRECTORY
                _buildAllWorkersTab(),
                // TAB 2: ACCOUNT APPROVALS
                _buildPendingApprovalsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllWorkersTab() {
    return FutureBuilder<List<dynamic>>(
      future: _allWorkersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFA63228)),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Failed to load workers: ${snapshot.error}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          );
        }

        final loaded = snapshot.data ?? [];
        final filtered = loaded.where((w) {
          final name =
              (w['full_name'] ??
                      w['name'] ??
                      '${w['first_name'] ?? ''} ${w['last_name'] ?? ''}')
                  .toString()
                  .toLowerCase();
          final role = (w['role'] ?? '').toString().toLowerCase();
          final position = (w['position'] ?? '').toString().toLowerCase();
          final phone = (w['phone'] ?? '').toString().toLowerCase();
          final workerCode = (w['worker_code'] ?? w['id'] ?? '')
              .toString()
              .toLowerCase();
          final q = _searchQuery.trim().toLowerCase();
          return name.contains(q) ||
              role.contains(q) ||
              position.contains(q) ||
              phone.contains(q) ||
              workerCode.contains(q);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              'No manpower records found.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: const Color(0xFFA63228),
          onRefresh: () async => _refreshData(),
          child: PaginatedListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final w = filtered[i];
              final name =
                  (w['full_name'] ??
                          w['name'] ??
                          '${w['first_name'] ?? ''} ${w['last_name'] ?? ''}')
                      .toString()
                      .trim();
              final role = (w['role'] ?? w['position'] ?? 'Worker').toString();
              final phone = (w['phone'] ?? 'No phone').toString();
              final rate = (w['daily_rate'] != null)
                  ? '₱${w['daily_rate']}/day'
                  : '₱600/day';
              final status = (w['status'] ?? 'Active').toString();

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(
                        0xFFA63228,
                      ).withValues(alpha: 0.08),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'W',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFA63228),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? 'Worker' : name,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$role • $rate',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Phone: $phone',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              color: Colors.grey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                        color:
                            status.toLowerCase() == 'approved' ||
                                status.toLowerCase() == 'active'
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color:
                              status.toLowerCase() == 'approved' ||
                                  status.toLowerCase() == 'active'
                              ? Colors.green.shade200
                              : Colors.orange.shade200,
                        ),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color:
                              status.toLowerCase() == 'approved' ||
                                  status.toLowerCase() == 'active'
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPendingApprovalsTab() {
    return FutureBuilder<List<dynamic>>(
      future: _pendingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFA63228)),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Failed to load pending registrations: ${snapshot.error}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          );
        }

        final loaded = snapshot.data ?? [];
        final filtered = loaded.where((w) {
          final name =
              (w['full_name'] ??
                      w['name'] ??
                      '${w['first_name'] ?? ''} ${w['last_name'] ?? ''}')
                  .toString()
                  .toLowerCase();
          final role = (w['role'] ?? '').toString().toLowerCase();
          final position = (w['position'] ?? '').toString().toLowerCase();
          final phone = (w['phone'] ?? '').toString().toLowerCase();
          final workerCode = (w['worker_code'] ?? w['id'] ?? '')
              .toString()
              .toLowerCase();
          final q = _searchQuery.trim().toLowerCase();
          return name.contains(q) ||
              role.contains(q) ||
              position.contains(q) ||
              phone.contains(q) ||
              workerCode.contains(q);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 48,
                  color: Colors.green.shade300,
                ),
                const SizedBox(height: 12),
                Text(
                  'All caught up!',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No pending account approvals.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: const Color(0xFFA63228),
          onRefresh: () async => _refreshData(),
          child: PaginatedListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final w = filtered[i];
              final name =
                  (w['full_name'] ??
                          w['name'] ??
                          '${w['first_name'] ?? ''} ${w['last_name'] ?? ''}')
                      .toString()
                      .trim();
              final role = (w['role'] ?? w['position'] ?? 'Worker').toString();
              final phone = (w['phone'] ?? 'No phone').toString();

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(
                            0xFFA63228,
                          ).withValues(alpha: 0.1),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'W',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFA63228),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isEmpty ? 'Unknown' : name,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                role,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.phone_outlined,
                                    size: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    phone,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFA63228),
                              side: const BorderSide(color: Color(0xFFA63228)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              final name = (w['full_name'] as String?)?.isNotEmpty == true
                                  ? w['full_name']
                                  : '${w['first_name'] ?? ''} ${w['last_name'] ?? ''}'.trim();
                              _updateStatus(w['id'], 'Rejected', workerName: name.isNotEmpty ? name : 'Worker');
                            },
                            child: Text(
                              'Reject',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => _updateStatus(w['id'], 'Approved'),
                            child: Text(
                              'Approve',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _NoLeadingOrRepeatedSpacesFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    if (text.startsWith(' ')) {
      text = text.trimLeft();
    }
    text = text.replaceAll(RegExp(r' {2,}'), ' ');
    final diff = newValue.text.length - text.length;
    final newOffset =
        (newValue.selection.baseOffset - diff).clamp(0, text.length);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}
