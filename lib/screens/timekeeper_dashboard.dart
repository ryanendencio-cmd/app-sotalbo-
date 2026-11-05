import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'timesheet_screen.dart';
import 'reports_screen.dart';
import 'timekeeper_profile_screen.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/shift_schedule_dialog.dart';
import '../services/api_service.dart';

class TimekeeperDashboard extends StatefulWidget {
  const TimekeeperDashboard({super.key});

  @override
  State<TimekeeperDashboard> createState() => _TimekeeperDashboardState();
}

class _TimekeeperDashboardState extends State<TimekeeperDashboard> {
  int _currentNavIndex = 0;

  DateTime _selectedTrendDate = DateTime.now();

  List<String> _currentCounts = ['55', '58', '48', '53', '56', '38'];
  List<double> _currentFactors = [0.85, 0.90, 0.75, 0.82, 0.88, 0.60];

  final List<Map<String, dynamic>> _recentLogs = [];
  List<Map<String, dynamic>> _allWorkers = [];
  bool _isLoadingWorkers = false;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
    _loadRecentLogs();
  }

  Future<void> _loadRecentLogs() async {
    try {
      final records = await ApiService.getAttendance('ALL');
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final List<Map<String, dynamic>> loaded = [];
      for (final r in records) {
        if (r['date'] == todayStr) {
          final timeIn = r['timeIn'] ?? r['morningIn'] ?? r['afternoonIn'];
          final timeOut = r['timeOut'] ?? r['afternoonOut'] ?? r['morningOut'];
          if (timeIn != null && timeIn != '—') {
            loaded.add({
              'name': r['worker_name'] ?? r['name'] ?? 'Worker',
              'role': r['role'] ?? 'Laborer',
              'time': timeIn,
              'status': r['status'] ?? 'Present',
              'type': 'IN',
            });
          }
          if (timeOut != null && timeOut != '—') {
            loaded.add({
              'name': r['worker_name'] ?? r['name'] ?? 'Worker',
              'role': r['role'] ?? 'Laborer',
              'time': timeOut,
              'status': r['status'] ?? 'Present',
              'type': 'OUT',
            });
          }
        }
      }
      if (mounted && loaded.isNotEmpty) {
        setState(() {
          _recentLogs.clear();
          _recentLogs.addAll(loaded);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadWorkers() async {
    setState(() => _isLoadingWorkers = true);
    try {
      final workersList = await ApiService.getWorkers();
      if (mounted) {
        setState(() {
          _allWorkers = List<Map<String, dynamic>>.from(workersList);
          _isLoadingWorkers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingWorkers = false);
      }
    }
  }

  Future<void> _pickTrendDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedTrendDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFA63228),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedTrendDate) {
      if (!mounted) return;
      setState(() {
        _selectedTrendDate = picked;
        _currentCounts = ['0', '0', '0', '0', '0', '0'];
        _currentFactors = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Graph updated for week of ${picked.month}/${picked.day}/${picked.year}'),
          backgroundColor: Colors.black87,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _openScannerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 24),
              Text('Scan ID Barcode / QR', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 8),
              Text('Align worker ID card with the camera', style: GoogleFonts.inter(color: Colors.grey.shade600)),
              const Spacer(),
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black87, width: 2),
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.grey.shade100,
                ),
                child: const Center(
                  child: Icon(Icons.qr_code_scanner_outlined, size: 60, color: Colors.black54),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: GoogleFonts.inter(color: Colors.black87, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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

  void _openManualEntryDialog() {
    TextEditingController? autocompleteNameController;
    final roleController = TextEditingController(text: 'Mason');
    DateTime selectedDate = DateTime.now();

    final now = TimeOfDay.now();
    final nowHour = now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod;
    final nowMin = now.minute.toString().padLeft(2, '0');
    final nowPeriod = now.period == DayPeriod.am ? 'AM' : 'PM';
    final nowFormatted = '${nowHour.toString().padLeft(2, '0')}:$nowMin $nowPeriod';

    String timeInValue = '08:00 AM';
    String timeOutValue = '05:00 PM';
    String selectedStatus = 'Present';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set Attendance Time',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 17, color: Colors.black87),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Admin / Staff Attendance Adjustment',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width > 500 ? 460 : double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // DATE PICKER ROW
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
                                  'Date: ${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2024),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setDialogState(() => selectedDate = picked);
                                }
                              },
                              child: Text(
                                'Change',
                                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFFA63228)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // WORKER NAME (AUTOCOMPLETE)
                      Autocomplete<Map<String, dynamic>>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<Map<String, dynamic>>.empty();
                          }
                          return _allWorkers.where((worker) {
                            final name = '${worker['first_name'] ?? ''} ${worker['last_name'] ?? ''}'.trim();
                            return name.toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        displayStringForOption: (Map<String, dynamic> option) {
                          return '${option['first_name'] ?? ''} ${option['last_name'] ?? ''}'.trim();
                        },
                        onSelected: (Map<String, dynamic> selection) {
                          roleController.text = selection['role']?.toString() ?? 'Mason';
                        },
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          autocompleteNameController = controller;
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            style: GoogleFonts.inter(color: Colors.black87, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Worker Full Name',
                              labelStyle: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 12),
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFFAF8F5),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFA63228), width: 1.5)),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      // ROLE
                      TextField(
                        controller: roleController,
                        style: GoogleFonts.inter(color: Colors.black87, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Role / Trade (e.g. Mason, Laborer)',
                          labelStyle: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 12),
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFFAF8F5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // QUICK PRESETS
                      Text(
                        'QUICK PRESETS',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: Colors.grey.shade600),
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
                              setDialogState(() {
                                timeInValue = '08:00 AM';
                                timeOutValue = '05:00 PM';
                                selectedStatus = 'Present';
                              });
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.access_time_rounded, size: 14, color: Colors.teal),
                            label: Text('Time In Now ($nowFormatted)', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600)),
                            backgroundColor: const Color(0xFFF9F8F6),
                            onPressed: () {
                              setDialogState(() {
                                timeInValue = nowFormatted;
                                timeOutValue = '--:--';
                                selectedStatus = 'Present';
                              });
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.logout_rounded, size: 14, color: Colors.indigo),
                            label: Text('Time Out Now ($nowFormatted)', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600)),
                            backgroundColor: const Color(0xFFF9F8F6),
                            onPressed: () {
                              setDialogState(() {
                                timeOutValue = nowFormatted;
                              });
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.cancel_rounded, size: 14, color: Colors.red),
                            label: Text('Absent', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600)),
                            backgroundColor: const Color(0xFFF9F8F6),
                            onPressed: () {
                              setDialogState(() {
                                timeInValue = '--:--';
                                timeOutValue = '--:--';
                                selectedStatus = 'Absent';
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // TIME IN & TIME OUT PICKERS
                      Text(
                        'SET EXACT HOURS',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // TIME IN BOX
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAF8F5),
                                borderRadius: BorderRadius.circular(12),
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
                                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade600),
                                      ),
                                      if (timeInValue != '--:--')
                                        GestureDetector(
                                          onTap: () => setDialogState(() => timeInValue = '--:--'),
                                          child: const Icon(Icons.close, size: 14, color: Colors.grey),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timeInValue,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
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
                                      label: Text('Pick Time', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFA63228))),
                                      onPressed: () async {
                                        final res = await _selectTime(context, timeInValue);
                                        if (res != null) {
                                          setDialogState(() => timeInValue = res);
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
                                borderRadius: BorderRadius.circular(12),
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
                                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade600),
                                      ),
                                      if (timeOutValue != '--:--')
                                        GestureDetector(
                                          onTap: () => setDialogState(() => timeOutValue = '--:--'),
                                          child: const Icon(Icons.close, size: 14, color: Colors.grey),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timeOutValue,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
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
                                      label: Text('Pick Time', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                                      onPressed: () async {
                                        final res = await _selectTime(context, timeOutValue);
                                        if (res != null) {
                                          setDialogState(() => timeOutValue = res);
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

                      // STATUS DROPDOWN
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
                        onChanged: (val) => setDialogState(() => selectedStatus = val!),
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              actions: [
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
                        child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA63228),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isSaving ? null : () async {
                          final workerName = autocompleteNameController?.text.trim() ?? '';
                          if (workerName.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter or select worker name')),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          final dateStr = selectedDate.toIso8601String().split('T')[0];

                          final matchedWorker = _allWorkers.firstWhere(
                            (w) => '${w['first_name'] ?? ''} ${w['last_name'] ?? ''}'.trim().toLowerCase() == workerName.toLowerCase(),
                            orElse: () => <String, dynamic>{},
                          );
                          final workerId = matchedWorker['id']?.toString();
                          final workerRate = matchedWorker['daily_rate'] ?? 600;

                          final effectiveTimeIn = timeInValue == '--:--' ? '—' : timeInValue;
                          final effectiveTimeOut = timeOutValue == '--:--' ? '—' : timeOutValue;

                          try {
                            await ApiService.saveAttendance({
                              'project_id': matchedWorker['project_id'] ?? '1',
                              'worker_id': workerId,
                              'worker_name': workerName,
                              'name': workerName,
                              'role': roleController.text,
                              'date': dateStr,
                              'timeIn': effectiveTimeIn,
                              'timeOut': effectiveTimeOut,
                              'rate': workerRate,
                              'status': selectedStatus,
                            });

                            if (mounted) {
                              setState(() {
                                if (effectiveTimeIn != '—') {
                                  _recentLogs.insert(0, {
                                    'name': workerName,
                                    'role': roleController.text,
                                    'time': effectiveTimeIn,
                                    'status': selectedStatus,
                                    'type': 'IN',
                                  });
                                }
                                if (effectiveTimeOut != '—') {
                                  _recentLogs.insert(0, {
                                    'name': workerName,
                                    'role': roleController.text,
                                    'time': effectiveTimeOut,
                                    'status': selectedStatus,
                                    'type': 'OUT',
                                  });
                                }
                              });
                            }

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Attendance recorded for $workerName (In: $effectiveTimeIn, Out: $effectiveTimeOut)', style: GoogleFonts.inter()),
                                  backgroundColor: const Color(0xFFA63228),
                                ),
                              );
                            }
                            _loadRecentLogs();
                          } catch (e) {
                            if (context.mounted) {
                              setDialogState(() => isSaving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error saving log: $e')),
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
                            : Text('Save Record', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildScannerTab(),
      const TimesheetScreen(),
      const ReportsScreen(),
      const TimekeeperProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Image.asset('assets/logo.png', height: 30),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_outlined, color: Colors.black87),
            onPressed: _openScannerModal,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentNavIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          setState(() {
            _currentNavIndex = index;
          });
        },
        selectedItemColor: const Color(0xFFA63228),
        unselectedItemColor: Colors.grey.shade500,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.document_scanner_outlined), activeIcon: Icon(Icons.document_scanner_rounded), label: 'Scanner'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline_rounded), activeIcon: Icon(Icons.people_rounded), label: 'Timesheet'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), activeIcon: Icon(Icons.assignment_rounded), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: MAIN SCANNER DASHBOARD + ANALYTICS
  // ==========================================
  Widget _buildScannerTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double horizontalPadding = constraints.maxWidth > 600 ? constraints.maxWidth * 0.15 : 16.0;

        return Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // GREETING (TANGGAL NA ANG TIMEKEEPER BADGE SA KANAN)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance Terminal',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hello, Admin Mark',
                      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // LIVE HEADCOUNT SUMMARY
                Row(
                  children: [
                    Expanded(child: _buildStatCard('Present', '0')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatCard('Late', '0')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatCard('Absent', '0')),
                  ],
                ),
                const SizedBox(height: 12),

                // ==========================================
                // WEEKLY ATTENDANCE ANALYTICS GRAPH
                // ==========================================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Weekly Attendance Trend',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.edit_calendar_rounded, size: 20, color: Color(0xFFA63228)),
                            tooltip: 'Pick Date to Filter Trend',
                            onPressed: () => _pickTrendDate(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildBarItem('Mon', _currentFactors[0], _currentCounts[0]),
                          _buildBarItem('Tue', _currentFactors[1], _currentCounts[1]),
                          _buildBarItem('Wed', _currentFactors[2], _currentCounts[2]),
                          _buildBarItem('Thu', _currentFactors[3], _currentCounts[3]),
                          _buildBarItem('Fri', _currentFactors[4], _currentCounts[4]),
                          _buildBarItem('Sat', _currentFactors[5], _currentCounts[5]),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // MAIN SCANNER BUTTON
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openScannerModal,
                    borderRadius: BorderRadius.circular(20),
                    splashColor: Colors.white.withValues(alpha: 0.2),
                    highlightColor: Colors.white.withValues(alpha: 0.1),
                    child: Ink(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 26),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA63228),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFA63228).withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.qr_code_scanner_outlined, size: 56, color: Colors.white),
                          const SizedBox(height: 10),
                          Text(
                            'SCAN WORKER ID',
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.0),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap to open camera for Time In / Out',
                            style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white70, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // RECENT LOGS HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Logs (Today)',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black87),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            ShiftScheduleDialog.show(
                              context,
                              initialDate: DateTime.now(),
                              onSaved: () => _loadRecentLogs(),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.alarm_on_rounded, size: 16, color: Color(0xFFA63228)),
                          label: Text(
                            'Shift Hours',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFA63228)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _openManualEntryDialog,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.edit_note_rounded, size: 18, color: Colors.black87),
                          label: Text(
                            'Manual Entry',
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // LOGS LIST DYNAMIC BUILDER
                _recentLogs.isEmpty
                    ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text("No records yet.", style: GoogleFonts.inter(color: Colors.grey)),
                  ),
                )
                    : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentLogs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final log = _recentLogs[index];

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Center(
                              child: Text(
                                log['type'],
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black87
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  log['name'],
                                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  log['role'],
                                  style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                log['time'],
                                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w900, color: Colors.black87),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                log['status'],
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBarItem(String day, double heightFactor, String count) {
    const double maxHeight = 85.0;
    return Column(
      children: [
        Text(
          count,
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Container(
          width: 26,
          height: maxHeight,
          alignment: Alignment.bottomCenter,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: FractionallySizedBox(
            heightFactor: heightFactor,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFA63228),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          day,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}