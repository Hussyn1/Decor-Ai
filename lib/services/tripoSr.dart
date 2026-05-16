import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import '../core/api_config.dart';

class FurnitureAiService {
  // Python backend URL
  static String get _baseUrl => ApiConfig.aiBaseUrl;

  /// Starts the 3D generation process and returns a taskId
  static Future<String> start3DGeneration(File imageFile, {String quality = 'Medium', String resolution = '1024'}) async {
    final uri = Uri.parse('$_baseUrl/generate-3d');
    var request = http.MultipartRequest('POST', uri);

    request.fields['quality'] = quality;
    request.fields['resolution'] = resolution;

    request.files.add(
      await http.MultipartFile.fromPath(
        'image', 
        imageFile.path,
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    try {
      print('[SERVICE-LOG] Sending request to: $uri');
      final streamedResponse = await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamedResponse);
      
      print('[SERVICE-LOG] Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[SERVICE-LOG] Task ID received: ${data['task_id']}');
        return data['task_id'];
      } else {
        print('[SERVICE-LOG] Error Body: ${response.body}');
        try {
          final data = jsonDecode(response.body);
          throw Exception(data['detail'] ?? 'Failed to start generation (HTTP ${response.statusCode})');
        } catch (_) {
          throw Exception('Failed to start generation (HTTP ${response.statusCode})');
        }
      }
    } catch (e) {
      print('[SERVICE-LOG] CONNECTION ERROR: $e');
      if (e is TimeoutException) {
        throw Exception('Request timed out after 60s. Your image might be too large or the server is busy.');
      }
      if (e is SocketException) {
        throw Exception('Could not connect to server at $_baseUrl. Ensure the server is running with --host 0.0.0.0 and your phone is on the same Wi-Fi.');
      }
      throw Exception('Request failed: $e');
    }
  }

  /// Polls the status of a specific task
  static Future<Map<String, dynamic>> getGenerationStatus(String taskId) async {
    final uri = Uri.parse('$_baseUrl/task-status/$taskId');
    
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Prepend base URL to result if it exists and is relative
        if (data['result'] != null && !(data['result'] as String).startsWith('http')) {
          data['result'] = '$_baseUrl${data['result']}';
        }
        return data;
      } else {
        throw Exception('Task not found (${response.statusCode})');
      }
    } on TimeoutException {
      // Don't crash the poll loop on a single timeout - just return processing
      return {'status': 'processing', 'progress': 0, 'message': 'Checking...'};
    } on SocketException {
      // Handle network flicker gracefully
      return {'status': 'processing', 'progress': 0, 'message': 'Reconnecting...'};
    } catch (e) {
       throw Exception('Error checking status: $e');
    }
  }

  /// Downloads a GLB file to the temporary cache for instant AR loading
  static Future<String> downloadToCache(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        final appDir = await getApplicationDocumentsDirectory();
        // Strip query params from URL before using as filename
        final rawName = url.split('/').last.split('?').first;
        final fileName = rawName.isEmpty ? 'model_${DateTime.now().millisecondsSinceEpoch}.glb' : rawName;
        
        final file = File('${appDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        
        print('[CACHE] Saved ${response.bodyBytes.length ~/ 1024}KB as $fileName');
        return fileName; // ✅ ONLY the filename — never the full path
      }
      return url;
    } catch (e) {
      print("[CACHE-LOG] Download failed: $e");
      return url;
    }
  }
}
