import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/tripoSr.dart';
import '../core/api_error_handler.dart';
import 'catalog_controller.dart';
import 'settings_controller.dart';

class ThreeDGeneratorController extends GetxController {
  var isGenerating = false.obs;
  var glbUrl = "".obs;
  var localGlbPath = "".obs;
  var statusMessage = "".obs;
  var progress = 0.obs;
  var selectedImage = Rx<File?>(null);
  
  final ImagePicker _picker = ImagePicker();

  void pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      selectedImage.value = File(image.path);
      statusMessage.value = "Image selected: ${image.name}";
      glbUrl.value = "";
      localGlbPath.value = "";
      progress.value = 0;
    }
  }

  void generate3DModel() async {
    if (selectedImage.value == null) return;

    isGenerating.value = true;
    glbUrl.value = "";
    localGlbPath.value = "";
    progress.value = 0;
    statusMessage.value = "Uploading to server...";

    try {
      final settingsController = Get.find<SettingsController>();
      print('[CONTROLLER-LOG] Starting 3D generation process with Quality: ${settingsController.generationQuality.value}, Res: ${settingsController.textureResolution.value}');
      
      final taskId = await FurnitureAiService.start3DGeneration(
        selectedImage.value!,
        quality: settingsController.generationQuality.value,
        resolution: settingsController.textureResolution.value,
      );
      print('[CONTROLLER-LOG] Task started successfully. TaskID: $taskId');
      
      // 2. Poll Status
      bool completed = false;
      int retryCount = 0;
      
      while (!completed && retryCount < 200) {
        await Future.delayed(const Duration(seconds: 2));
        final statusData = await FurnitureAiService.getGenerationStatus(taskId);
        
        String status = statusData['status'];
        progress.value = statusData['progress'] ?? 0;
        statusMessage.value = statusData['message'] ?? "Processing...";

        if (status == 'success') {
          completed = true;
          glbUrl.value = statusData['result'];
          statusMessage.value = "Generation Complete! Finalizing...";
          
          // Download to cache for instant AR
          statusMessage.value = "Preparing for AR...";
          final cachedFilename = await FurnitureAiService.downloadToCache(glbUrl.value);
          
          final appDir = await getApplicationDocumentsDirectory();
          
          // Reconstruct the full absolute path for ModelViewer
          // If the cachedFilename is somehow still a full URL (cache failed), use it directly
          if (cachedFilename.startsWith('http')) {
              localGlbPath.value = cachedFilename;
          } else {
              localGlbPath.value = '${appDir.path}/$cachedFilename';
          }
          
          statusMessage.value = "Model ready!";
          
          // 4. Register with Global Catalog
          try {
            final catalogController = Get.find<CatalogController>();
            await catalogController.addGeneratedModel(
              name: "AI Furniture #${catalogController.furnitureItems.length + 1}",
              glbUrl: glbUrl.value,
              localPath: localGlbPath.value,
              imageUrl: selectedImage.value!.path, // Use original picked image as thumbnail
            );
            print('[CONTROLLER-LOG] Successfully added to persistent catalog');
          } catch (e) {
            print('[CONTROLLER-LOG] Could not add to catalog: $e');
          }
          
          ApiErrorHandler.showSuccess("Success", "Model generated successfully.");
        } else if (status == 'failed') {
          throw Exception(statusData['message'] ?? 'Generation failed');
        }
        
        retryCount++;
      }
      
      if (!completed) throw Exception('Generation timed out');

    } catch (e) {
      statusMessage.value = "Error: $e";
      ApiErrorHandler.showError(ApiErrorHandler.handleException(e));
    } finally {
      isGenerating.value = false;
    }
  }

  void reset() {
    selectedImage.value = null;
    glbUrl.value = "";
    localGlbPath.value = "";
    statusMessage.value = "";
    isGenerating.value = false;
    progress.value = 0;
  }
}
