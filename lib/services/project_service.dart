import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:http/http.dart' as http;
import '../core/api_config.dart';

/// Represents a single piece of furniture placed in the AR scene.
class FurniturePlacement {
  final String modelUri;
  final vector.Vector3 position;
  final vector.Vector4 rotation;
  final vector.Vector3 scale;

  final String? cloudAnchorId;

  FurniturePlacement({
    required this.modelUri,
    required this.position,
    required this.rotation,
    required this.scale,
    this.cloudAnchorId,
  });

  Map<String, dynamic> toJson() {
    // Sanitize values to prevent JSON encoding errors (NaN is not encodable)
    double s(double val) => (val.isNaN || val.isInfinite) ? 0.0 : val;

    return {
      'modelUri': modelUri,
      'position': [s(position.x), s(position.y), s(position.z)],
      'rotation': [s(rotation.x), s(rotation.y), s(rotation.z), s(rotation.w)],
      'scale': [s(scale.x), s(scale.y), s(scale.z)],
      'cloudAnchorId': cloudAnchorId,
    };
  }

  factory FurniturePlacement.fromJson(Map<String, dynamic> json) {
    try {
      final String? cloudId = json['cloudAnchorId']?.toString();
      print(
        "DEBUG: Parsing FurniturePlacement - Model: ${json['modelUri']} | CloudID: $cloudId",
      );

      var posList = (json['position'] as List)
          .map((e) => (e as num).toDouble())
          .toList();

      var rotList = (json['rotation'] as List)
          .map((e) => (e as num).toDouble())
          .toList();

      var scaleList = (json['scale'] as List)
          .map((e) => (e as num).toDouble())
          .toList();

      return FurniturePlacement(
        modelUri: json['modelUri'],
        position: vector.Vector3(posList[0], posList[1], posList[2]),
        rotation: vector.Vector4(
          rotList[0],
          rotList[1],
          rotList[2],
          rotList[3],
        ),
        scale: vector.Vector3(scaleList[0], scaleList[1], scaleList[2]),
        cloudAnchorId: cloudId,
      );
    } catch (e, stack) {
      print("CRITICAL ERROR parsing FurniturePlacement: $e");
      print("DEBUG: Failing JSON: $json");
      print(stack);
      rethrow;
    }
  }
}

/// Represents an entire AR design project.
class Project {
  String id;
  String name;
  String roomType;
  String style;
  DateTime lastModified;
  List<FurniturePlacement> items;
  String? thumbnailPath; // Optional: Setup for future screen capture

  Project({
    required this.id,
    required this.name,
    required this.roomType,
    required this.style,
    required this.lastModified,
    this.items = const [],
    this.thumbnailPath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'roomType': roomType,
    'style': style,
    'lastModified': lastModified.toIso8601String(),
    'items': items.map((i) => i.toJson()).toList(),
    'thumbnailUrl': thumbnailPath,
  };

  factory Project.fromJson(Map<String, dynamic> json) {
    try {
      final name = json['name'] ?? "Untitled";
      print(
        "DEBUG [Data Fetch]: Parsing Project Metadata - Name: $name (ID: ${json['_id'] ?? json['id']})",
      );

      var id = json['id'] ?? json['_id'];
      var roomType = json['roomType'] ?? "Living Room";
      var style = json['style'] ?? "Modern";

      var lastModifiedStr = json['lastModified']?.toString();
      DateTime lastModified = lastModifiedStr != null
          ? DateTime.parse(lastModifiedStr)
          : DateTime.now();

      var itemsJson = json['items'] as List? ?? [];
      var items = itemsJson.map((i) => FurniturePlacement.fromJson(i)).toList();

      return Project(
        id: id,
        name: name,
        roomType: roomType,
        style: style,
        lastModified: lastModified,
        items: items,
        thumbnailPath: json['thumbnailPath'] ?? json['thumbnailUrl'],
      );
    } catch (e, stack) {
      print("ERROR parsing Project: $e");
      print(stack);
      rethrow;
    }
  }
}

class ProjectService {
  String get baseUrl => ApiConfig.projectsEndpoint;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  /// Save a project to Backend.
  Future<void> saveProject(Project project) async {
    final token = await _getToken();
    if (token == null) throw Exception("Not authenticated");

    // A project is considered new if its ID starts with 'temp_' or is not a valid MongoDB ObjectId (24 hex characters)
    final bool isNew =
        project.id.startsWith('temp_') || project.id.length != 24;
    final url = isNew ? baseUrl : '$baseUrl/${project.id}';

    // Log the payload for debugging
    final String jsonBody = jsonEncode(project.toJson());
    print("DEBUG: Saving Project JSON: $jsonBody");

    final response = isNew
        ? await http.post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonBody,
          )
        : await http.put(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonBody,
          );

    print("DEBUG: Save Response Code: ${response.statusCode}");
    print("DEBUG: Save Response Body: ${response.body}");

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Failed to save project: ${response.body}");
    }

    // If it was a temp ID, update the project with the real DB ID
    if (isNew) {
      final responseData = jsonDecode(response.body);
      project.id = responseData['_id'] ?? responseData['id'];
    }
  }

  /// Load all saved projects from Backend.
  Future<List<Project>> loadProjects() async {
    final token = await _getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      print("DEBUG: loadProjects Response: ${response.statusCode}");
      if (response.statusCode == 200) {
        List<dynamic> jsonList = jsonDecode(response.body);
        print("DEBUG: Loaded ${jsonList.length} projects from API");
        return jsonList.map((json) => Project.fromJson(json)).toList();
      } else {
        print("Error loading projects: ${response.body}");
        return [];
      }
    } catch (e) {
      print("Error loading projects: $e");
      return [];
    }
  }

  /// Delete a project by ID from Backend.
  Future<void> deleteProject(String id) async {
    final token = await _getToken();
    if (token == null) throw Exception("Not authenticated");

    final response = await http.delete(
      Uri.parse('$baseUrl/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to delete project");
    }
  }

  /// Upload project thumbnail to backend
  Future<String> uploadThumbnail(String projectId, Uint8List bytes) async {
    final token = await _getToken();
    if (token == null) throw Exception("Not authenticated");

    final url = Uri.parse('$baseUrl/$projectId/thumbnail');
    final request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes(
      'thumbnail',
      bytes,
      filename: 'thumbnail_${DateTime.now().millisecondsSinceEpoch}.png',
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception("Failed to upload thumbnail: ${response.body}");
    }

    final data = jsonDecode(response.body);
    return data['thumbnailUrl'];
  }
}
