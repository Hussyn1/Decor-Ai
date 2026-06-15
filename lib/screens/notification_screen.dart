import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/notification_controller.dart';
import '../core/app_theme.dart';
import 'ar_view_screen.dart';
import '../services/firestore_project_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<NotificationController>();

    // Mark all read when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.markAllRead();
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Get.back(),
        ),
        actions: [
          TextButton(
            onPressed: () => controller.clear(),
            child: const Text('Clear all'),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none_outlined,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No notifications yet',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: controller.notifications.length,
          itemBuilder: (context, index) {
            final notif = controller.notifications[index];
            return _buildNotificationCard(context, notif, controller);
          },
        );
      }),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    AppNotification notif,
    NotificationController controller,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: notif.isRead
            ? Theme.of(context).cardColor
            : AppTheme.primaryBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: notif.isRead
              ? Colors.grey.shade100
              : AppTheme.primaryBlue.withOpacity(0.2),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.view_in_ar,
            color: AppTheme.primaryBlue,
          ),
        ),
        title: Text(
          notif.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notif.body, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Text(
              _formatTime(notif.time),
              style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
            ),
          ],
        ),
        trailing: notif.glbUrl != null
            ? ElevatedButton(
                onPressed: () {
                  controller.markRead(notif.id);
                  Get.back();
                  final tempProject = Project(
                    id: 'fcm_${DateTime.now().millisecondsSinceEpoch}',
                    name: 'Generated Model',
                    roomType: 'Living Room',
                    style: 'Modern',
                    lastModified: DateTime.now(),
                    items: [],
                  );
                  Get.to(() => ArViewScreen(
                    project: tempProject,
                    initialModelUrl: notif.glbUrl,
                  ));
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Open AR', style: TextStyle(fontSize: 12)),
              )
            : null,
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${time.day}/${time.month}/${time.year}';
  }
}