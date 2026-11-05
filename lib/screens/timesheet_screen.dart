import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/shift_schedule_dialog.dart';
import '../services/api_service.dart';

class TimesheetScreen extends StatefulWidget {
  const TimesheetScreen({super.key});

  @override
  State<TimesheetScreen> createState() => _TimesheetScreenState();
}

class _TimesheetScreenState extends State<TimesheetScreen> {
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  final List<Map<String, dynamic>> _timesheetData = [];
  List<Map<String, dynamic>> _allWorkers = [];
  bool _isLoadingWorkers = false;
  Map<String, dynamic>? _activeShiftOverride;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    setState(() => _isLoadingWorkers = true);
    try {
      final workersList = await ApiService.getWorkers();
      final records = await ApiService.getAttendance('ALL');
      final dateStr = _selectedDate.toIso8601String().split('T')[0];

      try {
        final override = await ApiService.getScheduleOverrideForDate(dateStr);
        _activeShiftOverride = override != null ? Map<String, dynamic>.from(override as Map) : null;
      } catch (_) {
        _activeShiftOverride = null;
      }

      final Map<String, Map<String, dynamic>> attendanceMap = {};
      for (final r in records) {
        if ((r['date'] ?? '').toString() == dateStr) {
          final wId = (r['worker_id'] ?? '').toString();
          final wName = (r['worker_name'] ?? r['name'] ?? '').toString().trim().toLowerCase();
          if (wId.isNotEmpty) attendanceMap[wId] = Map<String, dynamic>.from(r as Map);
          if (wName.isNotEmpty) attendanceMap[wName] = Map<String, dynamic>.from(r as Map);
        }
      }

      final List<Map<String, dynamic>> timesheet = [];
      for (final w in workersList) {
        final wMap = Map<String, dynamic>.from(w as Map);
        final wId = (wMap['id'] ?? '').toString();
        final firstName = (wMap['first_name'] ?? '').toString();
        final lastName = (wMap['last_name'] ?? '').toString();
        final fullName = (wMap['full_name'] ?? '$firstName $lastName').toString().trim();
        final role = (wMap['role'] ?? wMap['position'] ?? 'Laborer').toString();
        final dailyRate = (wMap['daily_rate'] is num) ? (wMap['daily_rate'] as num).toDouble() : 600.0;

        final att = attendanceMap[wId] ?? attendanceMap[fullName.toLowerCase()];

        final morningIn = att?['morningIn'] ?? att?['morning_in'] ?? att?['timeIn'] ?? att?['time_in'] ?? '—';
        final morningOut = att?['morningOut'] ?? att?['morning_out'] ?? '—';
        final afternoonIn = att?['afternoonIn'] ?? att?['afternoon_in'] ?? '—';
        final afternoonOut = att?['afternoonOut'] ?? att?['afternoon_out'] ?? att?['timeOut'] ?? att?['time_out'] ?? '—';
        final timeIn = att?['timeIn'] ?? att?['time_in'] ?? (morningIn != '—' ? morningIn : (afternoonIn != '—' ? afternoonIn : '—'));
        final timeOut = att?['timeOut'] ?? att?['time_out'] ?? (afternoonOut != '—' ? afternoonOut : (morningOut != '—' ? morningOut : '—'));
        final status = att?['status'] ?? (att != null ? 'Present' : 'Not Recorded');

        timesheet.add({
          'id': wId,
          'attendanceId': att?['id'],
          'name': fullName.isEmpty ? 'Worker' : fullName,
          'role': role,
          'dailyRate': dailyRate,
          'morningIn': morningIn,
          'morningOut': morningOut,
          'afternoonIn': afternoonIn,
          'afternoonOut': afternoonOut,
          'timeIn': timeIn,
          'timeOut': timeOut,
          'regHours': (status == 'Present') ? '8.0h' : (status == 'Halfday' ? '4.0h' : '0.0h'),
          'otHours': '${att?['ot'] ?? att?['overtime_hours'] ?? 0}h',
          'status': status,
          'overtimeHrs': att?['ot'] ?? att?['overtime_hours'] ?? 0,
        });
      }

      if (mounted) {
        setState(() {
          _allWorkers = List<Map<String, dynamic>>.from(workersList);
          _timesheetData.clear();
          _timesheetData.addAll(timesheet);
          _isLoadingWorkers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingWorkers = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int? _parseTimeToMinutes(String? timeStr) {
    if (timeStr == null ||
        timeStr.isEmpty ||
        timeStr == '--:--' ||
        timeStr == '—')
      return null;
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?:\s*([AP]M))?$',
      caseSensitive: false,
    ).firstMatch(timeStr.trim());
    if (match == null) return null;

    int hours = int.tryParse(match.group(1) ?? '8') ?? 8;
    final int minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
    final String? meridian = match.group(3)?.toUpperCase();

    if (meridian == 'PM' && hours < 12) hours += 12;
    if (meridian == 'AM' && hours == 12) hours = 0;

    return hours * 60 + minutes;
  }

  Map<String, dynamic> _evaluateTwoSessions(
    String? morningIn,
    String? afternoonIn, [
    double baseRate = 600.0,
  ]) {
    final mMinutes = _parseTimeToMinutes(morningIn);
    final aMinutes = _parseTimeToMinutes(afternoonIn);

    // Morning Session Check
    String mStatus = 'Absent';
    if (mMinutes != null) {
      if (mMinutes <= 8 * 60 + 10) {
        mStatus = 'Present';
      } else if (mMinutes <= 10 * 60) {
        mStatus = 'Late';
      } else {
        mStatus = 'Absent';
      }
    }

    // Afternoon Session Check
    String aStatus = 'Absent';
    if (aMinutes != null) {
      if (aMinutes <= 13 * 60 + 10) {
        aStatus = 'Present';
      } else if (aMinutes <= 15 * 60) {
        aStatus = 'Late';
      } else {
        aStatus = 'Absent';
      }
    }

    final bool hasMorning = mStatus != 'Absent';
    final bool hasAfternoon = aStatus != 'Absent';

    if (hasMorning && hasAfternoon) {
      if (mStatus == 'Present' && aStatus == 'Present') {
        return {'status': 'Present', 'tag': 'Present (Full)', 'wage': baseRate};
      } else if (mStatus == 'Late' && aStatus == 'Late') {
        return {
          'status': 'Double Late',
          'tag': 'Double Late (-₱200)',
          'wage': (baseRate - 200).clamp(0.0, double.infinity),
        };
      } else {
        return {
          'status': 'Late',
          'tag': 'Late (-₱100)',
          'wage': (baseRate - 100).clamp(0.0, double.infinity),
        };
      }
    } else if (hasMorning) {
      final halfRate = baseRate * 0.5;
      final wage = mStatus == 'Late'
          ? (halfRate - 100).clamp(0.0, double.infinity)
          : halfRate;
      return {
        'status': mStatus == 'Late' ? 'Halfday (Late)' : 'Halfday',
        'tag': mStatus == 'Late'
            ? 'Halfday (Morning Late)'
            : 'Halfday (Morning)',
        'wage': wage,
      };
    } else if (hasAfternoon) {
      final halfRate = baseRate * 0.5;
      final wage = aStatus == 'Late'
          ? (halfRate - 100).clamp(0.0, double.infinity)
          : halfRate;
      return {
        'status': aStatus == 'Late' ? 'Halfday (Late)' : 'Halfday',
        'tag': aStatus == 'Late'
            ? 'Halfday (Afternoon Late)'
            : 'Halfday (Afternoon)',
        'wage': wage,
      };
    }

    return {'status': 'Absent', 'tag': 'Absent', 'wage': 0.0};
  }

  String _getFormattedDate(DateTime date) {
    const months = [
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'W';
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFA63228),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadWorkers();
    }
  }

  Future<String?> _selectTime(BuildContext context, String current) async {
    TimeOfDay initial = const TimeOfDay(hour: 8, minute: 0);
    final match = RegExp(r'^(\d{1,2}):(\d{2})(?:\s*([AP]M))?$', caseSensitive: false).firstMatch(current.trim());
    if (match != null) {
      int h = int.tryParse(match.group(1) ?? '8') ?? 8;
      final m = int.tryParse(match.group(2) ?? '0') ?? 0;
      final mer = match.group(3)?.toUpperCase();
      if (mer == 'PM' && h < 12) h += 12;
      if (mer == 'AM' && h == 12) h = 0;
      initial = TimeOfDay(hour: h, minute: m);
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFA63228),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final minute = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      final formattedHour = hour.toString().padLeft(2, '0');
      return '$formattedHour:$minute $period';
    }
    return null;
  }

