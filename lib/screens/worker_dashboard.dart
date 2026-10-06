import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'worker_attendance_screen.dart';
import 'worker_tools_screen.dart';
import 'worker_salary_screen.dart';
import 'worker_profile_screen.dart';
import '../services/api_service.dart';

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({super.key});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  int _currentNavIndex = 0;
  DateTime _selectedDate = DateTime(2026, 9, 17);
  
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _user = ApiService.currentUser;
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final user = ApiService.currentUser;
    final userId = user?['id']?.toString();
    final userName = (user?['full_name'] ?? user?['name'] ?? '${user?['first_name'] ?? ''} ${user?['last_name'] ?? ''}').toString().trim().toLowerCase();

    // 1. Fetch attendance
    try {
      final records = await ApiService.getAttendance('ALL');
      final todayStr = DateTime.now().toIso8601String().split('T')[0];

      String timeIn = "--:-- AM";
      String timeOut = "--:-- PM";

      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final Map<String, double> dayHours = {for (var d in days) d: 0.0};
      final double dailyRate = (user?['daily_rate'] is num) ? (user!['daily_rate'] as num).toDouble() : 600.0;

      for (final r in records) {
        final wId = r['worker_id']?.toString();
        final wName = (r['worker_name'] ?? r['name'] ?? '').toString().trim().toLowerCase();

        if (userId != null && wId != null && wId != userId) continue;
        if (userId == null && userName.isNotEmpty && wName.isNotEmpty && !wName.contains(userName) && !userName.contains(wName)) continue;

        final dStr = (r['date'] ?? '').toString();
        if (dStr == todayStr) {
          timeIn = (r['morningIn'] ?? r['timeIn'] ?? r['afternoonIn'] ?? "--:-- AM").toString();
          timeOut = (r['afternoonOut'] ?? r['timeOut'] ?? r['morningOut'] ?? "--:-- PM").toString();
        }

        final dt = DateTime.tryParse(dStr);
        if (dt != null) {
          final dayName = days[dt.weekday - 1];
          final hrs = (r['hours'] is num) ? (r['hours'] as num).toDouble() : 8.0;
          dayHours[dayName] = (dayHours[dayName] ?? 0.0) + hrs;
        }
      }

      final List<Map<String, dynamic>> weekly = days.map((d) {
        final hrs = dayHours[d] ?? 0.0;
        final earn = (hrs / 8.0) * dailyRate;
        return {
          'day': d,
          'hours': hrs,
          'earnings': earn,
          'labelHours': hrs > 0 ? '${hrs.toStringAsFixed(0)}h' : '0h',
          'labelEarnings': earn > 0 ? '₱${earn.toStringAsFixed(0)}' : '₱0',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _timeIn = timeIn;
          _timeOut = timeOut;
          _weeklyData.clear();
          _weeklyData.addAll(weekly);
        });
      }
    } catch (_) {}

    // 2. Fetch cash advances
    if (userId != null && userId.isNotEmpty) {
      try {
        final vales = await ApiService.getWorkerCashAdvances(userId);
        if (vales.isNotEmpty && mounted) {
          final latest = vales.first;
          final amt = (latest['amount'] ?? 0).toString();
          final st = (latest['status'] ?? 'Pending').toString();
          setState(() {
            _cashAdvance = "₱ $amt";
            _caStatus = st;
          });
        }
      } catch (_) {}
    }

    // 3. Fetch borrowed tools
    try {
      final tools = await ApiService.getBorrowHistory('ALL');
      final List<Map<String, String>> myTools = [];
      for (final t in tools) {
        final bId = t['worker_id']?.toString();
        final bName = (t['borrower_name'] ?? t['borrower'] ?? '').toString().trim().toLowerCase();
        if (userId != null && bId != null && bId != userId) continue;
        if (userId == null && userName.isNotEmpty && bName.isNotEmpty && !bName.contains(userName) && !userName.contains(bName)) continue;

        if (t['action'] == 'Borrowed' || t['status'] == 'In Use') {
          myTools.add({
            'name': (t['tool_name'] ?? t['name'] ?? 'Tool').toString(),
            'status': 'In Use',
          });
        }
      }
      if (mounted) {
        setState(() {
          _borrowedTools.clear();
          _borrowedTools.addAll(myTools);
        });
      }
    } catch (_) {}
  }

  String _timeIn = "--:-- AM";
  String _timeOut = "--:-- PM";
  String _cashAdvance = "₱ 0.00";
  String _caStatus = "None";

  // State para sa Graph Toggle ('hours' o 'earnings')
  String _selectedGraphMetric = 'hours';

  final List<Map<String, String>> _adminNotifications = [];

  final List<Map<String, String>> _borrowedTools = [];

  final List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  final List<Map<String, dynamic>> _weeklyData = [];

  void _showNotificationDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 480),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFA63228).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.notifications_active_outlined, color: Color(0xFFA63228), size: 16),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Broadcast Alerts',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Direct messages transmitted from Admin console',
                  style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade600),
                ),
                const Divider(height: 14),
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _adminNotifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final notif = _adminNotifications[index];
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF8F5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFA63228).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    notif['tag']!,
                                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFA63228)),
                                  ),
                                ),
                                Text(
                                  notif['time']!,
                                  style: GoogleFonts.inter(fontSize: 9.5, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notif['title']!,
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              notif['body']!,
                              style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade700, height: 1.3),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _pickDate(BuildContext context) {
    DateTime tempMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    DateTime tempPicked = _selectedDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final int daysInMonth = DateTime(tempMonth.year, tempMonth.month + 1, 0).day;
            final int offset = DateTime(tempMonth.year, tempMonth.month, 1).weekday % 7;
            final int totalGridCells = daysInMonth + offset;

            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left, size: 20),
                            onPressed: () {
                              setDialogState(() {
                                tempMonth = DateTime(tempMonth.year, tempMonth.month - 1, 1);
                              });
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          Text(
                            '${_months[tempMonth.month - 1]} ${tempMonth.year}',
                            style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, size: 20),
                            onPressed: () {
                              setDialogState(() {
                                tempMonth = DateTime(tempMonth.year, tempMonth.month + 1, 1);
                              });
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                            .map((d) => SizedBox(
                          width: 28,
                          child: Text(
                            d,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
                          ),
                        ))
                            .toList(),
                      ),
                      const SizedBox(height: 6),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: totalGridCells,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                          childAspectRatio: 1.0,
                        ),
                        itemBuilder: (context, index) {
                          if (index < offset) return const SizedBox.shrink();
                          final day = index - offset + 1;
                          final date = DateTime(tempMonth.year, tempMonth.month, day);
                          final isSelected = date.year == tempPicked.year &&
                              date.month == tempPicked.month &&
                              date.day == tempPicked.day;

                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              setDialogState(() {
                                tempPicked = date;
                              });
                            },
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFA63228) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$day',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Cancel', style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFA63228),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedDate = tempPicked;
                                if (tempPicked.day % 2 == 0) {
                                  _timeIn = "--:-- AM";
                                  _timeOut = "--:-- PM";
                                  _cashAdvance = "₱ 0.00";
                                  _caStatus = "None";
                                } else {
                                  _timeIn = "--:-- AM";
                                  _timeOut = "--:-- PM";
                                  _cashAdvance = "₱ 0.00";
                                  _caStatus = "None";
                                }
                              });
                              Navigator.pop(context);
                            },
                            child: Text('Apply', style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showRequestValeDialog() {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();
    final List<String> quickAmounts = ['500', '1000', '1500'];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    Text(
                      'Request Cash Advance',
                      style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.black87),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Text(
                  'Submitted directly to site admin for cutoff review',
                  style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                Row(
                  children: quickAmounts.map((amt) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => amountController.text = amt,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3EF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            '₱$amt',
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFFAF8F5),
                    isDense: true,
                    prefixText: '₱ ',
                    prefixStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFFA63228)),
                    hintText: 'Enter amount',
                    hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontWeight: FontWeight.normal, fontSize: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFA63228), width: 1.5)),
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
                    hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 11),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFA63228), width: 1.5)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel', style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA63228),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          final amount = double.tryParse(amountController.text) ?? 0.0;
                          final reason = reasonController.text.trim();
                          
                          if (amount <= 0 || reason.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter valid amount and reason')),
                            );
                            return;
                          }

                          try {
                            final user = ApiService.currentUser;
                            final workerName = user?['name'] ?? user?['full_name'] ?? 
                                '${user?['firstName'] ?? user?['first_name'] ?? ''} ${user?['lastName'] ?? user?['last_name'] ?? ''}'.trim();
                            final dateStr = DateTime.now().toIso8601String().split('T')[0];

                            await ApiService.createCashAdvance({
                              'project_id': 1, // Defaulting to 1 for now if worker project is unknown
                              'workerId': user?['id'],
                              'workerName': workerName.isNotEmpty ? workerName : 'Worker',
                              'amount': amount,
                              'reason': reason,
                              'date': dateStr,
                              'status': 'Pending',
                            });
                            
                            if (mounted) {
                              setState(() {
                                _cashAdvance = '₱ ${amount.toStringAsFixed(2)}';
                                _caStatus = 'Pending';
                              });
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Vale request submitted to Admin portal')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to request vale: $e')),
                              );
                            }
                          }
                        },
                        child: Text('Submit Vale', style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.bold)),
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

  String _getFormattedDate(DateTime date) {
    return "${_months[date.month - 1]} ${date.day}, ${date.year}";
  }

  Widget _buildHomeView(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final String greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
    final workerName = _user?['name'] ?? _user?['full_name'] ??
        ((_user?['firstName'] ?? _user?['first_name']) != null
            ? '${_user!['firstName'] ?? _user!['first_name']} ${_user!['lastName'] ?? _user!['last_name']}'
            : 'Worker');
    final firstName = workerName.split(' ').first;

    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 44,
        title: Image.asset('assets/logo.png', height: 24),
        centerTitle: true,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: Colors.black87, size: 22),
                onPressed: _showNotificationDialog,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFA63228),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double hp = constraints.maxWidth > 600 ? 20.0 : 12.0;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 550),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(hp, 8, hp, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── HERO GREETING CARD ──────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFA63228), Color(0xFFD94F3D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
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
                                    greeting,
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.white.withValues(alpha: 0.8),
                                        fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    firstName,
                                    style: GoogleFonts.inter(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: const BoxDecoration(color: Color(0xFF7CFC00), shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 5),
                                    Text('On Site',
                                        style: GoogleFonts.inter(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Stats Row
                          Row(
                            children: [
                              _buildHeroStat(Icons.schedule_rounded, 'Time In', _timeIn == '--:-- AM' ? '—' : _timeIn),
                              Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.25), margin: const EdgeInsets.symmetric(horizontal: 12)),
                              _buildHeroStat(Icons.logout_rounded, 'Time Out', _timeOut == '--:-- PM' ? '—' : _timeOut),
                              Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.25), margin: const EdgeInsets.symmetric(horizontal: 12)),
                              _buildHeroStat(Icons.today_rounded, 'Today', '${_months[now.month - 1]} ${now.day}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── QUICK ACTIONS ────────────────────────────────────
                    Row(
                      children: [
                        _buildQuickAction(
                          icon: Icons.access_time_filled,
                          label: 'Attendance',
                          color: const Color(0xFF2563EB),
                          onTap: () => setState(() => _currentNavIndex = 1),
                        ),
                        const SizedBox(width: 8),
                        _buildQuickAction(
                          icon: Icons.handyman_rounded,
                          label: 'Tools',
                          color: const Color(0xFF059669),
                          onTap: () => setState(() => _currentNavIndex = 2),
                        ),
                        const SizedBox(width: 8),
                        _buildQuickAction(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Salary',
                          color: const Color(0xFFD97706),
                          onTap: () => setState(() => _currentNavIndex = 3),
                        ),
                        const SizedBox(width: 8),
                        _buildQuickAction(
                          icon: Icons.person_rounded,
                          label: 'Profile',
                          color: const Color(0xFF7C3AED),
                          onTap: () => setState(() => _currentNavIndex = 4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ── DAILY RECORD SECTION HEADER ───────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Daily Record',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        InkWell(
                          onTap: () => _pickDate(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.today_rounded, size: 13, color: Color(0xFFA63228)),
                                const SizedBox(width: 4),
                                Text(
                                  _getFormattedDate(_selectedDate),
                                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.black87),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Colors.black54),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ── ATTENDANCE LOG ────────────────────────────────────
                    Container(
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
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TERMINAL ATTENDANCE',
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade600, letterSpacing: 0.5),
                              ),
                              Text(
                                'Operator: Mark',
                                style: GoogleFonts.inter(fontSize: 9.5, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                          const Divider(height: 14, color: Color(0xFFEEEEEE)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    Text('TIME IN', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(_timeIn, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.green.shade700)),
                                    ),
                                  ],
                                ),
                              ),
                              Container(height: 24, width: 1, color: Colors.grey.shade200),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text('TIME OUT', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(_timeOut, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── WEEKLY PERFORMANCE CHART ──────────────────────────
                    Container(
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Weekly Performance',
                                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF8F5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => setState(() => _selectedGraphMetric = 'hours'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _selectedGraphMetric == 'hours' ? const Color(0xFFA63228) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Hours',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: _selectedGraphMetric == 'hours' ? Colors.white : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => setState(() => _selectedGraphMetric = 'earnings'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _selectedGraphMetric == 'earnings' ? const Color(0xFFA63228) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Earnings',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: _selectedGraphMetric == 'earnings' ? Colors.white : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _weeklyData.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Text('No weekly data available',
                                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: _weeklyData.map((data) {
                                    final bool isHours = _selectedGraphMetric == 'hours';
                                    final double value = isHours ? data['hours'] : data['earnings'];
                                    final double maxValue = isHours ? 10.0 : 700.0;
                                    final double barHeight = (value / maxValue) * 70;

                                    return Column(
                                      children: [
                                        Text(
                                          isHours ? data['labelHours'] : data['labelEarnings'],
                                          style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          width: 22,
                                          height: barHeight > 10 ? barHeight : 10,
                                          decoration: BoxDecoration(
                                            color: data['day'] == 'Thu' ? const Color(0xFFA63228) : const Color(0xFFA63228).withValues(alpha: 0.25),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          data['day'],
                                          style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.black87),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── CASH ADVANCE (VALE) CARD ─────────────────────────
                    Container(
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'CASH ADVANCE (VALE)',
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade600, letterSpacing: 0.5),
                              ),
                              InkWell(
                                onTap: _showRequestValeDialog,
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFA63228).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.add, size: 14, color: Color(0xFFA63228)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Requested Total', style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade500)),
                                  const SizedBox(height: 2),
                                  Text(_cashAdvance, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _caStatus == 'Approved' ? Colors.green.shade50 : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _caStatus == 'Approved' ? Colors.green.shade200 : Colors.grey.shade300),
                                ),
                                child: Text(
                                  _caStatus,
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: _caStatus == 'Approved' ? Colors.green.shade700 : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── ISSUED TOOLS CARD ─────────────────────────────────
                    Container(
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ISSUED TOOLS (${_borrowedTools.length})',
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade600, letterSpacing: 0.5),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _currentNavIndex = 2),
                                child: Text(
                                  'See All →',
                                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFA63228), fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _borrowedTools.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text('No tools currently issued',
                                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _borrowedTools.length,
                                  separatorBuilder: (_, __) => Divider(height: 10, color: Colors.grey.shade100),
                                  itemBuilder: (context, index) {
                                    final tool = _borrowedTools[index];
                                    return Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                tool['name']!,
                                                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.black87),
                                              ),
                                              Text(
                                                '${tool['code']} · Assigned ${tool['time']}',
                                                style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.orange.shade200),
                                          ),
                                          child: Text(
                                            tool['status']!,
                                            style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                                          ),
                                        ),
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
        },
      ),
    );
  }

  Widget _buildHeroStat(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: Colors.white.withValues(alpha: 0.7)),
              const SizedBox(width: 3),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 9.5,
                      color: Colors.white.withValues(alpha: 0.75))),
            ],
          ),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1)),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(height: 5),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentNavIndex,
        children: [
          _buildHomeView(context),
          const WorkerAttendanceScreen(),
          const WorkerToolsScreen(),
          const WorkerSalaryScreen(),
          const WorkerProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          setState(() {
            _currentNavIndex = index;
          });
        },
        selectedItemColor: const Color(0xFFA63228),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.normal),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time_outlined),
            activeIcon: Icon(Icons.access_time_filled),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.handyman_outlined),
            activeIcon: Icon(Icons.handyman_rounded),
            label: 'Tools',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Salary',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}