import 'dart:convert';
import 'package:http/http.dart' as http;

class ColorPaletteItem {
  final String name;
  final String hex;
  final String role;
  final String why;

  ColorPaletteItem({
    required this.name,
    required this.hex,
    required this.role,
    required this.why,
  });

  factory ColorPaletteItem.fromJson(Map<String, dynamic> json) {
    return ColorPaletteItem(
      name: json['name'] ?? '',
      hex: json['hex'] ?? '#000000',
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

class StylingRecommendation {
  final List<ColorPaletteItem> colorPalette;
  final List<FurnitureRecommendation> furnitureRecommendations;
  final String overallDesignSummary;
  final String? visualizationPrompt;

  StylingRecommendation({
    required this.colorPalette,
    required this.furnitureRecommendations,
    required this.overallDesignSummary,
    this.visualizationPrompt,
  });

  factory StylingRecommendation.fromJson(Map<String, dynamic> json) {
    return StylingRecommendation(
      colorPalette: (json['color_palette'] as List)
          .map((e) => ColorPaletteItem.fromJson(e))
          .toList(),
      furnitureRecommendations: (json['furniture_recommendations'] as List)
          .map((e) => FurnitureRecommendation.fromJson(e))
          .toList(),
      overallDesignSummary: json['overall_design_summary'] ?? '',
      visualizationPrompt: json['visualization_prompt'],
    );
  }
}

class AiStylistService {
  final String baseUrl = "http://10.0.2.2:8000"; // Android Emulator loopback

  Future<StylingRecommendation> getRecommendations(
    String prompt, {
    String roomType = "Living Room",
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/recommend-style'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'prompt': prompt, 'room_type': roomType}),
    );

    if (response.statusCode == 200) {
      return StylingRecommendation.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(
        'Failed to load design recommendations: ${response.body}',
      );
    }
  }
}
