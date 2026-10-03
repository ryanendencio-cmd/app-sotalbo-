import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_service.dart';

class AdminService {
  static String get apiUrl => ApiService.baseUrl;

  static Map<String, String> get _headers {
    final token = ApiService.authToken;
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // Save admin profile to database
  static Future<Map<String, dynamic>> saveAdminProfile({
    required int adminId,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String assignedProjectSite,
    required String terminalId,
    required bool pushNotificationsEnabled,
    required bool biometricLoginEnabled,
    required String status,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/admin/profile/save'),
        headers: _headers,
        body: jsonEncode({
          'adminId': adminId,
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'phone': phone,
          'assignedProjectSite': assignedProjectSite,
          'terminalId': terminalId,
          'pushNotificationsEnabled': pushNotificationsEnabled,
          'biometricLoginEnabled': biometricLoginEnabled,
          'status': status,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'error': jsonDecode(response.body)['error'] ?? 'Failed to save profile'
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get admin profile from database
  static Future<Map<String, dynamic>> getAdminProfile(int adminId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/admin/profile/$adminId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'error': jsonDecode(response.body)['error'] ?? 'Failed to fetch profile'
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Update admin settings
  static Future<Map<String, dynamic>> updateAdminSettings({
    required int adminId,
    required bool pushNotificationsEnabled,
    required bool biometricLoginEnabled,
    required String assignedProjectSite,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$apiUrl/admin/$adminId/settings'),
        headers: _headers,
        body: jsonEncode({
          'pushNotificationsEnabled': pushNotificationsEnabled,
          'biometricLoginEnabled': biometricLoginEnabled,
          'assignedProjectSite': assignedProjectSite,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'error': jsonDecode(response.body)['error'] ?? 'Failed to update settings'
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Change admin password
  static Future<Map<String, dynamic>> changeAdminPassword({
    required int adminId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$apiUrl/admin/$adminId/password'),
        headers: _headers,
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'error': jsonDecode(response.body)['error'] ?? 'Failed to change password'
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
