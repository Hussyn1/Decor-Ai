import 'package:decor_ar_fyp/controllers/notification_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../screens/ar_view_screen.dart';
import '../services/firestore_project_service.dart';

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('[FCM] Permission: ${settings.authorizationStatus}');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('[FCM] Foreground message: ${message.notification?.title}');
      final title = message.notification?.title ?? '3D Model Ready!';
      final body =
          message.notification?.body ?? 'Your model is ready to place in AR.';
      final glbUrl = message.data['glb_url'];
      Get.find<NotificationController>().addNotification(
    title: title,
    body: body,
    glbUrl: glbUrl,
  );

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
                child: const Text(
                  'Open AR',
                  style: TextStyle(color: Color(0xFF4A90E2)),
                ),
              )
            : null,
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('[FCM] Notification tapped (background): ${message.data}');
      _openArScreen(message.data);
    });

    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      print('[FCM] App launched from notification: ${initialMessage.data}');

      await Future.delayed(const Duration(milliseconds: 1500));
      _openArScreen(initialMessage.data);
    }

    final token = await _fcm.getToken();
    print('[FCM] Device token: $token');

    _fcm.onTokenRefresh.listen((newToken) {
      print('[FCM] Token refreshed: $newToken');
    });
  }

  Future<String?> getToken() => _fcm.getToken();

  void _openArScreen(Map<String, dynamic> data) {
    final glbUrl = data['glb_url'] as String?;
    final action = data['action'] as String?;

    if (glbUrl == null || action != 'OPEN_AR') return;

    final tempProject = Project(
      id: 'fcm_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Generated Model',
      roomType: 'Living Room',
      style: 'Modern',
      lastModified: DateTime.now(),
      items: [],
    );

    Get.to(
      () => ArViewScreen(project: tempProject, initialModelUrl: glbUrl),
      transition: Transition.fadeIn,
      duration: const Duration(milliseconds: 400),
    );
  }
}
