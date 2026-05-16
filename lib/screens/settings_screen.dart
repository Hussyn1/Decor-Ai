import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../widgets/settings_tile.dart';
import '../widgets/settings_group.dart';
import 'edit_profile_screen.dart';
import 'ar_settings_screen.dart';
import 'gen_settings_screen.dart';
import 'info_screens.dart';
import '../controllers/settings_controller.dart';
import '../controllers/project_controller.dart';
import '../controllers/catalog_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController _authController = Get.find<AuthController>();
    final SettingsController _settingsController = Get.find<SettingsController>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Obx(() {
              final user = _authController.currentUser.value;
              return Column(
                children: [
                  _buildProfileCard(context, user),
                  const SizedBox(height: 16),
                  _buildUserStats(context),
                ],
              );
            }),
            const SizedBox(height: 32),

            SettingsGroup(
              title: 'Account',
              children: [
                SettingsTile(
                  icon: Icons.person_outline,
                  title: 'Personal Information',
                  subtitle: 'Name, Email, Bio',
                  onTap: () => Get.to(
                    () => const EditProfileScreen(),
                    transition: Transition.fadeIn,
                    duration: const Duration(milliseconds: 500),
                  ),
                ),
                SettingsTile(
                  icon: Icons.notifications_none,
                  title: 'Notifications',
                  onTap: () {},
                ),
                SettingsTile(
                  icon: Icons.lock_outline,
                  title: 'Privacy & Security',
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 24),
            SettingsGroup(
              title: 'Application',
              children: [
                SettingsTile(
                  icon: Icons.view_in_ar,
                  title: 'AR Core Settings',
                  subtitle: 'Plane detection, lighting, etc.',
                  onTap: () => Get.to(
                    () => const ArSettingsScreen(),
                    transition: Transition.fadeIn,
                    duration: const Duration(milliseconds: 500),
                  ),
                ),
                SettingsTile(
                  icon: Icons.threed_rotation,
                  title: '2D to 3D Settings',
                  subtitle: 'Resolution, quality, auto-scale',
                  onTap: () => Get.to(
                    () => const GenSettingsScreen(),
                    transition: Transition.fadeIn,
                    duration: const Duration(milliseconds: 500),
                  ),
                ),
                Obx(() => _buildThemeToggle(_settingsController)),
                SettingsTile(
                  icon: Icons.language_outlined,
                  title: 'Language',
                  subtitle: 'English (US)',
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 24),
            SettingsGroup(
              title: 'Support',
              children: [
                SettingsTile(
                  icon: Icons.help_outline,
                  title: 'Help Center',
                  onTap: () => Get.to(
                    () => const HelpCenterScreen(),
                    transition: Transition.fadeIn,
                    duration: const Duration(milliseconds: 500),
                  ),
                ),
                SettingsTile(
                  icon: Icons.info_outline,
                  title: 'About Decor AI',
                  onTap: () => Get.to(
                    () => const AboutScreen(),
                    transition: Transition.fadeIn,
                    duration: const Duration(milliseconds: 500),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SettingsTile(
                icon: Icons.logout_rounded,
                title: 'Log Out',
                isDestructive: true,
                onTap: () => _handleLogout(context),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildUserStats(BuildContext context) {
    // We try to find controllers, if they are not initialized yet, we show placeholders
    int projectCount = 0;
    int furnitureCount = 0;

    try {
      projectCount = Get.find<ProjectController>().projects.length;
    } catch (_) {}

    try {
      furnitureCount = Get.find<CatalogController>().furnitureItems.length;
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildStatItem(context, 'Projects', projectCount.toString(), Icons.folder_open),
          const SizedBox(width: 12),
          _buildStatItem(context, 'Assets', furnitureCount.toString(), Icons.chair_outlined),
          const SizedBox(width: 12),
          _buildStatItem(context, 'AR Views', '24', Icons.visibility_outlined),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.white10 
                : Colors.grey.shade100,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryBlue, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, Map<String, dynamic>? user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.grey.shade800 
                  : Colors.grey.shade300,
            ),
            child:
                (user?['profilePicture'] != null &&
                    user!['profilePicture'].isNotEmpty)
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: user['profilePicture'],
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.person,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  )
                : const Icon(Icons.person, size: 40, color: Colors.white),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?['username'] ?? 'User',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?['email'] ?? 'Not Logged In',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'PRO MEMBER',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Get.to(
              () => const EditProfileScreen(),
              transition: Transition.fadeIn,
              duration: const Duration(milliseconds: 500),
            ),
            icon: const Icon(Icons.edit_outlined, color: Colors.grey, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeToggle(SettingsController controller) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          controller.isDarkMode.value ? Icons.dark_mode : Icons.light_mode,
          color: Colors.orange,
          size: 22,
        ),
      ),
      title: const Text(
        'Dark Mode',
        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
      ),
      trailing: Switch(
        value: controller.isDarkMode.value,
        onChanged: (val) => controller.toggleDarkMode(val),
        activeColor: AppTheme.primaryBlue,
      ),
    );
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of Decor AI?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Get.find<AuthController>().logout();
            },
            child: const Text(
              'Log Out',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
