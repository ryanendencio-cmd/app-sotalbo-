import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'worker_attendance_screen.dart';
import 'worker_tools_screen.dart';
import 'worker_salary_screen.dart';
import 'worker_profile_screen.dart';
import '../services/api_service.dart';
import '../widgets/currency_text_field.dart';
import '../widgets/worker_app_header.dart';

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({super.key});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  int _currentNavIndex = 0;
  DateTime _selectedDate = DateTime.now();

  Map<String, dynamic>? _user;
  Map<String, dynamic>? _todayAttendance;
  Map<String, dynamic>? _todaySchedule;
  Map<String, dynamic>? _latestPayroll;
  String _attendanceStatus = 'Not Checked In';
  String? _attendanceError;
  String? _correctionError;
  String? _scheduleError;
  String? _payrollError;
  String? _announcementError;
  bool _payrollLoading = true;
  bool _announcementsLoading = true;
  bool _cashAdvancesLoading = true;
  bool _toolsLoading = true;
  String? _toolsError;
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _allAnnouncements = [];
  List<Map<String, dynamic>> _correctionRequests = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _user = ApiService.currentUser;
    _loadDashboardData();
    _loadDashboardExtras();
  }

  Future<void> _loadDashboardData() async {
    final user = ApiService.currentUser;
    final userId = user?['id']?.toString();
    final userName =
        (user?['full_name'] ??
                user?['name'] ??
                '${user?['first_name'] ?? ''} ${user?['last_name'] ?? ''}')
            .toString()
            .trim()
            .toLowerCase();

    if (mounted) {
      setState(() {
        _cashAdvancesLoading = true;
        _toolsLoading = true;
        _cashAdvanceError = null;
        _toolsError = null;
      });
    }

    // 1. Fetch attendance
    try {
      final records = await ApiService.getAttendance('ALL');
      final now = DateTime.now();
      final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final today = DateTime(now.year, now.month, now.day);
      final weekStart = today.subtract(Duration(days: today.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));

      String timeIn = "--:-- AM";
      String timeOut = "--:-- PM";
      Map<String, dynamic>? selectedAttendance;

      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final Map<String, double> dayHours = {for (var d in days) d: 0.0};
      final double dailyRate = (user?['daily_rate'] is num)
          ? (user!['daily_rate'] as num).toDouble()
          : 600.0;

      for (final r in records) {
        final wId = r['worker_id']?.toString();
        final wName = (r['worker_name'] ?? r['name'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (userId != null && wId != null && wId != userId) continue;
        if (userId == null &&
            userName.isNotEmpty &&
            wName.isNotEmpty &&
            !wName.contains(userName) &&
            !userName.contains(wName)) {
          continue;
        }

        final dStr = (r['date'] ?? '').toString();
        final datePart = dStr.length >= 10 ? dStr.substring(0, 10) : dStr;
        if (datePart == selectedDateStr) {
          selectedAttendance = Map<String, dynamic>.from(r as Map);
          timeIn = _formatAttendanceTime(
            _attendanceValue(r, const [
              'morningIn',
              'morning_in',
              'timeIn',
              'time_in',
              'afternoonIn',
              'afternoon_in',
            ]),
          );
          timeOut = _formatAttendanceTime(
            _attendanceValue(r, const [
              'afternoonOut',
              'afternoon_out',
              'timeOut',
              'time_out',
              'morningOut',
              'morning_out',
            ]),
          );
        }

        final dt = DateTime.tryParse(datePart);
        if (dt != null &&
            !dt.isBefore(weekStart) &&
            !dt.isAfter(weekEnd) &&
            !dt.isAfter(today)) {
          final dayName = days[dt.weekday - 1];
          final hrs = _attendanceHours(r);
          dayHours[dayName] = (dayHours[dayName] ?? 0.0) > hrs
              ? dayHours[dayName]!
              : hrs;
        }
      }

      final List<Map<String, dynamic>> weekly = days.map((d) {
        final hrs = dayHours[d] ?? 0.0;
        final totalMinutes = (hrs * 60).round();
        final earn = (hrs / 8.0) * dailyRate;
        return {
          'day': d,
          'hours': hrs,
          'earnings': earn,
          'labelHours': '${totalMinutes ~/ 60}h,${totalMinutes % 60}m',
          'labelEarnings': earn > 0 ? '₱${earn.toStringAsFixed(0)}' : '₱0',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _attendanceError = null;
          _timeIn = timeIn;
          _timeOut = timeOut;
          _todayAttendance = selectedAttendance;
          final recordedStatus = (selectedAttendance?['status'] ?? '')
              .toString()
              .trim();
          final hasTimeIn =
              timeIn.isNotEmpty &&
              timeIn != '—' &&
              timeIn != '--:--' &&
              timeIn != '--:-- AM';
          _attendanceStatus = recordedStatus.isNotEmpty
              ? recordedStatus
              : hasTimeIn
              ? 'On Site'
              : 'Not Checked In';
          _weeklyData.clear();
          _weeklyData.addAll(weekly);
        });
      }
    } catch (error) {
      debugPrint('Failed to load worker attendance: $error');
      if (mounted) {
        setState(() {
          _attendanceError = error.toString();
          _todayAttendance = null;
          _timeIn = '--:-- AM';
          _timeOut = '--:-- PM';
          _attendanceStatus = 'Unavailable';
          _weeklyData.clear();
        });
      }
    }

    // 2. Fetch cash advances
    if (userId != null && userId.isNotEmpty) {
      try {
        final vales = await ApiService.getWorkerCashAdvances(userId);
        if (mounted) {
          final latest = vales.isEmpty
              ? null
              : Map<String, dynamic>.from(vales.first as Map);
          setState(() {
            _cashAdvance = latest == null
                ? '₱ 0.00'
                : '₱ ${_formatMoney(latest['amount'])}';
            _caStatus = (latest?['status'] ?? 'None').toString();
            _cashAdvanceError = null;
            _cashAdvancesLoading = false;
          });
        }
      } catch (error) {
        debugPrint('Failed to load worker cash advances: $error');
        if (mounted) {
          setState(() {
            _cashAdvanceError = error.toString();
            _cashAdvancesLoading = false;
          });
        }
      }
    } else if (mounted) {
      setState(() => _cashAdvancesLoading = false);
    }

    // 3. Fetch borrowed tools
    try {
      final tools = await ApiService.getBorrowHistory('ALL');
      final List<Map<String, String>> myTools = [];
      final records = tools
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .toList();

      for (final t in records) {
        final bId = t['worker_id']?.toString();
        final bName = (t['borrower_name'] ?? t['borrower'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (userId != null && bId != null && bId != userId) continue;
        if (userId == null &&
            userName.isNotEmpty &&
            bName.isNotEmpty &&
            !bName.contains(userName) &&
            !userName.contains(bName)) {
          continue;
        }

        final action = (t['action'] ?? t['status'] ?? '').toString();
        if (!(action == 'Borrowed' ||
            action == 'In Use' ||
            action == 'Checked Out')) {
          continue;
        }

        final toolName = (t['tool_name'] ?? t['name'] ?? '').toString().trim();
        final borrowerName = (t['borrower_name'] ?? t['borrower'] ?? '')
            .toString()
            .trim();
        final rawTime =
            t['borrow_date'] ??
            t['date_time'] ??
            t['borrow_at'] ??
            t['created_at'] ??
            t['time'];
        final eventTime = _parseToolDateTime(rawTime);

        final hasLaterReturn = records.any((candidate) {
          final candidateAction =
              (candidate['action'] ?? candidate['status'] ?? '').toString();
          final candidateName =
              (candidate['tool_name'] ?? candidate['name'] ?? '')
                  .toString()
                  .trim();
          final candidateBorrower =
              (candidate['borrower_name'] ?? candidate['borrower'] ?? '')
                  .toString()
                  .trim();
          final candidateRawTime =
              candidate['borrow_date'] ??
              candidate['date_time'] ??
              candidate['borrow_at'] ??
              candidate['created_at'] ??
              candidate['time'];
          final candidateTime = _parseToolDateTime(candidateRawTime);
          final isReturnAction =
              candidateAction == 'Returned' ||
              candidateAction == 'Check-In' ||
              candidateAction == 'Checked In' ||
              candidateAction == 'Available' ||
              candidateAction == 'Return';
          if (!isReturnAction) return false;
          if (toolName.isEmpty || candidateName.isEmpty) return false;
          if (toolName.toLowerCase() != candidateName.toLowerCase()) {
            return false;
          }
          if (borrowerName.isNotEmpty &&
              candidateBorrower.isNotEmpty &&
              borrowerName.toLowerCase() != candidateBorrower.toLowerCase()) {
            return false;
          }
          if (eventTime == null || candidateTime == null) return false;
          return candidateTime.isAfter(eventTime);
        });

        if (hasLaterReturn) continue;

        final formattedTime = _formatToolDate(rawTime);
        final code = _formatToolCode(t);
        final condition = (t['condition_status'] ?? t['condition'] ?? 'Good')
            .toString();
        final qty = (t['quantity'] ?? t['qty'] ?? 1).toString();

        myTools.add({
          'name': (t['tool_name'] ?? t['name'] ?? 'Tool').toString(),
          'code': code,
          'time': formattedTime,
          'condition': condition,
          'quantity': qty,
          'status': 'In Use',
        });
      }
      if (mounted) {
        setState(() {
          _borrowedTools.clear();
          _borrowedTools.addAll(myTools);
          _toolsLoading = false;
          _toolsError = null;
        });
      }
    } catch (error) {
      debugPrint('Failed to load worker tools: $error');
      if (mounted) {
        setState(() {
          _toolsLoading = false;
          _toolsError = error.toString();
        });
      }
    }
  }

  Future<void> _loadDashboardExtras() async {
    final userId = _user?['id']?.toString();
    final today = DateTime.now();
    final todayStr =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    if (mounted) {
      setState(() {
        _payrollLoading = true;
        _announcementsLoading = true;
      });
    }

    try {
      final schedules = await ApiService.getAttendanceSchedules();
      final matching = schedules
          .map((value) => Map<String, dynamic>.from(value as Map))
          .where((schedule) {
            if (schedule['date']?.toString() != todayStr) return false;
            final workerId = schedule['worker_id']?.toString();
            return workerId == null ||
                workerId.isEmpty ||
                (userId != null && workerId == userId);
          })
          .toList();
      matching.sort((a, b) {
        final aSpecific = a['worker_id'] != null ? 0 : 1;
        final bSpecific = b['worker_id'] != null ? 0 : 1;
        return aSpecific.compareTo(bSpecific);
      });
      final settings = await ApiService.getAttendanceSettings();
      if (mounted) {
        setState(() {
          _todaySchedule = matching.isNotEmpty
              ? matching.first
              : {
                  'start_time': settings['default_time_in'] ?? '08:00',
                  'end_time': settings['default_time_out'] ?? '17:00',
                  'working_hours': settings['daily_work_hours'] ?? 8,
                  'notes': '',
                };
          _scheduleError = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _scheduleError = error.toString());
    }

    if (userId != null && userId.isNotEmpty) {
      try {
        final payroll = await ApiService.getWorkerPayroll(userId);
        final latest = payroll
            .map((value) => Map<String, dynamic>.from(value as Map))
            .where((item) => item['status'] != 'Draft')
            .toList();
        if (mounted) {
          setState(() {
            _latestPayroll = latest.isEmpty ? null : latest.first;
            _payrollError = null;
            _payrollLoading = false;
          });
        }
      } catch (error) {
        if (mounted) {
          setState(() {
            _payrollError = error.toString();
            _payrollLoading = false;
          });
        }
      }

      try {
        final requests = await ApiService.getAttendanceCorrectionRequests(
          workerId: userId,
        );
        if (mounted) {
          setState(() {
            _correctionRequests = requests
                .map((value) => Map<String, dynamic>.from(value as Map))
                .toList();
            _correctionError = null;
          });
        }
      } catch (error) {
        debugPrint('Failed to load attendance correction requests: $error');
        if (mounted) setState(() => _correctionError = error.toString());
      }
    } else if (mounted) {
      setState(() {
        _latestPayroll = null;
        _payrollError = 'Worker account ID is unavailable.';
        _payrollLoading = false;
      });
    }

    await _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    try {
      final notifications = await ApiService.getNotifications();
      final announcements = notifications
          .map((value) => Map<String, dynamic>.from(value as Map))
          .where(
            (item) =>
                (item['type'] ?? '').toString().toLowerCase() == 'announcement',
          )
          .toList();
      updateWorkerAnnouncementBadge(announcements);
      if (mounted) {
        setState(() {
          _allAnnouncements = announcements;
          _announcements = announcements.take(3).toList();
          _announcementError = null;
          _announcementsLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _announcementError = error.toString();
          _announcementsLoading = false;
        });
      }
    }
  }

  String _displayScheduleTime(dynamic value) {
    final parts = (value ?? '').toString().split(':');
    if (parts.length < 2) return '—';
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return '—';
    }
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  String _formatMoney(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return NumberFormat('#,##0.00').format(amount);
  }

  dynamic _attendanceValue(Map record, List<String> keys) {
    for (final key in keys) {
      final value = record[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text != '—' && text != '--:--') return value;
    }
    return null;
  }

  int? _attendanceMinutes(dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty || text == '—' || text == '--:--') return null;
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)?$',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;

    var hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || minute > 59) return null;
    final period = match.group(3)?.toUpperCase();
    if (period != null) {
      if (hour < 1 || hour > 12) return null;
      hour = hour % 12 + (period == 'PM' ? 12 : 0);
    } else if (hour > 23) {
      return null;
    }
    return hour * 60 + minute;
  }

  String _formatAttendanceTime(dynamic value) {
    final minutes = _attendanceMinutes(value);
    if (minutes == null) return '—';
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  double _attendanceHours(Map record) {
    final sessionPairs = [
      (
        _attendanceValue(record, const ['morningIn', 'morning_in']),
        _attendanceValue(record, const ['morningOut', 'morning_out']),
      ),
      (
        _attendanceValue(record, const ['afternoonIn', 'afternoon_in']),
        _attendanceValue(record, const ['afternoonOut', 'afternoon_out']),
      ),
    ];
    var minutesWorked = 0;
    var hasSessionPair = false;
    for (final (rawIn, rawOut) in sessionPairs) {
      final start = _attendanceMinutes(rawIn);
      final end = _attendanceMinutes(rawOut);
      if (start == null || end == null) continue;
      hasSessionPair = true;
      var duration = end - start;
      if (duration < 0) duration += 24 * 60;
      if (duration > 0 && duration <= 24 * 60) minutesWorked += duration;
    }

    if (!hasSessionPair) {
      final start = _attendanceMinutes(
        _attendanceValue(record, const ['timeIn', 'time_in']),
      );
      final end = _attendanceMinutes(
        _attendanceValue(record, const ['timeOut', 'time_out']),
      );
      if (start != null && end != null) {
        var duration = end - start;
        if (duration < 0) duration += 24 * 60;
        if (duration > 0 && duration <= 24 * 60) minutesWorked = duration;
      } else {
        final recordedHours = record['hours'];
        if (recordedHours is num) {
          return recordedHours.toDouble().clamp(0, 24).toDouble();
        }
        return double.tryParse(
              recordedHours?.toString() ?? '',
            )?.clamp(0, 24).toDouble() ??
            0;
      }
    }
    return minutesWorked / 60;
  }

  DateTime? _parseToolDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) {
      final secs = raw['_seconds'] ?? raw['seconds'];
      if (secs is num) {
        return DateTime.fromMillisecondsSinceEpoch(
          (secs * 1000).toInt(),
        ).toLocal();
      }
    }
    final str = raw.toString().trim();
    if (str.isEmpty || str == 'null') return null;
    try {
      return DateTime.parse(str).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _formatToolCode(Map<String, dynamic> t) {
    final rawCode =
        (t['tool_code'] ??
                t['code'] ??
                t['serial_no'] ??
                t['serial'] ??
                t['asset_code'])
            ?.toString()
            .trim();
    if (rawCode != null && rawCode.isNotEmpty && rawCode != 'null') {
      return rawCode.toUpperCase().startsWith('TL') ||
              rawCode.toUpperCase().startsWith('TOOL')
          ? rawCode
          : 'Code: $rawCode';
    }
    final type = (t['type'] ?? t['category'])?.toString().trim();
    if (type != null && type.isNotEmpty && type != 'null') {
      return type;
    }
    final condition = (t['condition_status'] ?? t['condition'])
        ?.toString()
        .trim();
    if (condition != null && condition.isNotEmpty && condition != 'null') {
      return 'Cond: $condition';
    }
    final id = (t['tool_id'] ?? t['asset_id'] ?? t['id'])?.toString().trim();
    if (id != null && id.isNotEmpty && id != 'null') {
      if (id.length <= 6) return 'Ref #$id';
      return 'Ref #${id.substring(0, 5).toUpperCase()}';
    }
    return 'Hand Tool';
  }

  String _formatToolDate(dynamic raw) {
    if (raw == null) return 'Recently';
    if (raw is Map) {
      final secs = raw['_seconds'] ?? raw['seconds'];
      if (secs is num) {
        final dt = DateTime.fromMillisecondsSinceEpoch(
          (secs * 1000).toInt(),
        ).toLocal();
        return _formatToolDateTime(dt);
      }
    }
    final str = raw.toString().trim();
    if (str.isEmpty || str == 'null') return 'Recently';
    try {
      final dt = DateTime.parse(str).toLocal();
      return _formatToolDateTime(dt);
    } catch (_) {
      return str;
    }
  }

  String _formatToolDateTime(DateTime dt) {
    final now = DateTime.now();
    final m = _months[dt.month - 1];
    final hr = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    if (now.year == dt.year && now.month == dt.month && now.day == dt.day) {
      return 'Today, $hr:$min $ampm';
    }
    return '$m ${dt.day}, ${dt.year}';
  }

  String _buildToolSubtitle(Map<String, String> tool) {
    final code = tool['code']?.trim();
    final time = tool['time']?.trim();
    final cond = tool['condition']?.trim();
    final qty = tool['quantity']?.trim();

    final parts = <String>[];
    if (qty != null && qty.isNotEmpty && qty != '1' && qty != 'null') {
      parts.add('Qty: $qty');
    }
    if (code != null && code.isNotEmpty && code != 'null') {
      parts.add(code);
    } else if (cond != null && cond.isNotEmpty && cond != 'null') {
      parts.add('Cond: $cond');
    } else {
      parts.add('Hand Tool');
    }

    if (time != null && time.isNotEmpty && time != 'null' && time != '—') {
      parts.add('Assigned $time');
    } else {
      parts.add('Assigned Active');
    }

    return parts.join(' · ');
  }

  String _timeIn = "--:-- AM";
  String _timeOut = "--:-- PM";
  String _cashAdvance = "₱ 0.00";
  String _caStatus = "None";
  String? _cashAdvanceError;

  // State para sa Graph Toggle ('hours' o 'earnings')
  String _selectedGraphMetric = 'hours';

  final List<Map<String, String>> _borrowedTools = [];

  final List<String> _months = [
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

  final List<Map<String, dynamic>> _weeklyData = [];

  Future<void> _submitCorrectionRequest() async {
    final userId = _user?['id']?.toString();
    if (userId == null || userId.isEmpty || _todayAttendance == null) {
      _showMessage(
        'A recorded attendance entry is required to request a correction.',
      );
      return;
    }

    final reasonController = TextEditingController();
    var selectedField = 'time_in';
    var requestedTime = TimeOfDay.now();
    var isSubmitting = false;
    final today = DateTime.now();
    final date =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    final workerName =
        (_user?['full_name'] ??
                _user?['name'] ??
                '${_user?['first_name'] ?? ''} ${_user?['last_name'] ?? ''}')
            .toString()
            .trim();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Request Attendance Correction',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedField,
                decoration: const InputDecoration(
                  labelText: 'Entry to correct',
                ),
                items: const [
                  DropdownMenuItem(value: 'time_in', child: Text('Time In')),
                  DropdownMenuItem(value: 'time_out', child: Text('Time Out')),
                ],
                onChanged: isSubmitting
                    ? null
                    : (value) {
                        if (value != null) {
                          setDialogState(() => selectedField = value);
                        }
                      },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: requestedTime,
                        );
                        if (picked != null) {
                          setDialogState(() => requestedTime = picked);
                        }
                      },
                icon: const Icon(Icons.access_time),
                label: Text(requestedTime.format(context)),
              ),
              TextField(
                controller: reasonController,
                enabled: !isSubmitting,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText:
                      'Explain why this attendance entry needs correction',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final reason = reasonController.text.trim();
                      if (reason.isEmpty) {
                        _showMessage(
                          'Please provide a reason for the correction.',
                        );
                        return;
                      }
                      setDialogState(() => isSubmitting = true);
                      final hour = requestedTime.hour.toString().padLeft(
                        2,
                        '0',
                      );
                      final minute = requestedTime.minute.toString().padLeft(
                        2,
                        '0',
                      );
                      final original = selectedField == 'time_in'
                          ? (_todayAttendance?['morningIn'] ??
                                    _todayAttendance?['morning_in'] ??
                                    _todayAttendance?['timeIn'] ??
                                    _todayAttendance?['time_in'] ??
                                    '')
                                .toString()
                          : (_todayAttendance?['afternoonOut'] ??
                                    _todayAttendance?['afternoon_out'] ??
                                    _todayAttendance?['timeOut'] ??
                                    _todayAttendance?['time_out'] ??
                                    '')
                                .toString();
                      try {
                        final submitted =
                            await ApiService.submitAttendanceCorrectionRequest({
                              'worker_id': userId,
                              'worker_name': workerName.isEmpty
                                  ? 'Worker'
                                  : workerName,
                              'date': date,
                              'field': selectedField,
                              'requested_time': '$hour:$minute',
                              'original_time': original,
                              'reason': reason,
                            });
                        if (mounted && dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          setState(() {
                            _correctionRequests.insert(
                              0,
                              Map<String, dynamic>.from(submitted as Map),
                            );
                            _correctionError = null;
                          });
                          _showMessage('Correction request sent for review.');
                        }
                      } catch (error) {
                        if (mounted && dialogContext.mounted) {
                          setDialogState(() => isSubmitting = false);
                          _showMessage('Unable to submit correction: $error');
                        }
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFA63228),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    reasonController.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFA63228),
      ),
    );
  }

  Future<void> _showNotificationDialog() async {
    await _loadAnnouncements();
    if (!mounted) return;
    final markingIds = <String>{};
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                              color: const Color(
                                0xFFA63228,
                              ).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_active_outlined,
                              color: Color(0xFFA63228),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Broadcast Alerts',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
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
                  const SizedBox(height: 2),
                  Text(
                    'Direct messages transmitted from Admin console',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Divider(height: 14),
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _announcements.isEmpty
                          ? 1
                          : _announcements.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (_announcements.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(
                              _announcementError == null
                                  ? 'No announcements at this time.'
                                  : 'Unable to load announcements.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          );
                        }
                        final notif = _announcements[index];
                        final rawId = notif['id'];
                        final id = rawId?.toString() ?? '';
                        final read =
                            notif['read'] == true ||
                            notif['read']?.toString().toLowerCase() == 'true';
                        final isMarking = markingIds.contains(id);
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
                              InkWell(
                                onTap: () {
                                  Navigator.pop(dialogContext);
                                  _showAnnouncementDetails(notif);
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFFA63228,
                                            ).withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            (notif['type'] ?? 'Announcement')
                                                .toString(),
                                            style: GoogleFonts.inter(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFFA63228),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          (notif['date'] ?? '').toString(),
                                          style: GoogleFonts.inter(
                                            fontSize: 9.5,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      (notif['title'] ?? 'Announcement')
                                          .toString(),
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      (notif['message'] ?? '').toString(),
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        color: Colors.grey.shade700,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: read || isMarking || id.isEmpty
                                      ? null
                                      : () async {
                                          setDialogState(
                                            () => markingIds.add(id),
                                          );
                                          try {
                                            await ApiService.markNotificationRead(
                                              id,
                                            );
                                            notif['read'] = true;
                                            updateWorkerAnnouncementBadge(
                                              _allAnnouncements,
                                            );
                                            if (mounted) {
                                              setState(() {
                                                final matching = _announcements
                                                    .firstWhere(
                                                      (item) =>
                                                          item['id']
                                                              ?.toString() ==
                                                          id,
                                                      orElse: () => notif,
                                                    );
                                                matching['read'] = true;
                                              });
                                            }
                                            setDialogState(() {});
                                          } catch (error) {
                                            _showMessage(
                                              'Unable to mark announcement as read: $error',
                                            );
                                          } finally {
                                            markingIds.remove(id);
                                            setDialogState(() {});
                                          }
                                        },
                                  icon: Icon(
                                    read
                                        ? Icons.done_all_rounded
                                        : Icons.mark_email_read_outlined,
                                    size: 16,
                                  ),
                                  label: Text(read ? 'Read' : 'Mark as read'),
                                ),
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
      ),
    );
  }

  Future<void> _showAnnouncementDetails(
    Map<String, dynamic> announcement,
  ) async {
    final title = (announcement['title'] ?? 'Announcement').toString();
    final message = (announcement['message'] ?? '').toString().trim();
    final date = (announcement['date'] ?? '').toString().trim();
    final time = (announcement['time'] ?? '').toString().trim();
    final severity = (announcement['severity'] ?? '').toString().trim();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.campaign_outlined,
              color: Color(0xFFA63228),
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (date.isNotEmpty || time.isNotEmpty || severity.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    [
                      if (date.isNotEmpty) date,
                      if (time.isNotEmpty) time,
                      if (severity.isNotEmpty) severity,
                    ].join(' • '),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              Text(
                message.isEmpty ? 'No additional details.' : message,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
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
            final int daysInMonth = DateTime(
              tempMonth.year,
              tempMonth.month + 1,
              0,
            ).day;
            final int offset =
                DateTime(tempMonth.year, tempMonth.month, 1).weekday % 7;
            final int totalGridCells = daysInMonth + offset;

            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
                                tempMonth = DateTime(
                                  tempMonth.year,
                                  tempMonth.month - 1,
                                  1,
                                );
                              });
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          Text(
                            '${_months[tempMonth.month - 1]} ${tempMonth.year}',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, size: 20),
                            onPressed: () {
                              setDialogState(() {
                                tempMonth = DateTime(
                                  tempMonth.year,
                                  tempMonth.month + 1,
                                  1,
                                );
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
                            .map(
                              (d) => SizedBox(
                                width: 28,
                                child: Text(
                                  d,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 6),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: totalGridCells,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                              childAspectRatio: 1.0,
                            ),
                        itemBuilder: (context, index) {
                          if (index < offset) return const SizedBox.shrink();
                          final day = index - offset + 1;
                          final date = DateTime(
                            tempMonth.year,
                            tempMonth.month,
                            day,
                          );
                          final isSelected =
                              date.year == tempPicked.year &&
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
                                color: isSelected
                                    ? const Color(0xFFA63228)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$day',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
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
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFA63228),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedDate = tempPicked;
                              });
                              Navigator.pop(context);
                              _loadDashboardData();
                            },
                            child: Text(
                              'Apply',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
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
                Text(
                  'Submitted directly to site admin for cutoff review',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: quickAmounts.map((amt) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => amountController.text =
                            CurrencyInputFormatter.formatEditing(amt),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3EF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            '₱$amt',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                CurrencyTextField(
                  controller: amountController,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFFAF8F5),
                    isDense: true,
                    prefixText: '₱ ',
                    prefixStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFA63228),
                    ),
                    hintText: 'Enter amount',
                    hintStyle: GoogleFonts.inter(
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.normal,
                      fontSize: 12,
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
                        onPressed: () async {
                          final amount =
                              CurrencyInputFormatter.parse(
                                amountController.text,
                              ) ??
                              0.0;
                          final reason = reasonController.text.trim();

                          if (amount <= 0 || reason.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter valid amount and reason',
                                ),
                              ),
                            );
                            return;
                          }

                          try {
                            final user = ApiService.currentUser;
                            final workerName =
                                user?['name'] ??
                                user?['full_name'] ??
                                '${user?['firstName'] ?? user?['first_name'] ?? ''} ${user?['lastName'] ?? user?['last_name'] ?? ''}'
                                    .trim();
                            final dateStr = DateTime.now()
                                .toIso8601String()
                                .split('T')[0];

                            await ApiService.createCashAdvance({
                              'project_id':
                                  1, // Defaulting to 1 for now if worker project is unknown
                              'workerId': user?['id'],
                              'workerName': workerName.isNotEmpty
                                  ? workerName
                                  : 'Worker',
                              'amount': amount,
                              'reason': reason,
                              'date': dateStr,
                              'status': 'Pending',
                            });

                            if (mounted && context.mounted) {
                              setState(() {
                                _cashAdvance = '₱ ${amount.toStringAsFixed(2)}';
                                _caStatus = 'Pending';
                              });
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Vale request submitted to Admin portal',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to request vale: $e'),
                                ),
                              );
                            }
                          }
                        },
                        child: Text(
                          'Submit Vale',
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
    );
  }

  String _getFormattedDate(DateTime date) {
    return "${_months[date.month - 1]} ${date.day}, ${date.year}";
  }

  String _workerGreetingName() {
    final user = _user ?? ApiService.currentUser;
    final firstName = (user?['firstName'] ?? user?['first_name'] ?? '')
        .toString()
        .trim();
    final lastName = (user?['lastName'] ?? user?['last_name'] ?? '')
        .toString()
        .trim();
    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      return [firstName, lastName].where((part) => part.isNotEmpty).join(' ');
    }

    final fullName = (user?['full_name'] ?? user?['name'] ?? '')
        .toString()
        .trim();
    final parts = fullName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length > 1) return '${parts.first} ${parts.last}';
    return parts.isEmpty ? 'Worker' : parts.first;
  }

  Widget _buildHomeView(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final String greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';
    final workerName = _workerGreetingName();

    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      appBar: WorkerAppHeader(onNotificationsPressed: _showNotificationDialog),
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
                                    '$greeting,',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    workerName,
                                    style: GoogleFonts.inter(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color:
                                            _attendanceStatus ==
                                                    'Not Checked In' ||
                                                _attendanceStatus ==
                                                    'Unavailable'
                                            ? Colors.white70
                                            : const Color(0xFF7CFC00),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _attendanceStatus,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Stats Row
                          Row(
                            children: [
                              _buildHeroStat(
                                Icons.schedule_rounded,
                                'Time In',
                                _timeIn == '--:-- AM' ? '—' : _timeIn,
                              ),
                              Container(
                                width: 1,
                                height: 28,
                                color: Colors.white.withValues(alpha: 0.25),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              _buildHeroStat(
                                Icons.logout_rounded,
                                'Time Out',
                                _timeOut == '--:-- PM' ? '—' : _timeOut,
                              ),
                              Container(
                                width: 1,
                                height: 28,
                                color: Colors.white.withValues(alpha: 0.25),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              _buildHeroStat(
                                Icons.today_rounded,
                                'Today',
                                '${_months[now.month - 1]} ${now.day}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── TODAY'S SCHEDULE ──────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
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
                                Icons.event_available_outlined,
                                size: 18,
                                color: Color(0xFFA63228),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  "Today's Schedule",
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Text(
                                _todaySchedule?['id'] == null
                                    ? 'Standard Shift'
                                    : 'Assigned Shift',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_scheduleError != null)
                            Text(
                              'Unable to load your schedule.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.red.shade700,
                              ),
                            )
                          else if (_todaySchedule == null)
                            Text(
                              'Loading schedule…',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            )
                          else ...[
                            Row(
                              children: [
                                _buildScheduleStat(
                                  Icons.login_rounded,
                                  'Time In',
                                  _displayScheduleTime(
                                    _todaySchedule?['start_time'],
                                  ),
                                ),
                                Container(
                                  height: 30,
                                  width: 1,
                                  color: Colors.grey.shade200,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                                _buildScheduleStat(
                                  Icons.logout_rounded,
                                  'Time Out',
                                  _displayScheduleTime(
                                    _todaySchedule?['end_time'],
                                  ),
                                ),
                                Container(
                                  height: 30,
                                  width: 1,
                                  color: Colors.grey.shade200,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                                _buildScheduleStat(
                                  Icons.hourglass_bottom_rounded,
                                  'Hours',
                                  '${_todaySchedule?['working_hours'] ?? 8}h',
                                ),
                              ],
                            ),
                            if ((_todaySchedule?['notes'] ?? '')
                                .toString()
                                .trim()
                                .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                _todaySchedule!['notes'].toString(),
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── DAILY RECORD SECTION HEADER ───────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Daily Record',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        InkWell(
                          onTap: () => _pickDate(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.today_rounded,
                                  size: 13,
                                  color: Color(0xFFA63228),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _getFormattedDate(_selectedDate),
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 14,
                                  color: Colors.black54,
                                ),
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
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.015),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TERMINAL ATTENDANCE',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'Operator: Mark',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  color: Colors.grey.shade500,
                                ),
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
                                    Text(
                                      'TIME IN',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _timeIn,
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                height: 24,
                                width: 1,
                                color: Colors.grey.shade200,
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      'TIME OUT',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _timeOut,
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _attendanceError == null
                                      ? 'Status: $_attendanceStatus'
                                      : 'Unable to load attendance status',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: _attendanceError != null
                                        ? Colors.red.shade700
                                        : _attendanceStatus == 'Not Checked In'
                                        ? Colors.grey.shade600
                                        : Colors.green.shade700,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _todayAttendance == null
                                    ? null
                                    : _submitCorrectionRequest,
                                icon: const Icon(Icons.edit_outlined, size: 14),
                                label: const Text('Request Correction'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFA63228),
                                  textStyle: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_correctionError != null) ...[
                            const Divider(height: 10),
                            Text(
                              'Unable to load correction request status.',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ] else if (_correctionRequests.isNotEmpty) ...[
                            const Divider(height: 10),
                            Text(
                              'Latest correction request: '
                              '${_correctionRequests.first['status'] ?? 'Pending'}',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Weekly Performance',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF8F5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => setState(
                                        () => _selectedGraphMetric = 'hours',
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _selectedGraphMetric == 'hours'
                                              ? const Color(0xFFA63228)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          'Hours',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                _selectedGraphMetric == 'hours'
                                                ? Colors.white
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => setState(
                                        () => _selectedGraphMetric = 'earnings',
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              _selectedGraphMetric == 'earnings'
                                              ? const Color(0xFFA63228)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          'Earnings',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                _selectedGraphMetric ==
                                                    'earnings'
                                                ? Colors.white
                                                : Colors.grey.shade600,
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
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: Text(
                                      'No weekly data available',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: _weeklyData.map((data) {
                                    final bool isHours =
                                        _selectedGraphMetric == 'hours';
                                    final double value = isHours
                                        ? data['hours']
                                        : data['earnings'];
                                    final double maxValue = isHours
                                        ? 10.0
                                        : 700.0;
                                    final double barHeight =
                                        ((value / maxValue) * 70)
                                            .clamp(0, 70)
                                            .toDouble();

                                    return Column(
                                      children: [
                                        Text(
                                          isHours
                                              ? data['labelHours']
                                              : data['labelEarnings'],
                                          style: GoogleFonts.inter(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          width: 22,
                                          height: barHeight > 10
                                              ? barHeight
                                              : 10,
                                          decoration: BoxDecoration(
                                            color: data['day'] == 'Thu'
                                                ? const Color(0xFFA63228)
                                                : const Color(
                                                    0xFFA63228,
                                                  ).withValues(alpha: 0.25),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          data['day'],
                                          style: GoogleFonts.inter(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── LATEST PAYSLIP SUMMARY ────────────────────────────
                    InkWell(
                      onTap: () => setState(() => _currentNavIndex = 3),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
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
                                  Icons.account_balance_wallet_outlined,
                                  size: 18,
                                  color: Color(0xFFA63228),
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    'Latest Payslip',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.grey,
                                  size: 18,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_payrollLoading)
                              Text(
                                'Loading latest payslip…',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              )
                            else if (_payrollError != null)
                              Text(
                                'Unable to load your latest payslip.',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.red.shade700,
                                ),
                              )
                            else if (_latestPayroll == null)
                              Text(
                                'No released payroll is available yet.',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${_latestPayroll?['cutoff_start'] ?? '—'} to ${_latestPayroll?['cutoff_end'] ?? '—'}',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '₱${_formatMoney(_latestPayroll?['net_pay'])}',
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFFA63228),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      (_latestPayroll?['status'] ?? 'Released')
                                          .toString(),
                                      style: GoogleFonts.inter(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── PROJECT ANNOUNCEMENTS ─────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
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
                                Icons.campaign_outlined,
                                size: 18,
                                color: Color(0xFFA63228),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  'Project Announcements',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (_announcements.isNotEmpty)
                                TextButton(
                                  onPressed: _showNotificationDialog,
                                  child: Text(
                                    'See all',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFA63228),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (_announcementsLoading)
                            Text(
                              'Loading announcements…',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            )
                          else if (_announcementError != null)
                            Text(
                              'Unable to load announcements.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.red.shade700,
                              ),
                            )
                          else if (_announcements.isEmpty)
                            Text(
                              'No new announcements.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            )
                          else
                            ..._announcements.take(2).map((announcement) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: InkWell(
                                  onTap: () =>
                                      _showAnnouncementDetails(announcement),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 4),
                                        child: Icon(
                                          Icons.circle,
                                          size: 6,
                                          color: Color(0xFFA63228),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              (announcement['title'] ??
                                                      'Announcement')
                                                  .toString(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              (announcement['message'] ?? '')
                                                  .toString(),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'CASH ADVANCE (VALE)',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              InkWell(
                                onTap: _showRequestValeDialog,
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFA63228,
                                    ).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    size: 14,
                                    color: Color(0xFFA63228),
                                  ),
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
                                  Text(
                                    'Latest Request',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _cashAdvancesLoading
                                        ? 'Loading…'
                                        : _cashAdvance,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _caStatus == 'Approved'
                                      ? Colors.green.shade50
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _caStatus == 'Approved'
                                        ? Colors.green.shade200
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  _cashAdvancesLoading ? 'Loading' : _caStatus,
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: _caStatus == 'Approved'
                                        ? Colors.green.shade700
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_cashAdvanceError != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Unable to load cash advance status.',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ISSUED TOOLS (${_borrowedTools.length})',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _currentNavIndex = 2),
                                child: Text(
                                  'See All →',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: const Color(0xFFA63228),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _toolsLoading
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'Loading issued tools…',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                )
                              : _toolsError != null
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'Unable to load issued tools.',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                )
                              : _borrowedTools.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'No tools currently issued',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _borrowedTools.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 10,
                                    color: Colors.grey.shade100,
                                  ),
                                  itemBuilder: (context, index) {
                                    final tool = _borrowedTools[index];
                                    return Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                (tool['name'] != null &&
                                                        tool['name']!
                                                            .isNotEmpty &&
                                                        tool['name'] != 'null')
                                                    ? tool['name']!
                                                    : 'Equipment',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _buildToolSubtitle(tool),
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: Colors.orange.shade200,
                                            ),
                                          ),
                                          child: Text(
                                            (tool['status'] != null &&
                                                    tool['status']!
                                                        .isNotEmpty &&
                                                    tool['status'] != 'null')
                                                ? tool['status']!
                                                : 'In Use',
                                            style: GoogleFonts.inter(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange.shade800,
                                            ),
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
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleStat(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: Colors.grey.shade500),
              const SizedBox(width: 3),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
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
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.normal,
        ),
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
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
