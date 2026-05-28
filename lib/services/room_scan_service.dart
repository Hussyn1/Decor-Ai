import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../core/api_error_handler.dart';
import 'ai_recommendation_service.dart';

class WallColorDetection {
  final String colorName;
  final String hex;
  final String location;

  WallColorDetection({
    required this.colorName,
    required this.hex,
    required this.location,
  });

  factory WallColorDetection.fromJson(Map<String, dynamic> json) {
    return WallColorDetection(
      colorName: json['color_name'] ?? '',
      hex: json['hex'] ?? '',
      location: json['location'] ?? '',
    );
  }
}

class ColorPaletteRecommendation {
  final String name;
  final String hex;
  final String role;
  final String why;

  ColorPaletteRecommendation({
    required this.name,
    required this.hex,
    required this.role,
    required this.why,
  });

  factory ColorPaletteRecommendation.fromJson(Map<String, dynamic> json) {
    return ColorPaletteRecommendation(
      name: json['name'] ?? '',
      hex: json['hex'] ?? '',
      role: json['role'] ?? '',
      why: json['why'] ?? '',
    );
  }
}

class FurnitureRecommendation {
  final String item;
  final String style;
  final String colorSuggestion;
  final String why;

  FurnitureRecommendation({
    required this.item,
    required this.style,
    required this.colorSuggestion,
    required this.why,
  });

  factory FurnitureRecommendation.fromJson(Map<String, dynamic> json) {
    return FurnitureRecommendation(
      item: json['item'] ?? '',
      style: json['style'] ?? '',
      colorSuggestion: json['color_suggestion'] ?? '',
      why: json['why'] ?? '',
    );
  }
}

class RoomScanResult {
  final String roomType;
  final List<WallColorDetection> wallColors;
  final String lightingCondition;
  final String existingStyle;
  final int harmonyScore;
  final List<FurnitureRecommendation> furnitureRecommendations;
  final List<ColorPaletteRecommendation> colorRecommendations;
  final List<String> layoutTips;
  final List<String> conflicts;
  final String overallSummary;

  RoomScanResult({
    required this.roomType,
    required this.wallColors,
    required this.lightingCondition,
    required this.existingStyle,
    required this.harmonyScore,
    required this.furnitureRecommendations,
    required this.colorRecommendations,
    required this.layoutTips,
    required this.conflicts,
    required this.overallSummary,
  });

  factory RoomScanResult.fromJson(Map<String, dynamic> json) {
    var wallColorsList = (json['wall_colors'] as List?)
        ?.map((e) => WallColorDetection.fromJson(e))
        .toList() ?? [];
    var furnitureRecommendationsList = (json['furniture_recommendations'] as List?)
        ?.map((e) => FurnitureRecommendation.fromJson(e))
        .toList() ?? [];
    var colorRecommendationsList = (json['color_recommendations'] as List?)
        ?.map((e) => ColorPaletteRecommendation.fromJson(e))
        .toList() ?? [];
    var layoutTipsList = (json['layout_tips'] as List?)
        ?.map((e) => e.toString())
        .toList() ?? [];
    var conflictsList = (json['conflicts'] as List?)
        ?.map((e) => e.toString())
        .toList() ?? [];

    return RoomScanResult(
      roomType: json['room_type'] ?? 'Unknown Room',
      wallColors: wallColorsList,
      lightingCondition: json['lighting_condition'] ?? 'Unknown',
      existingStyle: json['existing_style'] ?? 'Unknown',
      harmonyScore: json['harmony_score'] ?? 0,
      furnitureRecommendations: furnitureRecommendationsList,
      colorRecommendations: colorRecommendationsList,
      layoutTips: layoutTipsList,
      conflicts: conflictsList,
      overallSummary: json['overall_summary'] ?? '',
    );
  }
}

class RoomScanService {
  String get baseUrl => ApiConfig.aiBaseUrl;

  Future<RoomScanResult?> scanRoom({
    required String imageBase64,
    required List<FurnitureMetadata> placedFurniture,
    double? roomArea,
  }) async {
    print("RoomScanService: Sending scan request to $baseUrl/scan-room...");
    try {
      final requestBody = jsonEncode({
        'image_base64': imageBase64,
        'placed_furniture': placedFurniture.map((e) => e.toJson()).toList(),
        'room_area': roomArea,
      });

      final response = await http.post(
        Uri.parse('$baseUrl/scan-room'),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      ).timeout(const Duration(seconds: 45));

      print("RoomScanService: Status code ${response.statusCode}");
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return RoomScanResult.fromJson(decoded);
      } else {
        final error = ApiErrorHandler.handleStatusCode(
          response.statusCode,
          response.body,
        );
        print("RoomScanService error: ${error.title} - ${error.message}");
        return null;
      }
    } catch (e) {
      final error = ApiErrorHandler.handleException(e);
      print("RoomScanService Exception: ${error.title} - ${error.message}");
      return null;
    }
  }
}