  void _showManualAttendanceDialog() {
    _showSetAttendanceDialog();
  }

  void _showSetAttendanceDialog({Map<String, dynamic>? initialWorker}) {
    TextEditingController? autocompleteNameController;
    final TextEditingController idController = TextEditingController(
      text: initialWorker != null ? 'SCON-${initialWorker['id'] ?? ''}' : '',
    );
    String workerName = initialWorker?['name']?.toString() ?? '';
    String workerId = initialWorker?['id']?.toString() ?? '';
    String selectedRole = initialWorker?['role']?.toString() ?? 'Mason';
    double dailyRate = (initialWorker?['dailyRate'] is num)
        ? (initialWorker!['dailyRate'] as num).toDouble()
        : 600.0;

    String selectedStatus = initialWorker?['status']?.toString() ?? 'Present';
    if (selectedStatus == 'Not Recorded' || selectedStatus == 'On Duty') {
      selectedStatus = 'Present';
    }

    String timeInValue = (initialWorker?['timeIn'] != null &&
            initialWorker?['timeIn'] != '—' &&
            initialWorker?['timeIn'] != '--:--')
        ? initialWorker!['timeIn'].toString()
        : '08:00 AM';
    String timeOutValue = (initialWorker?['timeOut'] != null &&
            initialWorker?['timeOut'] != '—' &&
            initialWorker?['timeOut'] != '--:--')
        ? initialWorker!['timeOut'].toString()
        : '05:00 PM';

    DateTime recordDate = _selectedDate;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                initialWorker != null
                                    ? 'Set Attendance Time'
                                    : 'Manual Attendance Entry',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Set exact Time In and Time Out for personnel',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // DATE BADGE & PICKER
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF8F5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFFA63228)),
                                const SizedBox(width: 8),
                                Text(
                                  'Date: ${_getFormattedDate(recordDate)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: recordDate,
                                  firstDate: DateTime(2024),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setModalState(() => recordDate = picked);
                                }
                              },
                              child: Text(
                                'Change',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFA63228),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // WORKER SELECTOR / DISPLAY
                      if (initialWorker != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFA63228).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFA63228).withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFFA63228),
                                radius: 18,
                                child: Text(
                                  _getInitials(workerName),
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      workerName,
                                      style: GoogleFonts.inter(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      '${idController.text} • $selectedRole • ₱${dailyRate.toStringAsFixed(0)}/day',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        Autocomplete<Map<String, dynamic>>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<Map<String, dynamic>>.empty();
                            }
                            return _allWorkers.where((worker) {
                              final name =
                                  '${worker['first_name'] ?? ''} ${worker['last_name'] ?? ''}'.trim();
                              return name.toLowerCase().contains(textEditingValue.text.toLowerCase());
                            });
                          },
                          displayStringForOption: (Map<String, dynamic> option) {
                            return '${option['first_name'] ?? ''} ${option['last_name'] ?? ''}'.trim();
                          },
                          onSelected: (Map<String, dynamic> selection) {
                            final wName = '${selection['first_name'] ?? ''} ${selection['last_name'] ?? ''}'.trim();
                            workerName = wName;
                            workerId = (selection['id'] ?? '').toString();
                            idController.text = 'SCON-$workerId';
                            String roleStr = selection['role']?.toString() ?? 'Mason';
                            dailyRate = (selection['daily_rate'] is num)
                                ? (selection['daily_rate'] as num).toDouble()
                                : 600.0;
                            setModalState(() {
                              selectedRole = roleStr;
                            });
                          },
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            autocompleteNameController = controller;
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              style: GoogleFonts.inter(fontSize: 12.5),
                              decoration: InputDecoration(
                                labelText: 'Worker Full Name',
                                labelStyle: GoogleFonts.inter(fontSize: 11.5),
                                isDense: true,
                                filled: true,
                                fillColor: const Color(0xFFFAF8F5),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 12),

                      // QUICK PRESET BUTTONS
                      Text(
                        'QUICK PRESETS',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.wb_sunny_rounded, size: 14, color: Color(0xFFA63228)),
                            label: Text('Full Day (8AM - 5PM)', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600)),
                            backgroundColor: const Color(0xFFF9F8F6),
                            onPressed: () {
                              setModalState(() {
                                timeInValue = '08:00 AM';
                                timeOutValue = '05:00 PM';
                                selectedStatus = 'Present';
                              });
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.wb_twilight_rounded, size: 14, color: Colors.blue),
                            label: Text('Morning (8AM - 12PM)', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600)),
                            backgroundColor: const Color(0xFFF9F8F6),
                            onPressed: () {
                              setModalState(() {
                                timeInValue = '08:00 AM';
                                timeOutValue = '12:00 PM';
                                selectedStatus = 'Halfday';
                              });
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.nights_stay_rounded, size: 14, color: Colors.orange),
                            label: Text('Afternoon (1PM - 5PM)', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600)),
                            backgroundColor: const Color(0xFFF9F8F6),
                            onPressed: () {
                              setModalState(() {
                                timeInValue = '01:00 PM';
                                timeOutValue = '05:00 PM';
                                selectedStatus = 'Halfday';
                              });
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.cancel_rounded, size: 14, color: Colors.red),
                            label: Text('Absent', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600)),
                            backgroundColor: const Color(0xFFF9F8F6),
                            onPressed: () {
                              setModalState(() {
                                timeInValue = '--:--';
                                timeOutValue = '--:--';
                                selectedStatus = 'Absent';
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // TIME IN & TIME OUT CARDS
                      Text(
                        'SET WORK HOURS',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // TIME IN BOX
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAF8F5),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'TIME IN',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      if (timeInValue != '--:--')
                                        GestureDetector(
                                          onTap: () => setModalState(() => timeInValue = '--:--'),
                                          child: const Icon(Icons.close, size: 14, color: Colors.grey),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    timeInValue,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: timeInValue == '--:--' ? Colors.grey : const Color(0xFFA63228),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 32,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        side: const BorderSide(color: Color(0xFFA63228)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFFA63228)),
                                      label: Text('Set In', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFA63228))),
                                      onPressed: () async {
                                        final res = await _selectTime(context, timeInValue);
                                        if (res != null) {
                                          setModalState(() => timeInValue = res);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // TIME OUT BOX
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAF8F5),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'TIME OUT',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      if (timeOutValue != '--:--')
                                        GestureDetector(
                                          onTap: () => setModalState(() => timeOutValue = '--:--'),
                                          child: const Icon(Icons.close, size: 14, color: Colors.grey),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    timeOutValue,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: timeOutValue == '--:--' ? Colors.grey : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 32,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        side: BorderSide(color: Colors.grey.shade500),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.logout_rounded, size: 14, color: Colors.black87),
                                      label: Text('Set Out', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                                      onPressed: () async {
                                        final res = await _selectTime(context, timeOutValue);
                                        if (res != null) {
                                          setModalState(() => timeOutValue = res);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ATTENDANCE STATUS SELECTOR
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        isDense: true,
                        decoration: InputDecoration(
                          labelText: 'Attendance Status',
                          labelStyle: GoogleFonts.inter(fontSize: 11.5),
                          filled: true,
                          fillColor: const Color(0xFFFAF8F5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: ['Present', 'Late', 'Halfday', 'Absent'].map((st) {
                          return DropdownMenuItem(
                            value: st,
                            child: Text(st, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                        onChanged: (val) => setModalState(() => selectedStatus = val!),
                      ),
                      const SizedBox(height: 18),

                      // ACTION BUTTONS
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFA63228),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: isSaving ? null : () async {
                                final finalWorkerName = workerName.isNotEmpty
                                    ? workerName
                                    : (autocompleteNameController?.text.trim() ?? '');
                                if (finalWorkerName.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please select or enter worker name')),
                                  );
                                  return;
                                }

                                setModalState(() => isSaving = true);
                                final dateStr = recordDate.toIso8601String().split('T')[0];

                                final effectiveTimeIn = timeInValue == '--:--' ? '—' : timeInValue;
                                final effectiveTimeOut = timeOutValue == '--:--' ? '—' : timeOutValue;

                                try {
                                  await ApiService.saveAttendance({
                                    'project_id': '1',
                                    'worker_id': workerId.isNotEmpty ? workerId : null,
                                    'worker_name': finalWorkerName,
                                    'name': finalWorkerName,
                                    'role': selectedRole,
                                    'date': dateStr,
                                    'timeIn': effectiveTimeIn,
                                    'timeOut': effectiveTimeOut,
                                    'rate': dailyRate,
                                    'status': selectedStatus,
                                  });

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Attendance saved: $finalWorkerName (In: $effectiveTimeIn, Out: $effectiveTimeOut)',
                                          style: GoogleFonts.inter(),
                                        ),
                                        backgroundColor: const Color(0xFFA63228),
                                      ),
                                    );
                                  }
                                  await _loadWorkers();
                                } catch (e) {
                                  if (context.mounted) {
                                    setModalState(() => isSaving = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error saving attendance: $e')),
                                    );
                                  }
                                }
                              },
                              child: isSaving
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(
                                      'Save Attendance',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
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
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _timesheetData.where((worker) {
      final matchesRole =
          _selectedFilter == 'All' || worker['role'] == _selectedFilter;
      final query = _searchController.text.toLowerCase().trim();
      final matchesSearch =
          worker['name'].toString().toLowerCase().contains(query) ||
          worker['id'].toString().toLowerCase().contains(query);
      return matchesRole && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Daily Timesheet Logs',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.alarm_on_rounded,
              color: _activeShiftOverride != null ? const Color(0xFFA63228) : Colors.black87,
              size: 20,
            ),
            tooltip: 'Set Shift Schedule',
            onPressed: () {
              ShiftScheduleDialog.show(
                context,
                initialDate: _selectedDate,
                onSaved: () => _loadWorkers(),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.calendar_month_outlined,
              color: Colors.black87,
              size: 20,
            ),
            onPressed: _pickDate,
          ),
          const SizedBox(width: 2),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double screenWidth = constraints.maxWidth;
          final double horizontalPadding = screenWidth > 600 ? 20.0 : 12.0;
          final bool isWideScreen = screenWidth > 700;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                children: [
                  Container(
                    color: Colors.white,
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      4,
                      horizontalPadding,
                      8,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 38,
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (_) => setState(() {}),
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: Colors.black87,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Search worker name or ID...',
                                    hintStyle: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      size: 18,
                                      color: Colors.black54,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 0,
                                      horizontal: 12,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF3EFEA),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 38,
                              width: 38,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFA63228),
                                  padding: EdgeInsets.zero,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: _showManualAttendanceDialog,
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_activeShiftOverride != null) ...[
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () {
                              ShiftScheduleDialog.show(
                                context,
                                initialDate: _selectedDate,
                                onSaved: () => _loadWorkers(),
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFECDCA)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.alarm_on_rounded, size: 15, color: Color(0xFFA63228)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Shift for ${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}: ${_activeShiftOverride!['start_time']} - ${_activeShiftOverride!['grace_period_end']} (On-time window)',
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFA63228)),
                                    ),
                                  ),
                                  const Icon(Icons.edit_outlined, size: 14, color: Color(0xFFA63228)),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children:
                                [
                                  'All',
                                  'Mason',
                                  'Carpenter',
                                  'Laborer',
                                  'Foreman',
                                ].map((role) {
                                  final isSelected = _selectedFilter == role;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 4.0),
                                    child: ChoiceChip(
                                      label: Text(role),
                                      selected: isSelected,
                                      onSelected: (val) {
                                        if (val)
                                          setState(
                                            () => _selectedFilter = role,
                                          );
                                      },
                                      selectedColor: Colors.black87,
                                      backgroundColor: const Color(0xFFF3EFEA),
                                      labelStyle: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                      showCheckmark: false,
                                      side: BorderSide.none,
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Records: ${filteredList.length} Personnel',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _getFormattedDate(_selectedDate),
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.arrow_drop_down,
                                  size: 14,
                                  color: Colors.black87,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filteredList.isEmpty
                        ? Center(
                            child: Text(
                              'No personnel record found.',
                              style: GoogleFonts.inter(
                                color: Colors.grey.shade600,
                                fontSize: 12.5,
                              ),
                            ),
                          )
                        : isWideScreen
                        ? GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                              vertical: 2,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 1.85,
                                ),
                            itemCount: filteredList.length,
                            itemBuilder: (context, index) {
                              return _buildWorkerTimesheetCard(
                                filteredList[index],
                              );
                            },
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                              vertical: 2,
                            ),
                            itemCount: filteredList.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              return _buildWorkerTimesheetCard(
                                filteredList[index],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorkerTimesheetCard(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: Text(
                    _getInitials(item['name']),
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'],
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${item['id']} • ${item['role']}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _showSetAttendanceDialog(initialWorker: item),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA63228).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA63228).withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_calendar_rounded, size: 12, color: Color(0xFFA63228)),
                      const SizedBox(width: 3),
                      Text(
                        'Set Time',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFA63228),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: item['status'] == 'Present'
                      ? const Color(0xFFE6F4EA)
                      : item['status'] == 'Late'
                      ? const Color(0xFFFFF8E1)
                      : item['status'] == 'Halfday'
                      ? const Color(0xFFFFF3E0)
                      : const Color(0xFFFDECEA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: item['status'] == 'Present'
                        ? const Color(0xFFC3E6CB)
                        : item['status'] == 'Late'
                        ? const Color(0xFFFFE082)
                        : item['status'] == 'Halfday'
                        ? const Color(0xFFFFCC80)
                        : const Color(0xFFF5C6CB),
                  ),
                ),
                child: Text(
                  item['tag'] ??
                      (item['status'] == 'Late'
                          ? 'Late (-₱100)'
                          : item['status'] == 'Halfday'
                          ? 'Halfday (50%)'
                          : (item['status'] ?? 'On Duty')),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: item['status'] == 'Present'
                        ? const Color(0xFF2E7D32)
                        : item['status'] == 'Late'
                        ? const Color(0xFFF57F17)
                        : item['status'] == 'Halfday'
                        ? const Color(0xFFE65100)
                        : const Color(0xFFA63228),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F8F6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(child: _buildMetricTile('IN', item['timeIn']?.toString() ?? '—')),
                _buildDivider(),
                Expanded(child: _buildMetricTile('OUT', item['timeOut']?.toString() ?? '—')),
                _buildDivider(),
                Expanded(child: _buildMetricTile('REG', item['regHours']?.toString() ?? '—')),
                _buildDivider(),
                Expanded(child: _buildMetricTile('OT', item['otHours']?.toString() ?? '0h')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(height: 20, width: 1, color: Colors.grey.shade300);
  }
}
