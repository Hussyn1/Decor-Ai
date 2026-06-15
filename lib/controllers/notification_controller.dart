import 'package:get/get.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String? glbUrl;
  final DateTime time;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.glbUrl,
    required this.time,
    this.isRead = false,
  });
}

class NotificationController extends GetxController {
  final notifications = <AppNotification>[].obs;

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  void addNotification({
    required String title,
    required String body,
    String? glbUrl,
  }) {
    notifications.insert(
      0,
      AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        body: body,
        glbUrl: glbUrl,
        time: DateTime.now(),
      ),
    );
  }

  void markAllRead() {
    for (final n in notifications) {
      n.isRead = true;
    }
    notifications.refresh();
  }

  void markRead(String id) {
    final n = notifications.firstWhereOrNull((n) => n.id == id);
    if (n != null) {
      n.isRead = true;
      notifications.refresh();
    }
  }

  void clear() => notifications.clear();
}