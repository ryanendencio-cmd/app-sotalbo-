import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static String get baseUrl {
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:5000/api';
    return 'http://localhost:5000/api';
  }

  // Global state for current user's role (admin, staff, tool, worker)
  static String? currentUserRole;
  static Map<String, dynamic>? currentUser;
  static String? _authToken;

  static String? get authToken => _authToken;
  static void setToken(String? token) => _authToken = token;
  static void clearToken() => _authToken = null;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

  static Future<dynamic> _get(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: _headers);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load $path (${res.statusCode})');
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode == 200 || res.statusCode == 201) return jsonDecode(res.body);
    throw Exception('Failed to post $path (${res.statusCode})');
  }

  static Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to put $path (${res.statusCode})');
  }

  static Future<void> _delete(String path) async {
    final res = await http.delete(Uri.parse('$baseUrl$path'), headers: _headers);
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Failed to delete $path (${res.statusCode})');
    }
  }

  // Projects
  static Future<List<dynamic>> getProjects() => _get('/projects').then((v) => v as List);
  static Future<dynamic> createProject(Map<String, dynamic> data) => _post('/projects', data);
  static Future<dynamic> updateProject(dynamic id, Map<String, dynamic> data) => _put('/projects/$id', data);
  static Future<void> deleteProject(dynamic id) => _delete('/projects/$id');

  // Schedules
  static Future<List<dynamic>> getSchedules() => _get('/schedules').then((v) => v as List);
  static Future<dynamic> createSchedule(Map<String, dynamic> data) => _post('/schedules', data);
  static Future<dynamic> updateSchedule(dynamic id, Map<String, dynamic> data) => _put('/schedules/$id', data);
  static Future<void> deleteSchedule(dynamic id) => _delete('/schedules/$id');

  // Workers
  static Future<List<dynamic>> getWorkers() => _get('/workers').then((v) => v as List);
  static Future<dynamic> createWorker(Map<String, dynamic> data) => _post('/workers', data);
  static Future<dynamic> updateWorker(dynamic id, Map<String, dynamic> data) => _put('/workers/$id', data);
  static Future<void> deleteWorker(dynamic id) => _delete('/workers/$id');

  // Budget Additions
  static Future<List<dynamic>> getBudgetAdditions(dynamic projectId) =>
      _get('/projects/$projectId/budget-additions').then((v) => v as List);
  static Future<dynamic> createBudgetAddition(dynamic projectId, Map<String, dynamic> data) =>
      _post('/projects/$projectId/budget-additions', data);

  // Project-scoped endpoints
  static Future<List<dynamic>> getAttendance(dynamic projectId) =>
      _get('/attendance/$projectId').then((v) => v as List);
  static Future<dynamic> saveAttendance(Map<String, dynamic> data) =>
      _post('/attendance', data);
  static Future<dynamic> updateAttendanceRecord(dynamic id, Map<String, dynamic> data) =>
      _put('/attendance/$id', data);

  static Future<List<dynamic>> getExpenses(dynamic projectId) =>
      _get('/expenses/$projectId').then((v) => v as List);
  static Future<List<dynamic>> getAllExpenses() =>
      _get('/expenses').then((v) => v as List);
  static Future<Map<String, dynamic>> getExpensesSummary() =>
      _get('/expenses/summary').then((v) => Map<String, dynamic>.from(v as Map));
  static Future<Map<String, dynamic>> getBudgetSummary() =>
      _get('/expenses/budget-summary').then((v) => Map<String, dynamic>.from(v as Map));
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
  static Future<void> deleteExpense(dynamic id) =>
      _delete('/expenses/$id');

  static Future<List<dynamic>> getMaterials(dynamic projectId) =>
      _get('/materials/$projectId').then((v) => v as List);
  static Future<dynamic> createMaterial(Map<String, dynamic> data) =>
      _post('/materials', data);
  static Future<dynamic> updateMaterial(dynamic id, Map<String, dynamic> data) =>
      _put('/materials/$id', data);
  static Future<void> deleteMaterial(dynamic id) =>
      _delete('/materials/$id');

  static Future<List<dynamic>> getAssets(dynamic projectId) =>
      _get('/assets/$projectId').then((v) => v as List);
  static Future<dynamic> createAsset(Map<String, dynamic> data) =>
      _post('/assets', data);
  static Future<dynamic> updateAsset(dynamic id, Map<String, dynamic> data) =>
      _put('/assets/$id', data);
  static Future<void> deleteAsset(dynamic id) =>
      _delete('/assets/$id');

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
  static Future<dynamic> updateAssetDoc(dynamic id, Map<String, dynamic> data) =>
      _put('/assets/$id', data);
  static Future<List<dynamic>> getProjectBorrowHistory(dynamic projectId) =>
      _get('/borrow-history/$projectId').then((v) => v as List);
  static Future<dynamic> logBorrowHistory(Map<String, dynamic> data) =>
      _post('/borrow-history', data);

  // Reports
  static Future<List<dynamic>> getExpensesReport({dynamic projectId, String? startDate, String? endDate}) {
    String query = '';
    final params = <String>[];
    if (projectId != null) params.add('project_id=$projectId');
    if (startDate != null) params.add('startDate=$startDate');
    if (endDate != null) params.add('endDate=$endDate');
    if (params.isNotEmpty) query = '?${params.join('&')}';
    return _get('/reports/expenses$query').then((v) => v as List);
  }

  static Future<List<dynamic>> getManpowerReport({dynamic projectId, String? startDate, String? endDate}) {
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
  static Future<void> approveCashAdvance(dynamic id, String status) =>
      _put('/cash-advances/$id/approve', {'status': status});
  static Future<List<dynamic>> getWorkerCashAdvances(dynamic workerId) =>
      _get('/workers/$workerId/cash-advances').then((v) => v as List);

  // Notifications
  static Future<List<dynamic>> getNotifications() =>
      _get('/notifications').then((v) => v as List);
  static Future<void> markNotificationRead(int id) =>
      _put('/notifications/$id/read', {});

  // Auth
  static Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    final result = await _post('/register', data);
    return result as Map<String, dynamic>;
  }

  static String normalizePhone(String input) {
    final trimmed = input.trim();
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      final last10 = digits.substring(digits.length - 10);
      return '+63$last10';
    }
    return trimmed;
  }

  static Future<Map<String, dynamic>> login(String usernameOrPhone, String password) async {
    final raw = usernameOrPhone.trim();
    final normalized = normalizePhone(raw);

    // List of identifiers to try (normalized +639... first if phone number, then raw)
    final identifiersToTry = <String>[];

    // Attempt to lookup real username if the input is a phone number
    try {
      final workersRes = await http.get(Uri.parse('$baseUrl/workers'));
      if (workersRes.statusCode == 200) {
        final List<dynamic> workers = jsonDecode(workersRes.body);
        for (var w in workers) {
          final wPhone = (w['phone'] ?? '').toString();
          if (wPhone == raw || wPhone == normalized || wPhone == '+63$raw') {
            final wUsername = (w['username'] ?? w['user_name'] ?? '').toString();
            if (wUsername.isNotEmpty) {
              identifiersToTry.add(wUsername);
            }
          }
        }
      }
    } catch (_) {
      // ignore
    }

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

    for (final id in identifiersToTry) {
      final res = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': id, 'password': password}),
      );
      lastWorkerRes = res;

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        
        // Extract status if available
        String? status;
        if (body['status'] != null) {
          status = body['status'].toString();
        } else if (body['worker'] != null && body['worker']['status'] != null) {
          status = body['worker']['status'].toString();
        } else if (body['user'] != null && body['user']['status'] != null) {
          status = body['user']['status'].toString();
        }

        if (status != null) {
          if (status.toLowerCase() == 'pending' || status.toLowerCase().contains('pending')) {
            throw Exception('pending_approval');
          }
          if (status.toLowerCase() == 'rejected' || status.toLowerCase().contains('reject')) {
            throw Exception('Account was rejected');
          }
        }

        return body;
      }

      if (res.statusCode == 403) {
        final body = jsonDecode(res.body);
        if (body['error'] == 'pending_approval') throw Exception('pending_approval');
        if (body['error'] == 'rejected') throw Exception('Account was rejected');
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
    }

    // Try admin login
    try {
      final adminRes = await http.post(
        Uri.parse('$baseUrl/admin/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': raw, 'password': password}),
      );

      if (adminRes.statusCode == 200) {
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
    } catch (_) {
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
  static Future<Map<String, dynamic>> loginWithPhone(String phone, String password) =>
      login(phone, password);

  // Pending Registrations (Admin)
  static Future<List<dynamic>> getPendingRegistrations() =>
      _get('/pending-registrations').then((v) => v as List);

  static Future<void> approveWorker(dynamic id, String status) =>
      _put('/workers/$id/approve', {'status': status});

  static Future<Map<String, dynamic>> getWorker(dynamic id) =>
      _get('/workers').then((v) {
        if (v is List) {
          final worker = v.firstWhere((w) => w['id']?.toString() == id?.toString(), orElse: () => null);
          if (worker != null) {
            return worker as Map<String, dynamic>;
          }
        }
        throw Exception('Worker not found');
      });

  static Future<bool> checkPhoneExists(String phone) async {
    final raw = phone.trim();
    final normalized = normalizePhone(raw);
    try {
      final res = await http.get(Uri.parse('$baseUrl/workers'));
      if (res.statusCode == 200) {
        final List<dynamic> workers = jsonDecode(res.body);
        for (var w in workers) {
          final wPhone = (w['phone'] ?? '').toString();
          if (wPhone == raw || wPhone == normalized || wPhone == '+63$raw') {
            return true;
          }
        }
      }
    } catch (_) {}
    return false;
  }
}
