import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_sidebar.dart';
import '../services/api_service.dart';

class TimesheetScreen extends StatefulWidget {
  const TimesheetScreen({super.key});

  @override
  State<TimesheetScreen> createState() => _TimesheetScreenState();
}

class _TimesheetScreenState extends State<TimesheetScreen> {
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  DateTime _selectedDate = DateTime(2026, 9, 18);

  final List<Map<String, dynamic>> _timesheetData = [];
  List<Map<String, dynamic>> _allWorkers = [];
  bool _isLoadingWorkers = false;

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

        final morningIn = att?['morningIn'] ?? att?['timeIn'] ?? '—';
        final morningOut = att?['morningOut'] ?? '—';
        final afternoonIn = att?['afternoonIn'] ?? '—';
        final afternoonOut = att?['afternoonOut'] ?? att?['timeOut'] ?? '—';
        final status = att?['status'] ?? (att != null ? 'Present' : 'Not Recorded');

        timesheet.add({
          'id': wId,
          'name': fullName.isEmpty ? 'Worker' : fullName,
          'role': role,
          'dailyRate': dailyRate,
          'morningIn': morningIn,
          'morningOut': morningOut,
          'afternoonIn': afternoonIn,
          'afternoonOut': afternoonOut,
          'status': status,
          'overtimeHrs': att?['ot'] ?? 0,
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
    }
  }

  void _showManualAttendanceDialog() {
    TextEditingController? autocompleteNameController;
    final TextEditingController idController = TextEditingController();
    String selectedRole = 'Mason';
    String selectedStatus = 'On Duty';
    String timeInValue = '08:00 AM';

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
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 32,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Manual Attendance Entry',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Record time-in or attendance for personnel manually.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Autocomplete<Map<String, dynamic>>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<Map<String, dynamic>>.empty();
                          }
                          return _allWorkers.where((worker) {
                            final name =
                                '${worker['first_name'] ?? ''} ${worker['last_name'] ?? ''}'
                                    .trim();
                            return name.toLowerCase().contains(
                              textEditingValue.text.toLowerCase(),
                            );
                          });
                        },
                        displayStringForOption: (Map<String, dynamic> option) {
                          return '${option['first_name'] ?? ''} ${option['last_name'] ?? ''}'
                              .trim();
                        },
                        onSelected: (Map<String, dynamic> selection) {
                          idController.text = 'SCON-${selection['id'] ?? ''}';
                          String roleStr =
                              selection['role']?.toString() ?? 'Mason';
                          const validRoles = [
                            'Mason',
                            'Carpenter',
                            'Laborer',
                            'Foreman',
                          ];
                          if (!validRoles.contains(roleStr)) {
                            roleStr = 'Mason';
                          }
                          setModalState(() {
                            selectedRole = roleStr;
                          });
                        },
                        fieldViewBuilder:
                            (context, controller, focusNode, onFieldSubmitted) {
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
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFA63228),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              );
                            },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(10),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: 200,
                                  maxWidth:
                                      MediaQuery.of(context).size.width - 32,
                                ),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (BuildContext context, int index) {
                                    final option = options.elementAt(index);
                                    final name =
                                        '${option['first_name'] ?? ''} ${option['last_name'] ?? ''}'
                                            .trim();
                                    final workerId =
                                        option['id']?.toString() ?? '';
                                    final role = option['role'] ?? '';
                                    return ListTile(
                                      title: Text(
                                        name,
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'SCON-$workerId • $role',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      onTap: () {
                                        onSelected(option);
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: idController,
                              style: GoogleFonts.inter(fontSize: 12.5),
                              decoration: InputDecoration(
                                labelText: 'Worker ID (e.g. SCON-120)',
                                labelStyle: GoogleFonts.inter(fontSize: 11),
                                isDense: true,
                                filled: true,
                                fillColor: const Color(0xFFFAF8F5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
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
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedRole,
                              isDense: true,
                              decoration: InputDecoration(
                                labelText: 'Trade / Role',
                                labelStyle: GoogleFonts.inter(fontSize: 11),
                                filled: true,
                                fillColor: const Color(0xFFFAF8F5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                              ),
                              items:
                                  [
                                    'Mason',
                                    'Carpenter',
                                    'Laborer',
                                    'Foreman',
                                  ].map((role) {
                                    return DropdownMenuItem(
                                      value: role,
                                      child: Text(
                                        role,
                                        style: GoogleFonts.inter(fontSize: 12),
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (val) =>
                                  setModalState(() => selectedRole = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedStatus,
                        isDense: true,
                        decoration: InputDecoration(
                          labelText: 'Attendance Status',
                          labelStyle: GoogleFonts.inter(fontSize: 11.5),
                          filled: true,
                          fillColor: const Color(0xFFFAF8F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        items: ['On Duty', 'Complete', 'Absent'].map((st) {
                          return DropdownMenuItem(
                            value: st,
                            child: Text(
                              st,
                              style: GoogleFonts.inter(fontSize: 12),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setModalState(() => selectedStatus = val!),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
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
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFA63228),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () {
                                final workerName =
                                    autocompleteNameController?.text.trim() ??
                                    '';
                                if (workerName.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please enter worker name'),
                                    ),
                                  );
                                  return;
                                }
                                final eval = _evaluateTwoSessions(
                                  selectedStatus == 'Absent'
                                      ? '--:--'
                                      : timeInValue,
                                  null,
                                );
                                setState(() {
                                  _timesheetData.insert(0, {
                                    'name': workerName,
                                    'id': idController.text.trim().isEmpty
                                        ? 'SCON-${130 + _timesheetData.length}'
                                        : idController.text.trim(),
                                    'role': selectedRole,
                                    'timeIn': selectedStatus == 'Absent'
                                        ? '--:--'
                                        : timeInValue,
                                    'timeOut': '--:--',
                                    'regHours': selectedStatus == 'Absent'
                                        ? '0.0h'
                                        : (eval['status'].toString().contains(
                                                'Halfday',
                                              )
                                              ? '4.0h'
                                              : '8.0h'),
                                    'otHours': '0.0h',
                                    'status': selectedStatus == 'Absent'
                                        ? 'Absent'
                                        : eval['status'],
                                    'tag': eval['tag'],
                                  });
                                });
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Attendance recorded as ${eval['tag']}',
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                'Save Record',
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
                Expanded(child: _buildMetricTile('IN', item['timeIn'])),
                _buildDivider(),
                Expanded(child: _buildMetricTile('OUT', item['timeOut'])),
                _buildDivider(),
                Expanded(child: _buildMetricTile('REG', item['regHours'])),
                _buildDivider(),
                Expanded(child: _buildMetricTile('OT', item['otHours'])),
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
