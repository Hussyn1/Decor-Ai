import 'dart:io';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class ThreeDGeneratorController extends GetxController {
  var isGenerating = false.obs;
  var glbUrl = "".obs;
  var statusMessage = "".obs;
  var selectedImage = Rx<File?>(null);
  var generationStep = 0.obs;

  final ImagePicker _picker = ImagePicker();

  static const List<String> generationSteps = [
    'Analyzing image…',
    'Extracting geometry…',
    'Generating textures…',
    'Building 3D model…',
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

    // Simulate multi-step AI generation
    for (int i = 0; i < generationSteps.length; i++) {
      generationStep.value = i;
      statusMessage.value = generationSteps[i];
      await Future.delayed(const Duration(seconds: 2));
    }

    // Set sample GLB model URL (replace with real API response later)
    glbUrl.value = 'https://modelviewer.dev/shared-assets/models/Astronaut.glb';

    isGenerating.value = false;
    statusMessage.value = '3D model generated successfully!';
  }

  void reset() {
    selectedImage.value = null;
    glbUrl.value = "";
    statusMessage.value = "";
    isGenerating.value = false;
    generationStep.value = 0;
  }
}
