import 'dart:io';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../services/trellis_service.dart';

class ThreeDGeneratorController extends GetxController {
  var isGenerating = false.obs;
  var glbUrl = "".obs;
  var statusMessage = "".obs;
  var selectedImage = Rx<File?>(null);
  var generationStep = 0.obs;

  final ImagePicker _picker = ImagePicker();

  static const List<String> generationSteps = [
    'Uploading image…',
    'Analyzing geometry…',
    'Generating 3D mesh…',
    'Finalizing model…',
  ];

  bool get isModelReady => glbUrl.value.isNotEmpty && !isGenerating.value;

  void pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      selectedImage.value = File(image.path);
      statusMessage.value = "Image selected: ${image.name}";
      // Reset any previous generation
      glbUrl.value = "";
      generationStep.value = 0;
    }
  }

  void generate3DModel() async {
    if (selectedImage.value == null) return;

    isGenerating.value = true;
    generationStep.value = 0;
    statusMessage.value = "Starting generation...";

    try {
      // Step 1: Uploading
      generationStep.value = 0;
      statusMessage.value = generationSteps[0];

      // Call the API
      final String generatedUrl = await TrellisService.generate3DModel(
        selectedImage.value!,
      );

      // Step 3: Success
      generationStep.value = 3;
      statusMessage.value = generationSteps[3];

      glbUrl.value = generatedUrl;
      statusMessage.value = '3D model generated successfully!';
    } catch (e) {
      statusMessage.value = "Error: $e";
      Get.snackbar(
        "Generation Failed",
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isGenerating.value = false;
    }
  }

  void reset() {
    selectedImage.value = null;
    glbUrl.value = "";
    statusMessage.value = "";
    isGenerating.value = false;
    generationStep.value = 0;
  }
}
