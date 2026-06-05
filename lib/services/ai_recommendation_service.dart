import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_error_handler.dart';
import '../core/api_config.dart';

class FurnitureMetadata {
  final String id;
  final String name;
  final String style;
  final String baseColor;
  final List<double> dimensions;
  final double price;

  FurnitureMetadata({
    required this.id,
    required this.name,
    required this.style,
    required this.baseColor,
    required this.dimensions,
    required this.price,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'style': style,
    'base_color': baseColor,
    'dimensions': dimensions,
    'price': price,
  };
}

class SpatialContext {
  final double roomArea;
  final List<FurnitureMetadata> placedFurniture;
  final List<FurnitureMetadata> availableCatalog;

  SpatialContext({
    required this.roomArea,
    required this.placedFurniture,
    required this.availableCatalog,
  });

  Map<String, dynamic> toJson() => {
    'room_area': roomArea,
    'placed_furniture': placedFurniture.map((e) => e.toJson()).toList(),
    'available_catalog': availableCatalog.map((e) => e.toJson()).toList(),
  };
}

class AiInsight {
  final String
  type; // "Warning", "Suggestion", "Harmony", "Budget", "StyleConflict"
  final String title;
  final String message;
  final double impactScore;
  final List<double>? suggestedPosition; // [x, y, z] for Magic Arrange
  final String? suggestedAction; // e.g., "FILTER_STYLE"
  final String? suggestedValue; // e.g., "Industrial"

  AiInsight({
    required this.type,
    required this.title,
    required this.message,
    required this.impactScore,
    this.suggestedPosition,
    this.suggestedAction,
    this.suggestedValue,
  });

  factory AiInsight.fromJson(Map<String, dynamic> json) {
    return AiInsight(
      type: json['type'],
      title: json['title'],
      message: json['message'],
      impactScore: (json['impact_score'] as num).toDouble(),
      suggestedPosition: json['suggested_position'] != null
          ? (json['suggested_position'] as List)
                .map((e) => (e as num).toDouble())
                .toList()
          : null,
      suggestedAction: json['suggested_action'],
      suggestedValue: json['suggested_value'],
    );
  }
}

class AiRecommendationService {
  String get baseUrl => ApiConfig.aiBaseUrl;

  Future<List<AiInsight>> analyzeRoom(SpatialContext context) async {
    print("AI Service: Sending analysis request to $baseUrl...");
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/analyze'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(context.toJson()),
          )
          .timeout(const Duration(seconds: 15));

      print(
        "AI Service: Received response with status code ${response.statusCode}",
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        print("AI Service: Successfully parsed ${data.length} insights.");
        return data.map((json) => AiInsight.fromJson(json)).toList();
      } else {
        final error = ApiErrorHandler.handleStatusCode(
          response.statusCode,
          response.body,
        );
        print("AI Service: ${error.title} - ${error.message}");
        return [];
      }
    } catch (e) {
      final error = ApiErrorHandler.handleException(e);
      print("AI Service Error: ${error.title} - ${error.message}");
      print(
        "Check if: 1. Server is running at $baseUrl, 2. Internet permission is added, 3. You are using an emulator (if not, use your PC's IP).",
      );
      return [];
    }
  }
}
