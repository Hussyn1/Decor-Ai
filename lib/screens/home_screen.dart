import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../core/app_theme.dart';
import 'ar_measure_screen.dart';
import 'ar_view_screen.dart';
import '2d_3d_builder.dart';
import 'projects_screen.dart';
import 'discover_screen.dart';
import '../controllers/project_controller.dart';
import '../services/project_service.dart';
import 'settings_screen.dart';

import 'ai_stylist_screen.dart';

import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import '../controllers/auth_controller.dart';

import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController controller = Get.put(HomeController());

    final List<Widget> screens = [
      const HomeDashboard(),
      const ProjectsScreen(),
      const SizedBox.shrink(), // AR is launched via navigation, not inline
       DiscoverScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Obx(
        () => screens[controller.selectedIndex.value],
      ),
      bottomNavigationBar: _buildBottomNav(context, controller),
    );
  }

  Widget _buildBottomNav(BuildContext context, HomeController controller) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(controller, 0, 'Home', Icons.home_filled),
              _buildNavItem(controller, 1, 'Projects', Icons.grid_view_rounded),
              const SizedBox(width: 60), // Space for fab
              _buildNavItem(controller, 3, 'Discover', Icons.explore),
              _buildNavItem(controller, 4, 'Settings', Icons.settings),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Transform.translate(
              offset: const Offset(0, -25),
              child: FloatingActionButton(
                heroTag: 'home_fab',
                onPressed: () {
                  Get.to(() => const ArViewScreen());
                },
                backgroundColor: AppTheme.primaryBlue,
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(FontAwesomeIcons.cube, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    HomeController controller,
    int index,
    String label,
    IconData icon,
  ) {
    return Obx(() {
      bool isSelected = controller.selectedIndex.value == index;
      return GestureDetector(
        onTap: () => controller.changeTabIndex(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryBlue : Colors.grey,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryBlue : Colors.grey,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final ProjectController _projectController = Get.put(ProjectController());

  /// Formats a DateTime as a human-readable relative string.
  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildHeader(),
            const SizedBox(height: 24),
            _buildAiStylistBanner(),

            const SizedBox(height: 32),
            _buildQuickTools(),
            const SizedBox(height: 32),
            _buildRecentProjectsHeader(),
            const SizedBox(height: 16),
            _buildRecentProjectsList(),
            const SizedBox(height: 100), // Space for bottom nav
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final authController = Get.find<AuthController>();

    return Row(
      children: [
        Obx(() {
          final user = authController.currentUser.value;
          final profilePic = user?['profilePicture'];
          bool hasImage = profilePic != null && profilePic.isNotEmpty;

          return Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.grey.shade800 
                  : Colors.grey.shade300,
            ),
            child: hasImage
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: profilePic,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  )
                : const Icon(Icons.person, color: Colors.white, size: 30),
          );
        }),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Good morning', style: Theme.of(context).textTheme.bodySmall),
            Obx(
              () => Text(
                authController.currentUser.value?['username'] ?? 'User',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const Spacer(),
        RepaintBoundary(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.notifications_none_outlined, size: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildAiStylistBanner() {
    return GestureDetector(
      onTap: () => Get.to(
        () => const AiStylistScreen(),
        transition: Transition.fadeIn,
        duration: const Duration(milliseconds: 500),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryBlue.withOpacity(0.9),
              AppTheme.primaryBlue,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryBlue.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(Icons.auto_awesome, color: Colors.white),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Style Assistant',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Get personalized room ideas',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTools() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Tools', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Get.to(() => const ArMeasureScreen()),
                child: _buildToolCard(
                  'AR Measure',
                  'Real-time dimensions',
                  Icons.straighten,
                  const Color(0xFFE3F2FD),
                  AppTheme.primaryBlue,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () => Get.to(
                  () => const TwoDToThreeDBuilder(),
                  transition: Transition.fadeIn,
                  duration: const Duration(milliseconds: 500),
                ),
                child: _buildToolCard(
                  '2D to 3D',
                  'Convert sketches',
                  Icons.view_in_ar_outlined,
                  const Color(0xFFF3E5F5),
                  Colors.purple,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToolCard(
    String title,
    String subtitle,
    IconData icon,
    Color bg,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentProjectsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Recent Projects', style: Theme.of(context).textTheme.titleMedium),
        TextButton(
          onPressed: () {
            // Navigate to Projects tab (index 1)
            final homeController = Get.find<HomeController>();
            homeController.changeTabIndex(1);
          },
          child: const Text('See All'),
        ),
      ],
    );
  }

  Widget _buildRecentProjectsList() {
    return Obx(() {
      if (_projectController.isLoading.value) {
        // Loading skeleton
        return Column(
          children: List.generate(3, (index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          )),
        );
      }

      if (_projectController.projects.isEmpty) {
        // Empty state
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.view_in_ar, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'No projects yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap the AR button to start designing!',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // Show up to 3 most recent projects
      final recentProjects = _projectController.projects.take(3).toList();
      return Column(
        children: recentProjects.map((project) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildProjectItem(project),
          );
        }).toList(),
      );
    });
  }

  Widget _buildProjectItem(Project project) {
    final String status = project.items.isEmpty ? 'NEW' : 'IN PROGRESS';
    final bool isInProgress = status == 'IN PROGRESS';
    final bool hasThumbnail = project.thumbnailPath != null && project.thumbnailPath!.isNotEmpty;

    return GestureDetector(
      onTap: () {
        Get.to(() => ArViewScreen(project: project));
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: hasThumbnail
                  ? CachedNetworkImage(
                      imageUrl: project.thumbnailPath!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.shade100,
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.view_in_ar,
                        color: AppTheme.primaryBlue,
                        size: 36,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    project.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    'Last edited ${_formatRelativeTime(project.lastModified)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isInProgress
                          ? AppTheme.primaryBlue.withOpacity(0.1)
                          : AppTheme.successGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: isInProgress
                            ? AppTheme.primaryBlue
                            : AppTheme.successGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                Get.to(() => ArViewScreen(project: project));
              },
              icon: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}
