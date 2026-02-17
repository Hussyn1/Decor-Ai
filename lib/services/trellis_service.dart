import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class TrellisService {
  // Assuming the Python backend is running on this URL
  // Update this if the backend is on a different port or host
  static const String _baseUrl = 'http://192.168.100.8:8000';

  /// Uploads an image to the backend for 3D generation.
  /// Returns the URL of the generated GLB file.
  static Future<String> generate3DModel(File imageFile) async {
    final uri = Uri.parse('$_baseUrl/generate-3d');

    var request = http.MultipartRequest('POST', uri);

    // Attach the image file
    request.files.add(
      await http.MultipartFile.fromPath(
        'image', // The field name expected by the backend
        imageFile.path,
        contentType: MediaType(
          'image',
          'jpeg',
        ), // Adjust based on file type if needed
      ),
    );

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String? glbUrl = data['glb_url'];

        if (glbUrl != null && glbUrl.isNotEmpty) {
          // If the URL is relative, prepend the base URL
          if (!glbUrl.startsWith('http')) {
            return '$_baseUrl$glbUrl';
          }
          return glbUrl;
        } else {
          throw Exception('Backend returned empty GLB URL');
        }
      } else {
        throw Exception(
          'Failed to generate model: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error connecting to Trellis API: $e');
    }
  }
}
