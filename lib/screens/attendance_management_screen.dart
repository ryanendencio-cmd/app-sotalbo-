import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

import '../services/api_service.dart';
import '../widgets/admin_mobile_chrome.dart';

class AttendanceManagementScreen extends StatefulWidget {
  const AttendanceManagementScreen({super.key});

  @override
  State<AttendanceManagementScreen> createState() =>
      _AttendanceManagementScreenState();
}

class _AttendanceManagementScreenState extends State<AttendanceManagementScreen>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFFA63228);

  late final TabController _tabController;
  final _hoursController = TextEditingController();
  final _graceController = TextEditingController();
  List<Map<String, dynamic>> _workers = [];
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _attendanceRecords = [];
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _correctionRequests = [];
  DateTime _selectedAttendanceDate = DateTime.now();
  String _selectedProjectId = 'ALL';
  String _attendanceSessionFilter = 'All';
  bool _isLoading = true;
  bool _isLoadingNotifications = false;
  bool _isSavingSettings = false;
  bool _isRecordingScan = false;
  bool _autoSchedule = true;
  bool _sundaysOff = true;
  String _manualOverride = 'AUTO';
  String _timeIn = '08:00';
  String _timeOut = '17:00';
  String? _loadError;
  String? _notificationsError;
  List<Map<String, dynamic>> _notifications = [];
  final Set<String> _reviewingRequestIds = {};
  final Set<String> _reviewingCorrectionIds = {};

  bool get _isAdminMobile =>
      ApiService.currentUserRole?.toLowerCase() == 'admin';
  bool get _canMonitorAttendance {
    final role = ApiService.currentUserRole?.toLowerCase();
    final position = (ApiService.currentUser?['position'] ?? '')
        .toString()
        .toLowerCase();
    return role == 'admin' ||
        role == 'staff' ||
        (role == 'worker' && position.contains('attendance monitoring'));
  }

  bool _hasAttendanceValue(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();
    return normalized != null &&
        normalized.isNotEmpty &&
        normalized != '—' &&
        normalized != '--:--';
  }

  String _firstAttendanceValue(
    Map<String, dynamic>? record,
    List<String> keys,
  ) {
    if (record == null) return '—';
    for (final key in keys) {
      final value = record[key]?.toString().trim();
      if (value != null &&
          value.isNotEmpty &&
          value != '—' &&
          value != '--:--') {
        return value;
      }
    }
    return '—';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    if (_isAdminMobile) _loadNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hoursController.dispose();
    _graceController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        ApiService.getAttendanceSettings(),
        ApiService.getAttendanceSchedules(),
        ApiService.getWorkers(),
        ApiService.getEarlyOutRequests(),
        ApiService.getAttendanceCorrectionRequests(),
        ApiService.getAttendance('ALL'),
        ApiService.getProjects(),
      ]);
      if (!mounted) return;
      final settings = Map<String, dynamic>.from(results[0] as Map);
      setState(() {
        _autoSchedule = settings['auto_schedule'] != false;
        _sundaysOff = settings['auto_sundays_off'] != false;
        _manualOverride = (settings['manual_override'] ?? 'AUTO').toString();
        _timeIn = (settings['default_time_in'] ?? '08:00').toString();
        _timeOut = (settings['default_time_out'] ?? '17:00').toString();
        _hoursController.text = (settings['daily_work_hours'] ?? 8).toString();
        _graceController.text = (settings['grace_period_minutes'] ?? 10)
            .toString();
        _schedules = (results[1] as List)
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList();
        _workers = (results[2] as List)
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList();
        _requests = (results[3] as List)
            .map((value) => Map<String, dynamic>.from(value as Map))
            .where(
              (request) =>
                  !_isAdminMobile ||
                  (request['role'] ?? 'Worker').toString().toLowerCase() ==
                      'worker',
            )
            .toList();
        _correctionRequests = (results[4] as List)
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList();
        _attendanceRecords = (results[5] as List)
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList();
        _projects = (results[6] as List)
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Unable to load attendance management data: $error';
      });
    }
  }

  Future<void> _loadNotifications() async {
    if (mounted) {
      setState(() {
        _isLoadingNotifications = true;
        _notificationsError = null;
      });
    }
    try {
      final result = await ApiService.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = result
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _isLoadingNotifications = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _notificationsError = 'Unable to load notifications: $error';
        _isLoadingNotifications = false;
      });
    }
  }

  Future<void> _showAttendanceScanOptions() async {
    final method = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Record Attendance',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.nfc_rounded, color: _primary),
                title: const Text('Scan RFID with NFC'),
                subtitle: const Text('Tap the worker card on this phone'),
                onTap: () => Navigator.pop(sheetContext, 'nfc'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: _primary,
                ),
                title: const Text('Scan Worker QR'),
                subtitle: const Text('Scan the QR code on the worker profile'),
                onTap: () => Navigator.pop(sheetContext, 'qr'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || method == null) return;

    if (method == 'nfc') {
      final uid = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const _NfcAttendanceScannerScreen()),
      );
      if (uid != null && mounted) {
        await _submitAttendanceScan(
          () => ApiService.scanAttendanceWithNfc(uid),
        );
      }
    } else {
      final workerCode = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const _QrAttendanceScannerScreen()),
      );
      if (workerCode != null && mounted) {
        await _submitAttendanceScan(
          () => ApiService.scanAttendanceWithQr(workerCode),
        );
      }
    }
  }

  Future<void> _submitAttendanceScan(
    Future<Map<String, dynamic>> Function() submit,
  ) async {
    setState(() => _isRecordingScan = true);
    try {
      final result = await submit();
      await _loadData();
      if (!mounted) return;
      final workerName = (result['worker_name'] ?? 'Worker').toString();
      final action = (result['action'] ?? 'Attendance recorded').toString();
      final time = (result['time'] ?? '').toString();
      _showMessage(
        '$action for $workerName${time.isEmpty ? '' : ' at $time'}.',
      );
    } catch (error) {
      _showMessage('Unable to record attendance: $error');
    } finally {
      if (mounted) setState(() => _isRecordingScan = false);
    }
  }

  int get _unreadNotifications => _notifications.where((notification) {
    final value = notification['read'];
    return value != true && value?.toString().toLowerCase() != 'true';
  }).length;

  Future<void> _showNotifications() async {
    await _loadNotifications();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.75,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Notifications',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _unreadNotifications == 0
                            ? null
                            : () async {
                                try {
                                  await ApiService.markAllNotificationsRead();
                                  if (!mounted) return;
                                  setState(() {
                                    for (final notification in _notifications) {
                                      notification['read'] = true;
                                    }
                                  });
                                  setSheetState(() {});
                                } catch (error) {
                                  _showMessage(
                                    'Unable to mark notifications as read: $error',
                                  );
                                }
                              },
                        child: const Text('Mark all read'),
                      ),
                      IconButton(
                        tooltip: 'Refresh notifications',
                        onPressed: () async {
                          await _loadNotifications();
                          if (sheetContext.mounted) setSheetState(() {});
                        },
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _isLoadingNotifications
                      ? const Center(
                          child: CircularProgressIndicator(color: _primary),
                        )
                      : _notificationsError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(
                              _notificationsError!,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _notifications.isEmpty
                      ? Center(
                          child: Text(
                            'No notifications.',
                            style: GoogleFonts.inter(color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _notifications.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final notification = _notifications[index];
                            final isRead =
                                notification['read'] == true ||
                                notification['read']
                                        ?.toString()
                                        .toLowerCase() ==
                                    'true';
                            return ListTile(
                              leading: Icon(
                                isRead
                                    ? Icons.notifications_none_rounded
                                    : Icons.notifications_active_rounded,
                                color: isRead
                                    ? Colors.grey
                                    : const Color(0xFFA63228),
                              ),
                              title: Text(
                                (notification['title'] ?? 'Notification')
                                    .toString(),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: isRead
                                      ? FontWeight.w500
                                      : FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                (notification['message'] ?? '').toString(),
                                style: GoogleFonts.inter(fontSize: 11),
                              ),
                              onTap: isRead
                                  ? null
                                  : () async {
                                      try {
                                        await ApiService.markNotificationRead(
                                          notification['id'],
                                        );
                                        if (!mounted) return;
                                        setState(
                                          () => notification['read'] = true,
                                        );
                                        setSheetState(() {});
                                      } catch (error) {
                                        _showMessage(
                                          'Unable to mark notification as read: $error',
                                        );
                                      }
                                    },
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

  String _adminName() =>
      (ApiService.currentUser?['name'] ??
              ApiService.currentUser?['full_name'] ??
              'Attendance Administrator')
          .toString();

  String _workerName(Map<String, dynamic> worker) {
    final name = (worker['full_name'] ?? worker['name'] ?? '')
        .toString()
        .trim();
    if (name.isNotEmpty) return name;
    return '${worker['first_name'] ?? ''} ${worker['last_name'] ?? ''}'.trim();
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  TimeOfDay _parseTime(String? raw, TimeOfDay fallback) {
    if (raw == null) return fallback;
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw);
    if (match == null) return fallback;
    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return fallback;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _pickTime({
    required String current,
    required ValueChanged<String> onPicked,
  }) async {
    final value = await showTimePicker(
      context: context,
      initialTime: _parseTime(current, const TimeOfDay(hour: 8, minute: 0)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black87,
          ),
        ),
        child: child!,
      ),
    );
    if (value != null) onPicked(_formatTime(value));
  }

  Future<void> _saveSettings() async {
    final hours = double.tryParse(_hoursController.text.trim());
    final grace = int.tryParse(_graceController.text.trim());
    if (hours == null || hours <= 0 || hours > 24) {
      _showMessage('Working hours must be between 0 and 24 hours.');
      return;
    }
    if (grace == null || grace < 0 || grace > 180) {
      _showMessage('Grace period must be between 0 and 180 minutes.');
      return;
    }
    setState(() => _isSavingSettings = true);
    try {
      await ApiService.saveAttendanceSettings({
        'auto_schedule': _autoSchedule,
        'open_time': _timeIn,
        'close_time': _timeOut,
        'default_time_in': _timeIn,
        'default_time_out': _timeOut,
        'daily_work_hours': hours,
        'grace_period_minutes': grace,
        'auto_sundays_off': _sundaysOff,
        'manual_override': _manualOverride == 'AUTO' ? null : _manualOverride,
        'updated_by': _adminName(),
      });
      _showMessage('Attendance rules saved.');
    } catch (error) {
      _showMessage('Unable to save attendance rules: $error');
    } finally {
      if (mounted) setState(() => _isSavingSettings = false);
    }
  }

  Future<void> _showScheduleEditor({Map<String, dynamic>? schedule}) async {
    final formKey = GlobalKey<FormState>();
    var selectedDate =
        DateTime.tryParse((schedule?['date'] ?? '').toString()) ??
        DateTime.now();
    var selectedWorkerId = schedule?['worker_id']?.toString();
    var selectedWorkerName = (schedule?['worker_name'] ?? 'All Workers')
        .toString();
    var startTime = (schedule?['start_time'] ?? _timeIn).toString();
    var endTime = (schedule?['end_time'] ?? _timeOut).toString();
    final hoursController = TextEditingController(
      text: (schedule?['working_hours'] ?? _hoursController.text).toString(),
    );
    final notesController = TextEditingController(
      text: (schedule?['notes'] ?? '').toString(),
    );
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            schedule == null ? 'Create Attendance Schedule' : 'Edit Schedule',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.calendar_month,
                        color: _primary,
                      ),
                      title: const Text('Schedule date'),
                      subtitle: Text(_formatDate(selectedDate)),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedWorkerId,
                      decoration: const InputDecoration(
                        labelText: 'Apply to worker',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All workers'),
                        ),
                        ..._workers.map((worker) {
                          final id = worker['id']?.toString();
                          return DropdownMenuItem<String?>(
                            value: id,
                            child: Text(
                              _workerName(worker),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        selectedWorkerId = value;
                        selectedWorkerName = value == null
                            ? 'All Workers'
                            : _workerName(
                                _workers.firstWhere(
                                  (worker) => worker['id']?.toString() == value,
                                ),
                              );
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _timeButton('Time In', startTime, () async {
                            await _pickTime(
                              current: startTime,
                              onPicked: (value) =>
                                  setDialogState(() => startTime = value),
                            );
                          }),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _timeButton('Time Out', endTime, () async {
                            await _pickTime(
                              current: endTime,
                              onPicked: (value) =>
                                  setDialogState(() => endTime = value),
                            );
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: hoursController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Working hours',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final hours = double.tryParse(value ?? '');
                        return hours == null || hours <= 0 || hours > 24
                            ? 'Enter a value from 0 to 24'
                            : null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _primary),
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      final start = _parseTime(
                        startTime,
                        const TimeOfDay(hour: 8, minute: 0),
                      );
                      final end = _parseTime(
                        endTime,
                        const TimeOfDay(hour: 17, minute: 0),
                      );
                      if (end.hour * 60 + end.minute <=
                          start.hour * 60 + start.minute) {
                        _showMessage('Time Out must be later than Time In.');
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await ApiService.saveAttendanceSchedule({
                          if (schedule?['id'] != null) 'id': schedule!['id'],
                          'date': _formatDate(selectedDate),
                          'worker_id': selectedWorkerId,
                          'worker_name': selectedWorkerName,
                          'start_time': startTime,
                          'end_time': endTime,
                          'working_hours': double.parse(
                            hoursController.text.trim(),
                          ),
                          'notes': notesController.text.trim(),
                        });
                        if (!mounted || !dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        await _loadData();
                        _showMessage('Attendance schedule saved and applied.');
                      } catch (error) {
                        _showMessage('Unable to save schedule: $error');
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save Schedule'),
            ),
          ],
        ),
      ),
    );
    hoursController.dispose();
    notesController.dispose();
  }

  Future<void> _reviewRequest(
    Map<String, dynamic> request,
    String status,
  ) async {
    final id = request['id']?.toString();
    if (id == null || id.isEmpty) {
      _showMessage('This request has no record ID.');
      return;
    }
    setState(() => _reviewingRequestIds.add(id));
    try {
      await ApiService.reviewEarlyOutRequest(id, {
        'status': status,
        'reviewed_by': _adminName(),
      });
      await _loadData();
      _showMessage(
        status == 'Approved'
            ? 'Request approved and applied to attendance.'
            : 'Request rejected.',
      );
    } catch (error) {
      _showMessage('Unable to review request: $error');
    } finally {
      if (mounted) {
        setState(() => _reviewingRequestIds.remove(id));
      }
    }
  }

  Future<void> _reviewCorrectionRequest(
    Map<String, dynamic> request,
    String status,
  ) async {
    final id = request['id']?.toString();
    if (id == null || id.isEmpty) {
      _showMessage('This correction request has no record ID.');
      return;
    }
    setState(() => _reviewingCorrectionIds.add(id));
    try {
      await ApiService.reviewAttendanceCorrectionRequest(id, {
        'status': status,
        'reviewed_by': _adminName(),
      });
      await _loadData();
      _showMessage(
        status == 'Approved'
            ? 'Correction approved and applied to attendance.'
            : 'Correction rejected.',
      );
    } catch (error) {
      _showMessage('Unable to review correction: $error');
    } finally {
      if (mounted) setState(() => _reviewingCorrectionIds.remove(id));
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: _primary));
  }

  Widget _timeButton(String label, String value, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
        foregroundColor: Colors.black87,
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12)),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesTab() {
    final schedules = [..._schedules]
      ..sort(
        (a, b) => (a['date'] ?? '').toString().compareTo(
          (b['date'] ?? '').toString(),
        ),
      );
    return RefreshIndicator(
      color: _primary,
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.all(14),
        children: [
          _sectionCard(
            title: 'Default Attendance Rules',
            icon: Icons.rule_outlined,
            child: Column(
              children: [
                _timeButton('Default Time In', _timeIn, () {
                  _pickTime(
                    current: _timeIn,
                    onPicked: (value) => setState(() => _timeIn = value),
                  );
                }),
                const SizedBox(height: 8),
                _timeButton('Default Time Out', _timeOut, () {
                  _pickTime(
                    current: _timeOut,
                    onPicked: (value) => setState(() => _timeOut = value),
                  );
                }),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _hoursController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Working hours/day',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _graceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Grace minutes',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: _primary,
                  title: const Text('Enable automatic attendance hours'),
                  value: _autoSchedule,
                  onChanged: (value) => setState(() => _autoSchedule = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: _primary,
                  title: const Text('Sundays are non-working days'),
                  value: _sundaysOff,
                  onChanged: (value) => setState(() => _sundaysOff = value),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _manualOverride,
                  decoration: const InputDecoration(
                    labelText: 'Attendance terminal',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'AUTO', child: Text('Automatic')),
                    DropdownMenuItem(value: 'OPEN', child: Text('Force open')),
                    DropdownMenuItem(
                      value: 'CLOSED',
                      child: Text('Force closed'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _manualOverride = value);
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSavingSettings ? null : _saveSettings,
                    style: FilledButton.styleFrom(backgroundColor: _primary),
                    icon: _isSavingSettings
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save Rules'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Worker Schedules',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showScheduleEditor(),
                style: FilledButton.styleFrom(backgroundColor: _primary),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (schedules.isEmpty)
            _emptyMessage('No custom schedules have been created.')
          else
            ...schedules.map(_buildScheduleCard),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFF7EDEA),
          child: Icon(Icons.schedule, color: _primary),
        ),
        title: Text(
          (schedule['worker_name'] ?? 'All Workers').toString(),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Text(
          '${schedule['date']} • ${schedule['start_time']} - ${schedule['end_time']}'
          ' • ${schedule['working_hours']} hrs'
          '${(schedule['notes'] ?? '').toString().isEmpty ? '' : '\n${schedule['notes']}'}',
          style: GoogleFonts.inter(fontSize: 11, height: 1.5),
        ),
        isThreeLine: (schedule['notes'] ?? '').toString().isNotEmpty,
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'edit') {
              await _showScheduleEditor(schedule: schedule);
            } else if (value == 'delete') {
              await _deleteSchedule(schedule);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSchedule(Map<String, dynamic> schedule) async {
    final id = schedule['id'];
    if (id == null) return;
    try {
      await ApiService.deleteAttendanceSchedule(id);
      await _loadData();
      _showMessage('Schedule deleted.');
    } catch (error) {
      _showMessage('Unable to delete schedule: $error');
    }
  }

  Widget _buildRequestsTab() {
    final requests = [..._requests]
      ..sort((a, b) {
        final aPending = a['status'] == 'Pending';
        final bPending = b['status'] == 'Pending';
        if (aPending != bPending) return aPending ? -1 : 1;
        return (b['date'] ?? '').toString().compareTo(
          (a['date'] ?? '').toString(),
        );
      });
    return RefreshIndicator(
      color: _primary,
      onRefresh: _loadData,
      child: requests.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 140),
                _emptyMessage('No early-out requests have been submitted.'),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.all(14),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _buildRequestCard(requests[index]),
            ),
    );
  }

  Widget _buildCorrectionRequestsTab() {
    final requests = [..._correctionRequests]
      ..sort((a, b) {
        final aPending = a['status'] == 'Pending';
        final bPending = b['status'] == 'Pending';
        if (aPending != bPending) return aPending ? -1 : 1;
        return (b['date'] ?? '').toString().compareTo(
          (a['date'] ?? '').toString(),
        );
      });
    return RefreshIndicator(
      color: _primary,
      onRefresh: _loadData,
      child: requests.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 140),
                _emptyMessage(
                  'No attendance correction requests have been submitted.',
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.all(14),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final request = requests[index];
                final id = request['id']?.toString() ?? '';
                final status = (request['status'] ?? 'Pending').toString();
                final isPending = status == 'Pending';
                final isBusy = _reviewingCorrectionIds.contains(id);
                final field = request['field'] == 'time_in'
                    ? 'Time In'
                    : 'Time Out';
                final originalTime = (request['original_time'] ?? '')
                    .toString()
                    .trim();
                final subtitle =
                    '${request['date']} • $field: '
                    '${originalTime.isEmpty ? '—' : originalTime} → '
                    '${request['requested_time'] ?? '—'}\n'
                    'Reason: ${request['reason'] ?? '—'}';
                return Card(
                  color: Colors.white,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.edit_calendar_outlined,
                              color: _primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (request['worker_name'] ?? 'Worker').toString(),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            _statusBadge(status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(fontSize: 12, height: 1.5),
                        ),
                        if (isPending) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isBusy
                                      ? null
                                      : () => _reviewCorrectionRequest(
                                          request,
                                          'Rejected',
                                        ),
                                  child: const Text('Reject'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton(
                                  onPressed: isBusy
                                      ? null
                                      : () => _reviewCorrectionRequest(
                                          request,
                                          'Approved',
                                        ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _primary,
                                  ),
                                  child: isBusy
                                      ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Approve'),
                                ),
                              ),
                            ],
                          ),
                        ] else if (request['reviewed_by'] != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Reviewed by ${request['reviewed_by']}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final id = request['id']?.toString() ?? '';
    final status = (request['status'] ?? 'Pending').toString();
    final isPending = status == 'Pending';
    final isBusy = _reviewingRequestIds.contains(id);
    final subtitle = [
      request['date'],
      'Requested out: ${request['requested_out_time'] ?? '—'}',
      'Reason: ${request['reason'] ?? '—'}',
      if ((request['details'] ?? '').toString().trim().isNotEmpty)
        request['details'],
    ].join('\n');
    return Card(
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.exit_to_app, color: _primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (request['worker_name'] ?? 'Worker').toString(),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _statusBadge(status),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 12, height: 1.5)),
            if (isPending) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isBusy
                          ? null
                          : () => _reviewRequest(request, 'Rejected'),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: isBusy
                          ? null
                          : () => _reviewRequest(request, 'Approved'),
                      style: FilledButton.styleFrom(backgroundColor: _primary),
                      child: isBusy
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ] else if (request['reviewed_by'] != null) ...[
              const SizedBox(height: 6),
              Text(
                'Reviewed by ${request['reviewed_by']}',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final normalized = status.toLowerCase();
    final pending = normalized == 'pending';
    final approved =
        normalized == 'approved' ||
        normalized == 'present' ||
        normalized == 'full day';
    final warning = normalized.contains('late') || normalized == 'halfday';
    final neutral = normalized == 'not recorded' || normalized == 'non-working';
    final color = neutral
        ? Colors.grey.shade700
        : warning
        ? Colors.orange.shade800
        : pending
        ? Colors.orange.shade800
        : approved
        ? Colors.green.shade800
        : Colors.red.shade800;
    final background = neutral
        ? Colors.grey.shade100
        : warning
        ? Colors.orange.shade50
        : pending
        ? Colors.orange.shade50
        : approved
        ? Colors.green.shade50
        : Colors.red.shade50;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Future<void> _pickAttendanceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedAttendanceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedAttendanceDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
        );
      });
    }
  }

  Widget _buildAttendanceMonitorTab() {
    final date = _formatDate(_selectedAttendanceDate);
    final recordsByWorkerId = <String, Map<String, dynamic>>{};
    final recordsByWorkerName = <String, Map<String, dynamic>>{};
    for (final record in _attendanceRecords) {
      if ((record['date'] ?? '').toString() != date) continue;
      if (_selectedProjectId != 'ALL' &&
          (record['project_id'] ?? '').toString() != _selectedProjectId) {
        continue;
      }
      final workerId = (record['worker_id'] ?? '').toString();
      final workerName = (record['worker_name'] ?? record['name'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (workerId.isNotEmpty) recordsByWorkerId[workerId] = record;
      if (workerName.isNotEmpty) recordsByWorkerName[workerName] = record;
    }

    final workers = _workers.where((worker) {
      final status = (worker['status'] ?? '').toString().toLowerCase();
      final approval = (worker['approval_status'] ?? '')
          .toString()
          .toLowerCase();
      final projectId = (worker['project_id'] ?? '').toString();
      final workerName = _workerName(worker).toLowerCase();
      return status != 'inactive' &&
          approval != 'pending' &&
          (_selectedProjectId == 'ALL' ||
              projectId == _selectedProjectId ||
              recordsByWorkerId.containsKey((worker['id'] ?? '').toString()) ||
              recordsByWorkerName.containsKey(workerName));
    }).toList();

    final rows = workers.map((worker) {
      final id = (worker['id'] ?? '').toString();
      final name = _workerName(worker);
      final record =
          recordsByWorkerId[id] ?? recordsByWorkerName[name.toLowerCase()];
      final morningIn = _firstAttendanceValue(record, [
        'morningIn',
        'morning_in',
        'timeIn',
        'time_in',
      ]);
      final morningOut = _firstAttendanceValue(record, [
        'morningOut',
        'morning_out',
      ]);
      final afternoonIn = _firstAttendanceValue(record, [
        'afternoonIn',
        'afternoon_in',
      ]);
      final afternoonOut = _firstAttendanceValue(record, [
        'afternoonOut',
        'afternoon_out',
        'timeOut',
        'time_out',
      ]);
      final rawStatus =
          (record?['status'] ?? (record == null ? 'Not Recorded' : 'Present'))
              .toString();
      final normalizedStatus = rawStatus.toLowerCase();
      final status = normalizedStatus.contains('halfday')
          ? 'Halfday'
          : normalizedStatus.contains('double late')
          ? 'Late'
          : normalizedStatus.contains('late')
          ? 'Late'
          : normalizedStatus.contains('absent')
          ? 'Absent'
          : normalizedStatus.contains('non-working')
          ? 'Non-working'
          : normalizedStatus == 'present' || normalizedStatus == 'full day'
          ? 'Full day'
          : rawStatus;
      final hasMorningAttendance =
          morningIn != '—' ||
          morningOut != '—' ||
          _hasAttendanceValue(
            record?['morningStatus'] ?? record?['morning_status'],
          );
      final hasAfternoonAttendance =
          afternoonIn != '—' ||
          afternoonOut != '—' ||
          _hasAttendanceValue(
            record?['afternoonStatus'] ?? record?['afternoon_status'],
          );
      return {
        'name': name.isEmpty ? 'Worker' : name,
        'role': (worker['role'] ?? worker['position'] ?? 'Worker').toString(),
        'status': status,
        'morningIn': morningIn,
        'morningOut': morningOut,
        'afternoonIn': afternoonIn,
        'afternoonOut': afternoonOut,
        'hasMorningAttendance': hasMorningAttendance,
        'hasAfternoonAttendance': hasAfternoonAttendance,
      };
    }).toList();
    final visibleRows = rows.where((row) {
      if (_attendanceSessionFilter == 'Morning') {
        return row['hasMorningAttendance'] == true || row['status'] == 'Absent';
      }
      if (_attendanceSessionFilter == 'Afternoon') {
        return row['hasAfternoonAttendance'] == true ||
            row['status'] == 'Absent';
      }
      return true;
    }).toList();
    final fullDayCount = visibleRows
        .where((row) => row['status'] == 'Full day')
        .length;
    final lateCount = visibleRows
        .where((row) => row['status'] == 'Late')
        .length;
    final halfdayCount = visibleRows
        .where((row) => row['status'] == 'Halfday')
        .length;
    final absentCount = visibleRows
        .where((row) => row['status'] == 'Absent')
        .length;
    final presentCount = fullDayCount + lateCount + halfdayCount;

    return RefreshIndicator(
      color: _primary,
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.all(14),
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isRecordingScan ? null : _showAttendanceScanOptions,
              icon: const Icon(Icons.how_to_reg_rounded),
              label: Text(
                _isRecordingScan
                    ? 'Recording Attendance...'
                    : 'Record Attendance',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Attendance Status',
            icon: Icons.fact_check_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue:
                      _projects.any(
                        (project) =>
                            (project['id'] ?? '').toString() ==
                            _selectedProjectId,
                      )
                      ? _selectedProjectId
                      : 'ALL',
                  decoration: const InputDecoration(
                    labelText: 'Project',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'ALL',
                      child: Text('All Projects'),
                    ),
                    ..._projects.map(
                      (project) => DropdownMenuItem(
                        value: (project['id'] ?? '').toString(),
                        child: Text(
                          (project['name'] ?? 'Project').toString(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedProjectId = value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickAttendanceDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(date),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Morning', 'Afternoon'].map((session) {
                      final selected = _attendanceSessionFilter == session;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(session),
                          selected: selected,
                          selectedColor: _primary,
                          labelStyle: GoogleFonts.inter(
                            fontSize: 11,
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          onSelected: (value) {
                            if (value) {
                              setState(
                                () => _attendanceSessionFilter = session,
                              );
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Present: $presentCount workers',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _statusCount('Full day', fullDayCount, Colors.green),
                    const SizedBox(width: 8),
                    _statusCount('Late', lateCount, Colors.orange),
                    const SizedBox(width: 8),
                    _statusCount('Halfday', halfdayCount, Colors.deepOrange),
                    const SizedBox(width: 8),
                    _statusCount('Absent', absentCount, Colors.red),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (visibleRows.isEmpty)
            _sectionCard(
              title: 'Workers',
              icon: Icons.people_outline,
              child: _emptyMessage('No active workers found.'),
            )
          else
            ...visibleRows.map((row) {
              final timeIn = _attendanceSessionFilter == 'Morning'
                  ? row['morningIn']
                  : _attendanceSessionFilter == 'Afternoon'
                  ? row['afternoonIn']
                  : row['morningIn'] != '—'
                  ? row['morningIn']
                  : row['afternoonIn'];
              final timeOut = _attendanceSessionFilter == 'Morning'
                  ? row['morningOut']
                  : _attendanceSessionFilter == 'Afternoon'
                  ? row['afternoonOut']
                  : row['afternoonOut'] != '—'
                  ? row['afternoonOut']
                  : row['morningOut'];
              return Card(
                color: Colors.white,
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    row['name'] as String,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${row['role']} · In $timeIn · Out $timeOut',
                    style: GoogleFonts.inter(fontSize: 11),
                  ),
                  trailing: _statusBadge(row['status'] as String),
                ),
              );
            }),
          const SizedBox(height: 8),
          Text(
            'Workers without an attendance record are shown as Not Recorded; they are not automatically counted absent.',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _statusCount(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _emptyMessage(String text) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      appBar: _isAdminMobile
          ? AdminMobileAppBar(
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _isLoading ? null : _loadData,
                  icon: const Icon(Icons.refresh, color: Colors.black87),
                ),
              ],
              onNotificationsPressed: _showNotifications,
              unreadCount: _unreadNotifications,
              bottom: _buildAttendanceTabs(),
            )
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              title: Text(
                'Attendance Management',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _isLoading ? null : _loadData,
                  icon: const Icon(Icons.refresh, color: Colors.black87),
                ),
              ],
              bottom: _buildAttendanceTabs(),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _canMonitorAttendance
                    ? _buildAttendanceMonitorTab()
                    : _buildRulesTab(),
                _buildRequestsTab(),
                _buildCorrectionRequestsTab(),
              ],
            ),
      bottomNavigationBar: _isAdminMobile
          ? AdminMobileBottomNavigationBar(
              currentIndex: 4,
              onTap: (index) => navigateAdminMobileSection(context, index),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAttendanceTabs() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(44),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: _primary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: _primary,
        tabs: [
          Tab(text: _canMonitorAttendance ? 'Attendance' : 'Schedules & Rules'),
          Tab(
            text:
                'Early Out (${_requests.where((r) => r['status'] == 'Pending').length})',
          ),
          Tab(
            text:
                'Corrections (${_correctionRequests.where((r) => r['status'] == 'Pending').length})',
          ),
        ],
      ),
    );
  }
}

class _NfcAttendanceScannerScreen extends StatefulWidget {
  const _NfcAttendanceScannerScreen();

  @override
  State<_NfcAttendanceScannerScreen> createState() =>
      _NfcAttendanceScannerScreenState();
}

class _NfcAttendanceScannerScreenState
    extends State<_NfcAttendanceScannerScreen> {
  bool _isStarting = true;
  bool _sessionActive = false;
  String _message = 'Preparing NFC reader...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSession());
  }

  @override
  void dispose() {
    if (_sessionActive) {
      NfcManager.instance.stopSession().catchError((Object error) {
        debugPrint('Unable to stop NFC session: $error');
      });
    }
    super.dispose();
  }

  Future<void> _startSession() async {
    if (!Platform.isAndroid) {
      if (mounted) {
        setState(() {
          _isStarting = false;
          _message =
              'NFC attendance scanning is currently supported on Android.';
        });
      }
      return;
    }

    try {
      final availability = await NfcManager.instance.checkAvailability();
      if (availability != NfcAvailability.enabled) {
        if (mounted) {
          setState(() {
            _isStarting = false;
            _message = 'Turn on NFC in your phone settings, then try again.';
          });
        }
        return;
      }

      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443},
        alertMessageIos: 'Hold the worker RFID card near your phone.',
        onDiscovered: (tag) async {
          final identifier = NfcTagAndroid.from(tag)?.id
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join()
              .toUpperCase();
          await NfcManager.instance.stopSession();
          _sessionActive = false;
          if (!mounted) return;
          if (identifier == null || identifier.isEmpty) {
            setState(() {
              _isStarting = false;
              _message = 'Could not read the card UID. Tap Try Again.';
            });
            return;
          }
          Navigator.of(context).pop(identifier);
        },
      );
      _sessionActive = true;
      if (mounted) {
        setState(() {
          _isStarting = false;
          _message =
              'Hold the worker RFID card near the NFC area of this phone.';
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isStarting = false;
        _message = 'Could not start NFC scanning: $error';
      });
    }
  }

  Future<void> _cancel() async {
    if (_sessionActive) {
      await NfcManager.instance.stopSession();
      _sessionActive = false;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan RFID with NFC'),
        actions: [TextButton(onPressed: _cancel, child: const Text('Cancel'))],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.nfc_rounded,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 18),
              if (_isStarting)
                const CircularProgressIndicator()
              else
                Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              if (!_isStarting && !_sessionActive) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _startSession,
                  child: const Text('Try Again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QrAttendanceScannerScreen extends StatefulWidget {
  const _QrAttendanceScannerScreen();

  @override
  State<_QrAttendanceScannerScreen> createState() =>
      _QrAttendanceScannerScreenState();
}

class _QrAttendanceScannerScreenState
    extends State<_QrAttendanceScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) continue;
      _handled = true;
      _controller.stop();
      Navigator.of(context).pop(value);
      return;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Worker QR')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: Text(
                'Point the camera at the QR code on the worker profile.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
