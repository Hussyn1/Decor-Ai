import 'dart:io';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../services/reimagine_service.dart';
import '../screens/reimagine_viewer_screen.dart';

class ReimagineController extends GetxController {
  final ReimagineService _service = ReimagineService();
  final ImagePicker _picker = ImagePicker();

  var isGenerating = false.obs;
  var selectedImage = Rxn<File>();
  var selectedStyle = 'Modern'.obs;
  var referenceImageUrl = Rxn<String>();
  var referenceStyleName = Rxn<String>();
  
  final List<String> styles = [
    'Modern',
    'Scandinavian',
    'Industrial',
    'Bohemian',
    'Minimalist',
    'Luxury'
  ];

  Future<void> pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    
    if (image != null) {
      selectedImage.value = File(image.path);
    }
  }

  Future<void> generateDesign() async {
    if (selectedImage.value == null) {
      Get.snackbar("Error", "Please upload a room photo first");
      return;
    }

    try {
      isGenerating.value = true;
      
      // Get the generated image URL
      final imageUrl = await _service.generateStagedRoom(
        imageFile: selectedImage.value!,
        style: referenceStyleName.value ?? selectedStyle.value,
        roomDescription: "empty living room", 
        referenceUrl: referenceImageUrl.value,
      );

      isGenerating.value = false;

      // Navigate to results screen
      Get.to(() => ReimagineViewerScreen(
        originalImage: selectedImage.value!,
        generatedImageUrl: imageUrl,
        style: selectedStyle.value,
      ));
      
    } catch (e) {
      isGenerating.value = false;
      Get.snackbar("Error", "Failed to generate design: $e");
    }
  }
}
