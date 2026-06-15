import 'package:decor_ar_fyp/controllers/project_controller_firestore.dart';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';

import 'create_project_screen.dart';

import 'package:get/get.dart';
import '../services/firestore_project_service.dart';
import 'ar_view_screen.dart';
import 'three_floor_plan_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
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
                color: isSelected
                    ? AppTheme.primaryBlue
                    : Theme.of(context).cardColor,
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
    bool isRecent =
        DateTime.now().difference(project.lastModified).inHours < 24;
    String status = isRecent ? 'IN PROGRESS' : 'SAVED';

    return GestureDetector(
      onTap: () async {
        if (project.layoutData != null && project.layoutData!.isNotEmpty) {
          await Get.bottomSheet(
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    project.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Get.back();
                      Get.to(() => ThreeFloorPlanScreen(project: project));
                    },
                    icon: const Icon(Icons.edit_note),
                    label: const Text(
                      'Open in 3D Editor',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Get.back();
                      Get.to(() => ArViewScreen(project: project));
                    },
                    icon: const Icon(
                      Icons.view_in_ar,
                      color: Colors.cyanAccent,
                    ),
                    label: const Text('Preview in AR'),
                  ),
                ],
              ),
            ),
          );
        } else {
          await Get.to(() => ArViewScreen(project: project));
        }
        _projectController.fetchProjects();
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
                child:
                    project.thumbnailPath != null &&
                        project.thumbnailPath!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: project.thumbnailPath!,
                        width: double.infinity,
                        height: 150,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(
                            Icons.view_in_ar,
                            size: 48,
                            color: Colors.black12,
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.view_in_ar,
                          size: 48,
                          color: Colors.black12,
                        ),
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
