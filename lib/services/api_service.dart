import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const _readNotificationIdsKey = 'readNotificationIds';
  static const _deletedNotificationIdsKey = 'deletedWorkerNotificationIds';

  // For emulator, use '10.0.2.2'.
  // For physical device via wireless debugging, use your PC's local IP address.
  // Run `ipconfig` in cmd to find your PC's IPv4 address.
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );
  static String androidHost = const String.fromEnvironment(
    'API_HOST',
    defaultValue: '127.0.0.1',
  );
  static const String _wifiHost = '192.168.1.17';
  static String? _customHost;
  static String? _workingHost;

  static String get effectiveHost =>
      _customHost ?? _workingHost ?? androidHost;

  static Future<void> initHost() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedHost = prefs.getString('custom_server_host');
      if (savedHost != null && savedHost.trim().isNotEmpty) {
        _customHost = savedHost.trim();
      }
    } catch (_) {}
  }

  static Future<void> updateHost(String newHost) async {
    final trimmed = newHost.trim().replaceFirst(RegExp(r'^https?://'), '').replaceFirst(RegExp(r'/.*$'), '');
    _customHost = trimmed.isNotEmpty ? trimmed : null;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_customHost == null) {
        await prefs.remove('custom_server_host');
      } else {
        await prefs.setString('custom_server_host', _customHost!);
      }
    } catch (_) {}
  }

  static String get baseUrl => resolveBaseUrl(
    configured: _configuredBaseUrl,
    isReleaseMode: false,
    isAndroid: !kIsWeb && Platform.isAndroid,
    androidHost: effectiveHost,
  );

  @visibleForTesting
  static String resolveBaseUrl({
    required String configured,
    required bool isReleaseMode,
    required bool isAndroid,
    required String androidHost,
  }) {
    final configuredUrl = configured.trim();
    if (configuredUrl.isNotEmpty) {
      return configuredUrl.replaceFirst(RegExp(r'/+$'), '');
    }
    if (isReleaseMode) {
      throw StateError(
        'API_BASE_URL must be set for release builds. '
        'Build with --dart-define=API_BASE_URL=https://<backend-host>/api.',
      );
    }
    if (isAndroid) return 'http://$androidHost:5000/api';
    return 'http://localhost:5000/api';
  }

  // Global state for current user's role (admin, staff, tool, worker)
  static String? currentUserRole;
  static Map<String, dynamic>? currentUser;
  static String? _authToken;

  static String? get authToken => _authToken;
  static void setToken(String? token) => _authToken = token;
  static void clearToken() => _authToken = null;

  static Future<void> logout() async {
    try {
      final user = currentUser;
      final userId = user?['id']?.toString();
      final name =
          user?['name'] ?? user?['full_name'] ?? user?['username'] ?? 'User';
      final role =
          currentUserRole ?? user?['role'] ?? user?['position'] ?? 'Worker';

      await _post('/logout', {
        'userId': userId,
        'name': name,
        'role': role,
        'client': 'Mobile App',
      });
    } catch (_) {
      // Continue cleanup even if server unreachable
    } finally {
      currentUser = null;
      currentUserRole = null;
      clearToken();
    }
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-client-platform': 'mobile',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
    if (currentUser?['name'] != null ||
        currentUser?['full_name'] != null ||
        currentUser?['username'] != null)
      'x-actor-name':
          (currentUser?['name'] ??
                  currentUser?['full_name'] ??
                  currentUser?['username'] ??
                  'User')
              .toString(),
    if (currentUserRole != null || currentUser?['role'] != null)
      'x-actor-role': (currentUserRole ?? currentUser?['role'] ?? 'Worker')
          .toString(),
    if (currentUser?['id'] != null) 'x-actor-id': currentUser!['id'].toString(),
  };

  static const Duration requestTimeout = Duration(seconds: 12);

  /// Converts raw technical exceptions into user-friendly messages
  static String sanitizeErrorMessage(
    dynamic error, [
    String fallback = 'An unexpected error occurred. Please try again.',
  ]) {
    final text = error.toString().replaceAll('Exception: ', '').trim();
    final lower = text.toLowerCase();

    if (lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('network is unreachable') ||
        lower.contains('clientexception') ||
        lower.contains('socketexception') ||
        lower.contains('connection closed') ||
        lower.contains('failed to connect') ||
        lower.contains('software caused connection abort')) {
      return 'Unable to connect to the server. Please check your network connection.';
    }

    if (lower.contains('timed out') || lower.contains('timeoutexception')) {
      return 'Request timed out. The server took too long to respond. Please try again.';
    }

    if (lower.contains('resource_exhausted') || lower.contains('quota exceeded')) {
      return 'Database quota exceeded. Service resets daily at 4:00 PM.';
    }

    if (lower.contains('formatexception')) {
      return 'Invalid response received from server.';
    }

    return text.isNotEmpty ? text : fallback;
  }

  static String _extractErrorMessage(http.Response res, String defaultMessage) {
    try {
      final response = jsonDecode(res.body);
      if (response is Map) {
        if (response['error'] != null &&
            response['error'].toString().trim().isNotEmpty) {
          return response['error'].toString().trim();
        }
        if (response['message'] != null &&
            response['message'].toString().trim().isNotEmpty) {
          return response['message'].toString().trim();
        }
      }
    } catch (_) {}
    return defaultMessage;
  }

  static Future<dynamic> _get(String path) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl$path'), headers: _headers)
          .timeout(requestTimeout);
      if (res.statusCode == 200) return jsonDecode(res.body);
      final message = _extractErrorMessage(
        res,
        'Failed to load $path (${res.statusCode})',
      );
      throw Exception(message);
    } catch (e) {
      if (e is Exception &&
          !e.toString().contains('SocketException') &&
          !e.toString().contains('TimeoutException') &&
          !e.toString().contains('ClientException')) {
        rethrow;
      }
      throw Exception(sanitizeErrorMessage(e));
    }
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);
      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body);
      }
      final message = _extractErrorMessage(
        res,
        'Failed to submit data (${res.statusCode})',
      );
      throw Exception(message);
    } catch (e) {
      if (e is Exception &&
          !e.toString().contains('SocketException') &&
          !e.toString().contains('TimeoutException') &&
          !e.toString().contains('ClientException')) {
        rethrow;
      }
      throw Exception(sanitizeErrorMessage(e));
    }
  }

  static Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    try {
      final res = await http
          .put(
            Uri.parse('$baseUrl$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);
      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body);
      }
      final message = _extractErrorMessage(
        res,
        'Failed to update $path (${res.statusCode})',
      );
      throw Exception(message);
    } catch (e) {
      if (e is Exception &&
          !e.toString().contains('SocketException') &&
          !e.toString().contains('TimeoutException') &&
          !e.toString().contains('ClientException')) {
        rethrow;
      }
      throw Exception(sanitizeErrorMessage(e));
    }
  }

  static Future<void> _delete(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    try {
      final res = await http
          .delete(
            Uri.parse('$baseUrl$path'),
            headers: _headers,
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(requestTimeout);
      if (res.statusCode != 200 && res.statusCode != 204) {
        final message = _extractErrorMessage(
          res,
          'Failed to delete $path (${res.statusCode})',
        );
        throw Exception(message);
      }
    } catch (e) {
      if (e is Exception &&
          !e.toString().contains('SocketException') &&
          !e.toString().contains('TimeoutException') &&
          !e.toString().contains('ClientException')) {
        rethrow;
      }
      throw Exception(sanitizeErrorMessage(e));
    }
  }

  // Projects
  static Future<List<dynamic>> getProjects() =>
      _get('/projects').then((v) => v as List);
  static Future<dynamic> createProject(Map<String, dynamic> data) =>
      _post('/projects', data);
  static Future<dynamic> updateProject(dynamic id, Map<String, dynamic> data) =>
      _put('/projects/$id', data);
  static Future<void> deleteProject(dynamic id) => _delete('/projects/$id');

  // Schedules
  static Future<List<dynamic>> getSchedules() =>
      _get('/schedules').then((v) => v as List);
  static Future<dynamic> createSchedule(Map<String, dynamic> data) =>
      _post('/schedules', data);
  static Future<dynamic> updateSchedule(
    dynamic id,
    Map<String, dynamic> data,
  ) => _put('/schedules/$id', data);
  static Future<void> deleteSchedule(dynamic id) => _delete('/schedules/$id');

  // Schedule Overrides (Date-specific work shift rules)
  static Future<List<dynamic>> getScheduleOverrides() =>
      _get('/schedule-overrides').then((v) => v as List);
  static Future<dynamic> getScheduleOverrideForDate(String date) =>
      _get('/schedule-overrides/$date');
  static Future<dynamic> saveScheduleOverride(Map<String, dynamic> data) =>
      _post('/schedule-overrides', data);
  static Future<dynamic> deleteScheduleOverride(String date) =>
      _delete('/schedule-overrides/$date');

  // Attendance management
  static Future<Map<String, dynamic>> getAttendanceSettings() => _get(
    '/attendance-settings',
  ).then((v) => Map<String, dynamic>.from(v as Map));
  static Future<Map<String, dynamic>> saveAttendanceSettings(
    Map<String, dynamic> data,
  ) => _post(
    '/attendance-settings',
    data,
  ).then((v) => Map<String, dynamic>.from(v as Map));
  static Future<List<dynamic>> getAttendanceSchedules() =>
      _get('/attendance-schedules').then((v) => v as List);
  static Future<dynamic> saveAttendanceSchedule(Map<String, dynamic> data) =>
      _post('/attendance-schedules', data);
  static Future<void> deleteAttendanceSchedule(dynamic id) =>
      _delete('/attendance-schedules/$id');
  static Future<List<dynamic>> getEarlyOutRequests({dynamic workerId}) {
    final query = workerId == null
        ? ''
        : '?worker_id=${Uri.encodeQueryComponent(workerId.toString())}';
    return _get('/early-out-requests$query').then((v) => v as List);
  }

  static Future<dynamic> submitEarlyOutRequest(Map<String, dynamic> data) =>
      _post('/early-out-requests', data);
  static Future<dynamic> reviewEarlyOutRequest(
    dynamic id,
    Map<String, dynamic> data,
  ) => _put('/early-out-requests/$id/review', data);
  static Future<List<dynamic>> getAttendanceCorrectionRequests({
    dynamic workerId,
  }) {
    final query = workerId == null
        ? ''
        : '?worker_id=${Uri.encodeQueryComponent(workerId.toString())}';
    return _get('/attendance-correction-requests$query').then((v) => v as List);
  }

  static Future<dynamic> submitAttendanceCorrectionRequest(
    Map<String, dynamic> data,
  ) => _post('/attendance-correction-requests', data);
  static Future<dynamic> reviewAttendanceCorrectionRequest(
    dynamic id,
    Map<String, dynamic> data,
  ) => _put('/attendance-correction-requests/$id/review', data);

  // Workers
  static Future<List<dynamic>> getWorkers() =>
      _get('/workers').then((v) => v as List);
  static Future<dynamic> createWorker(Map<String, dynamic> data) =>
      _post('/workers', data);
  static Future<dynamic> updateWorker(dynamic id, Map<String, dynamic> data) =>
      _put('/workers/$id', data);
  static Future<void> deleteWorker(dynamic id) => _delete('/workers/$id');

  // Budget Additions
  static Future<List<dynamic>> getBudgetAdditions(dynamic projectId) =>
      _get('/projects/$projectId/budget-additions').then((v) => v as List);
  static Future<dynamic> createBudgetAddition(
    dynamic projectId,
    Map<String, dynamic> data,
  ) => _post('/projects/$projectId/budget-additions', data);

  // Project-scoped endpoints
  static Future<List<dynamic>> getAttendance(dynamic projectId) =>
      _get('/attendance/$projectId').then((v) => v as List);
  static Future<dynamic> saveAttendance(Map<String, dynamic> data) =>
      _post('/attendance', data);
  static Future<Map<String, dynamic>> scanAttendanceWithNfc(String rfidUid) =>
      _post('/attendance/scan', {
        'rfid_uid': rfidUid,
        'scan_source': 'NFC',
        'terminal_id': 'MOBILE-NFC',
      }).then((value) => Map<String, dynamic>.from(value as Map));
  static Future<Map<String, dynamic>> scanAttendanceWithQr(String workerCode) =>
      _post('/attendance/scan', {
        'worker_code': workerCode,
        'scan_source': 'QR',
        'terminal_id': 'MOBILE-QR',
      }).then((value) => Map<String, dynamic>.from(value as Map));
  static Future<dynamic> updateAttendanceRecord(
    dynamic id,
    Map<String, dynamic> data,
  ) => _put('/attendance/$id', data);

  static Future<List<dynamic>> getExpenses(dynamic projectId) =>
      _get('/expenses/$projectId').then((v) => v as List);
  static Future<List<dynamic>> getAllExpenses() =>
      _get('/expenses').then((v) => v as List);
  static Future<Map<String, dynamic>> getExpensesSummary() => _get(
    '/expenses/summary',
  ).then((v) => Map<String, dynamic>.from(v as Map));
  static Future<Map<String, dynamic>> getBudgetSummary() => _get(
    '/expenses/budget-summary',
  ).then((v) => Map<String, dynamic>.from(v as Map));
  static Future<Map<String, dynamic>> getWorkersSummary() =>
      _get('/workers/summary').then((v) => Map<String, dynamic>.from(v as Map));
  static Future<Map<String, dynamic>> getAssetsSummary() =>
      _get('/assets/summary').then((v) => Map<String, dynamic>.from(v as Map));
  static Future<List<dynamic>> getMonthlyExpenses() =>
      _get('/expenses/monthly').then((v) => v as List);
  static Future<dynamic> createExpense(Map<String, dynamic> data) =>
      _post('/expenses', data);
  static Future<dynamic> updateExpense(dynamic id, Map<String, dynamic> data) =>
      _put('/expenses/$id', data);
  static Future<void> deleteExpense(dynamic id) => _delete('/expenses/$id');

  static Future<List<dynamic>> getMaterials(dynamic projectId) =>
      _get('/materials/$projectId').then((v) => v as List);
  static Future<dynamic> createMaterial(Map<String, dynamic> data) =>
      _post('/materials', data);
  static Future<dynamic> updateMaterial(
    dynamic id,
    Map<String, dynamic> data,
  ) => _put('/materials/$id', data);
  static Future<void> deleteMaterial(dynamic id) => _delete('/materials/$id');

  static Future<List<dynamic>> getAssets(dynamic projectId) =>
      _get('/assets/$projectId').then((v) => v as List);
  static Future<List<dynamic>> getAllAssets() =>
      _get('/assets').then((v) => v as List);
  static Future<dynamic> createAsset(Map<String, dynamic> data) =>
      _post('/assets', data);
  static Future<dynamic> updateAsset(dynamic id, Map<String, dynamic> data) =>
      _put('/assets/$id', data);
  static Future<void> deleteAsset(dynamic id) => _delete('/assets/$id');

  // Borrow History
  static Future<List<dynamic>> getBorrowHistory(dynamic projectId) =>
      _get('/borrow-history/$projectId').then((v) => v as List);
  static Future<dynamic> createBorrowRecord(Map<String, dynamic> data) =>
      _post('/borrow-history', data);

  // Firestore-backed (string document IDs) asset helpers used by Tools Monitoring
  static Future<List<dynamic>> getProjectAssets(dynamic projectId) =>
      _get('/assets/$projectId').then((v) => v as List);
  static Future<dynamic> createAssetDoc(Map<String, dynamic> data) =>
      _post('/assets', data);
  static Future<dynamic> updateAssetDoc(
    dynamic id,
    Map<String, dynamic> data,
  ) => _put('/assets/$id', data);
  static Future<List<dynamic>> getProjectBorrowHistory(dynamic projectId) =>
      _get('/borrow-history/$projectId').then((v) => v as List);
  static Future<dynamic> logBorrowHistory(Map<String, dynamic> data) =>
      _post('/borrow-history', data);

  // Reports
  static Future<List<dynamic>> getExpensesReport({
    dynamic projectId,
    String? startDate,
    String? endDate,
  }) {
    String query = '';
    final params = <String>[];
    if (projectId != null) params.add('project_id=$projectId');
    if (startDate != null) params.add('startDate=$startDate');
    if (endDate != null) params.add('endDate=$endDate');
    if (params.isNotEmpty) query = '?${params.join('&')}';
    return _get('/reports/expenses$query').then((v) => v as List);
  }

  static Future<List<dynamic>> getManpowerReport({
    dynamic projectId,
    String? startDate,
    String? endDate,
  }) {
    String query = '';
    final params = <String>[];
    if (projectId != null) params.add('project_id=$projectId');
    if (startDate != null) params.add('startDate=$startDate');
    if (endDate != null) params.add('endDate=$endDate');
    if (params.isNotEmpty) query = '?${params.join('&')}';
    return _get('/reports/manpower$query').then((v) => v as List);
  }

  static Future<List<dynamic>> getMaterialsReport({dynamic projectId}) {
    final query = projectId != null ? '?project_id=$projectId' : '';
    return _get('/reports/materials$query').then((v) => v as List);
  }

  static Future<List<dynamic>> getAssetsReport({dynamic projectId}) {
    final query = projectId != null ? '?project_id=$projectId' : '';
    return _get('/reports/assets$query').then((v) => v as List);
  }

  static Future<List<dynamic>> getCashAdvances(dynamic projectId) =>
      _get('/cash-advances/$projectId').then((v) => v as List);

  static Future<dynamic> createCashAdvance(Map<String, dynamic> data) =>
      _post('/cash-advances', data);
  static Future<List<dynamic>> getPendingCashAdvances() =>
      _get('/cash-advances/pending').then((v) => v as List);
  static Future<List<dynamic>> getCashAdvanceHistory() async {
    try {
      final res = await _get('/cash-advances/ALL');
      if (res is List && res.isNotEmpty) return res;
    } catch (_) {}
    try {
      final res = await _get('/cash-advances/history');
      if (res is List && res.isNotEmpty) return res;
    } catch (_) {}
    try {
      final res = await _get('/cash-advances/ALL');
      if (res is List) return res;
    } catch (_) {}
    return [];
  }

  static Future<void> approveCashAdvance(
    dynamic id,
    String status, {
    String? rejectionReason,
  }) =>
      _put('/cash-advances/$id/approve', {
        'status': status,
        if (status == 'Rejected')
          'rejection_reason': rejectionReason ?? 'Rejected by Administrator',
      });
  static Future<List<dynamic>> getWorkerCashAdvances(dynamic workerId) =>
      _get('/workers/$workerId/cash-advances').then((v) => v as List);
  static Future<List<dynamic>> getWorkerPayroll(dynamic workerId) =>
      _get('/workers/$workerId/payroll').then((v) => v as List);
  static Future<Map<String, dynamic>> getWorkerSalarySummary(
    dynamic workerId,
  ) => _get(
    '/workers/$workerId/salary-summary',
  ).then((v) => Map<String, dynamic>.from(v as Map));

  // Notifications
  static Future<List<dynamic>> getNotifications() async {
    final result = await _get('/notifications') as List;
    final preferences = await SharedPreferences.getInstance();
    final readIds = preferences.getStringList(_readNotificationIdsKey) ?? [];
    final readIdSet = readIds.toSet();

    return result.map((item) {
      final notification = Map<String, dynamic>.from(item as Map);
      if (notification['read'] == true ||
          readIdSet.contains(notification['id']?.toString())) {
        notification['read'] = true;
      }
      return notification;
    }).toList();
  }

  static Future<List<dynamic>> getWorkerNotifications() async {
    final result =
        await _get('/worker/notifications').then((value) => value as List);
    final preferences = await SharedPreferences.getInstance();
    final readIds = preferences.getStringList(_readNotificationIdsKey) ?? [];
    final readIdSet = readIds.toSet();
    final deletedIds =
        preferences.getStringList(_deletedNotificationIdsKey) ?? [];
    final deletedIdSet = deletedIds.toSet();

    return result.where((item) {
      if (item is! Map) return false;
      final id = item['id']?.toString() ?? '';
      return !deletedIdSet.contains(id);
    }).map((item) {
      final notification = Map<String, dynamic>.from(item as Map);
      if (notification['read'] == true ||
          readIdSet.contains(notification['id']?.toString())) {
        notification['read'] = true;
      }
      return notification;
    }).toList();
  }

  static Future<void> markWorkerNotificationRead(dynamic id) async {
    final notificationId = id.toString();
    try {
      await _put(
        '/worker/notifications/${Uri.encodeComponent(notificationId)}/read',
        {},
      );
    } catch (_) {}
    await _saveReadNotificationIds([notificationId]);
  }

  static Future<void> deleteWorkerNotifications(
    List<String> notificationIds,
  ) async {
    final uniqueIds =
        notificationIds.map((e) => e.toString()).toSet().toList();
    try {
      await _delete('/worker/notifications', {'notificationIds': uniqueIds});
    } catch (_) {}
    await _saveDeletedNotificationIds(uniqueIds);
  }

  static Future<void> _saveDeletedNotificationIds(Iterable<String> ids) async {
    final preferences = await SharedPreferences.getInstance();
    final deletedIds =
        preferences.getStringList(_deletedNotificationIdsKey) ?? [];
    await preferences.setStringList(
      _deletedNotificationIdsKey,
      {...deletedIds, ...ids}.toList(),
    );
  }

  static Future<void> markNotificationRead(dynamic id) async {
    final notificationId = id.toString();
    await _put('/notifications/$notificationId/read', {});
    await _saveReadNotificationIds([notificationId]);
  }

  static Future<void> markAllNotificationsRead({
    required List<String> notificationIds,
  }) async {
    final uniqueIds = notificationIds.toSet().toList();
    await _put('/notifications/mark-all-read', {'notificationIds': uniqueIds});
    await _saveReadNotificationIds(uniqueIds);
  }

  static Future<void> _saveReadNotificationIds(Iterable<String> ids) async {
    final preferences = await SharedPreferences.getInstance();
    final readIds = preferences.getStringList(_readNotificationIdsKey) ?? [];
    await preferences.setStringList(
      _readNotificationIdsKey,
      {...readIds, ...ids}.toList(),
    );
  }

  static Future<dynamic> logAdminNotification({
    required String title,
    required String message,
    String type = 'Staff & Workers',
    String severity = 'Medium',
    String? actorName,
    String? actorRole,
    String? action,
    String? workerId,
  }) => _post('/notifications', {
    'title': title,
    'message': message,
    'type': type,
    'severity': severity,
    if (actorName != null) 'actor_name': actorName,
    if (actorRole != null) 'actor_role': actorRole,
    if (action != null) 'action': action,
    if (workerId != null) 'worker_id': workerId,
  });

  // Auth
  static Future<Map<String, dynamic>> register(
    Map<String, dynamic> data,
  ) async {
    final result = await _post('/register', data);
    return result as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> sendEmailOtp({
    required String email,
    required String purpose,
  }) async {
    final result = await _post('/email-otp/send', {
      'email': email,
      'purpose': purpose,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<String> verifyEmailOtp({
    required String email,
    required String purpose,
    required String code,
  }) async {
    final result = await _post('/email-otp/verify', {
      'email': email,
      'purpose': purpose,
      'code': code,
    });
    return (result as Map)['verificationToken'].toString();
  }

  static Future<void> resetPasswordWithEmailOtp({
    required String verificationToken,
    required String newPassword,
  }) async {
    await _post('/password/reset/email', {
      'verificationToken': verificationToken,
      'newPassword': newPassword,
    });
  }

  static String normalizePhone(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;

    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('63')) {
      return '+$digits';
    }
    if (digits.length == 10 && digits.startsWith('9')) {
      return '+63$digits';
    }
    if (digits.length == 10 && digits.startsWith('0')) {
      return '+63${digits.substring(1)}';
    }
    if (digits.length >= 10) {
      final last10 = digits.substring(digits.length - 10);
      return '+63$last10';
    }
    return trimmed;
  }

  static Set<String> phoneLookupVariants(String input) {
    final raw = input.trim();
    final compact = raw.replaceAll(RegExp(r'\D'), '');
    final variants = <String>{raw, raw.replaceAll(' ', ''), compact};

    if (compact.isEmpty) return variants;

    final last10 = compact.length >= 10
        ? compact.substring(compact.length - 10)
        : compact;
    variants.addAll({
      last10,
      '0$last10',
      '63$last10',
      '+63$last10',
      '+63${compact.startsWith('0') ? compact.substring(1) : compact}',
    });

    if (compact.startsWith('63')) {
      variants.add('+$compact');
    }
    if (compact.startsWith('0')) {
      variants.add('+63${compact.substring(1)}');
    }
    if (compact.length == 11 && compact.startsWith('9')) {
      variants.add('+63$compact');
    }

    return variants.map((v) => v.trim()).where((v) => v.isNotEmpty).toSet();
  }

  static Future<Map<String, dynamic>> login(
    String usernameOrPhone,
    String password,
  ) async {
    return _loginInternal(usernameOrPhone, password, allowFallback: true);
  }

  static Future<Map<String, dynamic>> _loginInternal(
    String usernameOrPhone,
    String password, {
    bool allowFallback = true,
  }) async {
    final raw = usernameOrPhone.trim();
    final normalized = normalizePhone(raw);

    // The worker login endpoint supports phone and username lookup itself.
    final identifiersToTry = <String>[];

    if (normalized != raw) {
      identifiersToTry.add(normalized);
      identifiersToTry.add(raw);
    } else {
      identifiersToTry.add(raw);
    }

    // Also try adding +63 to the raw input in case it was stored as +6309... during registration
    if (!raw.startsWith('+63')) {
      identifiersToTry.add('+63$raw');
    }

    http.Response? lastWorkerRes;

    try {
      for (final id in identifiersToTry) {
        final res = await http
            .post(
              Uri.parse('$baseUrl/login'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'username': id, 'password': password}),
            )
            .timeout(requestTimeout);
        lastWorkerRes = res;

        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);

          // Extract status if available
          String? status;
          if (body['status'] != null) {
            status = body['status'].toString();
          } else if (body['worker'] != null &&
              body['worker']['status'] != null) {
            status = body['worker']['status'].toString();
          } else if (body['user'] != null && body['user']['status'] != null) {
            status = body['user']['status'].toString();
          }

          if (status != null) {
            if (status.toLowerCase() == 'pending' ||
                status.toLowerCase().contains('pending')) {
              throw Exception('pending_approval');
            }
            if (status.toLowerCase() == 'rejected' ||
                status.toLowerCase().contains('reject')) {
              throw Exception('Account was rejected');
            }
          }

          if (body['token'] is String) {
            setToken(body['token'] as String);
          }
          _workingHost = effectiveHost;
          return body;
        }

        if (res.statusCode == 403) {
          final body = jsonDecode(res.body);
          if (body['error'] == 'pending_approval') {
            throw Exception('pending_approval');
          }
          if (body['error'] == 'rejected') {
            throw Exception('Account was rejected');
          }
        }

        if (res.statusCode == 401) {
          try {
            final body = jsonDecode(res.body);
            if (body['error'] == 'Invalid password') {
              throw Exception('Wrong Password');
            }
          } catch (e) {
            if (e is! FormatException) rethrow;
          }
        }

        if (res.statusCode == 500) {
          try {
            final body = jsonDecode(res.body);
            final err = (body['error'] ?? '').toString();
            if (err.contains('RESOURCE_EXHAUSTED') ||
                err.contains('Quota exceeded')) {
              throw Exception(
                'Firebase Daily Quota Exceeded. Reset occurs daily at 4:00 PM.',
              );
            }
          } catch (e) {
            if (e.toString().contains('Firebase Daily Quota')) rethrow;
          }
        }
      }
    } catch (e) {
      final str = e.toString();
      if (str.contains('pending_approval') ||
          str.contains('Account was rejected') ||
          str.contains('Wrong Password') ||
          str.contains('Firebase Daily Quota')) {
        rethrow;
      }
      if (str.contains('SocketException') ||
          str.contains('TimeoutException') ||
          str.contains('ClientException')) {
        if (allowFallback && !kIsWeb && Platform.isAndroid) {
          final nextHost = effectiveHost == '127.0.0.1' ? _wifiHost : '127.0.0.1';
          _workingHost = nextHost;
          try {
            return await _loginInternal(usernameOrPhone, password, allowFallback: false);
          } catch (_) {
            _workingHost = null;
          }
        }
        throw Exception(sanitizeErrorMessage(e));
      }
    }

    // Try admin login
    try {
      final adminRes = await http
          .post(
            Uri.parse('$baseUrl/admin/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': raw, 'password': password}),
          )
          .timeout(requestTimeout);

      if (adminRes.statusCode == 200) {
        _workingHost = effectiveHost;
        final data = jsonDecode(adminRes.body);
        // Store JWT token for subsequent authenticated requests
        if (data['token'] != null) setToken(data['token'] as String);
        return {
          'success': true,
          'role': 'Admin',
          'admin': data['admin'],
          'user': data['admin'],
        };
      }

      if (adminRes.statusCode == 500) {
        try {
          final body = jsonDecode(adminRes.body);
          final err = (body['error'] ?? '').toString();
          if (err.contains('RESOURCE_EXHAUSTED') ||
              err.contains('Quota exceeded')) {
            throw Exception(
              'Firebase Daily Quota Exceeded. Reset occurs daily at 4:00 PM.',
            );
          }
        } catch (e) {
          if (e.toString().contains('Firebase Daily Quota')) rethrow;
        }
      }
    } catch (e) {
      if (e.toString().contains('Firebase Daily Quota')) rethrow;
      final str = e.toString();
      if (allowFallback &&
          !kIsWeb &&
          Platform.isAndroid &&
          (str.contains('SocketException') ||
              str.contains('TimeoutException') ||
              str.contains('ClientException'))) {
        final nextHost = effectiveHost == '127.0.0.1' ? _wifiHost : '127.0.0.1';
        _workingHost = nextHost;
        try {
          return await _loginInternal(usernameOrPhone, password, allowFallback: false);
        } catch (_) {
          _workingHost = null;
        }
      }
      // continue to error handling
    }

    if (lastWorkerRes != null && lastWorkerRes.statusCode == 401) {
      try {
        final body = jsonDecode(lastWorkerRes.body);
        final err = body['error'];
        if (err == 'Account not found') {
          throw Exception('Account not existing');
        }
        throw Exception(err ?? 'Invalid username or password');
      } catch (e) {
        if (e is! FormatException) rethrow;
      }
      throw Exception('Invalid username or password');
    }

    throw Exception('Login failed (${lastWorkerRes?.statusCode ?? 400})');
  }

  // New endpoint for phone based login (workers only)
  static Future<Map<String, dynamic>> loginWithPhone(
    String phone,
    String password,
  ) => login(phone, password);

  // Pending Registrations (Admin)
  static Future<List<dynamic>> getPendingRegistrations() =>
      _get('/pending-registrations').then((v) => v as List);

  static Future<void> approveWorker(
    dynamic id,
    String status, {
    String? rejectionReason,
  }) =>
      _put('/workers/$id/approve', {
        'status': status,
        if (status == 'Rejected' && rejectionReason != null)
          'rejection_reason': rejectionReason,
      });

  static Future<Map<String, dynamic>> getWorker(dynamic id) => _get(
    '/workers/${Uri.encodeComponent(id.toString())}',
  ).then((value) => Map<String, dynamic>.from(value as Map));

  static Future<bool> checkPhoneExists(String phone) async {
    final raw = phone.trim();
    final variants = phoneLookupVariants(raw);
    final compactVariants = variants
        .map((value) => value.replaceAll(RegExp(r'\D'), ''))
        .toSet();

    bool matches(dynamic stored) {
      final storedPhone = (stored ?? '').toString().trim();
      if (storedPhone.isEmpty || storedPhone == 'null') return false;
      final storedCompact = storedPhone.replaceAll(RegExp(r'\D'), '');

      if (storedPhone == raw || variants.contains(storedPhone)) return true;
      if (storedCompact.isNotEmpty && compactVariants.contains(storedCompact)) {
        return true;
      }
      if (normalizePhone(storedPhone) == normalizePhone(raw)) return true;
      return false;
    }

    // 1. Check in workers list
    try {
      final res = await http.get(Uri.parse('$baseUrl/workers'));
      if (res.statusCode == 200) {
        final List<dynamic> workers = jsonDecode(res.body);
        for (var w in workers) {
          if (matches(w['phone'])) return true;
        }
      }
    } catch (_) {}

    // 2. Check in admins / staff list
    try {
      final resAdmin = await http.get(Uri.parse('$baseUrl/admins'));
      if (resAdmin.statusCode == 200) {
        final List<dynamic> admins = jsonDecode(resAdmin.body);
        for (var a in admins) {
          if (matches(a['phone']) ||
              matches(a['contact']) ||
              matches(a['mobile'])) {
            return true;
          }
        }
      }
    } catch (_) {}

    return false;
  }
}
