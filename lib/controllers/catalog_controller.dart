import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/ar_data.dart';
import 'package:ar_flutter_plugin/datatypes/surface_type.dart';

class CatalogController extends GetxController {
  static const String _storageKey = 'generated_furniture_v1';
  
  var furnitureItems = <Map<String, dynamic>>[].obs;
  var isLoading = true.obs;
  
  final List<Map<String, dynamic>> _unfilteredItems = [];

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
      _unfilteredItems.assignAll(items);
    } catch (e) {
      print("[CATALOG-LOG] Error loading catalog: $e");
      furnitureItems.assignAll(ArData.furniture);
      _unfilteredItems.assignAll(ArData.furniture);
    } finally {
      isLoading.value = false;
    }
  }

  void filterByStyle(String style) {
    if (style.isEmpty) {
      resetFilters();
      return;
    }
    final filtered = _unfilteredItems.where((item) {
      final itemStyle = (item['style'] as String?) ?? '';
      return itemStyle.toLowerCase().contains(style.toLowerCase());
    }).toList();
    furnitureItems.assignAll(filtered);
  }

  void filterByColor(String color) {
    if (color.isEmpty) {
      resetFilters();
      return;
    }
    final filtered = _unfilteredItems.where((item) {
      final itemColor = (item['color'] as String?) ?? '';
      return itemColor.toLowerCase().contains(color.toLowerCase());
    }).toList();
    furnitureItems.assignAll(filtered);
  }

  void resetFilters() {
    furnitureItems.assignAll(_unfilteredItems);
  }

  List<Map<String, dynamic>> getRecommendedItems(List<dynamic> recommendations) {
    final recommended = <Map<String, dynamic>>[];
    for (var rec in recommendations) {
      // rec can be FurnitureRecommendation or dynamic
      final recStyle = rec.style.toString().toLowerCase();
      final recItem = rec.item.toString().toLowerCase();
      
      for (var item in _unfilteredItems) {
        final itemStyle = ((item['style'] as String?) ?? '').toLowerCase();
        final itemName = ((item['name'] as String?) ?? '').toLowerCase();
        
        if (itemStyle.contains(recStyle) || itemName.contains(recItem)) {
          if (!recommended.contains(item)) {
            recommended.add(item);
          }
        }
      }
    }
    return recommended;
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
    _unfilteredItems.insert(0, newItem);
    
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
