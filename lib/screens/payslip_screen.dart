import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class PayslipScreen extends StatefulWidget {
  const PayslipScreen({super.key});

  @override
  State<PayslipScreen> createState() => _PayslipScreenState();
}

class _PayslipScreenState extends State<PayslipScreen> {
  final Map<String, Set<int>> _monthlyWorkDays = {};
  final Map<String, Map<int, String>> _monthlyValeDays = {};
  bool _isLoading = false;

  final List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _fetchPayslipData();
  }

  Future<void> _fetchPayslipData() async {
    setState(() => _isLoading = true);
    try {
      final user = ApiService.currentUser;
      final userId = user?['id']?.toString();
      final userName = (user?['full_name'] ?? user?['name'] ?? '${user?['first_name'] ?? ''} ${user?['last_name'] ?? ''}').toString().trim().toLowerCase();

      final records = await ApiService.getAttendance('ALL');
      final Map<String, Set<int>> workDays = {};

      for (final r in records) {
        final wId = r['worker_id']?.toString();
        final wName = (r['worker_name'] ?? r['name'] ?? '').toString().trim().toLowerCase();
        if (userId != null && wId != null && wId != userId) continue;
        if (userId == null && userName.isNotEmpty && wName.isNotEmpty && !wName.contains(userName) && !userName.contains(wName)) continue;

        final dStr = (r['date'] ?? '').toString();
        final dt = DateTime.tryParse(dStr);
        if (dt != null && (r['status'] == 'Present' || r['status'] == null || r['morningIn'] != null)) {
          final mKey = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
          workDays.putIfAbsent(mKey, () => {}).add(dt.day);
        }
      }

      final Map<String, Map<int, String>> valeDays = {};
      if (userId != null && userId.isNotEmpty) {
        try {
          final vales = await ApiService.getWorkerCashAdvances(userId);
          for (final v in vales) {
            final dStr = (v['date'] ?? '').toString();
            final dt = DateTime.tryParse(dStr);
            if (dt != null) {
              final mKey = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
              final amt = (v['amount'] ?? 0).toString();
              valeDays.putIfAbsent(mKey, () => {})[dt.day] = '₱$amt';
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _monthlyWorkDays.clear();
          _monthlyWorkDays.addAll(workDays);
          _monthlyValeDays.clear();
          _monthlyValeDays.addAll(valeDays);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMonthlyCalendarDialog() {
    DateTime displayedMonth = DateTime(2026, 9, 1);
    int selectedCalendarDay = 17;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final String monthKey =
                '${displayedMonth.year}-${displayedMonth.month.toString().padLeft(2, '0')}';
            final Set<int> currentWorkDays = _monthlyWorkDays[monthKey] ?? {};
            final Map<int, String> currentValeDays = _monthlyValeDays[monthKey] ?? {};

            final int daysInMonth = DateTime(displayedMonth.year, displayedMonth.month + 1, 0).day;
            final int firstWeekdayOffset = DateTime(displayedMonth.year, displayedMonth.month, 1).weekday % 7;
            final int totalCells = daysInMonth + firstWeekdayOffset;

            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // DIALOG HEADER
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Attendance & Vale',
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                  Text(
                                    'Select a day to view details',
                                    style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                              onPressed: () => Navigator.pop(context),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // MONTH CONTROLS
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF8F5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left, size: 20, color: Colors.black87),
                                onPressed: () {
                                  setDialogState(() {
                                    displayedMonth = DateTime(displayedMonth.year, displayedMonth.month - 1, 1);
                                    selectedCalendarDay = 1;
                                  });
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              Text(
                                '${_monthNames[displayedMonth.month - 1]} ${displayedMonth.year}',
                                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right, size: 20, color: Colors.black87),
                                onPressed: () {
                                  setDialogState(() {
                                    displayedMonth = DateTime(displayedMonth.year, displayedMonth.month + 1, 1);
                                    selectedCalendarDay = 1;
                                  });
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // WEEKDAY LABELS
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                              .map((d) => Expanded(
                            child: Text(
                              d,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                            ),
                          ))
                              .toList(),
                        ),
                        const SizedBox(height: 4),

                        // CALENDAR GRID
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: totalCells,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 3,
                            crossAxisSpacing: 3,
                            childAspectRatio: 1.0,
                          ),
                          itemBuilder: (context, index) {
                            if (index < firstWeekdayOffset) return const SizedBox.shrink();

                            final day = index - firstWeekdayOffset + 1;
                            final bool isWork = currentWorkDays.contains(day);
                            final bool hasVale = currentValeDays.containsKey(day);
                            final bool isSelected = selectedCalendarDay == day;

                            return InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () {
                                setDialogState(() {
                                  selectedCalendarDay = day;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFA63228).withValues(alpha: 0.12)
                                      : (isWork ? Colors.green.shade50 : Colors.grey.shade100),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFA63228)
                                        : (hasVale ? const Color(0xFFE8C547) : Colors.transparent),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$day',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        color: isSelected ? const Color(0xFFA63228) : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (isWork)
                                          Container(
                                            width: 3.5,
                                            height: 3.5,
                                            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                          ),
                                        if (isWork && hasVale) const SizedBox(width: 1.5),
                                        if (hasVale)
                                          Container(
                                            width: 3.5,
                                            height: 3.5,
                                            decoration: const BoxDecoration(color: Color(0xFFA63228), shape: BoxShape.circle),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),

                        // LEGEND
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildLegend(Colors.green, 'May Pasok'),
                            _buildLegend(const Color(0xFFA63228), 'Bumale'),
                            _buildLegend(Colors.grey.shade400, 'Walang Pasok'),
                          ],
                        ),
                        const Divider(height: 12),

                        // DETAILS CARD
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF8F5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_monthNames[displayedMonth.month - 1]} $selectedCalendarDay, ${displayedMonth.year} Log:',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currentWorkDays.contains(selectedCalendarDay)
                                    ? '• Attendance: Present (Time In: 07:55 AM | Time Out: 05:05 PM)'
                                    : '• Attendance: Walang naitalang pasok / Rest Day',
                                style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade700),
                              ),
                              Text(
                                currentValeDays.containsKey(selectedCalendarDay)
                                    ? '• Cash Advance: ${currentValeDays[selectedCalendarDay]}'
                                    : '• Cash Advance: Walang binale',
                                style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Payslip & Earnings',
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double horizontalPadding = constraints.maxWidth > 600 ? 20.0 : 12.0;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 550),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ESTIMATE CARD
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA63228),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFA63228).withValues(alpha: 0.2),
                            blurRadius: 6,
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CURRENT CUTOFF ESTIMATE',
                                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 10, letterSpacing: 0.8, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text('— / —', style: GoogleFonts.inter(color: Colors.white, fontSize: 11.5)),
                                ],
                              ),
                              InkWell(
                                onTap: _showMonthlyCalendarDialog,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.calendar_month, color: Colors.white, size: 18),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text('₱ 0.00', style: GoogleFonts.inter(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                          ),
                          const SizedBox(height: 2),
                          Text('Net Payout (After Deductions & Vale)', style: GoogleFonts.inter(color: Colors.white70, fontSize: 10.5)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // EARNINGS SUMMARY
                    _buildSection(
                      title: 'Earnings Summary',
                      children: [
                        _buildRow('Daily Rate', '₱ 0.00'),
                        _buildRow('Days Worked', '₱ 0.00'),
                        _buildRow('Overtime', '₱ 0.00'),
                        _buildRow('Sunday / Special Holiday Pay', '₱ 0.00'),
                        const Divider(height: 12, color: Color(0xFFEEEEEE)),
                        _buildRow('Gross Earnings', '₱ 0.00', isBold: true),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // DEDUCTIONS & VALE
                    _buildSection(
                      title: 'Deductions & Advances',
                      children: [
                        _buildRow('Cash Advance (Vale)', '₱ 0.00', textColor: const Color(0xFFA63228)),
                        _buildRow('SSS Contribution', '₱ 0.00', textColor: const Color(0xFFA63228)),
                        _buildRow('PhilHealth', '₱ 0.00', textColor: const Color(0xFFA63228)),
                        _buildRow('Pag-IBIG', '₱ 0.00', textColor: const Color(0xFFA63228)),
                        const Divider(height: 12, color: Color(0xFFEEEEEE)),
                        _buildRow('Total Deductions', '₱ 0.00', isBold: true, textColor: const Color(0xFFA63228)),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // PAST PAYSLIPS
                    _buildSection(
                      title: 'Past Payslips',
                      children: [
                        Center(child: Text('No past payslips available.', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey))),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 3),
        Text(label, style: GoogleFonts.inter(fontSize: 9.5, color: Colors.grey.shade700)),
      ],
    );
  }

  static Widget _buildSection({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.015), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  static Widget _buildRow(String label, String amount, {bool isBold = false, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: isBold ? Colors.black87 : Colors.grey.shade700,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: textColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }


}