import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/auth/login_screen.dart'; // For logout redirection
import 'dart:io';
import 'package:get/get_connect/http/src/multipart/multipart_file.dart'
    as get_multipart;

class AuthController extends GetxController {
  final isLoading = false.obs;
  final Rx<Map<String, dynamic>?> currentUser = Rx<Map<String, dynamic>?>(null);

  // Base URL for API calls - Ensure port 5000 is included
  static const String baseUrl = 'http://192.168.100.8:5000/api/auth';

  @override
  void onInit() {
    super.onInit();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userData = prefs.getString('user_data');
    final String? token = prefs.getString('auth_token');

    if (userData != null) {
      currentUser.value = jsonDecode(userData);
    }

    if (token != null) {
      // Fetch fresh profile data
      fetchUserProfile();
    }
  }

  // Generic GetConnect wrapper for simplicity, or just use http for now to minimize friction
  // Using GetConnect is cleaner but let's stick to the working logic first, just wrapped in GetX
  final GetConnect _connect = GetConnect();

  Future<void> fetchUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) return;

      final response = await _connect.get(
        '$baseUrl/me',
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = response.body;
        // Merge with existing token if needed, or just update user data
        // backend /me returns {id, username, email}
        // we might want to keep the token in the map if our app expects it,
        // but currentUser usually just needs user info.
        // Let's update the currentUser observable
        currentUser.value = data;

        // Update cached data (preserving token if it was in the old data,
        // but /me doesn't return token usually. We should handle this carefully
        // if _saveSession expects a token in the map for 'user_data' string.)
        // For now, let's just update the observable for UI.
      }
    } catch (e) {
      print("Error fetching profile: $e");
    }
  }

  Future<void> login(String email, String password) async {
    isLoading.value = true;
    try {
      final response = await _connect.post('$baseUrl/login', {
        'email': email,
        'password': password,
      });

      isLoading.value = false;

      if (response.statusCode == 200) {
        final data = response.body;
        await _saveSession(data);
        Get.offAll(() => const HomeScreen());
        Get.snackbar(
          "Success",
          "Welcome back!",
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        final message =
            (response.body is Map && response.body['message'] != null)
            ? response.body['message']
            : "Login failed (Status: ${response.statusCode})";
        Get.snackbar(
          "Error",
          message,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      isLoading.value = false;
      Get.snackbar(
        "Error",
        "Connection failed: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> signup(String username, String email, String password) async {
    isLoading.value = true;
    try {
      final response = await _connect.post('$baseUrl/signup', {
        'username': username,
        'email': email,
        'password': password,
      });

      isLoading.value = false;

      if (response.statusCode == 201) {
        final data = response.body;
        await _saveSession(data);
        Get.offAll(() => const HomeScreen());
        Get.snackbar(
          "Success",
          "Account created!",
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        final message =
            (response.body is Map && response.body['message'] != null)
            ? response.body['message']
            : "Signup failed (Status: ${response.statusCode})";
        Get.snackbar(
          "Error",
          message,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      isLoading.value = false;
      Get.snackbar(
        "Error",
        "Connection failed: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', data['token']);
    // user data is in data directly? Check controller logic.
    // data structure from backend: { _id, username, email, token }
    await prefs.setString('user_data', jsonEncode(data));
    currentUser.value = data;
  }

  Future<void> uploadProfilePicture(File imageFile) async {
    isLoading.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        Get.snackbar("Error", "You need to be logged in");
        isLoading.value = false;
        return;
      }

      final form = FormData({
        'profilePicture': get_multipart.MultipartFile(
          imageFile,
          filename: imageFile.path.split(Platform.pathSeparator).last,
        ),
      });

      final response = await _connect.post(
        '$baseUrl/upload-profile-picture',
        form,
        headers: {'Authorization': 'Bearer $token'},
      );

      isLoading.value = false;

      if (response.statusCode == 200) {
        // Update local user data with new profile picture URL
        final newUrl = response.body['profilePicture'];

        if (currentUser.value != null && newUrl != null) {
          final updatedUser = Map<String, dynamic>.from(currentUser.value!);
          updatedUser['profilePicture'] = newUrl;
          currentUser.value = updatedUser;

          await _saveSession(updatedUser);
        }

        Get.snackbar(
          "Success",
          "Profile picture updated!",
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          "Error",
          "Failed to upload image",
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      isLoading.value = false;
      Get.snackbar(
        "Error",
        "Upload failed: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
    currentUser.value = null;
    Get.offAll(() => const LoginScreen());
  }
}
