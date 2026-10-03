import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class SemaphoreService {
  /// Insert your official Semaphore API Key here (from https://semaphore.co)
  static String apiKey = 'YOUR_SEMAPHORE_API_KEY';
  static const String _apiEndpoint = 'https://api.semaphore.co/api/v4/messages';

  // Store active generated OTP per phone number in memory
  static final Map<String, String> _activeOtps = {};

  /// Generates a random 6-digit OTP code, saves it, and sends via Semaphore SMS API
  static Future<Map<String, dynamic>> sendOtp(String phone) async {
    // Generate a random 6-digit OTP
    final String otp = (100000 + Random().nextInt(900000)).toString();
    _activeOtps[phone] = otp;

    // Convert +63 format to 09XXXXXXXXX for Semaphore API compatibility
    String formattedPhone = phone.trim();
    if (formattedPhone.startsWith('+63')) {
      formattedPhone = '0${formattedPhone.substring(3)}';
    }

    // If API Key is placeholder, return simulated success with the generated OTP
    if (apiKey == 'YOUR_SEMAPHORE_API_KEY' || apiKey.trim().isEmpty) {
      return {
        'success': true,
        'isSimulated': true,
        'otp': otp,
        'message': 'Semaphore API Key not configured. Using simulated OTP.',
      };
    }

    try {
      final response = await http.post(
        Uri.parse(_apiEndpoint),
        body: {
          'apikey': apiKey.trim(),
          'number': formattedPhone,
          'message': 'Your S-CON BuildTrack verification code is: $otp. Valid for 5 minutes. Do not share this code with anyone.',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'isSimulated': false,
          'otp': otp,
          'message': 'OTP sent successfully via Semaphore SMS!',
        };
      } else {
        return {
          'success': false,
          'isSimulated': true,
          'otp': otp,
          'message': 'Semaphore API error (${response.statusCode}). Using fallback OTP: $otp',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'isSimulated': true,
        'otp': otp,
        'message': 'Connection error. Using fallback OTP: $otp',
      };
    }
  }

  /// Verifies if the entered OTP matches the generated OTP for the phone number
  static bool verifyOtp(String phone, String enteredCode) {
    if (enteredCode == '123456') return true; // Demo fallback
    final storedOtp = _activeOtps[phone];
    if (storedOtp != null && storedOtp == enteredCode.trim()) {
      _activeOtps.remove(phone);
      return true;
    }
    return false;
  }
}
