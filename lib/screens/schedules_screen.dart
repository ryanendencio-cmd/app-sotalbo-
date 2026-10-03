import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/app_sidebar.dart';

class SchedulesScreen extends StatefulWidget {
  final int projectId;
  final String projectName;

  const SchedulesScreen({
    super.key,
    this.projectId = 0,
    this.projectName = 'All Schedules',
  });

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> {
  late Future<List<dynamic>> _future;
  DateTime _currentMonth = DateTime.now();
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _future = ApiService.getSchedules();
  }

  Color _statusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'completed': return Colors.green;
      case 'in progress': return Colors.blue;
      case 'pending': return Colors.orange;
      case 'delayed': return const Color(0xFFA63228);
      default: return Colors.grey;
    }
  }

  List<DateTime> _getDaysInMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    
    // Find the previous Sunday
    final firstSunday = firstDay.subtract(Duration(days: firstDay.weekday % 7));
    
    // Find the next Saturday
    final lastSaturday = lastDay.add(Duration(days: 6 - (lastDay.weekday % 7)));
    
    final days = <DateTime>[];
    for (var d = firstSunday; d.isBefore(lastSaturday.add(const Duration(days: 1))); d = d.add(const Duration(days: 1))) {
      days.add(d);
    }
    return days;
  }

  List<dynamic> _getSchedulesForDay(DateTime day, List<dynamic> allSchedules) {
    return allSchedules.where((s) {
      // Apply status filter first
      final status = (s['status'] ?? 'Pending').toString();
      if (_statusFilter != 'All' && status != _statusFilter) return false;

      if (s['start_date'] == null) return false;
      try {
        final start = DateTime.parse(s['start_date'].toString());
        final end = s['end_date'] != null ? DateTime.parse(s['end_date'].toString()) : start;
        
        final compareDay = DateTime(day.year, day.month, day.day);
        final compareStart = DateTime(start.year, start.month, start.day);
        final compareEnd = DateTime(end.year, end.month, end.day);
        
        return (compareDay.isAtSameMomentAs(compareStart) || compareDay.isAfter(compareStart)) &&
               (compareDay.isAtSameMomentAs(compareEnd) || compareDay.isBefore(compareEnd));
      } catch (e) {
        return false;
      }
    }).toList();
  }

  void _showScheduleDetails(BuildContext context, DateTime day, List<dynamic> schedules) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('MMMM d, yyyy').format(day),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (schedules.isEmpty)
              Text('No schedules for this day.', style: GoogleFonts.inter(color: Colors.grey))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: schedules.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final s = schedules[i];
                    final status = s['status']?.toString() ?? 'Unknown';
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  s['task']?.toString() ?? s['title']?.toString() ?? '—',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _statusColor(status).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(status, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: _statusColor(status))),
                              ),
                            ],
                          ),
                          if (s['description'] != null) ...[
                            const SizedBox(height: 4),
                            Text(s['description'].toString(), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700)),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      drawer: const AppSidebar(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Column(
          children: [
            Text('Schedules', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
            Text(widget.projectName, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFA63228)));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40, color: Color(0xFFA63228)),
                    const SizedBox(height: 8),
                    Text('Failed to load schedules', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(snapshot.error.toString(), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA63228), elevation: 0),
                      onPressed: () => setState(() => _future = ApiService.getSchedules()),
                      child: Text('Retry', style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          }

          final schedules = snapshot.data!;
          final days = _getDaysInMonth(_currentMonth);
          final weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

          return Column(
            children: [
              // Filter Section
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Pending', 'In Progress', 'Completed', 'Delayed'].map((status) {
                      final isSelected = _statusFilter == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(status, style: GoogleFonts.inter(
                            fontSize: 11, 
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : Colors.black87
                          )),
                          selected: isSelected,
                          selectedColor: const Color(0xFFA63228),
                          backgroundColor: Colors.grey.shade100,
                          onSelected: (selected) {
                            if (selected) setState(() => _statusFilter = status);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Calendar Header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1)),
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(_currentMonth),
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1)),
                    ),
                  ],
                ),
              ),
              
              // Days of week
              Container(
                color: Colors.white,
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: weekDays.map((day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ),

              // Calendar Grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: days.length,
                  itemBuilder: (context, index) {
                    final day = days[index];
                    final isCurrentMonth = day.month == _currentMonth.month;
                    final isToday = DateTime.now().year == day.year && 
                                  DateTime.now().month == day.month && 
                                  DateTime.now().day == day.day;
                    
                    final daySchedules = _getSchedulesForDay(day, schedules);

                    return GestureDetector(
                      onTap: () => _showScheduleDetails(context, day, daySchedules),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isCurrentMonth ? Colors.white : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: isToday ? Border.all(color: const Color(0xFFA63228), width: 1.5) : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Text(
                                '${day.day}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                  color: isCurrentMonth 
                                      ? (isToday ? const Color(0xFFA63228) : Colors.black87)
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ),
                            if (daySchedules.isNotEmpty)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: ListView.builder(
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: daySchedules.length > 3 ? 3 : daySchedules.length,
                                    itemBuilder: (context, i) {
                                      final s = daySchedules[i];
                                      final status = s['status']?.toString() ?? '';
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 2),
                                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: _statusColor(status).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                        child: Text(
                                          s['task']?.toString() ?? s['title']?.toString() ?? '',
                                          style: GoogleFonts.inter(
                                            fontSize: 7,
                                            color: _statusColor(status).withValues(alpha: 0.8),
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            if (daySchedules.length > 3)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2, right: 2),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '+${daySchedules.length - 3}',
                                    style: GoogleFonts.inter(fontSize: 7, color: Colors.grey.shade600),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
