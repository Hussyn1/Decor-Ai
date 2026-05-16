import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../screens/home_screen.dart';
import '../screens/auth/login_screen.dart'; // For logout redirection
import 'dart:io';
import 'package:get/get_connect/http/src/multipart/multipart_file.dart'
    as get_multipart;
import '../core/api_error_handler.dart';
import '../core/api_config.dart';

class AuthController extends GetxController {
  final isLoading = false.obs;
  final Rx<Map<String, dynamic>?> currentUser = Rx<Map<String, dynamic>?>(null);

  // Base URL for API calls
  static String get baseUrl => ApiConfig.authEndpoint;

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
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = response.body;
        currentUser.value = data;
      } else if (response.statusCode == 401) {
        // Token expired — force re-login
        await logout();
      } else if (response.statusCode != null) {
        final error = ApiErrorHandler.handleStatusCode(
          response.statusCode!,
          response.body,
        );
        print("Profile fetch error: $error");
      }
    } catch (e) {
      // Silent fail for background profile refresh — don't annoy user
      print("Error fetching profile: $e");
    }
  }

  Future<void> login(String email, String password) async {
    // Input validation
    if (email.trim().isEmpty || password.trim().isEmpty) {
      ApiErrorHandler.showError(const AppError(
        title: 'Missing Fields',
        message: 'Please enter both email and password.',
        type: AppErrorType.validation,
      ));
      return;
    }

    isLoading.value = true;
    try {
      final response = await _connect.post('$baseUrl/login', {
        'email': email.trim(),
        'password': password,
      }).timeout(const Duration(seconds: 20));

      isLoading.value = false;

      if (response.statusCode == 200) {
        final data = response.body;
        await _saveSession(data);
        Get.offAll(() => const HomeScreen());
        ApiErrorHandler.showSuccess("Success", "Welcome back!");
      } else {
        final error = ApiErrorHandler.handleStatusCode(
          response.statusCode ?? 500,
          response.body,
        );
        ApiErrorHandler.showError(error);
      }
    } catch (e) {
      isLoading.value = false;
      final error = ApiErrorHandler.handleException(e);
      ApiErrorHandler.showError(error);
    }
  }

  Future<void> signup(String username, String email, String password) async {
    // Input validation
    if (username.trim().isEmpty || email.trim().isEmpty || password.trim().isEmpty) {
      ApiErrorHandler.showError(const AppError(
        title: 'Missing Fields',
        message: 'Please fill in all fields to create an account.',
        type: AppErrorType.validation,
      ));
      return;
    }

    if (password.length < 6) {
      ApiErrorHandler.showError(const AppError(
        title: 'Weak Password',
        message: 'Password must be at least 6 characters long.',
        type: AppErrorType.validation,
      ));
      return;
    }

    isLoading.value = true;
    try {
      final response = await _connect.post('$baseUrl/signup', {
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
      }).timeout(const Duration(seconds: 20));

      isLoading.value = false;

      if (response.statusCode == 201) {
        final data = response.body;
        await _saveSession(data);
        Get.offAll(() => const HomeScreen());
        ApiErrorHandler.showSuccess("Success", "Account created!");
      } else {
        final error = ApiErrorHandler.handleStatusCode(
          response.statusCode ?? 500,
          response.body,
        );
        ApiErrorHandler.showError(error);
      }
    } catch (e) {
      isLoading.value = false;
      final error = ApiErrorHandler.handleException(e);
      ApiErrorHandler.showError(error);
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
        ApiErrorHandler.showError(const AppError(
          title: 'Not Logged In',
          message: 'You need to be logged in to upload a profile picture.',
          type: AppErrorType.auth,
        ));
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
      ).timeout(const Duration(seconds: 30));

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

        ApiErrorHandler.showSuccess("Success", "Profile picture updated!");
      } else {
        final error = ApiErrorHandler.handleStatusCode(
          response.statusCode ?? 500,
          response.body,
        );
        ApiErrorHandler.showError(error);
      }
    } catch (e) {
      isLoading.value = false;
      final error = ApiErrorHandler.handleException(e);
      ApiErrorHandler.showError(error);
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
