import 'package:get/get.dart';
import '../services/ai_stylist_service.dart';

class AiStylistController extends GetxController {
  final AiStylistService _service = AiStylistService();

  var isLoading = false.obs;
  var errorMessage = ''.obs;
  var recommendation = Rxn<StylingRecommendation>();

  Future<void> fetchRecommendations(String prompt) async {
    if (prompt.trim().isEmpty) return;

    isLoading.value = true;
    errorMessage.value = '';
    recommendation.value = null;

    try {
      final result = await _service.getRecommendations(prompt);
      recommendation.value = result;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
