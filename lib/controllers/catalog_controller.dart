import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/ar_data.dart';
import 'package:ar_flutter_plugin/datatypes/surface_type.dart';

class CatalogController extends GetxController {
  static const String _storageKey = 'generated_furniture_v1';
  
  var furnitureItems = <Map<String, dynamic>>[].obs;
  var isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadCatalog();
  }

  Future<void> loadCatalog() async {
    try {
      isLoading.value = true;
      final prefs = await SharedPreferences.getInstance();
      // 1. Start with hardcoded furniture
      List<Map<String, dynamic>> items = List.from(ArData.furniture);
      // 2. Load generated ones from storage
      final String? storedJson = prefs.getString(_storageKey);
      if (storedJson != null) {
        final List<dynamic> storedList = jsonDecode(storedJson);
        for (var item in storedList) {
          // Convert surface back to enum from string if necessary
          if (item['surface'] is String) {
            item['surface'] = _parseSurface(item['surface']);
          }
          items.insert(0, Map<String, dynamic>.from(item));
        }
      }
      
      furnitureItems.assignAll(items);
    } catch (e) {
      print("[CATALOG-LOG] Error loading catalog: $e");
      furnitureItems.assignAll(ArData.furniture);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addGeneratedModel({
    required String name,
    required String glbUrl,
    required String localPath,
    required String imageUrl,
  }) async {
    final newItem = {
      'id': 'gen_${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'price': 0.0,
      'price_display': 'Custom',
      'image': imageUrl,
      'model': glbUrl,
      'local_path': localPath,
      'scale': 1.0,
      'style': 'AI Generated',
      'color': 'Custom',
      'dims': [0.5, 0.5, 0.5],
      'surface': SurfaceType.floor,
      'is_generated': true,
    };

    // Add to top of list
    furnitureItems.insert(0, newItem);
    
    // Persist
    await _saveToStorage();
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final generatedOnly = furnitureItems.where((item) => item['is_generated'] == true).toList();
      
      // Convert enums to strings for JSON
      final serializable = generatedOnly.map((item) {
        final copy = Map<String, dynamic>.from(item);
        if (copy['surface'] is SurfaceType) {
          copy['surface'] = (copy['surface'] as SurfaceType).name;
        }
        return copy;
      }).toList();
      
      await prefs.setString(_storageKey, jsonEncode(serializable));
    } catch (e) {
      print("[CATALOG-LOG] Error saving to storage: $e");
    }
  }

  SurfaceType _parseSurface(String name) {
    return SurfaceType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => SurfaceType.floor,
    );
  }
}
