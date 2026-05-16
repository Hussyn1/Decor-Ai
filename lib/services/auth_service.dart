import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_error_handler.dart';
import '../core/api_config.dart';

class AuthService {
  static String get baseUrl => ApiConfig.authEndpoint;

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveToken(data['token']);
        await _saveUser(data);
        return {'success': true, 'data': data};
      } else {
        final error = ApiErrorHandler.handleStatusCode(
          response.statusCode,
          response.body,
        );
        return {'success': false, 'message': error.message};
      }
    } catch (e) {
      final error = ApiErrorHandler.handleException(e);
      return {'success': false, 'message': error.message};
    }
  }

  Future<Map<String, dynamic>> signup(
    String username,
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        await _saveToken(data['token']);
        await _saveUser(data);
        return {'success': true, 'data': data};
      } else {
        final error = ApiErrorHandler.handleStatusCode(
          response.statusCode,
          response.body,
        );
        return {'success': false, 'message': error.message};
      }
    } catch (e) {
      final error = ApiErrorHandler.handleException(e);
      return {'success': false, 'message': error.message};
    }
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> _saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(user));
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
  }
}
