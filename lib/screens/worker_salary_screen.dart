import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/worker_app_header.dart';
import '../widgets/currency_text_field.dart';
import '../widgets/paginated_list_view.dart';

class WorkerSalaryScreen extends StatefulWidget {
  const WorkerSalaryScreen({super.key});

  @override
  State<WorkerSalaryScreen> createState() => _WorkerSalaryScreenState();
}

class _WorkerSalaryScreenState extends State<WorkerSalaryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _salarySummaryError;
  String _payrollPeriodFilter = 'All time';
  String _payrollStatusFilter = 'All statuses';
  String _cashAdvancePeriodFilter = 'All time';
  String _cashAdvanceStatusFilter = 'All statuses';
  List<Map<String, dynamic>> _cashAdvances = [];
  List<Map<String, dynamic>> _payrollHistory = [];
  Map<String, dynamic> _salarySummary = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static const _periodFilterOptions = ['All time', 'This month', 'This cutoff'];

  DateTime? _dateForFilter(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty || text == 'null') return null;
    return DateTime.tryParse(text.length >= 10 ? text.substring(0, 10) : text);
  }

  bool _matchesPeriod(dynamic rawDate, String filter) {
    final date = _dateForFilter(rawDate);
    if (date == null) return false;
    if (filter == 'All time') return true;
    final now = DateTime.now();
    if (filter == 'This month') {
      return date.year == now.year && date.month == now.month;
    }

    final start = DateTime(now.year, now.month, now.day <= 15 ? 1 : 16);
    final end = now.day <= 15
        ? DateTime(now.year, now.month, 15)
        : DateTime(now.year, now.month + 1, 0);
    return !date.isBefore(start) && !date.isAfter(end);
  }

  List<Map<String, dynamic>> get _filteredPayrollHistory {
    return _payrollHistory.where((payroll) {
      final periodDate = payroll['cutoff_end'] ?? payroll['cutoff_start'];
      if (!_matchesPeriod(periodDate, _payrollPeriodFilter)) return false;
      return _payrollStatusFilter == 'All statuses' ||
          (payroll['status'] ?? '').toString().toLowerCase() ==
              _payrollStatusFilter.toLowerCase();
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredCashAdvances {
    return _cashAdvances.where((advance) {
      if (!_matchesPeriod(advance['date'], _cashAdvancePeriodFilter)) {
        return false;
      }
      return _cashAdvanceStatusFilter == 'All statuses' ||
          (advance['status'] ?? '').toString().toLowerCase() ==
              _cashAdvanceStatusFilter.toLowerCase();
    }).toList();
  }

  Widget _buildHistoryFilters({
    required String period,
    required String status,
    required ValueChanged<String?> onPeriodChanged,
    required ValueChanged<String?> onStatusChanged,
    required double horizontalPadding,
  }) {
    const statuses = [
      'All statuses',
      'Paid',
      'Released',
      'Approved',
      'Pending',
      'Rejected',
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 10, horizontalPadding, 2),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterDropdown(
              value: period,
              values: _periodFilterOptions,
              label: 'Date range',
              onChanged: onPeriodChanged,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterDropdown(
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

  Widget _buildFilterDropdown({
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
        labelStyle: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      style: GoogleFonts.inter(
        fontSize: 11,
        color: Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      items: values
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = ApiService.currentUser?['id']?.toString();
      if (userId != null && userId.isNotEmpty) {
        final res = await Future.wait([
          ApiService.getWorkerCashAdvances(userId),
          ApiService.getWorkerPayroll(userId),
        ]);
        if (mounted) {
          setState(() {
            _cashAdvances = List<Map<String, dynamic>>.from(res[0]);
            _payrollHistory = List<Map<String, dynamic>>.from(res[1]);
          });
        }
        try {
          final summary = await ApiService.getWorkerSalarySummary(userId);
          if (mounted) {
            setState(() {
              _salarySummary = summary;
              _salarySummaryError = null;
            });
          }
        } catch (error) {
          if (mounted) {
            setState(
              () =>
                  _salarySummaryError = 'Unable to load salary summary: $error',
            );
          }
        }
      }
    } catch (error) {
      debugPrint('Unable to load worker salary records: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to load salary records. Please try again.',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            backgroundColor: const Color(0xFFA63228),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCashAdvanceDialog() {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();
    final List<String> quickAmounts = ['500', '1000', '1500', '2000'];
    String? amountError;
    String? reasonError;
    String? submissionError;
    bool isSubmitting = false;

    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
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
                            'Request Cash Advance',
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'Submitted to admin for cutoff review',
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
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    children: quickAmounts.map((amt) {
                      return InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () {
                          amountController.text =
                              CurrencyInputFormatter.formatEditing(amt);
                          if (amountError != null || submissionError != null) {
                            setDialogState(() {
                              amountError = null;
                              submissionError = null;
                            });
                          }
                        },
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
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  CurrencyTextField(
                    controller: amountController,
                    onChanged: (val) {
                      if (amountError != null || submissionError != null) {
                        setDialogState(() {
                          amountError = null;
                          submissionError = null;
                        });
                      }
                    },
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
                      errorText: amountError,
                      errorMaxLines: 3,
                      errorStyle: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: const Color(0xFFA63228),
                        fontWeight: FontWeight.w600,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: amountError != null
                              ? const Color(0xFFA63228)
                              : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: amountError != null
                              ? const Color(0xFFA63228)
                              : Colors.grey.shade300,
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
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    maxLength: 100,
                    maxLines: 2,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(100),
                      _NoLeadingOrRepeatedSpacesFormatter(),
                    ],
                    onChanged: (val) {
                      if (reasonError != null || submissionError != null) {
                        setDialogState(() {
                          reasonError = null;
                          submissionError = null;
                        });
                      } else {
                        setDialogState(() {});
                      }
                    },
                    style: GoogleFonts.inter(fontSize: 12),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFFAF8F5),
                      isDense: true,
                      hintText: 'Reason (max 100 letters, e.g., Medical, Travel)',
                      hintStyle: GoogleFonts.inter(
                        color: Colors.grey.shade400,
                        fontSize: 11,
                      ),
                      errorText: reasonError,
                      errorMaxLines: 3,
                      errorStyle: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: const Color(0xFFA63228),
                        fontWeight: FontWeight.w600,
                      ),
                      counterText: '${reasonController.text.length} / 100',
                      counterStyle: GoogleFonts.inter(
                        fontSize: 10,
                        color: reasonController.text.length >= 100
                            ? const Color(0xFFA63228)
                            : Colors.grey.shade500,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: reasonError != null
                              ? const Color(0xFFA63228)
                              : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: reasonError != null
                              ? const Color(0xFFA63228)
                              : Colors.grey.shade300,
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
                  if (submissionError != null && submissionError!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFA63228).withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1.5),
                            child: Icon(
                              Icons.error_outline_rounded,
                              size: 16,
                              color: Color(0xFFA63228),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              submissionError!,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFA63228),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                          onPressed: () => Navigator.of(dialogContext).pop(),
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
                                  final rawAmount =
                                      amountController.text.trim();
                                  final amount =
                                      CurrencyInputFormatter.parse(rawAmount) ??
                                      0.0;
                                  final rawReason = reasonController.text;
                                  final trimmedReason = rawReason.trim();

                                  // Condition 1: Check amount first (Main condition)
                                  if (rawAmount.isEmpty || amount <= 0) {
                                    setDialogState(() {
                                      amountError =
                                          'Please enter an amount greater than ₱0.';
                                      reasonError = null;
                                      submissionError =
                                          'Please enter an amount greater than ₱0.';
                                    });
                                    return;
                                  }

                                  // Condition 2: Spaces-only check
                                  if (rawReason.isNotEmpty &&
                                      trimmedReason.isEmpty) {
                                    setDialogState(() {
                                      reasonError =
                                          'Spaces only are not allowed.';
                                      amountError = null;
                                      submissionError =
                                          'Spaces only are not allowed.';
                                    });
                                    return;
                                  }

                                  // Condition 3: Check reason
                                  if (trimmedReason.isEmpty) {
                                    setDialogState(() {
                                      reasonError =
                                          'Please enter a reason for cash advance.';
                                      amountError = null;
                                      submissionError =
                                          'Please enter a reason for cash advance.';
                                    });
                                    return;
                                  }

                                  setDialogState(() {
                                    amountError = null;
                                    reasonError = null;
                                    submissionError = null;
                                    isSubmitting = true;
                                  });

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
                                      'project_id': 1,
                                      'workerId': user?['id'],
                                      'workerName': workerName.isNotEmpty
                                          ? workerName
                                          : 'Worker',
                                      'amount': amount,
                                      'reason': trimmedReason,
                                      'date': dateStr,
                                      'status': 'Pending',
                                    });
                                    try {
                                      await ApiService.logAdminNotification(
                                        title: 'New Cash Advance Request',
                                        message:
                                            '$workerName submitted a cash advance request for ₱${amount.toStringAsFixed(2)}. Reason: $trimmedReason',
                                        type: 'Cash Advance',
                                        severity: 'Medium',
                                        action: 'VALE_REQUESTED',
                                        workerId: user?['id']?.toString(),
                                      );
                                    } catch (_) {}
                                    if (dialogContext.mounted) {
                                      Navigator.of(dialogContext).pop();
                                    }
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Cash advance request submitted!',
                                            style: GoogleFonts.inter(fontSize: 12),
                                          ),
                                          backgroundColor: Colors.green.shade700,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      );
                                      _loadData();
                                    }
                                  } catch (e) {
                                    if (dialogContext.mounted) {
                                      setDialogState(() {
                                        isSubmitting = false;
                                        final msg =
                                            ApiService.sanitizeErrorMessage(
                                          e,
                                          'Unable to submit cash advance.',
                                        );
                                        submissionError = msg;
                                        final lower = msg.toLowerCase();
                                        if (lower.contains('amount') ||
                                            lower.contains('limit') ||
                                            lower.contains('exceed')) {
                                          amountError = 'Exceeds advance limit';
                                          reasonError = null;
                                        } else if (lower.contains('reason')) {
                                          reasonError = 'Invalid reason';
                                          amountError = null;
                                        } else {
                                          amountError = null;
                                          reasonError = null;
                                        }
                                      });
                                    }
                                  }
                                },
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Submit',
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
  }

  String _formatDate(String? raw) {
    if (raw == null) return '—';
    try {
      final datePart = raw.contains('T')
          ? raw.split('T')[0]
          : raw.split(' ')[0];
      final parts = datePart.split('-');
      if (parts.length < 3) return raw;
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
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (m == null || d == null) return raw;
      return '${months[m - 1]} $d, ${parts[0]}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final approvedAdvances = _cashAdvances
        .where((c) => c['status'] == 'Approved')
        .toList();
    final filteredPayroll = _filteredPayrollHistory;
    final filteredCashAdvances = _filteredCashAdvances;

    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEA),
      appBar: WorkerAppHeader(
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFFA63228),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFFA63228),
                indicatorWeight: 2.5,
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                labelStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                tabs: const [
                  Tab(text: 'Payroll History'),
                  Tab(text: 'Cash Advance History'),
                  Tab(text: 'Request Advance'),
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
                        // --- TAB 1: PAYROLL HISTORY ---
                        RefreshIndicator(
                          color: const Color(0xFFA63228),
                          onRefresh: _loadData,
                          child: PaginatedListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            leadingItemCount: 2,
                            padding: EdgeInsets.symmetric(
                              horizontal: hp,
                              vertical: 10,
                            ),
                            itemCount: filteredPayroll.isEmpty
                                ? 3
                                : filteredPayroll.length + 2,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              if (i == 0) {
                                return _buildSalarySummaryCard();
                              }
                              if (i == 1) {
                                return _buildHistoryFilters(
                                  period: _payrollPeriodFilter,
                                  status: _payrollStatusFilter,
                                  horizontalPadding: 0,
                                  onPeriodChanged: (value) {
                                    if (value != null) {
                                      setState(
                                        () => _payrollPeriodFilter = value,
                                      );
                                    }
                                  },
                                  onStatusChanged: (value) {
                                    if (value != null) {
                                      setState(
                                        () => _payrollStatusFilter = value,
                                      );
                                    }
                                  },
                                );
                              }
                              if (filteredPayroll.isEmpty) {
                                return _buildHistoryNoResults(
                                  hasRecords: _payrollHistory.isNotEmpty,
                                  title: 'No salary payouts found',
                                  subtitle: _payrollHistory.isNotEmpty
                                      ? 'Try another date range or status.'
                                      : 'Your salary payout history will appear here once processed by the admin.',
                                  icon: Icons.account_balance_wallet_outlined,
                                );
                              }
                              return _buildPayrollCard(filteredPayroll[i - 2]);
                            },
                          ),
                        ),

                        // --- TAB 2: CASH ADVANCE HISTORY ---
                        RefreshIndicator(
                          color: const Color(0xFFA63228),
                          onRefresh: _loadData,
                          child: PaginatedListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            leadingItemCount: 1,
                            padding: EdgeInsets.symmetric(
                              horizontal: hp,
                              vertical: 10,
                            ),
                            itemCount: filteredCashAdvances.isEmpty
                                ? 2
                                : filteredCashAdvances.length + 1,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              if (i == 0) {
                                return _buildHistoryFilters(
                                  period: _cashAdvancePeriodFilter,
                                  status: _cashAdvanceStatusFilter,
                                  horizontalPadding: 0,
                                  onPeriodChanged: (value) {
                                    if (value != null) {
                                      setState(
                                        () => _cashAdvancePeriodFilter = value,
                                      );
                                    }
                                  },
                                  onStatusChanged: (value) {
                                    if (value != null) {
                                      setState(
                                        () => _cashAdvanceStatusFilter = value,
                                      );
                                    }
                                  },
                                );
                              }
                              if (filteredCashAdvances.isEmpty) {
                                return _buildHistoryNoResults(
                                  hasRecords: _cashAdvances.isNotEmpty,
                                  title: 'No cash advance records found',
                                  subtitle: _cashAdvances.isNotEmpty
                                      ? 'Try another date range or status.'
                                      : 'Your cash advance requests will appear here once submitted.',
                                  icon: Icons.receipt_long_outlined,
                                );
                              }
                              final ca = filteredCashAdvances[i - 1];
                              final status =
                                  ca['status']?.toString() ?? 'Pending';
                              final isApproved = status == 'Approved';
                              final isPending = status == 'Pending';

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.015,
                                      ),
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
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFA63228,
                                        ).withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.payments_outlined,
                                        size: 20,
                                        color: Color(0xFFA63228),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ca['reason']?.toString() ??
                                                'Cash Advance',
                                            style: GoogleFonts.inter(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            _formatDate(ca['date']?.toString()),
                                            style: GoogleFonts.inter(
                                              fontSize: 10.5,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₱${ca['amount']?.toString() ?? '0'}',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isApproved
                                                ? Colors.green.shade50
                                                : isPending
                                                ? Colors.orange.shade50
                                                : Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
                                            border: Border.all(
                                              color: isApproved
                                                  ? Colors.green.shade200
                                                  : isPending
                                                  ? Colors.orange.shade200
                                                  : Colors.red.shade200,
                                            ),
                                          ),
                                          child: Text(
                                            status,
                                            style: GoogleFonts.inter(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: isApproved
                                                  ? Colors.green.shade800
                                                  : isPending
                                                  ? Colors.orange.shade800
                                                  : Colors.red.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (status.toLowerCase() == 'rejected' &&
                                    (ca['rejection_reason'] ?? '')
                                        .toString()
                                        .trim()
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: Colors.red.shade200,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(
                                              Icons.info_outline,
                                              size: 12,
                                              color: Color(0xFFA63228),
                                            ),
                                            const SizedBox(width: 5),
                                            Expanded(
                                              child: Text(
                                                'Rejection reason: ${ca['rejection_reason']}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  color:
                                                      const Color(0xFFA63228),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                        // --- TAB 3: REQUEST CASH ADVANCE ---
                        ListView(
                          padding: EdgeInsets.symmetric(
                            horizontal: hp,
                            vertical: 14,
                          ),
                          children: [
                            // Summary Card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFA63228),
                                    Color(0xFFD94F3D),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.account_balance_wallet,
                                        color: Colors.white70,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Cash Advance Summary',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      const spacing = 12.0;
                                      final columns =
                                          constraints.maxWidth < 360 ? 2 : 3;
                                      final itemWidth =
                                          (constraints.maxWidth -
                                              spacing * (columns - 1)) /
                                          columns;
                                      return Wrap(
                                        spacing: spacing,
                                        runSpacing: 10,
                                        children: [
                                          SizedBox(
                                            width: itemWidth,
                                            child: _buildSummaryItem(
                                              'Total Requested',
                                              '₱${_cashAdvances.fold<double>(0, (sum, c) => sum + (double.tryParse(c['amount']?.toString() ?? '0') ?? 0)).toStringAsFixed(2)}',
                                            ),
                                          ),
                                          SizedBox(
                                            width: itemWidth,
                                            child: _buildSummaryItem(
                                              'Approved',
                                              '₱${approvedAdvances.fold<double>(0, (sum, c) => sum + (double.tryParse(c['amount']?.toString() ?? '0') ?? 0)).toStringAsFixed(2)}',
                                            ),
                                          ),
                                          SizedBox(
                                            width: itemWidth,
                                            child: _buildSummaryItem(
                                              'Pending',
                                              '${_cashAdvances.where((c) => c['status'] == 'Pending').length}',
                                              isBadge: true,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Request Button
                            ElevatedButton.icon(
                              onPressed: _showCashAdvanceDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFA63228),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: Text(
                                'Request Cash Advance',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Info Card
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade100),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 16,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Cash advance requests are reviewed by the admin during cutoff. Approved amounts will be deducted from your next salary payout.',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.blue.shade800,
                                        height: 1.4,
                                      ),
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
              },
            ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {bool isBadge = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(fontSize: 10, color: Colors.white70),
        ),
        const SizedBox(height: 2),
        isBadge
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildHistoryNoResults({
    required bool hasRecords,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 18),
      child: Column(
        children: [
          Icon(
            hasRecords ? Icons.filter_list_off : icon,
            size: 32,
            color: const Color(0xFFA63228),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSalarySummaryCard() {
    final dailyLogs = (_salarySummary['daily_logs'] as List? ?? const [])
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
    double amount(String key) =>
        double.tryParse(_salarySummary[key]?.toString() ?? '') ?? 0;
    String currency(dynamic value) {
      final parsed = double.tryParse(value?.toString() ?? '') ?? 0;
      return '₱${parsed.toStringAsFixed(2)}';
    }

    Widget detail(String label, String value, {bool emphasize = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Text(
                label,
                softWrap: true,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.grey.shade700,
                  fontWeight: emphasize ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: emphasize
                          ? const Color(0xFFA63228)
                          : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFA63228).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SALARY MONITORING',
            style: GoogleFonts.inter(
              fontSize: 10,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFA63228),
            ),
          ),
          if (_salarySummaryError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _salarySummaryError!,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          const SizedBox(height: 8),
          detail('Daily salary rate', currency(_salarySummary['daily_rate'])),
          detail(
            'Regular earnings (after attendance deductions)',
            currency(amount('base_earnings')),
          ),
          detail(
            'Attendance deductions',
            currency(amount('attendance_deductions')),
          ),
          detail('Approved overtime pay', currency(amount('overtime_pay'))),
          const Divider(height: 14),
          detail(
            'Accumulated total earnings',
            currency(amount('total_earnings')),
            emphasize: true,
          ),
          if (dailyLogs.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                'Daily attendance and salary breakdown (${dailyLogs.length})',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              children: dailyLogs.map((log) {
                final date = _formatDate(log['date']?.toString());
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade100),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$date • ${log['status'] ?? 'Attendance'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                currency(log['total_earnings']),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFA63228),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'AM: ${log['morning_in'] ?? '—'} - ${log['morning_out'] ?? '—'}  •  '
                        'PM: ${log['afternoon_in'] ?? '—'} - ${log['afternoon_out'] ?? '—'}',
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        'Regular: ${currency(log['daily_salary'])}  •  '
                        'Deduction: ${currency(log['attendance_deduction'])}  •  '
                        'OT: ${currency(log['overtime_pay'])}',
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPayrollCard(Map<String, dynamic> p) {
    final status = p['status']?.toString() ?? 'Approved';
    final isPaid = status == 'Paid';
    final netPay = p['net_pay']?.toString() ?? '0';
    final grossPay = p['gross_pay']?.toString() ?? '0';
    final workedDays = p['worked_days']?.toString() ?? '0';
    final totalHours = p['total_hours']?.toString() ?? '0';
    final caDeductions = p['cash_advance_deductions'] ?? 0;
    final lateDeductions = p['late_deductions'] ?? 0;
    final overtimePay = p['overtime_pay'] ?? 0;
    final dailyLogs = (p['daily_logs'] as List? ?? const [])
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
    final cutoffStart = _formatDate(p['cutoff_start']?.toString());
    final cutoffEnd = _formatDate(p['cutoff_end']?.toString());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPaid
              ? const Color(0xFF2E7D32).withValues(alpha: 0.25)
              : Colors.grey.shade200,
          width: isPaid ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFA63228).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 16,
                        color: Color(0xFFA63228),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$cutoffStart — $cutoffEnd',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            p['project_name']?.toString() ?? 'Project Site',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPaid ? 'PAID / RELEASED' : status.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: isPaid
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF1565C0),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F7F4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Days & Hours Worked',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$workedDays days ($totalHours hrs)',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Gross Earnings',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '₱$grossPay',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if ((num.tryParse(overtimePay.toString()) ?? 0) > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Approved overtime pay',
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      color: const Color(0xFF2E7D32),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '+₱$overtimePay',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: const Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if ((num.tryParse(caDeductions.toString()) ?? 0) > 0 ||
              (num.tryParse(lateDeductions.toString()) ?? 0) > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Deductions (Late: ₱$lateDeductions • CA: ₱$caDeductions)',
                    softWrap: true,
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '-₱${(num.tryParse(caDeductions.toString()) ?? 0) + (num.tryParse(lateDeductions.toString()) ?? 0)}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          if (dailyLogs.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                'Attendance breakdown (${dailyLogs.length} days)',
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              children: dailyLogs.map((log) {
                final date = _formatDate(log['date']?.toString());
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '$date • ${log['status'] ?? ''}',
                          style: GoogleFonts.inter(fontSize: 8.5),
                        ),
                      ),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Regular ₱${log['base_earned'] ?? 0} • '
                            'Deduction ₱${log['deduction'] ?? 0} • '
                            'OT ₱${log['overtime_pay'] ?? 0}',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'NET TAKE-HOME PAY',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '₱$netPay',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFA63228),
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
}

class _NoLeadingOrRepeatedSpacesFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;
    // Disallow leading whitespace/spaces
    if (text.startsWith(RegExp(r'\s'))) {
      text = text.replaceFirst(RegExp(r'^\s+'), '');
    }
    // Collapse 2 or more consecutive spaces into a single space
    text = text.replaceAll(RegExp(r' {2,}'), ' ');

    if (text != newValue.text) {
      final newOffset = text.length < newValue.selection.baseOffset
          ? text.length
          : newValue.selection.baseOffset;
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: newOffset),
      );
    }
    return newValue;
  }
}
