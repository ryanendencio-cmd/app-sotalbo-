import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/admin_mobile_chrome.dart';
import 'schedules_screen.dart';
import '../widgets/app_sidebar.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  late Future<List<dynamic>> _future;
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _future = ApiService.getProjects();
  }

  Color _statusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'ongoing':
      case 'active':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'on hold':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatProjectDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return '—';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showProjectDetails(Map<String, dynamic> project) {
    final projectId = project['id'];
    final expensesFuture = projectId == null
        ? Future<List<dynamic>>.value([])
        : ApiService.getExpenses(projectId);
    final budget = double.tryParse(project['budget']?.toString() ?? '') ?? 0;
    final progress =
        double.tryParse(project['progress']?.toString() ?? '') ?? 0;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.84,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFF3EFEA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 12, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project['name']?.toString() ?? 'Project Details',
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            project['location']?.toString() ??
                                'No location set',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close project details',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(14),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _projectInfoChip(
                          'Status',
                          project['status']?.toString() ?? 'Ongoing',
                          _statusColor(project['status']?.toString()),
                        ),
                        _projectInfoChip(
                          'Budget',
                          '₱${budget.toStringAsFixed(2)}',
                          const Color(0xFFA63228),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _projectDetailRow(
                      'Project ID',
                      projectId?.toString() ?? '—',
                    ),
                    _projectDetailRow(
                      'Start Date',
                      _formatProjectDate(project['start_date']),
                    ),
                    _projectDetailRow(
                      'Target Completion',
                      _formatProjectDate(project['end_date']),
                    ),
                    if ((project['description'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty)
                      _projectDetailRow(
                        'Description',
                        project['description'].toString(),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'PROJECT PROGRESS',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: (progress / 100).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _statusColor(project['status']?.toString()),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${progress.toStringAsFixed(0)}% complete',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'EXPENSES',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<dynamic>>(
                      future: expensesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(18),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFA63228),
                              ),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Could not load project expenses: ${snapshot.error}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFFA63228),
                              ),
                            ),
                          );
                        }

                        final expenses = snapshot.data ?? [];
                        final spent = expenses.fold<double>(
                          0,
                          (total, expense) =>
                              total +
                              (double.tryParse(
                                    expense['amount']?.toString() ?? '',
                                  ) ??
                                  0),
                        );
                        final remaining = budget - spent;
                        final recentExpenses = expenses.take(5).toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _projectMetricCard(
                                    'Spent',
                                    '₱${spent.toStringAsFixed(2)}',
                                    const Color(0xFFA63228),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _projectMetricCard(
                                    'Remaining',
                                    '₱${remaining.toStringAsFixed(2)}',
                                    remaining < 0
                                        ? Colors.red
                                        : Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${expenses.length} expense record${expenses.length == 1 ? '' : 's'}',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (recentExpenses.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  'No expenses recorded for this project.',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              )
                            else ...[
                              const SizedBox(height: 6),
                              ...recentExpenses.map((expense) {
                                final date = _formatProjectDate(
                                  expense['date'],
                                );
                                final category =
                                    expense['category']?.toString() ??
                                    'Expense';
                                final amount =
                                    double.tryParse(
                                      expense['amount']?.toString() ?? '',
                                    ) ??
                                    0;
                                return _projectDetailRow(
                                  '$category • $date',
                                  '₱${amount.toStringAsFixed(2)}',
                                );
                              }),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _projectInfoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _projectMetricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _projectDetailRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.black87,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ApiService.currentUserRole?.toLowerCase() == 'admin';
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      drawer: isAdmin ? null : const AppSidebar(),
      appBar: isAdmin
          ? AdminMobileAppBar(
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () =>
                      setState(() => _future = ApiService.getProjects()),
                  icon: const Icon(Icons.refresh, color: Colors.black87),
                ),
              ],
            )
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              iconTheme: const IconThemeData(color: Colors.black87),
              title: Text(
                'Projects',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          final loadedProjects = snapshot.data ?? [];

          // Apply filters
          final filteredProjects = loadedProjects.where((p) {
            final name = (p['name'] ?? '').toString().toLowerCase();
            final location = (p['location'] ?? '').toString().toLowerCase();
            final rawStatus = (p['status'] ?? 'Ongoing')
                .toString()
                .trim()
                .toLowerCase();
            final status = rawStatus == 'active' ? 'ongoing' : rawStatus;

            final matchesSearch =
                name.contains(_searchQuery.toLowerCase()) ||
                location.contains(_searchQuery.toLowerCase());
            final matchesStatus =
                _statusFilter == 'All' ||
                status == _statusFilter.trim().toLowerCase();

            return matchesSearch && matchesStatus;
          }).toList();

          return Scaffold(
            backgroundColor: const Color(0xFFF3EFEA),
            body: snapshot.connectionState == ConnectionState.waiting
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFA63228)),
                  )
                : snapshot.hasError
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 36,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load projects: ${snapshot.error}',
                            style: GoogleFonts.inter(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFA63228),
                            ),
                            onPressed: () => setState(
                              () => _future = ApiService.getProjects(),
                            ),
                            child: Text(
                              'Retry',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      // Filter Section
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            TextField(
                              decoration: InputDecoration(
                                hintText: 'Search projects...',
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
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                              ),
                              onChanged: (val) =>
                                  setState(() => _searchQuery = val),
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children:
                                    [
                                      'All',
                                      'Ongoing',
                                      'Completed',
                                      'On Hold',
                                    ].map((status) {
                                      final isSelected =
                                          _statusFilter == status;
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: ChoiceChip(
                                          label: Text(
                                            status,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                          selected: isSelected,
                                          selectedColor: const Color(
                                            0xFFA63228,
                                          ),
                                          backgroundColor: Colors.grey.shade100,
                                          onSelected: (selected) {
                                            if (selected) {
                                              setState(
                                                () => _statusFilter = status,
                                              );
                                            }
                                          },
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: filteredProjects.isEmpty
                            ? Center(
                                child: Text(
                                  'No projects found.',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: filteredProjects.length,
                                itemBuilder: (context, i) {
                                  final p = filteredProjects[i];
                                  final name = p['name'] ?? 'Untitled Project';
                                  final location =
                                      p['location'] ?? 'No location set';
                                  final budget = (p['budget'] != null)
                                      ? '₱${double.tryParse(p['budget'].toString())?.toStringAsFixed(2) ?? '0.00'}'
                                      : '₱0.00';
                                  final status = p['status'] ?? 'Ongoing';
                                  final color = _statusColor(status);
                                  final isAdmin =
                                      ApiService.currentUserRole
                                          ?.toLowerCase() ==
                                      'admin';

                                  return Card(
                                    color: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: InkWell(
                                      onTap: () => _showProjectDetails(
                                        Map<String, dynamic>.from(p as Map),
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    name,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: color.withValues(
                                                      alpha: 0.12,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    status,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10.5,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: color,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Icon(
                                                  Icons.chevron_right_rounded,
                                                  size: 20,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.location_on_outlined,
                                                  size: 13,
                                                  color: Colors.grey.shade600,
                                                ),
                                                const SizedBox(width: 3),
                                                Expanded(
                                                  child: Text(
                                                    location,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Divider(height: 16),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'Budget: $budget',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color(
                                                      0xFFA63228,
                                                    ),
                                                  ),
                                                ),
                                                if (!isAdmin)
                                                  TextButton.icon(
                                                    style: TextButton.styleFrom(
                                                      padding: EdgeInsets.zero,
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                    ),
                                                    icon: const Icon(
                                                      Icons
                                                          .calendar_month_outlined,
                                                      size: 14,
                                                      color: Color(0xFFA63228),
                                                    ),
                                                    label: Text(
                                                      'Schedules',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color(
                                                          0xFFA63228,
                                                        ),
                                                      ),
                                                    ),
                                                    onPressed: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              SchedulesScreen(
                                                                projectId:
                                                                    p['id'] ??
                                                                    0,
                                                                projectName:
                                                                    name,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
          );
        },
      ),
      bottomNavigationBar: isAdmin
          ? AdminMobileBottomNavigationBar(
              currentIndex: 0,
              onTap: (index) => navigateAdminMobileSection(context, index),
            )
          : null,
    );
  }
}
