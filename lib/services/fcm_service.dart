import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../screens/ar_view_screen.dart';
import '../services/firestore_project_service.dart';
/// Handles Firebase Cloud Messaging initialization, token retrieval,
/// and routing to AR screen when the user taps a "model ready" notification.
class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  /// Call once at app startup after Firebase.initializeApp()
  Future<void> init() async {
    // Request permission (required on Android 13+, always on iOS)
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('[FCM] Permission: ${settings.authorizationStatus}');

    // Foreground messages — show a snackbar
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('[FCM] Foreground message: ${message.notification?.title}');
      final title = message.notification?.title ?? '3D Model Ready!';
      final body = message.notification?.body ?? 'Your model is ready to place in AR.';
      final glbUrl = message.data['glb_url'];

      Get.snackbar(
        title,
        body,
        duration: const Duration(seconds: 6),
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF1E1E2E),
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
        mainButton: glbUrl != null
            ? TextButton(
                onPressed: () => _openArScreen(message.data),
                child: const Text('Open AR', style: TextStyle(color: Color(0xFF4A90E2))),
              )
            : null,
      );
    });

    // Background/terminated → user tapped notification → open AR
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('[FCM] Notification tapped (background): ${message.data}');
      _openArScreen(message.data);
    });

    // App was fully terminated when notification arrived
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      print('[FCM] App launched from notification: ${initialMessage.data}');
      // Slight delay so the app finishes initializing before navigating
      await Future.delayed(const Duration(milliseconds: 1500));
      _openArScreen(initialMessage.data);
    }

    // Log token for debugging
    final token = await _fcm.getToken();
    print('[FCM] Device token: $token');

    // Handle token refresh
    _fcm.onTokenRefresh.listen((newToken) {
      print('[FCM] Token refreshed: $newToken');
    });
  }

  /// Returns the FCM token to be sent with /generate-3d requests
  Future<String?> getToken() => _fcm.getToken();

  /// Navigates to AR screen and pre-loads the generated model
  void _openArScreen(Map<String, dynamic> data) {
    final glbUrl = data['glb_url'] as String?;
    final action = data['action'] as String?;

    if (glbUrl == null || action != 'OPEN_AR') return;

    // Create a temporary quick-session project for the generated model
    final tempProject = Project(
      id: 'fcm_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Generated Model',
      roomType: 'Living Room',
      style: 'Modern',
      lastModified: DateTime.now(),
      items: [],
    );

    Get.to(
      () => ArViewScreen(
        project: tempProject,
        initialModelUrl: glbUrl,
      ),
      transition: Transition.fadeIn,
      duration: const Duration(milliseconds: 400),
    );
  }
}
