import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:decor_ar_fyp/core/api_config.dart';

class ReimagineService {
  static const _stabilityUrl = 'https://api.stability.ai/v2beta/stable-image/control/structure';

  Future<String> generateStagedRoom({
    required File imageFile,
    required String prompt,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_stabilityUrl));
      
      // Add authentication and accept headers
      request.headers['authorization'] = 'Bearer ${ApiConfig.stabilityApiKey}';
      request.headers['accept'] = 'image/*';
      
      // Add the room image file
      final fileStream = http.ByteStream(imageFile.openRead());
      final length = await imageFile.length();
      final multipartFile = http.MultipartFile(
        'image',
        fileStream,
        length,
        filename: imageFile.path.split('/').last,
      );
      request.files.add(multipartFile);

      // Add text prompt and other settings
      request.fields['prompt'] = prompt;
      request.fields['output_format'] = 'jpeg';
      request.fields['control_strength'] = '0.7';

      // Send the request
      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // Save the received binary bytes of the redesigned image to a local file
        final dir = await getApplicationDocumentsDirectory();
        final file = File(
          '${dir.path}/reimagined_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      } else {
        // Handle API errors
        String errorMessage = 'Failed to generate room';
        if (response.statusCode == 401) {
          errorMessage = 'Unauthorized: Please check your Stability API Key.';
        } else if (response.statusCode == 403) {
          errorMessage = 'Forbidden: Access denied. Verify permissions.';
        } else {
          try {
            final errorJson = jsonDecode(response.body);
            if (errorJson != null && errorJson['errors'] != null) {
              final errorsList = errorJson['errors'] as List<dynamic>;
              errorMessage = errorsList.join(', ');
            }
          } catch (_) {
            errorMessage = 'API Error: ${response.statusCode} - ${response.reasonPhrase}';
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Reimagine failed: $e');
    }
  }
}

