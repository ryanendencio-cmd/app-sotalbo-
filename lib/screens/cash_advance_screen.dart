import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/app_sidebar.dart';

class CashAdvanceScreen extends StatefulWidget {
  const CashAdvanceScreen({super.key});

  @override
  State<CashAdvanceScreen> createState() => _CashAdvanceScreenState();
}

class _CashAdvanceScreenState extends State<CashAdvanceScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getPendingCashAdvances();
  }

  Color _statusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'approved': return Colors.green;
      case 'pending': return Colors.orange;
      case 'rejected': return const Color(0xFFA63228);
      default: return Colors.grey;
    }
  }

  Future<void> _updateStatus(dynamic id, String status) async {
    try {
      await ApiService.approveCashAdvance(id, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cash advance $status successfully'),
            backgroundColor: status == 'Approved' ? Colors.green : const Color(0xFFA63228),
          ),
        );
        setState(() => _future = ApiService.getPendingCashAdvances());
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
          'Pending Cash Advances',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFA63228)));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40, color: Color(0xFFA63228)),
                    const SizedBox(height: 8),
                    Text('Failed to load cash advances', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(snapshot.error.toString(), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA63228), elevation: 0),
                      onPressed: () => setState(() => _future = ApiService.getPendingCashAdvances()),
                      child: Text('Retry', style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          }

          final advances = snapshot.data!;
          if (advances.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 48, color: Colors.green.shade300),
                  const SizedBox(height: 12),
                  Text('All caught up!', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('No pending cash advances.', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: const Color(0xFFA63228),
            onRefresh: () async => setState(() => _future = ApiService.getPendingCashAdvances()),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: advances.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final ca = advances[i];
                final name = ca['name']?.toString() ?? 'Unknown Worker';
                final role = ca['role']?.toString() ?? 'Worker';
                final amount = ca['amount']?.toString() ?? '₱0.00';
                final reason = ca['reason']?.toString() ?? 'No reason provided';
                
                String dateStr = 'Unknown Date';
                if (ca['date'] != null) {
                  try {
                    final d = DateTime.parse(ca['date'].toString());
                    dateStr = DateFormat('MMM d, yyyy').format(d);
                  } catch (_) {}
                }

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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  role,
                                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            amount,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFA63228),
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1),
                      ),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Text(dateStr, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.notes_outlined, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              reason,
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700),
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
                              onPressed: () => _updateStatus(ca['id'], 'Rejected'),
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
                              onPressed: () => _updateStatus(ca['id'], 'Approved'),
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
      ),
    );
  }
}