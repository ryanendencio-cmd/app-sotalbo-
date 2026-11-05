import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class ShiftScheduleDialog extends StatefulWidget {
  final DateTime? initialDate;
  final VoidCallback? onSaved;

  const ShiftScheduleDialog({
    super.key,
    this.initialDate,
    this.onSaved,
  });

  static Future<void> show(BuildContext context, {DateTime? initialDate, VoidCallback? onSaved}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ShiftScheduleDialog(
        initialDate: initialDate,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<ShiftScheduleDialog> createState() => _ShiftScheduleDialogState();
}

class _ShiftScheduleDialogState extends State<ShiftScheduleDialog> {
  late DateTime _selectedDate;
  String _startTime = '09:00 AM';
  String _gracePeriodEnd = '09:30 AM';
  String _endTime = '05:00 PM';
  String _lateCutoff = '11:00 AM';
  final TextEditingController _notesController = TextEditingController(text: 'Special Shift Hours');

  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasExistingOverride = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _checkExistingOverride();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _checkExistingOverride() async {
    setState(() => _isLoading = true);
    try {
      final dateStr = _formatDate(_selectedDate);
      final override = await ApiService.getScheduleOverrideForDate(dateStr);
      if (override != null && mounted) {
        final data = Map<String, dynamic>.from(override as Map);
        setState(() {
          _hasExistingOverride = true;
          _startTime = data['start_time'] ?? '09:00 AM';
          _gracePeriodEnd = data['grace_period_end'] ?? '09:30 AM';
          _endTime = data['end_time'] ?? '05:00 PM';
          _lateCutoff = data['late_cutoff'] ?? '11:00 AM';
          _notesController.text = data['notes'] ?? '';
        });
      } else if (mounted) {
        setState(() {
          _hasExistingOverride = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _hasExistingOverride = false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _selectTime(String currentFormatted) async {
    TimeOfDay initial = const TimeOfDay(hour: 9, minute: 0);
    try {
      final parts = currentFormatted.trim().split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      if (parts.length > 1 && parts[1].toUpperCase() == 'PM' && hour < 12) {
        hour += 12;
      } else if (parts.length > 1 && parts[1].toUpperCase() == 'AM' && hour == 12) {
        hour = 0;
      }
      initial = TimeOfDay(hour: hour, minute: minute);
    } catch (_) {}

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

  Future<void> _saveOverride() async {
    setState(() => _isSaving = true);
    final dateStr = _formatDate(_selectedDate);

    try {
      final user = ApiService.currentUser;
      final setBy = (user?['name'] ?? user?['full_name'] ?? 'Admin / Attendance Monitoring Officer').toString();

      await ApiService.saveScheduleOverride({
        'date': dateStr,
        'start_time': _startTime,
        'grace_period_end': _gracePeriodEnd,
        'end_time': _endTime,
        'late_cutoff': _lateCutoff,
        'notes': _notesController.text.trim(),
        'set_by': setBy,
        'project_id': 'ALL',
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Shift Schedule set for $dateStr ($_startTime - $_gracePeriodEnd on-time window)',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(0xFFA63228),
          ),
        );
      }
      widget.onSaved?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving schedule: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteOverride() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Revert to Standard Shift?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('This will remove the custom shift hours for ${_formatDate(_selectedDate)} and restore default 8:00 AM shift.', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA63228)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revert', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    final dateStr = _formatDate(_selectedDate);

    try {
      await ApiService.deleteScheduleOverride(dateStr);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Custom shift for $dateStr removed. Restored standard 8:00 AM shift.', style: GoogleFonts.inter()),
            backgroundColor: Colors.black87,
          ),
        );
      }
      widget.onSaved?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting schedule: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(_selectedDate);

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.alarm_on_rounded, color: Color(0xFFA63228), size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set Shift Schedule',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87),
                  ),
                  Text(
                    'Set official work hours for a specific date',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
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
              // TARGET DATE SELECTOR
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF8F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFFA63228)),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Target Date',
                              style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              dateStr,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                          ],
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: const BorderSide(color: Color(0xFFA63228)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.edit_calendar_rounded, size: 14, color: Color(0xFFA63228)),
                      label: Text('Change Date', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFA63228))),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                          _checkExistingOverride();
                        }
                      },
                    ),
                  ],
                ),
              ),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFA63228))),
                )
              else ...[
                if (_hasExistingOverride) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF7ED),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFC8E6C9)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 15, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Active custom shift schedule already exists for this date.',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF2E7D32)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),

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
                      avatar: const Icon(Icons.access_time_filled_rounded, size: 13, color: Color(0xFFA63228)),
                      label: Text('9:00 AM - 9:30 AM Shift', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700)),
                      backgroundColor: const Color(0xFFF9F8F6),
                      onPressed: () {
                        setState(() {
                          _startTime = '09:00 AM';
                          _gracePeriodEnd = '09:30 AM';
                          _endTime = '05:00 PM';
                          _lateCutoff = '11:00 AM';
                          _notesController.text = 'Adjusted 9:00 AM Shift';
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.wb_sunny_rounded, size: 13, color: Colors.grey),
                      label: Text('Standard 8:00 AM - 8:10 AM', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600)),
                      backgroundColor: const Color(0xFFF9F8F6),
                      onPressed: () {
                        setState(() {
                          _startTime = '08:00 AM';
                          _gracePeriodEnd = '08:10 AM';
                          _endTime = '05:00 PM';
                          _lateCutoff = '10:00 AM';
                          _notesController.text = 'Regular Shift';
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.wb_twilight_rounded, size: 13, color: Colors.grey),
                      label: Text('10:00 AM - 10:15 AM Shift', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600)),
                      backgroundColor: const Color(0xFFF9F8F6),
                      onPressed: () {
                        setState(() {
                          _startTime = '10:00 AM';
                          _gracePeriodEnd = '10:15 AM';
                          _endTime = '06:00 PM';
                          _lateCutoff = '12:00 PM';
                          _notesController.text = '10:00 AM Shift';
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // TIME WINDOW ROW
                Row(
                  children: [
                    // START TIME
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF8F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SHIFT STARTS',
                              style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _startTime,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black87),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              height: 28,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  side: const BorderSide(color: Color(0xFFA63228)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: () async {
                                  final res = await _selectTime(_startTime);
                                  if (res != null) setState(() => _startTime = res);
                                },
                                child: Text('Set Start', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFFA63228))),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // GRACE PERIOD (ON-TIME UNTIL)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF8F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFA63228).withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ON-TIME UNTIL',
                              style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFFA63228)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _gracePeriodEnd,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFFA63228)),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              height: 28,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFA63228),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: () async {
                                  final res = await _selectTime(_gracePeriodEnd);
                                  if (res != null) setState(() => _gracePeriodEnd = res);
                                },
                                child: Text('Set Grace', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // SHIFT END
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF8F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SHIFT ENDS',
                              style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _endTime,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black87),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              height: 28,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  side: BorderSide(color: Colors.grey.shade400),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: () async {
                                  final res = await _selectTime(_endTime);
                                  if (res != null) setState(() => _endTime = res);
                                },
                                child: Text('Set End', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black87)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // SUMMARY EXPLANATION BANNER
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F8FA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCFE2EC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF1E6091)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'On $dateStr, workers who time-in between $_startTime and $_gracePeriodEnd will be marked Present. Late starts after $_gracePeriodEnd.',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF1E6091), height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // NOTES FIELD
                TextField(
                  controller: _notesController,
                  style: GoogleFonts.inter(fontSize: 12.5),
                  decoration: InputDecoration(
                    labelText: 'Notes / Reason',
                    hintText: 'e.g. Special 9:00 AM Shift, Client site adjustment',
                    labelStyle: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade600),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFFAF8F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ACTION BUTTONS
              Row(
                children: [
                  if (_hasExistingOverride) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: Text('Revert', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: _isSaving ? null : _deleteOverride,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: Text('Cancel', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA63228),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _isSaving ? null : _saveOverride,
                      child: _isSaving
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Save Shift Schedule', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

