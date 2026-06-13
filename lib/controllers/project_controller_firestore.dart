import 'package:get/get.dart';
import '../services/firestore_project_service.dart';
import '../core/api_error_handler.dart';

class ProjectController extends GetxController {
  // ── swap: was ProjectService, now FirestoreProjectService ──
  final FirestoreProjectService _service = FirestoreProjectService();

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
      final loaded = await _service.loadProjects();
      projects.assignAll(loaded);
    } catch (e) {
      ApiErrorHandler.showError(ApiErrorHandler.handleException(e));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> saveProject(Project project) async {
    try {
      await _service.saveProject(project);

      // Upsert in the local list — project.id is already updated by saveProject()
      final idx = projects.indexWhere((p) => p.id == project.id);
      if (idx >= 0) {
        projects[idx] = project;
      } else {
        projects.insert(0, project);
      }

      ApiErrorHandler.showSuccess('Saved', 'Project saved successfully!');
    } catch (e) {
      ApiErrorHandler.showError(ApiErrorHandler.handleException(e));
    }
  }

  Future<void> deleteProject(String id) async {
    try {
      await _service.deleteProject(id);
      projects.removeWhere((p) => p.id == id);
      ApiErrorHandler.showSuccess('Deleted', 'Project removed.');
    } catch (e) {
      ApiErrorHandler.showError(ApiErrorHandler.handleException(e));
    }
  }
}