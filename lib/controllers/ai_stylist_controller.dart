import 'package:get/get.dart';
import '../services/ai_stylist_service.dart';
import '../core/api_error_handler.dart';

class AiStylistController extends GetxController {
  final AiStylistService _service = AiStylistService();

  var isLoading = false.obs;
  var errorMessage = ''.obs;
  var recommendation = Rxn<StylingRecommendation>();

  Future<void> fetchRecommendations(String prompt) async {
    if (prompt.trim().isEmpty) {
      ApiErrorHandler.showError(const AppError(
        title: 'Empty Prompt',
        message: 'Please describe your room style preferences.',
        type: AppErrorType.validation,
      ));
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';
    recommendation.value = null;

    try {
      final result = await _service.getRecommendations(prompt);
      recommendation.value = result;
    } catch (e) {
      final error = ApiErrorHandler.handleException(e);
      errorMessage.value = error.message;
      ApiErrorHandler.showError(error);
    } finally {
      isLoading.value = false;
    }
  }
}
