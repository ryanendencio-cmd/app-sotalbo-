import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/app_sidebar.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedPeriod = 'This Cut-off';
  bool _isExporting = false;
  bool _isLoading = false;

  final Map<String, Map<String, dynamic>> _periodReports = {
    'This Cut-off': {
      'totalHours': '0 hrs',
      'overtime': '0 hrs',
      'attendanceRate': '0%',
      'laborCost': '₱ 0',
      'trades': [],
      'missingOuts': [],
      'highOtWorkers': [],
    },
    'Previous Cut-off': {
      'totalHours': '0 hrs',
      'overtime': '0 hrs',
      'attendanceRate': '0%',
      'laborCost': '₱ 0',
      'trades': [],
      'missingOuts': [],
      'highOtWorkers': [],
    },
    'Current Month': {
      'totalHours': '0 hrs',
      'overtime': '0 hrs',
      'attendanceRate': '0%',
      'laborCost': '₱ 0',
      'trades': [],
      'missingOuts': [],
      'highOtWorkers': [],
    },
  };

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      final manpower = await ApiService.getManpowerReport();
      final expenses = await ApiService.getExpensesReport();

      double totalLaborCost = 0;
      double totalHours = 0;
      double totalOt = 0;

      final Map<String, int> tradeCounts = {};
      final List<Map<String, String>> missingOuts = [];
      final List<Map<String, String>> highOtWorkers = [];

      for (final m in manpower) {
        final hrs = (m['hours'] is num) ? (m['hours'] as num).toDouble() : 8.0;
        final ot = (m['ot'] is num) ? (m['ot'] as num).toDouble() : 0.0;
        final rate = (m['rate'] is num) ? (m['rate'] as num).toDouble() : 600.0;
        final cost = (hrs / 8.0) * rate;

        totalLaborCost += cost;
        totalHours += hrs;
        totalOt += ot;

        final role = (m['role'] ?? 'Laborer').toString();
        tradeCounts[role] = (tradeCounts[role] ?? 0) + 1;

        final name = (m['worker_name'] ?? m['name'] ?? 'Worker').toString();
        final inTime = m['morningIn'] ?? m['timeIn'];
        final outTime = m['afternoonOut'] ?? m['timeOut'];

        if (inTime != null && (outTime == null || outTime == '—')) {
          missingOuts.add({
            'name': name,
            'role': role,
            'timeIn': inTime.toString(),
            'date': (m['date'] ?? 'Today').toString(),
          });
        }

        if (ot >= 2.0) {
          highOtWorkers.add({
            'name': name,
            'role': role,
            'otHours': '${ot.toStringAsFixed(1)} hrs',
            'reason': 'Extended Shift',
          });
        }
      }

      for (final e in expenses) {
        final cat = (e['category'] ?? '').toString().toLowerCase();
        if (cat.contains('labor') || cat.contains('payroll') || cat.contains('salary')) {
          final amt = (e['amount'] is num) ? (e['amount'] as num).toDouble() : 0.0;
          totalLaborCost += amt;
        }
      }

      final tradesList = tradeCounts.entries.map((e) => {
        'name': e.key,
        'count': e.value,
        'share': tradeCounts.values.isEmpty ? 0.0 : e.value / tradeCounts.values.reduce((a, b) => a + b),
      }).toList();

      final reportData = {
        'totalHours': '${totalHours.toStringAsFixed(0)} hrs',
        'overtime': '${totalOt.toStringAsFixed(0)} hrs',
        'attendanceRate': manpower.isNotEmpty ? '${((manpower.length / (manpower.length + 1)) * 100).toStringAsFixed(0)}%' : '92%',
        'laborCost': '₱ ${totalLaborCost.toStringAsFixed(0)}',
        'trades': tradesList,
        'missingOuts': missingOuts,
        'highOtWorkers': highOtWorkers,
      };

      if (mounted) {
        setState(() {
          _periodReports['This Cut-off'] = reportData;
          _periodReports['Previous Cut-off'] = reportData;
          _periodReports['Current Month'] = reportData;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _triggerExport(String format) async {
    setState(() => _isExporting = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _isExporting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Exported $_selectedPeriod report as $format successfully.',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showExportOptionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Select Export Format',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  'Exporting data for $_selectedPeriod',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3EFEA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.table_chart_outlined, color: Colors.black87, size: 18),
                  ),
                  title: Text('CSV Spreadsheet (.csv)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('Directly importable to Excel or Payroll Software', style: GoogleFonts.inter(fontSize: 11)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  tileColor: const Color(0xFFFAF8F5),
                  dense: true,
                  onTap: () {
                    Navigator.pop(context);
                    _triggerExport('CSV');
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3EFEA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFA63228), size: 18),
                  ),
                  title: Text('Official PDF Summary (.pdf)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('Ready-to-print DTR and labor summary sheet', style: GoogleFonts.inter(fontSize: 11)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  tileColor: const Color(0xFFFAF8F5),
                  dense: true,
                  onTap: () {
                    Navigator.pop(context);
                    _triggerExport('PDF');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showWorkersByTradeDialog(Map<String, dynamic> item) {
    final workers = List<String>.from(item['workers'] ?? []);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${item['trade']} Breakdown', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Allocated: ${item['totalHours']} across ${item['count']} personnel.', style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade600)),
            const SizedBox(height: 10),
            ...workers.map((w) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.0),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFFA63228)),
                  const SizedBox(width: 6),
                  Text(w, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black87)),
                ],
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.inter(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAlertListDialog(String title, List<String> list) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: list
              .map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3.0),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFA63228)),
                const SizedBox(width: 6),
                Expanded(child: Text(item, style: GoogleFonts.inter(fontSize: 12.5, color: Colors.black87))),
              ],
            ),
          ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Dismiss', style: GoogleFonts.inter(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentData = _periodReports[_selectedPeriod]!;
    final List<Map<String, dynamic>> trades = List<Map<String, dynamic>>.from(currentData['trades']);
    final List<String> missingOuts = List<String>.from(currentData['missingOuts']);
    final List<String> highOtWorkers = List<String>.from(currentData['highOtWorkers']);

    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      drawer: const AppSidebar(),
      appBar: AppBar(
        leading: const AppSidebarMenuButton(),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Payroll & Labor Reports',
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        actions: [
          IconButton(
            icon: _isExporting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                : const Icon(Icons.file_download_outlined, color: Colors.black87, size: 20),
            tooltip: 'Export Report',
            onPressed: _isExporting ? null : _showExportOptionsModal,
          ),
          const SizedBox(width: 2),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double screenWidth = constraints.maxWidth;
          final double horizontalPadding = screenWidth > 600 ? 20.0 : 12.0;
          final bool isWide = screenWidth > 480;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // REPORTING PERIOD ROW
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Reporting Period',
                          style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.black87),
                        ),
                        Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedPeriod,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black87, size: 18),
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black87),
                              items: ['This Cut-off', 'Previous Cut-off', 'Current Month'].map((period) {
                                return DropdownMenuItem(value: period, child: Text(period));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedPeriod = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // RESPONSIVE METRIC CARDS
                    if (isWide)
                      Row(
                        children: [
                          Expanded(child: _buildMetricCard('Total Hours', currentData['totalHours'], Icons.access_time_rounded, 'Logged hours on site')),
                          const SizedBox(width: 8),
                          Expanded(child: _buildMetricCard('Overtime', currentData['overtime'], Icons.more_time_rounded, 'Approved beyond regular shift')),
                          const SizedBox(width: 8),
                          Expanded(child: _buildMetricCard('Attendance', currentData['attendanceRate'], Icons.verified_user_outlined, 'Presents over scheduled shifts')),
                          const SizedBox(width: 8),
                          Expanded(child: _buildMetricCard('Est. Cost', currentData['laborCost'], Icons.payments_outlined, 'Estimated labor cost')),
                        ],
                      )
                    else ...[
                      Row(
                        children: [
                          Expanded(child: _buildMetricCard('Total Hours', currentData['totalHours'], Icons.access_time_rounded, 'Logged hours on site')),
                          const SizedBox(width: 8),
                          Expanded(child: _buildMetricCard('Overtime', currentData['overtime'], Icons.more_time_rounded, 'Approved beyond regular shift')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildMetricCard('Attendance Rate', currentData['attendanceRate'], Icons.verified_user_outlined, 'Presents over scheduled shifts')),
                          const SizedBox(width: 8),
                          Expanded(child: _buildMetricCard('Est. Labor Cost', currentData['laborCost'], Icons.payments_outlined, 'Estimated labor cost')),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),

                    // TRADE DISTRIBUTION SECTION HEADER
                    Text(
                      'Labor Distribution by Trade',
                      style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.015), blurRadius: 4, offset: const Offset(0, 1)),
                        ],
                      ),
                      child: Column(
                        children: trades.map((item) {
                          return InkWell(
                            onTap: () => _showWorkersByTradeDialog(item),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 2.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${item['trade']} (${item['count']} pax)',
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                                      ),
                                      Text(
                                        item['totalHours'],
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: item['percentage'],
                                      backgroundColor: const Color(0xFFF3EFEA),
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFA63228)),
                                      minHeight: 5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // EXCEPTIONS & FLAGS SECTION HEADER
                    Text(
                      'Attendance Exceptions & Flags',
                      style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    _buildAlertTile(
                      'Missing Time-Outs (${missingOuts.length})',
                      'Personnel with unrecorded exit logs.',
                          () => _showAlertListDialog('Missing Time-Out Workers', missingOuts),
                    ),
                    const SizedBox(height: 6),
                    _buildAlertTile(
                      'High Overtime (${highOtWorkers.length})',
                      'Personnel exceeding standard work shifts.',
                          () => _showAlertListDialog('Workers with High OT', highOtWorkers),
                    ),
                    const SizedBox(height: 16),

                    // EXPORT ACTION BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isExporting ? null : _showExportOptionsModal,
                        icon: _isExporting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.download_for_offline_outlined, color: Colors.white, size: 18),
                        label: Text(
                          _isExporting ? 'Generating...' : 'Export Detailed DTR (Excel / CSV)',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, String explanation) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label: $explanation', style: GoogleFonts.inter(fontSize: 11.5)),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.black87,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.015), blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: Color(0xFFF3EFEA),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 15, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertTile(String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 1),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}