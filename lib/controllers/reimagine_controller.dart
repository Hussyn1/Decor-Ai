import 'dart:io';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../services/reimagine_service.dart';
import '../screens/reimagine_viewer_screen.dart';

class ReimagineController extends GetxController {
  final ReimagineService _service = ReimagineService();
  final ImagePicker _picker = ImagePicker();

  var isGenerating = false.obs;
  var progressMessage = 'Starting generation...'.obs;
  var selectedImage = Rxn<File>();
  var styleImage = Rxn<File>(); // Custom style inspiration image
  var selectedStyle = 'Modern'.obs;
  var customPrompt = ''.obs; // New field for custom prompt instructions
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

  Future<void> pickStyleImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    
    if (image != null) {
      styleImage.value = File(image.path);
      // Clear preset selections when a custom image is chosen
      referenceImageUrl.value = null;
      referenceStyleName.value = null;
      selectedStyle.value = 'Custom';
    }
  }

  String _buildPrompt(String style, String customText) {
    String basePrompt;
    switch (style.toLowerCase()) {
      case 'modern':
        basePrompt = 'A modern interior design style living room, sleek minimalist furniture, clean lines, neutral colors, cozy decor, highly detailed, photorealistic';
        break;
      case 'scandinavian':
        basePrompt = 'A Scandinavian interior design style living room, light wood furniture, white and grey tones, cozy textiles, simple functional decor, highly detailed, photorealistic';
        break;
      case 'industrial':
        basePrompt = 'An industrial interior design style living room, exposed brick walls, metal accents, leather seating, rustic wood elements, highly detailed, photorealistic';
        break;
      case 'bohemian':
        basePrompt = 'A bohemian interior design style living room, colorful textiles, indoor plants, vintage furniture, layered rugs, warm ambient lighting, highly detailed, photorealistic';
        break;
      case 'minimalist':
        basePrompt = 'A minimalist interior design style living room, very clean, clutter-free, functional simple furniture, natural light, highly detailed, photorealistic';
        break;
      case 'luxury':
        basePrompt = 'A luxury interior design style living room, high-end marble finishes, gold accents, premium velvet furniture, designer lighting, highly detailed, photorealistic';
        break;
      default:
        basePrompt = 'A beautifully decorated $style style room, modern furniture, cozy styling, highly detailed, photorealistic';
    }
    
    if (customText.trim().isNotEmpty) {
      if (style.toLowerCase() == 'custom') {
        return customText.trim();
      }
      return '$basePrompt, specifically with: ${customText.trim()}';
    }
    return basePrompt;
  }

  Future<void> generateDesign() async {
    if (selectedImage.value == null) {
      Get.snackbar("Error", "Please upload a photo of your empty room first", snackPosition: SnackPosition.BOTTOM);
      return;
    }

    try {
      isGenerating.value = true;
      progressMessage.value = 'Uploading your room photo...';

      // Small delay so user sees the message
      await Future.delayed(const Duration(milliseconds: 500));
      progressMessage.value = 'AI is redesigning your room...';

      final activeStyle = referenceStyleName.value ?? selectedStyle.value;
      final finalPrompt = _buildPrompt(activeStyle, customPrompt.value);

      final imageUrl = await _service.generateStagedRoom(
        imageFile: selectedImage.value!,
        prompt: finalPrompt,
      );

      progressMessage.value = 'Finalizing...';
      isGenerating.value = false;

      // Navigate to results screen
      Get.to(() => ReimagineViewerScreen(
        originalImage: selectedImage.value!,
        generatedImageUrl: imageUrl,
        style: activeStyle,
      ));
      
    } catch (e) {
      isGenerating.value = false;
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      Get.snackbar(
        "Generation failed",
        errorMsg.contains('503')
            ? "AI model is warming up. Please retry in 30 seconds."
            : errorMsg.contains('429')
                ? "Rate limit reached. Please wait a minute and try again."
                : "Failed: $errorMsg",
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
      );
    }
  }
}
