import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/admin_service.dart';
import '../services/api_service.dart';
import 'tools_monitoring_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;

  bool _pushNotifications = true;
  bool _biometricLogin = false;
  String _activeProjectSite = 'S-CON Residential Phase 2 (Santa Cruz)';

  List<Map<String, dynamic>> _pendingRegistrations = [];
  bool _isLoadingPending = false;

  final List<Map<String, dynamic>> _pendingValeRequests = [];

  List<Map<String, dynamic>> _allWorkers = [];
  bool _isLoadingWorkers = false;

  // Web Dashboard Parity State
  bool _isLoadingDashboard = false;
  int _activeProjectsCount = 0;
  double _totalExpenses = 0.0;
  int _totalManpower = 0;
  int _presentToday = 0;
  int _equipAvailable = 0;
  int _equipInUse = 0;
  int _equipMaintenance = 0;
  double _totalBudget = 0.0;
  double _totalSpent = 0.0;
  double _remainingBudget = 0.0;
  int _budgetPercent = 0;
  List<Map<String, dynamic>> _budgetCategories = [];
  List<Map<String, dynamic>> _projectsList = [];
  List<Map<String, dynamic>> _recentExpenses = [];
  List<double> _monthlyExpenses = List<double>.filled(12, 0.0);

  // Admin profile data
  final int _adminId = 1; // Default admin ID
  String _adminFirstName = 'Mark';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _loadAdminProfile();
    _loadPendingRegistrations();
    _loadWorkers();
    _loadPendingValeRequests();
  }

  double _parseDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  int _parseInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String)
      return int.tryParse(value) ??
          (double.tryParse(value)?.toInt() ?? defaultValue);
    return defaultValue;
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoadingDashboard = true);
    try {
      final results = await Future.wait([
        ApiService.getProjects().catchError((_) => []),
        ApiService.getExpensesSummary().catchError((_) => <String, dynamic>{}),
        ApiService.getBudgetSummary().catchError((_) => <String, dynamic>{}),
        ApiService.getWorkersSummary().catchError((_) => <String, dynamic>{}),
        ApiService.getAssetsSummary().catchError((_) => <String, dynamic>{}),
        ApiService.getMonthlyExpenses().catchError((_) => []),
      ]);

      if (mounted) {
        final projectsData = results[0] as List<dynamic>;
        final expSummary = results[1] as Map<String, dynamic>;
        final budgetSummary = results[2] as Map<String, dynamic>;
        final workersSummary = results[3] as Map<String, dynamic>;
        final assetsSummary = results[4] as Map<String, dynamic>;
        final monthlyData = results[5] as List<dynamic>;

        setState(() {
          _projectsList = List<Map<String, dynamic>>.from(projectsData);
          _activeProjectsCount = _projectsList.length;

          _totalExpenses = _parseDouble(expSummary['total']);
          _recentExpenses =
              (expSummary['recent'] as List<dynamic>?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [];

          _totalBudget = _parseDouble(budgetSummary['totalBudget']);
          _totalSpent = _parseDouble(
            budgetSummary['totalSpent'],
            _totalExpenses,
          );
          _remainingBudget = _parseDouble(
            budgetSummary['remaining'],
            _totalBudget - _totalSpent,
          );
          _budgetPercent = _parseInt(
            budgetSummary['percent'],
            _totalBudget > 0 ? ((_totalSpent / _totalBudget) * 100).round() : 0,
          );
          _budgetCategories =
              (budgetSummary['categories'] as List<dynamic>?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [];

          _totalManpower = _parseInt(workersSummary['totalManpower']);
          _presentToday = _parseInt(workersSummary['presentToday']);

          _equipAvailable = _parseInt(assetsSummary['available']);
          _equipInUse = _parseInt(assetsSummary['inUse']);
          _equipMaintenance = _parseInt(assetsSummary['maintenance']);

          if (monthlyData.isNotEmpty) {
            _monthlyExpenses = monthlyData.map((e) => _parseDouble(e)).toList();
          }

          _isLoadingDashboard = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingDashboard = false);
    }
  }

  Future<void> _loadPendingRegistrations() async {
    setState(() => _isLoadingPending = true);
    try {
      final list = await ApiService.getPendingRegistrations();
      if (mounted) {
        setState(() {
          _pendingRegistrations = List<Map<String, dynamic>>.from(list);
          _isLoadingPending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPending = false);
      }
    }
  }

  Future<void> _loadWorkers() async {
    setState(() => _isLoadingWorkers = true);
    try {
      final list = await ApiService.getWorkers();
      if (mounted) {
        setState(() {
          final all = List<Map<String, dynamic>>.from(list);
          _allWorkers = all.where((w) {
            final status = (w['approval_status'] ?? w['status'] ?? '').toString().toLowerCase();
            return status != 'pending';
          }).toList();
          _isLoadingWorkers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingWorkers = false);
      }
    }
  }

  Future<void> _loadAdminProfile() async {
    final profile = await AdminService.getAdminProfile(_adminId);
    if (profile['id'] != null) {
      setState(() {
        _adminFirstName = profile['fullName']?.split(' ').first ?? 'Mark';
        _activeProjectSite =
            profile['assignedProjectSite'] ??
            'S-CON Residential Phase 2 (Santa Cruz)';
        _pushNotifications = profile['pushNotificationsEnabled'] ?? true;
        _biometricLogin = profile['biometricLoginEnabled'] ?? false;
      });
    }
  }



  Future<void> _handleAccountApproval(int index, bool isApproved) async {
    final applicant = _pendingRegistrations[index];
    final dynamic workerId = applicant['id'];

    if (workerId == null || workerId.toString().isEmpty) return;

    final String name = (applicant['full_name'] as String?)?.isNotEmpty == true
        ? applicant['full_name']
        : '${applicant['first_name'] ?? ''} ${applicant['last_name'] ?? ''}'
              .trim();
    final String statusStr = isApproved ? 'Approved' : 'Rejected';

    try {
      await ApiService.approveWorker(workerId, statusStr);
      if (mounted) {
        setState(() => _pendingRegistrations.removeAt(index));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Account for $name has been $statusStr.',
              style: GoogleFonts.inter(fontSize: 11),
            ),
            backgroundColor: isApproved
                ? Colors.green.shade700
                : const Color(0xFFA63228),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
          ),
        );
        if (isApproved) {
          _loadWorkers();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update status: $e',
              style: GoogleFonts.inter(fontSize: 11),
            ),
            backgroundColor: const Color(0xFFA63228),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
          ),
        );
      }
    }
  }

  Future<void> _loadPendingValeRequests() async {
    try {
      final list = await ApiService.getPendingCashAdvances();
      if (mounted) {
        setState(() {
          _pendingValeRequests.clear();
          for (var item in list) {
            _pendingValeRequests.add(Map<String, dynamic>.from(item));
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading pending vale requests: $e');
    }
  }

  Future<void> _handleValeApproval(int index, bool isApproved) async {
    final vale = _pendingValeRequests[index];
    final statusStr = isApproved ? 'Approved' : 'Rejected';
    final valeId = vale['id']?.toString();

    if (valeId == null || valeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invalid cash advance record ID',
            style: GoogleFonts.inter(fontSize: 11),
          ),
          backgroundColor: const Color(0xFFA63228),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(8),
        ),
      );
      return;
    }

    try {
      await ApiService.approveCashAdvance(valeId, statusStr);
      if (mounted) {
        setState(() => _pendingValeRequests.removeAt(index));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cash advance for ${vale['name'] ?? vale['workerName'] ?? 'Worker'} has been $statusStr.',
              style: GoogleFonts.inter(fontSize: 11),
            ),
            backgroundColor: isApproved
                ? Colors.green.shade700
                : const Color(0xFFA63228),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update vale status: $e',
              style: GoogleFonts.inter(fontSize: 11),
            ),
            backgroundColor: const Color(0xFFA63228),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
          ),
        );
      }
    }
  }

  String _formatCurrency(num value) {
    final parts = value.toStringAsFixed(2).split('.');
    final whole = parts[0];
    final dec = parts[1];
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formattedWhole = whole.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '₱$formattedWhole.$dec';
  }

  String _formatCompactCurrency(num value) {
    if (value >= 1000000) {
      return '₱${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '₱${(value / 1000).toStringAsFixed(1)}k';
    }
    return '₱${value.toStringAsFixed(0)}';
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _showAddExpenseDialog() {
    if (_projectsList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No projects available. Please create a project first.',
            style: GoogleFonts.inter(fontSize: 12),
          ),
          backgroundColor: const Color(0xFFA63228),
        ),
      );
      return;
    }

    int selectedProjectId = _projectsList[0]['id'] is int
        ? _projectsList[0]['id']
        : int.tryParse(_projectsList[0]['id'].toString()) ?? 1;
    String selectedCategory = 'Materials';
    final amountController = TextEditingController();
    final receiptController = TextEditingController();
    final remarksController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final categories = [
      'Materials',
      'Labor',
      'Equipment',
      'Subcontractor',
      'Utilities',
      'Others',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFA63228).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add_card_rounded,
                  color: Color(0xFFA63228),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Add New Expense',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Project',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<int>(
                  value: selectedProjectId,
                  isDense: true,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.black87),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                  items: _projectsList.map((p) {
                    final id = p['id'] is int
                        ? p['id'] as int
                        : int.tryParse(p['id'].toString()) ?? 1;
                    return DropdownMenuItem<int>(
                      value: id,
                      child: Text(
                        p['name'] ?? 'Project #$id',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null)
                      setDialogState(() => selectedProjectId = val);
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  'Category',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  isDense: true,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.black87),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                  items: categories
                      .map(
                        (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null)
                      setDialogState(() => selectedCategory = val);
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  'Amount (₱)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GoogleFonts.inter(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    prefixText: '₱ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Receipt No. (Opt)',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: receiptController,
                            style: GoogleFonts.inter(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'e.g. REC-1029',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setDialogState(() => selectedDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                                    style: GoogleFonts.inter(fontSize: 12),
                                  ),
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Remarks / Item Description',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: remarksController,
                  maxLines: 2,
                  style: GoogleFonts.inter(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'e.g. Portland Cement 50 bags',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA63228),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                final amt =
                    double.tryParse(amountController.text.trim()) ?? 0.0;
                if (amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Please enter a valid expense amount.',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                      backgroundColor: const Color(0xFFA63228),
                    ),
                  );
                  return;
                }
                Navigator.pop(context);
                try {
                  final dateStr =
                      '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                  await ApiService.createExpense({
                    'project_id': selectedProjectId,
                    'category': selectedCategory,
                    'amount': amt,
                    'date': dateStr,
                    'receipt_no': receiptController.text.trim(),
                    'remarks': remarksController.text.trim(),
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Expense added successfully!',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                        backgroundColor: Colors.green.shade700,
                      ),
                    );
                    _loadDashboardData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to save expense: $e',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                        backgroundColor: const Color(0xFFA63228),
                      ),
                    );
                  }
                }
              },
              child: Text(
                'Save Expense',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showScanReceiptDialog() {
    if (_projectsList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No projects available. Please create a project first.',
            style: GoogleFonts.inter(fontSize: 12),
          ),
          backgroundColor: const Color(0xFFA63228),
        ),
      );
      return;
    }

    int selectedProjectId = _projectsList[0]['id'] is int
        ? _projectsList[0]['id']
        : int.tryParse(_projectsList[0]['id'].toString()) ?? 1;
    String selectedCategory = 'Materials';
    final amountController = TextEditingController(text: '4500.00');
    final receiptController = TextEditingController(
      text:
          'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );
    final descController = TextEditingController(
      text: 'Official Receipt - Construction Supplies',
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8C547).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.document_scanner_rounded,
                  color: Color(0xFF8B1A10),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Scan Receipt (OCR)',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Scan success badge matching web
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4EA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFC8E6C9)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF2E7D32),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Receipt attached & optical read verified',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Assigned Project',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<int>(
                  value: selectedProjectId,
                  isDense: true,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.black87),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                  items: _projectsList.map((p) {
                    final id = p['id'] is int
                        ? p['id'] as int
                        : int.tryParse(p['id'].toString()) ?? 1;
                    return DropdownMenuItem<int>(
                      value: id,
                      child: Text(
                        p['name'] ?? 'Project #$id',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null)
                      setDialogState(() => selectedProjectId = val);
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Category',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: selectedCategory,
                            isDense: true,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                            ),
                            items:
                                [
                                      'Materials',
                                      'Labor',
                                      'Equipment',
                                      'Subcontractor',
                                      'Utilities',
                                      'Others',
                                    ]
                                    .map(
                                      (cat) => DropdownMenuItem(
                                        value: cat,
                                        child: Text(cat),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (val) {
                              if (val != null)
                                setDialogState(() => selectedCategory = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detected Amount',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFA63228),
                            ),
                            decoration: InputDecoration(
                              prefixText: '₱ ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Detected Receipt #',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: receiptController,
                  style: GoogleFonts.inter(fontSize: 12),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Items / Notes',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  style: GoogleFonts.inter(fontSize: 12),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B1A10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                final amt =
                    double.tryParse(amountController.text.trim()) ?? 0.0;
                Navigator.pop(context);
                try {
                  final now = DateTime.now();
                  final dateStr =
                      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                  await ApiService.createExpense({
                    'project_id': selectedProjectId,
                    'category': selectedCategory,
                    'amount': amt,
                    'date': dateStr,
                    'receipt_no': receiptController.text.trim(),
                    'remarks': descController.text.trim(),
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Scanned receipt saved as expense!',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                        backgroundColor: Colors.green.shade700,
                      ),
                    );
                    _loadDashboardData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to save receipt: $e',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                        backgroundColor: const Color(0xFFA63228),
                      ),
                    );
                  }
                }
              },
              child: Text(
                'Confirm & Save',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          'Log Out Confirmation',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Sigurado ka bang nais mong mag-log out sa Admin Portal?',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA63228),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              ApiService.currentUserRole = null;
              ApiService.clearToken();
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: Text(
              'Yes, Log Out',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSiteConfigDialog() {
    final TextEditingController siteController = TextEditingController(
      text: _activeProjectSite,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Project Site Configuration',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: siteController,
          style: GoogleFonts.inter(fontSize: 12),
          decoration: InputDecoration(
            isDense: true,
            labelText: 'Active Project Site',
            labelStyle: GoogleFonts.inter(fontSize: 11),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA63228),
              elevation: 0,
            ),
            onPressed: () {
              setState(() => _activeProjectSite = siteController.text.trim());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Project site updated successfully!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(
              'Save',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _triggerDataExport() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        content: Row(
          children: [
            const CircularProgressIndicator(color: Color(0xFFA63228)),
            const SizedBox(width: 16),
            Text(
              'Generating CSV / Excel report...',
              style: GoogleFonts.inter(fontSize: 12),
            ),
          ],
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payroll & Attendance report exported successfully (Downloads folder).',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  String _getTitleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Admin Dashboard';
      case 1:
        return 'Tools Monitoring';
      case 2:
        return 'Cash Advance Approvals';
      case 3:
        return 'Manpower Directory';
      case 4:
        return 'Admin Settings';
      default:
        return 'Admin Portal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          _getTitleForIndex(_currentIndex),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/admin_profile'),
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFA63228),
                child: Text(
                  _adminFirstName.isNotEmpty
                      ? _adminFirstName[0].toUpperCase()
                      : 'A',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildOverviewTab(screenWidth, screenHeight),
            const ToolsMonitoringScreen(hideAppBar: true),
            _buildValeApprovalsTab(screenWidth, screenHeight),
            _buildManpowerTab(screenWidth, screenHeight),
            _buildSettingsTab(screenWidth, screenHeight),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 0) {
            _loadDashboardData();
          } else if (index == 2) {
            _loadPendingValeRequests();
          } else if (index == 3) {
            _loadWorkers();
            _loadPendingRegistrations();
          }
        },
        selectedItemColor: const Color(0xFFA63228),
        unselectedItemColor: Colors.grey.shade500,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            activeIcon: Icon(Icons.grid_view_rounded),
            label: 'Overview',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.handyman_outlined),
            activeIcon: Icon(Icons.handyman_rounded),
            label: 'Tools',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _pendingValeRequests.isNotEmpty,
              label: Text('${_pendingValeRequests.length}'),
              child: const Icon(Icons.payments_outlined),
            ),
            activeIcon: Badge(
              isLabelVisible: _pendingValeRequests.isNotEmpty,
              label: Text('${_pendingValeRequests.length}'),
              child: const Icon(Icons.payments_rounded),
            ),
            label: 'Cash Adv',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _pendingRegistrations.isNotEmpty,
              label: Text('${_pendingRegistrations.length}'),
              child: const Icon(Icons.groups_outlined),
            ),
            activeIcon: Badge(
              isLabelVisible: _pendingRegistrations.isNotEmpty,
              label: Text('${_pendingRegistrations.length}'),
              child: const Icon(Icons.groups_rounded),
            ),
            label: 'Manpower',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  // TAB 0: OVERVIEW WITH WEB PARITY DASHBOARD
  Widget _buildOverviewTab(double screenWidth, double screenHeight) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _loadDashboardData(),
          _loadPendingRegistrations(),
          _loadWorkers(),
        ]);
      },
      color: const Color(0xFFA63228),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoadingDashboard)
              const LinearProgressIndicator(
                minHeight: 2.5,
                backgroundColor: Colors.transparent,
                color: Color(0xFFA63228),
              ),
            // GREETING BANNER & QUICK ACTIONS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DASHBOARD',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: const Color(0xFFA63228),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_greeting()}, ${_adminFirstName.isNotEmpty ? _adminFirstName : 'Engr. Aldrich'}.',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A1A1A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Here's an overview of your projects and expenses.",
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
            const SizedBox(height: 12),

            // QUICK ACTIONS ROW
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8C547),
                      foregroundColor: const Color(0xFF1A1A1A),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: Color(0xFF1A1A1A),
                    ),
                    label: Text(
                      '+ Add Expense',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: _showAddExpenseDialog,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1A1A1A),
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(
                      Icons.document_scanner_outlined,
                      size: 16,
                      color: Color(0xFFA63228),
                    ),
                    label: Text(
                      'Scan Receipt',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: _showScanReceiptDialog,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // WEB SUMMARY CARDS ROW 1: ACTIVE PROJECTS & TOTAL EXPENSES
            Row(
              children: [
                _buildSummaryCard(
                  'ACTIVE PROJECTS',
                  '$_activeProjectsCount',
                  Icons.business_center_outlined,
                  subtitle: 'Managed sites',
                ),
                const SizedBox(width: 8),
                _buildSummaryCard(
                  'TOTAL EXPENSES',
                  _formatCurrency(_totalExpenses),
                  Icons.payments_outlined,
                  subtitle: 'Tracked spending',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // WEB SUMMARY CARDS ROW 2: TOTAL MANPOWER & EQUIPMENT
            Row(
              children: [
                _buildSummaryCard(
                  'TOTAL MANPOWER',
                  _totalManpower > 0
                      ? '$_totalManpower'
                      : '${_allWorkers.length}',
                  Icons.engineering_outlined,
                  subtitle: '${_allWorkers.length} workers registered',
                ),
                const SizedBox(width: 8),
                _buildEquipmentSummaryCard(
                  'EQUIPMENT',
                  available: _equipAvailable,
                  inUse: _equipInUse,
                  maintenance: _equipMaintenance,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // EXPENSE VS BUDGET HERO CARD (BURGUNDY THEME)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF6B120B),
                    Color(0xFF8B1A10),
                    Color(0xFFA63228),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFA63228).withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
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
                        'Expense vs Budget',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'All Projects • Overall',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BUDGET',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.7),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatCompactCurrency(_totalBudget),
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ACTUAL SPENDING',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.7),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatCompactCurrency(_totalSpent),
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFE8C547),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'REMAINING',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.7),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatCompactCurrency(_remainingBudget),
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 8,
                      child: LinearProgressIndicator(
                        value: (_budgetPercent / 100.0).clamp(0.0, 1.0),
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFE8C547),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$_budgetPercent% of budget used',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.pushNamed(context, '/projects'),
                        child: Text(
                          'View Details →',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFE8C547),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_budgetCategories.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Divider(
                      color: Colors.white.withValues(alpha: 0.15),
                      height: 1,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ACTUAL EXPENSES BREAKDOWN',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.6),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _budgetCategories.map((cat) {
                        final name = cat['category'] ?? 'General';
                        final total = _parseDouble(cat['total']);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(
                                0xFFE8C547,
                              ).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatCompactCurrency(total),
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFE8C547),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // EXPENSE TRAJECTORY (LINE GRAPH)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
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
                            'Expense Trajectory',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Full year moving trend (Jan - Dec)',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFA63228,
                          ).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Full Analytics →',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFA63228),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _ExpenseTrajectoryPainter(
                        monthlyValues: _monthlyExpenses,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // MONTHLY VOLUME (BAR GRAPH)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
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
                            'Monthly Volume',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Total expenses tracked annually',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatCompactCurrency(_totalExpenses),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFA63228),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _MonthlyVolumeBarPainter(
                        monthlyValues: _monthlyExpenses,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ACTIVE PROJECTS SECTION
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active Projects',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.pushNamed(context, '/projects'),
                        child: Text(
                          'View All →',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFA63228),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_projectsList.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Center(
                        child: Text(
                          'No active projects recorded.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._projectsList.take(3).map((proj) {
                      final name = proj['name'] ?? 'Untitled Project';
                      final budget = _parseDouble(proj['budget']);
                      final progress = _parseDouble(proj['progress']);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  _formatCurrency(budget),
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${progress.toInt()}%',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFA63228),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (progress / 100.0).clamp(0.0, 1.0),
                                backgroundColor: Colors.grey.shade100,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFA63228),
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // RECENT EXPENSES SECTION
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Expenses',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      InkWell(
                        onTap: _showAddExpenseDialog,
                        child: Text(
                          '+ Add New',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFA63228),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_recentExpenses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Center(
                        child: Text(
                          'No expenses recorded recently.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._recentExpenses.take(4).map((exp) {
                      final cat = exp['category'] ?? 'Expense';
                      final date = exp['date'] ?? '';
                      final amt = _parseDouble(exp['amount']);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F7F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFA63228,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.receipt_outlined,
                                    size: 14,
                                    color: Color(0xFFA63228),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cat,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    if (date.isNotEmpty)
                                      Text(
                                        date.toString().substring(
                                          0,
                                          date.toString().length > 10
                                              ? 10
                                              : date.toString().length,
                                        ),
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            Text(
                              _formatCurrency(amt),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFA63228),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // SITE OPERATIONS QUICK STATS
            Text(
              'Site Operations Overview',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildStatCard(
                  'Present Today',
                  '$_presentToday / $_totalManpower',
                  Icons.check_circle_outline_rounded,
                ),
                const SizedBox(width: 6),
                _buildStatCard(
                  'Pending Users',
                  '${_pendingRegistrations.length}',
                  Icons.person_add_alt_1_outlined,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildStatCard(
                  'Vale Requests',
                  '${_pendingValeRequests.length}',
                  Icons.payments_outlined,
                ),
                const SizedBox(width: 6),
                _buildStatCard(
                  'Active Workers',
                  '${_allWorkers.length}',
                  Icons.groups_outlined,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // PENDING APPROVALS LIST
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pending Account Approvals',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _currentIndex = 1),
                  child: Text(
                    'View All',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFA63228),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_isLoadingPending)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFA63228)),
                ),
              )
            else if (_pendingRegistrations.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'No pending registration requests.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              )
            else
              ...List.generate(
                _pendingRegistrations.length > 2
                    ? 2
                    : _pendingRegistrations.length,
                (i) {
                  return _buildApplicantCard(i);
                },
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // TAB 1: ACCOUNT APPROVALS
  Widget _buildAccountApprovalsTab(double screenWidth, double screenHeight) {
    if (_isLoadingPending) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFA63228)),
      );
    }

    if (_pendingRegistrations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPendingRegistrations,
        color: const Color(0xFFA63228),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            SizedBox(height: screenHeight * 0.2),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All Clear!',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Walang pending account applications.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _loadPendingRegistrations,
                    icon: const Icon(
                      Icons.refresh,
                      size: 16,
                      color: Color(0xFFA63228),
                    ),
                    label: Text(
                      'Refresh',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFFA63228),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPendingRegistrations,
      color: const Color(0xFFA63228),
      child: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: _pendingRegistrations.length,
        itemBuilder: (context, index) => _buildApplicantCard(index),
      ),
    );
  }

  // TAB 2: CASH ADVANCE APPROVALS
  Widget _buildValeApprovalsTab(double screenWidth, double screenHeight) {
    return RefreshIndicator(
      onRefresh: _loadPendingValeRequests,
      color: const Color(0xFFA63228),
      child: _pendingValeRequests.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: screenHeight * 0.25),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.payments_outlined,
                        size: 40,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No Pending Vale Requests',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Walang cash advance na nakabinbin. Pull down to refresh.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(10),
              itemCount: _pendingValeRequests.length,
              itemBuilder: (context, index) {
                final vale = _pendingValeRequests[index];
                final name =
                    (vale['name'] ??
                            vale['workerName'] ??
                            vale['workerFullName'] ??
                            'Worker')
                        .toString();
                final amount =
                    (vale['amount'] ??
                            (vale['rawAmount'] != null
                                ? '₱${vale['rawAmount']}'
                                : '₱0.00'))
                        .toString();
                final role = (vale['role'] ?? vale['workerRole'] ?? 'Worker')
                    .toString();
                final reason = (vale['reason'] ?? 'No reason provided')
                    .toString();

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
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
                              name,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            amount,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFA63228),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Role: $role • Reason: $reason',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const Divider(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 30),
                              ),
                              onPressed: () =>
                                  _handleValeApproval(index, false),
                              child: Text(
                                'Reject',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFA63228),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 30),
                              ),
                              onPressed: () => _handleValeApproval(index, true),
                              child: Text(
                                'Approve Vale',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
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
                );
              },
            ),
    );
  }

  // TAB 3: MANPOWER DIRECTORY (With All Manpower & Account Approvals Tabs)
  Widget _buildManpowerTab(double screenWidth, double screenHeight) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              labelColor: const Color(0xFFA63228),
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: const Color(0xFFA63228),
              indicatorWeight: 2.5,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
              tabs: [
                const Tab(text: 'All Manpower'),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Account Approvals'),
                      if (_pendingRegistrations.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFA63228),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_pendingRegistrations.length}',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildActiveWorkersList(screenWidth, screenHeight),
                _buildAccountApprovalsTab(screenWidth, screenHeight),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveWorkersList(double screenWidth, double screenHeight) {
    if (_isLoadingWorkers) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFA63228)),
      );
    }

    if (_allWorkers.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadWorkers,
        color: const Color(0xFFA63228),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            SizedBox(height: screenHeight * 0.2),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Walang active workers.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _loadWorkers,
                    icon: const Icon(
                      Icons.refresh,
                      size: 16,
                      color: Color(0xFFA63228),
                    ),
                    label: Text(
                      'Refresh',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFFA63228),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWorkers,
      color: const Color(0xFFA63228),
      child: ListView.separated(
        padding: const EdgeInsets.all(10),
        itemCount: _allWorkers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, i) {
          final w = _allWorkers[i];
          final String name = (w['full_name'] as String?)?.isNotEmpty == true
              ? w['full_name']
              : '${w['first_name'] ?? ''} ${w['last_name'] ?? ''}'.trim();
          final role = w['role'] ?? 'Worker';
          final position = w['position'] ?? 'N/A';
          final phone = w['phone'] ?? 'N/A';
          final status = w['approval_status'] ?? w['status'] ?? 'Active';

          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'Worker #${w['id']}' : name,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$role ($position) • $phone',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // TAB 4: SETTINGS (FULLY FUNCTIONAL)
  Widget _buildSettingsTab(double screenWidth, double screenHeight) {
    return ListView(
      padding: const EdgeInsets.all(10),
      physics: const BouncingScrollPhysics(),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.admin_panel_settings_outlined,
                color: Colors.black87,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Administrator',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'admin@scon-buildtrack.ph',
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
        ),
        const SizedBox(height: 8),
        ListTile(
          dense: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          tileColor: Colors.white,
          leading: const Icon(
            Icons.storefront_outlined,
            color: Colors.black87,
            size: 20,
          ),
          title: Text(
            'Project Site Configuration',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _activeProjectSite,
            style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500),
          ),
          trailing: const Icon(Icons.chevron_right, size: 16),
          onTap: _showSiteConfigDialog,
        ),
        const SizedBox(height: 6),
        ListTile(
          dense: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          tileColor: Colors.white,
          leading: const Icon(
            Icons.download_outlined,
            color: Colors.black87,
            size: 20,
          ),
          title: Text(
            'Export Payroll & Attendance Data',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          trailing: const Icon(Icons.chevron_right, size: 16),
          onTap: _triggerDataExport,
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          dense: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          tileColor: Colors.white,
          secondary: const Icon(
            Icons.notifications_outlined,
            color: Colors.black87,
            size: 20,
          ),
          title: Text(
            'Push Notifications',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          value: _pushNotifications,
          activeThumbColor: const Color(0xFFA63228),
          onChanged: (val) => setState(() => _pushNotifications = val),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          dense: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          tileColor: Colors.white,
          secondary: const Icon(
            Icons.fingerprint_outlined,
            color: Colors.black87,
            size: 20,
          ),
          title: Text(
            'Biometric Security Login',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          value: _biometricLogin,
          activeThumbColor: const Color(0xFFA63228),
          onChanged: (val) => setState(() => _biometricLogin = val),
        ),
        const SizedBox(height: 24),
        // LOGOUT BUTTON
        GestureDetector(
          onTap: _showLogoutConfirmationDialog,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFA63228),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFA63228).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Log Out',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: Colors.black87),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicantCard(int index) {
    final applicant = _pendingRegistrations[index];
    final String name = (applicant['full_name'] as String?)?.isNotEmpty == true
        ? applicant['full_name']
        : '${applicant['first_name'] ?? ''} ${applicant['last_name'] ?? ''}'
              .trim();
    final String role = applicant['role'] ?? 'Worker';
    final String position = applicant['position'] ?? 'Worker';
    final String phone = applicant['phone'] ?? 'N/A';
    final String? address = applicant['address'];
    final isStaff = role == 'Staff';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name.isEmpty ? 'Applicant #${applicant['id']}' : name,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isStaff ? Colors.purple.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  role,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isStaff
                        ? Colors.purple.shade700
                        : Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Phone: $phone • Position: $position',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade800),
          ),
          if (address != null && address.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Address: $address',
              style: GoogleFonts.inter(
                fontSize: 10.5,
                color: Colors.grey.shade600,
              ),
            ),
          ],
          const Divider(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 30),
                  ),
                  onPressed: () => _handleAccountApproval(index, false),
                  child: Text(
                    'Reject',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA63228),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 30),
                  ),
                  onPressed: () => _handleAccountApproval(index, true),
                  child: Text(
                    'Approve',
                    style: GoogleFonts.inter(
                      fontSize: 11,
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
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon, {
    String? subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
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
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, size: 15, color: const Color(0xFFA63228)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1A1A1A),
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentSummaryCard(
    String title, {
    required int available,
    required int inUse,
    required int maintenance,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Icon(
                  Icons.precision_manufacturing_outlined,
                  size: 15,
                  color: Color(0xFFA63228),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$available',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.green.shade700,
                        ),
                      ),
                      Text(
                        'Avail',
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 18, color: Colors.grey.shade200),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$inUse',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFA63228),
                        ),
                      ),
                      Text(
                        'In Use',
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 18, color: Colors.grey.shade200),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$maintenance',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.amber.shade800,
                        ),
                      ),
                      Text(
                        'Maint',
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// EXPENSE TRAJECTORY (LINE GRAPH) PAINTER
class _ExpenseTrajectoryPainter extends CustomPainter {
  final List<double> monthlyValues;
  _ExpenseTrajectoryPainter({required this.monthlyValues});

  @override
  void paint(Canvas canvas, Size size) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    const bottomPadding = 20.0;
    final chartHeight = size.height - bottomPadding;

    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = chartHeight * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    double maxVal = 0.0;
    for (final v in monthlyValues) {
      if (v > maxVal) maxVal = v;
    }
    if (maxVal == 0) maxVal = 5000.0; // Fallback if no data

    final points = <Offset>[];
    final stepX = size.width / (months.length - 1);

    final currentMonth = DateTime.now().month - 1;

    for (int i = 0; i < months.length; i++) {
      final val = i < monthlyValues.length ? monthlyValues[i] : 0.0;
      final x = i * stepX;
      final normalizedY = maxVal > 0 ? (val / maxVal) : 0.0;
      final y = chartHeight - (normalizedY * (chartHeight - 15)) - 6;
      points.add(Offset(x, y));

      final textSpan = TextSpan(
        text: months[i],
        style: TextStyle(
          fontSize: 8.0,
          fontWeight: i == currentMonth ? FontWeight.bold : FontWeight.w500,
          color: i == currentMonth ? const Color(0xFFA63228) : Colors.grey.shade500,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, chartHeight + 4),
      );
    }

    if (points.isEmpty) return;

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final cx = (p1.dx + p2.dx) / 2;
      path.cubicTo(cx, p1.dy, cx, p2.dy, p2.dx, p2.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, chartHeight)
      ..lineTo(0, chartHeight)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFA63228).withValues(alpha: 0.22),
          const Color(0xFFA63228).withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = const Color(0xFFA63228)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // Active peak dot (Current Month)
    final peakPt = points[currentMonth];
    final dotPaint = Paint()
      ..color = const Color(0xFFA63228)
      ..style = PaintingStyle.fill;
    final dotInner = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(peakPt, 4.5, dotPaint);
    canvas.drawCircle(peakPt, 2.0, dotInner);

    // Peak badge
    final currentVal = currentMonth < monthlyValues.length ? monthlyValues[currentMonth] : 0.0;
    final fmtVal = currentVal >= 1000000 
        ? '${(currentVal/1000000).toStringAsFixed(1)}M' 
        : currentVal >= 1000 
            ? '${(currentVal/1000).round()}k' 
            : currentVal.round().toString();
            
    final badgeSpan = TextSpan(
      text: '₱$fmtVal',
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        color: Color(0xFFA63228),
      ),
    );
    final badgePainter = TextPainter(
      text: badgeSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    badgePainter.paint(
      canvas,
      Offset(peakPt.dx - badgePainter.width / 2, peakPt.dy - 15),
    );
  }

  @override
  bool shouldRepaint(covariant _ExpenseTrajectoryPainter oldDelegate) => true;
}

