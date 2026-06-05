import 'package:flutter/material.dart';
import '../core/app_theme.dart';

import 'create_project_screen.dart';

import 'package:get/get.dart';
import '../controllers/project_controller.dart';
import '../services/project_service.dart'; // Import Project model only
import 'ar_view_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  // Use Get.put to make it available (or find if already put in Home/Binding)
  // For now, put here to be safe as lazy singleton
  final ProjectController _projectController = Get.find<ProjectController>();
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'My Projects',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.filter_list)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildCategorySelector(),
          ),
          Expanded(
            child: Obx(() {
              if (_projectController.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              if (_projectController.projects.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No projects yet",
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                );
              }

              // Filter logic (basic)
              var displayProjects = _projectController.projects;
              if (_selectedCategory != 'All') {
                displayProjects = _projectController.projects
                    .where((p) => p.roomType == _selectedCategory)
                    .toList()
                    .obs;
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: displayProjects.length,
                itemBuilder: (context, index) {
                  final project = displayProjects[index];
                  return _buildProjectCard(project);
                },
              );
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'projects_fab',
        onPressed: () async {
          await Get.to(
            () => const CreateProjectScreen(),
            transition: Transition.fadeIn,
            duration: const Duration(milliseconds: 500),
          );
          // ProjectController updates its list automatically if we called fetch/save there
          // But CreateProjectScreen navigates to ArViewScreen, which Saves.
          // When returning from ArViewScreen (Save), we might need to refresh if not using a global single stream.
          // The helper _projectController.fetchProjects() is called in onInit.
          // If we added a new project and saved it to disk, we should call fetchProjects again.
          _projectController.fetchProjects();
        },
        backgroundColor: AppTheme.primaryBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ['All', 'Living Room', 'Bedroom', 'Kitchen', 'Office'].map((
          label,
        ) {
          bool isSelected = _selectedCategory == label;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = label),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryBlue : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryBlue
                      : Colors.grey.shade200,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProjectCard(Project project) {
    // Determine status based on last modified (Just for UI demo)
    bool isRecent =
        DateTime.now().difference(project.lastModified).inHours < 24;
    String status = isRecent ? 'IN PROGRESS' : 'SAVED';

    return GestureDetector(
      onTap: () async {
        await Get.to(() => ArViewScreen(project: project));
        _projectController.fetchProjects(); // Refresh on return
      },
      onLongPress: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Project?'),
            content: Text(
              'Are you sure you want to delete "${project.name}"? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _projectController.deleteProject(project.id);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'project_ar_${project.id}',
              child: Container(
                height: 150,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey.shade800 
                    : Colors.grey.shade100,
                child: const Center(
                  child: Icon(Icons.view_in_ar, size: 48, color: Colors.black12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${project.roomType} • ${project.items.length} items',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isRecent
                          ? AppTheme.primaryBlue.withOpacity(0.1)
                          : AppTheme.successGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: isRecent
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
          ],
        ),
      ),
    );
  }
}
