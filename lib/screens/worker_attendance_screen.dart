import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/worker_app_header.dart';

class WorkerAttendanceScreen extends StatefulWidget {
  const WorkerAttendanceScreen({super.key});

  @override
  State<WorkerAttendanceScreen> createState() => _WorkerAttendanceScreenState();
}

class _WorkerAttendanceScreenState extends State<WorkerAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _loadError;
  List<Map<String, dynamic>> _attendanceLogs = [];
  List<Map<String, dynamic>> _earlyOutRequests = [];
  bool _isLoadingRequests = false;
  String? _requestError;
  String _attendancePeriod = 'This cutoff';
  String _attendanceStatusFilter = 'All statuses';
  String _requestPeriod = 'All time';
  String _requestStatusFilter = 'All statuses';

  static const _periodFilters = ['This cutoff', 'This month', 'All time'];

  bool get _canManageAttendance {
    final role = (ApiService.currentUserRole ?? '').trim().toLowerCase();
    final user = ApiService.currentUser;
    final positions = [
      user?['position'],
      user?['positions'],
      user?['role'],
      user?['roles'],
    ].where((value) => value != null).join(' ').toLowerCase();
    return role == 'admin' ||
        role == 'staff' ||
        (role == 'worker' && positions.contains('attendance monitoring'));
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAttendance();
    _loadEarlyOutRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAttendance() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final data = await ApiService.getAttendance('ALL');
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
      final userNames = <String>{
        user?['name']?.toString() ?? '',
        user?['full_name']?.toString() ?? '',
        [
              user?['first_name'] ?? user?['firstName'],
              user?['middle_name'] ?? user?['middleName'],
              user?['last_name'] ?? user?['lastName'],
            ]
            .where((part) => part != null && part.toString().trim().isNotEmpty)
            .join(' '),
      }.map(_normalizeIdentity).where((name) => name.isNotEmpty).toSet();

      if (mounted) {
        setState(() {
          _attendanceLogs =
              List<Map<String, dynamic>>.from(data).where((r) {
                final recordIds =
                    {r['worker_id'], r['workerId'], r['employee_id']}
                        .where(
                          (value) =>
                              value != null &&
                              value.toString().trim().isNotEmpty,
                        )
                        .map((value) => value.toString().trim())
                        .toSet();
                if (recordIds.any(userIds.contains)) return true;

                final recordName = _normalizeIdentity(
                  r['worker_name'] ?? r['name'],
                );
                if (recordName.isNotEmpty && userNames.contains(recordName)) {
                  return true;
                }
                return false;
              }).toList()..sort((a, b) {
                return (_recordDate(
                      b,
                    )?.compareTo(_recordDate(a) ?? DateTime(0)) ??
                    0);
              });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadError = 'Unable to load attendance history: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _normalizeIdentity(dynamic value) {
    return (value ?? '').toString().trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
  }

  Future<void> _loadEarlyOutRequests() async {
    final user = ApiService.currentUser;
    final workerId = user?['id'] ?? user?['worker_id'];
    if (workerId == null) {
      setState(() {
        _requestError = 'Worker account ID is unavailable.';
      });
      return;
    }
    setState(() {
      _isLoadingRequests = true;
      _requestError = null;
    });
    try {
      final requests = await ApiService.getEarlyOutRequests(workerId: workerId);
      if (!mounted) return;
      setState(() {
        _earlyOutRequests = requests
            .map((request) => Map<String, dynamic>.from(request as Map))
            .toList();
      });
    } catch (error) {
      if (mounted) setState(() => _requestError = error.toString());
    } finally {
      if (mounted) setState(() => _isLoadingRequests = false);
    }
  }

  DateTime get _cutoffStart {
    final today = DateTime.now();
    return DateTime(today.year, today.month, today.day <= 15 ? 1 : 16);
  }

  DateTime get _cutoffEnd {
    final today = DateTime.now();
    if (today.day <= 15) return DateTime(today.year, today.month, 15);
    return DateTime(today.year, today.month + 1, 0);
  }

  List<Map<String, dynamic>> get _currentCutoffLogs {
    return _attendanceLogs.where((record) {
      final date = _recordDate(record);
      return date != null &&
          !date.isBefore(_cutoffStart) &&
          !date.isAfter(_cutoffEnd);
    }).toList();
  }

  DateTime? _recordDate(Map<String, dynamic> record) {
    final rawDate = record['date']?.toString();
    if (rawDate == null || rawDate.trim().isEmpty) return null;
    final datePart = rawDate.contains('T')
        ? rawDate.split('T').first
        : rawDate.split(' ').first;
    return DateTime.tryParse(datePart);
  }

  bool _isWithinPeriod(DateTime? date, String period) {
    if (date == null || period == 'All time') return date != null;
    final now = DateTime.now();
    if (period == 'This month') {
      return date.year == now.year && date.month == now.month;
    }
    return !date.isBefore(_cutoffStart) && !date.isAfter(_cutoffEnd);
  }

  List<Map<String, dynamic>> get _filteredAttendanceLogs {
    return _attendanceLogs.where((record) {
      if (!_isWithinPeriod(_recordDate(record), _attendancePeriod)) {
        return false;
      }
      if (_attendanceStatusFilter == 'All statuses') return true;
      return _normalizeStatus(record['status']) ==
          _normalizeStatus(_attendanceStatusFilter);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredEarlyOutRequests {
    return _earlyOutRequests.where((request) {
      final date = _recordDate(request);
      if (!_isWithinPeriod(date, _requestPeriod)) return false;
      if (_requestStatusFilter == 'All statuses') return true;
      return _normalizeStatus(request['status']) ==
          _normalizeStatus(_requestStatusFilter);
    }).toList();
  }

  String _normalizeStatus(dynamic value) {
    return (value ?? 'Present').toString().trim().toLowerCase().replaceAll(
      RegExp(r'[\s_-]+'),
      '',
    );
  }

  double get _cutoffWorkingHours {
    return _currentCutoffLogs.fold<double>(
      0,
      (total, record) => total + _workingHours(record),
    );
  }

  String _formatHours(double value) {
    final totalMinutes = (value * 60).round();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '$hours hour/s, $minutes min/s';
  }

  int? _parseTimeMinutes(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty || value == '—' || value == '--:--') return null;
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)?$',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) return null;
    var hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || minute > 59) return null;
    final meridiem = match.group(3)?.toUpperCase();
    if (meridiem != null) {
      if (hour < 1 || hour > 12) return null;
      hour = hour % 12 + (meridiem == 'PM' ? 12 : 0);
    } else if (hour > 23) {
      return null;
    }
    return hour * 60 + minute;
  }

  dynamic _firstTimeValue(Map<String, dynamic> record, List<String> keys) {
    for (final key in keys) {
      final value = record[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text != '—' && text != '--:--') return value;
    }
    return null;
  }

  double _workingHours(Map<String, dynamic> record) {
    final status = _normalizeStatus(record['status']);
    if (status == 'absent') return 0;

    final sessions = [
      (
        _firstTimeValue(record, const ['morning_in', 'morningIn']),
        _firstTimeValue(record, const ['morning_out', 'morningOut']),
      ),
      (
        _firstTimeValue(record, const ['afternoon_in', 'afternoonIn']),
        _firstTimeValue(record, const ['afternoon_out', 'afternoonOut']),
      ),
    ];
    var totalMinutes = 0;
    var foundSessionPair = false;
    for (final (rawIn, rawOut) in sessions) {
      final start = _parseTimeMinutes(rawIn);
      final end = _parseTimeMinutes(rawOut);
      if (start == null || end == null) continue;
      foundSessionPair = true;
      var duration = end - start;
      if (duration < 0) duration += 24 * 60;
      if (duration > 0 && duration < 24 * 60) totalMinutes += duration;
    }
    if (foundSessionPair) return totalMinutes / 60;

    final start = _parseTimeMinutes(
      _firstTimeValue(record, const ['time_in', 'timeIn']),
    );
    final end = _parseTimeMinutes(
      _firstTimeValue(record, const ['time_out', 'timeOut']),
    );
    if (start != null && end != null) {
      var duration = end - start;
      if (duration < 0) duration += 24 * 60;
      if (duration > 0 && duration < 24 * 60) return duration / 60;
    }

    final recorded = record['hours_worked'] ?? record['hours'];
    if (recorded is num) return recorded.toDouble().clamp(0, 24).toDouble();
    return double.tryParse(
          recorded?.toString() ?? '',
        )?.clamp(0, 24).toDouble() ??
        0;
  }

  String _displayWorkingHours(Map<String, dynamic> record) {
    if (_normalizeStatus(record['status']) == 'absent') {
      return _formatHours(0);
    }
    final explicitHours = record['hours_worked'] ?? record['hours'];
    if (explicitHours != null &&
        explicitHours.toString().trim().isNotEmpty &&
        explicitHours.toString() != '—') {
      return _formatHours(_workingHours(record));
    }
    final hasAnyTime = [
      'morning_in',
      'morningIn',
      'morning_out',
      'morningOut',
      'afternoon_in',
      'afternoonIn',
      'afternoon_out',
      'afternoonOut',
      'time_in',
      'timeIn',
      'time_out',
      'timeOut',
    ].any((key) => _parseTimeMinutes(record[key]) != null);
    final hours = _workingHours(record);
    return hasAnyTime && hours > 0 ? _formatHours(hours) : '— hour/s, — min/s';
  }

  String _formatAttendanceTime(dynamic raw) {
    final minutes = _parseTimeMinutes(raw);
    if (minutes == null) return '—';
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  Widget _buildAttendanceRecordCard({
    required String date,
    required String day,
    required String timeIn,
    required String timeOut,
    required String status,
    required String hours,
    required String overtime,
  }) {
    final normalizedStatus = status.toLowerCase();
    final statusColor = normalizedStatus.contains('absent')
        ? const Color(0xFFB42318)
        : normalizedStatus.contains('late')
        ? const Color(0xFFB76E00)
        : const Color(0xFF26734D);
    final statusBackground = normalizedStatus.contains('absent')
        ? const Color(0xFFFFEFED)
        : normalizedStatus.contains('late')
        ? const Color(0xFFFFF5E5)
        : const Color(0xFFEAF6EF);
    final dateParts = date.split(' ');
    final month = dateParts.isNotEmpty ? dateParts.first : '';
    final dayNumber = dateParts.length > 1
        ? dateParts[1].replaceAll(',', '')
        : '';
    final hasOvertime = overtime != '0' && overtime.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFECE9E7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF25212A).withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9EEEC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      day,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFA63228),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      dayNumber,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF28242A),
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF28242A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$month attendance',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: const Color(0xFF89868D),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: statusBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF0EEEC)),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _attendanceTimeColumn(
                  icon: Icons.login_rounded,
                  label: 'TIME IN',
                  value: timeIn,
                ),
              ),
              Container(width: 1, height: 30, color: const Color(0xFFECE9E7)),
              Expanded(
                child: _attendanceTimeColumn(
                  icon: Icons.logout_rounded,
                  label: 'TIME OUT',
                  value: timeOut,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F6),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 15,
                  color: Color(0xFF68656B),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    hours,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3B383E),
                    ),
                  ),
                ),
                if (hasOvertime) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF2D8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'OT $overtime hr',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF996000),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _attendanceTimeColumn({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: const Color(0xFFA63228)),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: const Color(0xFF89868D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF353239),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters({
    required String period,
    required String status,
    required ValueChanged<String?> onPeriodChanged,
    required ValueChanged<String?> onStatusChanged,
    required List<String> statuses,
    required double horizontalPadding,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 10, horizontalPadding, 2),
      child: Row(
        children: [
          Expanded(
            child: _filterDropdown(
              value: period,
              values: _periodFilters,
              label: 'Date range',
              onChanged: onPeriodChanged,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _filterDropdown(
              value: status,
              values: statuses,
              label: 'Status',
              onChanged: onStatusChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown({
    required String value,
    required List<String> values,
    required String label,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          fontSize: 10,
          color: const Color(0xFF85838A),
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE9E6E4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE9E6E4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFA63228), width: 1.4),
        ),
      ),
      style: GoogleFonts.inter(
        fontSize: 12,
        color: Colors.black87,
        fontWeight: FontWeight.w700,
      ),
      items: values
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
    );
  }

  int get _daysWorked {
    return _currentCutoffLogs.where((record) {
      final status = (record['status'] ?? 'Present').toString().toLowerCase();
      return !status.contains('absent');
    }).length;
  }

  int get _lateOrAbsentCount {
    return _currentCutoffLogs.where((record) {
      final status = (record['status'] ?? '').toString().toLowerCase();
      return status.contains('late') || status.contains('absent');
    }).length;
  }

  String get _overtimeTotal {
    final total = _currentCutoffLogs.fold<double>(0, (sum, record) {
      final value = record['overtime_hours'];
      if (value is num) return sum + value.toDouble();
      return sum + (double.tryParse(value?.toString() ?? '') ?? 0);
    });
    return _formatHours(total);
  }

  Widget _buildAttendanceSummary() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFA63228), Color(0xFF681D18)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA63228).withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Attendance summary',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'THIS CUTOFF',
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'TOTAL WORK HOURS',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatHours(_cutoffWorkingHours),
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.18)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildSummaryStat(
                  'Days worked',
                  '$_daysWorked',
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              Expanded(
                child: _buildSummaryStat(
                  'Overtime',
                  _overtimeTotal,
                  icon: Icons.bolt_rounded,
                ),
              ),
              Expanded(
                child: _buildSummaryStat(
                  'Late / absent',
                  '$_lateOrAbsentCount',
                  icon: Icons.schedule_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(
    String label,
    String value, {
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.76)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.76),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEarlyOutDialog() async {
    final TextEditingController reasonController = TextEditingController();
    String selectedReason = 'Medical / Health';
    TimeOfDay requestedOutTime = const TimeOfDay(hour: 15, minute: 30);
    bool isSubmitting = false;
    final List<String> reasons = [
      'Medical / Health',
      'Family Emergency',
      'Personal Errand',
      'Doctor Appointment',
      'Other',
    ];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
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
                            'Request Early Out',
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'Requires admin approval',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.grey,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Requested Time Out',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: requestedOutTime,
                              builder: (context, child) => Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFFA63228),
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                    onSurface: Colors.black87,
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setDialogState(() => requestedOutTime = picked);
                            }
                          },
                    icon: const Icon(Icons.access_time, size: 16),
                    label: Text(
                      requestedOutTime.format(context),
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Reason',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: reasons.map((r) {
                      final isSelected = selectedReason == r;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedReason = r),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFA63228)
                                : const Color(0xFFF5F3EF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFA63228)
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            r,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    style: GoogleFonts.inter(fontSize: 12),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFFAF8F5),
                      isDense: true,
                      hintText: 'Additional details (optional)',
                      hintStyle: GoogleFonts.inter(
                        color: Colors.grey.shade400,
                        fontSize: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
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
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          onPressed: () => Navigator.pop(context),
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
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final user = ApiService.currentUser;
                                  final workerId =
                                      user?['id'] ?? user?['worker_id'];
                                  final workerName =
                                      (user?['name'] ??
                                              user?['full_name'] ??
                                              '${user?['first_name'] ?? ''} ${user?['last_name'] ?? ''}')
                                          .toString()
                                          .trim();
                                  if (workerId == null || workerName.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Your worker profile is missing an ID or name. Please contact an administrator.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  setDialogState(() => isSubmitting = true);
                                  try {
                                    final now = DateTime.now();
                                    await ApiService.submitEarlyOutRequest({
                                      'worker_id': workerId.toString(),
                                      'worker_name': workerName,
                                      'date':
                                          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
                                      'requested_out_time':
                                          '${requestedOutTime.hour.toString().padLeft(2, '0')}:${requestedOutTime.minute.toString().padLeft(2, '0')}',
                                      'reason': selectedReason,
                                      'details': reasonController.text.trim(),
                                    });
                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                    await _loadEarlyOutRequests();
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Early-out request submitted: $selectedReason',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                          ),
                                        ),
                                        backgroundColor: const Color(
                                          0xFFA63228,
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    );
                                  } catch (error) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Unable to submit request: $error',
                                        ),
                                      ),
                                    );
                                  } finally {
                                    if (context.mounted) {
                                      setDialogState(
                                        () => isSubmitting = false,
                                      );
                                    }
                                  }
                                },
                          child: Text(
                            isSubmitting ? 'Submitting...' : 'Submit Request',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
    reasonController.dispose();
  }

  String _formatDate(String? raw) {
    if (raw == null) return '—';
    try {
      final datePart = raw.contains('T')
          ? raw.split('T')[0]
          : raw.split(' ')[0];
      final parts = datePart.split('-');
      if (parts.length < 3) return raw;
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
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (m == null || d == null) return raw;
      return '${months[m - 1]} $d, ${parts[0]}';
    } catch (_) {
      return raw;
    }
  }

  String _dayOfWeek(String? raw) {
    if (raw == null) return '—';
    try {
      final datePart = raw.contains('T')
          ? raw.split('T')[0]
          : raw.split(' ')[0];
      final dt = DateTime.parse(datePart);
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F4),
      appBar: WorkerAppHeader(
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFFA63228),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFFA63228),
                indicatorWeight: 3,
                labelStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
                tabs: const [
                  Tab(text: 'Attendance History'),
                  Tab(text: 'Requests'),
                ],
              ),
            ),
          ),
        ),
      ),
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
                        // --- TAB 1: ATTENDANCE HISTORY ---
                        RefreshIndicator(
                          color: const Color(0xFFA63228),
                          onRefresh: _loadAttendance,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: EdgeInsets.fromLTRB(
                              hp,
                              14,
                              hp,
                              _canManageAttendance ? 100 : 14,
                            ),
                            itemCount: _filteredAttendanceLogs.isEmpty
                                ? 3
                                : _filteredAttendanceLogs.length + 2,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final contentIndex = i;
                              if (contentIndex == 0) {
                                return _buildAttendanceSummary();
                              }
                              if (contentIndex == 1) {
                                return _buildFilters(
                                  period: _attendancePeriod,
                                  status: _attendanceStatusFilter,
                                  statuses: const [
                                    'All statuses',
                                    'Present',
                                    'Full day',
                                    'Late',
                                    'Halfday',
                                    'Absent',
                                  ],
                                  horizontalPadding: 0,
                                  onPeriodChanged: (value) {
                                    if (value != null) {
                                      setState(() => _attendancePeriod = value);
                                    }
                                  },
                                  onStatusChanged: (value) {
                                    if (value != null) {
                                      setState(
                                        () => _attendanceStatusFilter = value,
                                      );
                                    }
                                  },
                                );
                              }
                              if (_filteredAttendanceLogs.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 40,
                                  ),
                                  child: Column(
                                    children: [
                                      _buildEmptyMessage(
                                        _loadError != null
                                            ? Icons.cloud_off_outlined
                                            : _attendanceLogs.isEmpty
                                            ? Icons.event_note_outlined
                                            : Icons.filter_list_off,
                                        _loadError != null
                                            ? 'Could not load attendance history'
                                            : _attendanceLogs.isEmpty
                                            ? 'No attendance records yet'
                                            : 'No matching attendance',
                                        _loadError ??
                                            (_attendanceLogs.isEmpty
                                                ? 'Your attendance logs will appear here once recorded by the timekeeper.'
                                                : 'Try another date range or status filter.'),
                                      ),
                                      if (_loadError != null) ...[
                                        const SizedBox(height: 12),
                                        OutlinedButton.icon(
                                          onPressed: _loadAttendance,
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('Try again'),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }
                              final record =
                                  _filteredAttendanceLogs[contentIndex - 2];
                              final dateStr = _formatDate(
                                record['date']?.toString(),
                              );
                              final day = _dayOfWeek(
                                record['date']?.toString(),
                              );
                              final timeIn = _formatAttendanceTime(
                                _firstTimeValue(record, const [
                                  'time_in',
                                  'timeIn',
                                  'morning_in',
                                  'morningIn',
                                  'afternoon_in',
                                  'afternoonIn',
                                ]),
                              );
                              final timeOut = _formatAttendanceTime(
                                _firstTimeValue(record, const [
                                  'time_out',
                                  'timeOut',
                                  'afternoon_out',
                                  'afternoonOut',
                                  'morning_out',
                                  'morningOut',
                                ]),
                              );
                              final status =
                                  record['status']?.toString() ?? 'Present';
                              final hours = _displayWorkingHours(record);
                              final ot =
                                  record['overtime_hours']?.toString() ?? '0';

                              return _buildAttendanceRecordCard(
                                date: dateStr,
                                day: day,
                                timeIn: timeIn,
                                timeOut: timeOut,
                                status: status,
                                hours: hours,
                                overtime: ot,
                              );
                            },
                          ),
                        ),

                        // --- TAB 2: REQUESTS ---
                        _buildEarlyOutRequests(hp),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: _showEarlyOutDialog,
            backgroundColor: const Color(0xFFA63228),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            icon: const Icon(
              Icons.exit_to_app_rounded,
              size: 18,
              color: Colors.white,
            ),
            label: Text(
              'Early Out',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          if (_canManageAttendance) ...[
            const SizedBox(height: 10),
            FloatingActionButton.extended(
              onPressed: () =>
                  Navigator.pushNamed(context, '/attendance_management'),
              backgroundColor: const Color(0xFFA63228),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              icon: const Icon(
                Icons.fact_check_rounded,
                size: 18,
                color: Colors.white,
              ),
              label: Text(
                'Attendance Management',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEarlyOutRequests(double horizontalPadding) {
    if (_isLoadingRequests) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFA63228)),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFA63228),
      onRefresh: _loadEarlyOutRequests,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 10,
        ),
        itemCount: _filteredEarlyOutRequests.isEmpty
            ? 2
            : _filteredEarlyOutRequests.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildFilters(
              period: _requestPeriod,
              status: _requestStatusFilter,
              statuses: const [
                'All statuses',
                'Pending',
                'Approved',
                'Rejected',
              ],
              horizontalPadding: 0,
              onPeriodChanged: (value) {
                if (value != null) setState(() => _requestPeriod = value);
              },
              onStatusChanged: (value) {
                if (value != null) setState(() => _requestStatusFilter = value);
              },
            );
          }
          if (_filteredEarlyOutRequests.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  _buildEmptyMessage(
                    _requestError != null
                        ? Icons.cloud_off_outlined
                        : _earlyOutRequests.isEmpty
                        ? Icons.inbox_outlined
                        : Icons.filter_list_off,
                    _requestError != null
                        ? 'Unable to load requests'
                        : _earlyOutRequests.isEmpty
                        ? 'No early-out requests yet'
                        : 'No matching requests',
                    _requestError ??
                        (_earlyOutRequests.isEmpty
                            ? 'Your early-out requests will appear here once submitted.'
                            : 'Try another date range or status filter.'),
                  ),
                  if (_requestError != null)
                    TextButton.icon(
                      onPressed: _loadEarlyOutRequests,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                ],
              ),
            );
          }

          final request = _filteredEarlyOutRequests[index - 1];
          final status = (request['status'] ?? 'Pending').toString();
          final color = status == 'Approved'
              ? Colors.green.shade700
              : status == 'Rejected'
              ? Colors.red.shade700
              : Colors.orange.shade800;
          final background = status == 'Approved'
              ? Colors.green.shade50
              : status == 'Rejected'
              ? Colors.red.shade50
              : Colors.orange.shade50;
          final details = (request['details'] ?? '').toString().trim();
          final rejectionReason = (request['rejection_reason'] ?? '')
              .toString()
              .trim();
          return Container(
            padding: const EdgeInsets.all(14),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.exit_to_app_rounded,
                      color: Color(0xFFA63228),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatDate(request['date']?.toString()),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.inter(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Requested time out: ${_formatAttendanceTime(request['requested_out_time'])}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Reason: ${request['reason'] ?? '—'}',
                  style: GoogleFonts.inter(fontSize: 11),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    details,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                if (status != 'Pending' &&
                    (request['reviewed_by'] != null ||
                        request['reviewed_at'] != null)) ...[
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (request['reviewed_by'] != null)
                        'Reviewed by ${request['reviewed_by']}',
                      if (request['reviewed_at'] != null)
                        'on ${_formatDate(request['reviewed_at'].toString())}',
                    ].join(' '),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                if (rejectionReason.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    'Admin note: $rejectionReason',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyMessage(IconData icon, String title, String subtitle) {
    return Center(
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
    );
  }
}
