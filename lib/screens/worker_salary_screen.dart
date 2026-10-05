import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class WorkerSalaryScreen extends StatefulWidget {
  const WorkerSalaryScreen({super.key});

  @override
  State<WorkerSalaryScreen> createState() => _WorkerSalaryScreenState();
}

class _WorkerSalaryScreenState extends State<WorkerSalaryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<Map<String, dynamic>> _cashAdvances = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = ApiService.currentUser?['id'];
      if (userId != null) {
        final id = int.tryParse(userId.toString());
        if (id != null) {
          final data = await ApiService.getWorkerCashAdvances(id);
          if (mounted) {
            setState(() {
              _cashAdvances = List<Map<String, dynamic>>.from(data);
            });
          }
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCashAdvanceDialog() {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();
    final List<String> quickAmounts = ['500', '1000', '1500', '2000'];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          'Request Cash Advance',
                          style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87),
                        ),
                        Text(
                          'Submitted to admin for cutoff review',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.close, size: 16, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: quickAmounts.map((amt) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => amountController.text = amt,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3EF),
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          '₱$amt',
                          style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFFAF8F5),
                    isDense: true,
                    prefixText: '₱ ',
                    prefixStyle: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFA63228)),
                    hintText: 'Enter amount',
                    hintStyle: GoogleFonts.inter(
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.normal,
                        fontSize: 12),
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
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  style: GoogleFonts.inter(fontSize: 12),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFFAF8F5),
                    isDense: true,
                    hintText: 'Reason (e.g., Medical, Travel fare)',
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
                        onPressed: () async {
                          final amount =
                              double.tryParse(amountController.text) ?? 0.0;
                          final reason = reasonController.text.trim();
                          if (amount <= 0 || reason.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Please enter valid amount and reason')),
                            );
                            return;
                          }
                          try {
                            final user = ApiService.currentUser;
                            final workerName = user?['name'] ??
                                user?['full_name'] ??
                                '${user?['firstName'] ?? user?['first_name'] ?? ''} ${user?['lastName'] ?? user?['last_name'] ?? ''}'
                                    .trim();
                            final dateStr = DateTime.now()
                                .toIso8601String()
                                .split('T')[0];
                            await ApiService.createCashAdvance({
                              'project_id': 1,
                              'workerId': user?['id'],
                              'workerName': workerName.isNotEmpty
                                  ? workerName
                                  : 'Worker',
                              'amount': amount,
                              'reason': reason,
                              'date': dateStr,
                              'status': 'Pending',
                            });
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Cash advance request submitted!',
                                    style: GoogleFonts.inter(fontSize: 12),
                                  ),
                                  backgroundColor: Colors.green.shade700,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                ),
                              );
                              _loadData();
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Failed: $e')),
                              );
                            }
                          }
                        },
                        child: Text('Submit',
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
    );
  }

  String _formatDate(String? raw) {
    if (raw == null) return '—';
    try {
      final datePart =
          raw.contains('T') ? raw.split('T')[0] : raw.split(' ')[0];
      final parts = datePart.split('-');
      if (parts.length < 3) return raw;
      const months = [
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
    final approvedAdvances =
        _cashAdvances.where((c) => c['status'] == 'Approved').toList();
    final allAdvances = _cashAdvances;

    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Salary & Finances',
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
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.bold, fontSize: 12),
                tabs: const [
                  Tab(text: 'Payroll History'),
                  Tab(text: 'Cash Advance History'),
                  Tab(text: 'Request Advance'),
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
                        // --- TAB 1: PAYROLL HISTORY ---
                        _buildEmpty(
                          Icons.account_balance_wallet_outlined,
                          'No salary payouts yet',
                          'Your salary payout history will appear here once processed by the admin.',
                        ),

                        // --- TAB 2: CASH ADVANCE HISTORY ---
                        RefreshIndicator(
                          color: const Color(0xFFA63228),
                          onRefresh: _loadData,
                          child: allAdvances.isEmpty
                              ? _buildEmpty(
                                  Icons.receipt_long_outlined,
                                  'No cash advance records',
                                  'Your cash advance requests will appear here once submitted.',
                                )
                              : ListView.separated(
                                  physics: const BouncingScrollPhysics(),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: hp, vertical: 10),
                                  itemCount: allAdvances.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (ctx, i) {
                                    final ca = allAdvances[i];
                                    final status =
                                        ca['status']?.toString() ?? 'Pending';
                                    final isApproved =
                                        status == 'Approved';
                                    final isPending = status == 'Pending';

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
                                              offset: const Offset(0, 1)),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFA63228)
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                                Icons.payments_outlined,
                                                size: 20,
                                                color: Color(0xFFA63228)),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  ca['reason']?.toString() ??
                                                      'Cash Advance',
                                                  style: GoogleFonts.inter(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black87),
                                                ),
                                                Text(
                                                  _formatDate(ca['date']
                                                      ?.toString()),
                                                  style: GoogleFonts.inter(
                                                      fontSize: 10.5,
                                                      color: Colors
                                                          .grey.shade600),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '₱${ca['amount']?.toString() ?? '0'}',
                                                style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w800,
                                                    color: Colors.black87),
                                              ),
                                              const SizedBox(height: 2),
                                              Container(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 6,
                                                    vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isApproved
                                                      ? Colors.green.shade50
                                                      : isPending
                                                          ? Colors
                                                              .orange.shade50
                                                          : Colors
                                                              .red.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          5),
                                                  border: Border.all(
                                                      color: isApproved
                                                          ? Colors
                                                              .green.shade200
                                                          : isPending
                                                              ? Colors.orange
                                                                  .shade200
                                                              : Colors.red
                                                                  .shade200),
                                                ),
                                                child: Text(
                                                  status,
                                                  style: GoogleFonts.inter(
                                                      fontSize: 9.5,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isApproved
                                                          ? Colors
                                                              .green.shade800
                                                          : isPending
                                                              ? Colors.orange
                                                                  .shade800
                                                              : Colors
                                                                  .red.shade800),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),

                        // --- TAB 3: REQUEST CASH ADVANCE ---
                        ListView(
                          padding: EdgeInsets.symmetric(
                              horizontal: hp, vertical: 14),
                          children: [
                            // Summary Card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFA63228),
                                    Color(0xFFD94F3D)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.account_balance_wallet,
                                          color: Colors.white70, size: 16),
                                      const SizedBox(width: 6),
                                      Text('Cash Advance Summary',
                                          style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildSummaryItem(
                                        'Total Requested',
                                        '₱${_cashAdvances.fold<double>(0, (sum, c) => sum + (double.tryParse(c['amount']?.toString() ?? '0') ?? 0)).toStringAsFixed(2)}',
                                      ),
                                      _buildSummaryItem(
                                        'Approved',
                                        '₱${approvedAdvances.fold<double>(0, (sum, c) => sum + (double.tryParse(c['amount']?.toString() ?? '0') ?? 0)).toStringAsFixed(2)}',
                                      ),
                                      _buildSummaryItem(
                                        'Pending',
                                        '${_cashAdvances.where((c) => c['status'] == 'Pending').length}',
                                        isBadge: true,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Request Button
                            ElevatedButton.icon(
                              onPressed: _showCashAdvanceDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFA63228),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.add_circle_outline,
                                  color: Colors.white, size: 18),
                              label: Text(
                                'Request Cash Advance',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Info Card
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.blue.shade100),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.info_outline_rounded,
                                      size: 16,
                                      color: Colors.blue.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Cash advance requests are reviewed by the admin during cutoff. Approved amounts will be deducted from your next salary payout.',
                                      style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.blue.shade800,
                                          height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSummaryItem(String label, String value,
      {bool isBadge = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10, color: Colors.white70)),
        const SizedBox(height: 2),
        isBadge
            ? Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              )
            : Text(value,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
      ],
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
                child:
                    Icon(icon, size: 32, color: const Color(0xFFA63228)),
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
