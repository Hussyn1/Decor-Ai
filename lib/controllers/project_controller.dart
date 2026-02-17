import 'package:get/get.dart';
import '../services/project_service.dart';

class ProjectController extends GetxController {
  final ProjectService _projectService = ProjectService();
  
  var projects = <Project>[].obs;
  var isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    fetchProjects();
  }

  Future<void> fetchProjects() async {
    try {
      isLoading.value = true;
      var loadedProjects = await _projectService.loadProjects();
      projects.assignAll(loadedProjects);
    } catch (e) {
      Get.snackbar("Error", "Failed to load projects: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> saveProject(Project project) async {
    try {
      await _projectService.saveProject(project);
      
      // Update local list manually to avoid full reload (or just fetch again)
      // fetchProjects() is safer but slightly slower. Let's optimize:
      int index = projects.indexWhere((p) => p.id == project.id);
      if (index >= 0) {
        projects[index] = project;
      } else {
        projects.insert(0, project);
      }
      
      Get.snackbar("Success", "Project saved successfully!");
    } catch (e) {
      Get.snackbar("Error", "Failed to save project: $e");
    }
  }

  Future<void> deleteProject(String id) async {
    try {
      await _projectService.deleteProject(id);
      projects.removeWhere((p) => p.id == id);
    } catch (e) {
      Get.snackbar("Error", "Failed to delete project: $e");
    }
  }
}
