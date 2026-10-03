import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'schedules_screen.dart';
import '../widgets/app_sidebar.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  late Future<List<dynamic>> _future;
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _future = ApiService.getProjects();
  }

  Color _statusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'ongoing':
      case 'active':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'on hold':
        return Colors.orange;
      default:
        return Colors.grey;
    }
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
        title: Text('Projects', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          final loadedProjects = snapshot.data ?? [];
          
          // Apply filters
          final filteredProjects = loadedProjects.where((p) {
            final name = (p['name'] ?? '').toString().toLowerCase();
            final location = (p['location'] ?? '').toString().toLowerCase();
            final status = (p['status'] ?? 'Ongoing').toString();
            
            final matchesSearch = name.contains(_searchQuery.toLowerCase()) || 
                                location.contains(_searchQuery.toLowerCase());
            final matchesStatus = _statusFilter == 'All' || status == _statusFilter;
            
            return matchesSearch && matchesStatus;
          }).toList();

          return Scaffold(
            backgroundColor: const Color(0xFFF3EFEA),
            body: snapshot.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFA63228)))
                : snapshot.hasError
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 36, color: Colors.red),
                              const SizedBox(height: 8),
                              Text('Failed to load projects: ${snapshot.error}', style: GoogleFonts.inter(fontSize: 12), textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA63228)),
                                onPressed: () => setState(() => _future = ApiService.getProjects()),
                                child: Text('Retry', style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          // Filter Section
                          Container(
                            color: Colors.white,
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Search projects...',
                                    hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade400),
                                    prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey.shade200),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey.shade200),
                                    ),
                                  ),
                                  onChanged: (val) => setState(() => _searchQuery = val),
                                ),
                                const SizedBox(height: 8),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: ['All', 'Ongoing', 'Completed', 'On Hold'].map((status) {
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
                              ],
                            ),
                          ),
                          Expanded(
                            child: filteredProjects.isEmpty
                                ? Center(
                                    child: Text('No projects found.', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: filteredProjects.length,
                                    itemBuilder: (context, i) {
                                      final p = filteredProjects[i];
                                      final name = p['name'] ?? 'Untitled Project';
                                      final location = p['location'] ?? 'No location set';
                                      final budget = (p['budget'] != null) ? '₱${double.tryParse(p['budget'].toString())?.toStringAsFixed(2) ?? '0.00'}' : '₱0.00';
                                      final status = p['status'] ?? 'Ongoing';
                                      final color = _statusColor(status);

                                      return Card(
                                        color: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          side: BorderSide(color: Colors.grey.shade200),
                                        ),
                                        margin: const EdgeInsets.only(bottom: 10),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: color.withOpacity(0.12),
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    child: Text(status, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(Icons.location_on_outlined, size: 13, color: Colors.grey.shade600),
                                                  const SizedBox(width: 3),
                                                  Expanded(
                                                    child: Text(location, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
                                                  ),
                                                ],
                                              ),
                                              const Divider(height: 16),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text('Budget: $budget', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFA63228))),
                                                  TextButton.icon(
                                                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                                                    icon: const Icon(Icons.calendar_month_outlined, size: 14, color: Color(0xFFA63228)),
                                                    label: Text('Schedules', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFA63228))),
                                                    onPressed: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(builder: (_) => SchedulesScreen(projectId: p['id'] ?? 0, projectName: name)),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
          );
        },
      ),
    );
  }
}