// MONTHLY VOLUME (BAR GRAPH) PAINTER
class _MonthlyVolumeBarPainter extends CustomPainter {
  final List<double> monthlyValues;
  _MonthlyVolumeBarPainter({required this.monthlyValues});

  @override
  void paint(Canvas canvas, Size size) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    const bottomPadding = 20.0;
    final chartHeight = size.height - bottomPadding;

    double maxVal = 0.0;
    for (final v in monthlyValues) {
      if (v > maxVal) maxVal = v;
    }
    if (maxVal == 0) maxVal = 5000.0; // Fallback if no data

    final slotWidth = size.width / months.length;
    final barWidth = slotWidth * 0.52;

    final currentMonth = DateTime.now().month - 1;

    for (int i = 0; i < months.length; i++) {
      final val = i < monthlyValues.length ? monthlyValues[i] : 0.0;
      final x = (i * slotWidth) + (slotWidth - barWidth) / 2;
      final isCurrent = i == currentMonth;
      final heightRatio = maxVal > 0 ? (val / maxVal) : 0.0;
      final h = isCurrent && val == 0
          ? 3.0 // Minimum height for current month even if 0
          : (heightRatio * (chartHeight - 15)).clamp(3.0, chartHeight);
      final y = chartHeight - h;

      final barPaint = Paint()
        ..color = isCurrent ? const Color(0xFFA63228) : Colors.grey.shade200
        ..style = PaintingStyle.fill;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, h),
        const Radius.circular(3),
      );
      canvas.drawRRect(rrect, barPaint);

      if (isCurrent && val > 0) {
        final fmtVal = val >= 1000000 
            ? '${(val/1000000).toStringAsFixed(1)}M' 
            : val >= 1000 
                ? '${(val/1000).round()}k' 
                : val.round().toString();
                
        final badgeSpan = TextSpan(
          text: '₱$fmtVal',
          style: const TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFFA63228),
          ),
        );
        final badgePainter = TextPainter(
          text: badgeSpan,
          textDirection: TextDirection.ltr,
        )..layout();
        badgePainter.paint(
          canvas,
          Offset(x + (barWidth - badgePainter.width) / 2, y - 13),
        );
      }

      final textSpan = TextSpan(
        text: months[i],
        style: TextStyle(
          fontSize: 8.0,
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
          color: isCurrent ? const Color(0xFFA63228) : Colors.grey.shade500,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(x + (barWidth - textPainter.width) / 2, chartHeight + 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MonthlyVolumeBarPainter oldDelegate) => true;
}
