import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RoomPlannerController extends GetxController {
  // Default room dimensions (in meters)
  final RxDouble roomWidth = 4.0.obs;
  final RxDouble roomLength = 5.0.obs;
  final RxDouble roomHeight = 2.4.obs;

  // Wall color (hex string, e.g. '#F5F0E8')
  final RxString wallColor = '#F5F0E8'.obs;

  // The raw JSON layout data from JS (full state including placements)
  String? _savedLayoutJson;
  String? get savedLayoutJson => _savedLayoutJson;

  // Text controllers for the dimension editor popup
  late TextEditingController widthController;
  late TextEditingController lengthController;
  late TextEditingController heightController;

  static const _storageKey = 'three_floor_plan_layout';

  @override
  void onInit() {
    super.onInit();
    widthController = TextEditingController(text: roomWidth.value.toString());
    lengthController = TextEditingController(text: roomLength.value.toString());
    heightController = TextEditingController(text: roomHeight.value.toString());
    // Eagerly load any saved layout
    _loadFromPrefs();
  }

  void applyManualDimensions() {
    final w = double.tryParse(widthController.text);
    final l = double.tryParse(lengthController.text);
    final h = double.tryParse(heightController.text);

    if (w != null && w > 0) roomWidth.value = w;
    if (l != null && l > 0) roomLength.value = l;
    if (h != null && h > 0) roomHeight.value = h;
  }

  // ── Save / Load ──────────────────────────────────────────────

  /// Stores the raw layout JSON from JS `getLayoutData()` into SharedPreferences.
  Future<void> saveLayout(String layoutJson) async {
    _savedLayoutJson = layoutJson;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, layoutJson);
    print('[RoomPlanner] Layout saved (${layoutJson.length} chars)');
  }

  /// Loads saved layout from SharedPreferences if available.
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _savedLayoutJson = prefs.getString(_storageKey);
    if (_savedLayoutJson != null) {
      print('[RoomPlanner] Found saved layout');
    }
  }

  /// Returns true if there is a saved layout to restore.
  bool get hasSavedLayout => _savedLayoutJson != null && _savedLayoutJson!.isNotEmpty;

  @override
  void onClose() {
    widthController.dispose();
    lengthController.dispose();
    heightController.dispose();
    super.onClose();
  }
}
