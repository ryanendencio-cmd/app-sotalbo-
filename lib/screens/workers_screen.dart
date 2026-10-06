import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/app_sidebar.dart';

class WorkersScreen extends StatefulWidget {
  const WorkersScreen({super.key});

  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen> with SingleTickerProviderStateMixin {
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

  Future<void> _updateStatus(dynamic id, String status) async {
    try {
      await ApiService.approveWorker(id, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account $status successfully'),
            backgroundColor: status == 'Approved' ? Colors.green : const Color(0xFFA63228),
          ),
        );
        _refreshData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFA63228)),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _refreshData,
          ),
        ],
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
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
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
                hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
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
          return const Center(child: CircularProgressIndicator(color: Color(0xFFA63228)));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Failed to load workers: ${snapshot.error}',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
          );
        }

        final loaded = snapshot.data ?? [];
        final filtered = loaded.where((w) {
          final name = (w['full_name'] ?? w['name'] ?? '${w['first_name'] ?? ''} ${w['last_name'] ?? ''}').toString().toLowerCase();
          final role = (w['role'] ?? w['position'] ?? '').toString().toLowerCase();
          final phone = (w['phone'] ?? '').toString().toLowerCase();
          final q = _searchQuery.toLowerCase();
          return name.contains(q) || role.contains(q) || phone.contains(q);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text('No manpower records found.',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
          );
        }

        return RefreshIndicator(
          color: const Color(0xFFA63228),
          onRefresh: () async => _refreshData(),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final w = filtered[i];
              final name = (w['full_name'] ?? w['name'] ?? '${w['first_name'] ?? ''} ${w['last_name'] ?? ''}').toString().trim();
              final role = (w['role'] ?? w['position'] ?? 'Worker').toString();
              final phone = (w['phone'] ?? 'No phone').toString();
              final rate = (w['daily_rate'] != null) ? '₱${w['daily_rate']}/day' : '₱600/day';
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
                      backgroundColor: const Color(0xFFA63228).withValues(alpha: 0.08),
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
                            style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$role • $rate',
                            style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Phone: $phone',
                            style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: status.toLowerCase() == 'approved' || status.toLowerCase() == 'active'
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: status.toLowerCase() == 'approved' || status.toLowerCase() == 'active'
                                ? Colors.green.shade200
                                : Colors.orange.shade200),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: status.toLowerCase() == 'approved' || status.toLowerCase() == 'active'
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
          return const Center(child: CircularProgressIndicator(color: Color(0xFFA63228)));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Failed to load pending registrations: ${snapshot.error}',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
          );
        }

        final loaded = snapshot.data ?? [];
        final filtered = loaded.where((w) {
          final name = (w['full_name'] ?? w['name'] ?? '${w['first_name'] ?? ''} ${w['last_name'] ?? ''}').toString().toLowerCase();
          final role = (w['role'] ?? w['position'] ?? '').toString().toLowerCase();
          final phone = (w['phone'] ?? '').toString().toLowerCase();
          final q = _searchQuery.toLowerCase();
          return name.contains(q) || role.contains(q) || phone.contains(q);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 48, color: Colors.green.shade300),
                const SizedBox(height: 12),
                Text('All caught up!', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('No pending account approvals.', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: const Color(0xFFA63228),
          onRefresh: () async => _refreshData(),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final w = filtered[i];
              final name = (w['full_name'] ?? w['name'] ?? '${w['first_name'] ?? ''} ${w['last_name'] ?? ''}').toString().trim();
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
                          backgroundColor: const Color(0xFFA63228).withValues(alpha: 0.1),
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
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                role,
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.phone_outlined, size: 12, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                    phone,
                                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _updateStatus(w['id'], 'Rejected'),
                            child: Text('Reject', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _updateStatus(w['id'], 'Approved'),
                            child: Text('Approve', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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