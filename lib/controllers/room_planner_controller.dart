import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RoomPlannerController extends GetxController {
  
  final RxDouble roomWidth = 4.0.obs;
  final RxDouble roomLength = 5.0.obs;
  final RxDouble roomHeight = 2.4.obs;

  
  final RxString wallColor = '#F5F0E8'.obs;

  
  String? _savedLayoutJson;
  String? get savedLayoutJson => _savedLayoutJson;

  
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

  void setDimensionsFromScan({
    required double width,
    required double length,
    double height = 2.4,
  }) {
    if (width.isFinite && width >= 0.2) {
      roomWidth.value = double.parse(width.toStringAsFixed(2));
    }
    if (length.isFinite && length >= 0.2) {
      roomLength.value = double.parse(length.toStringAsFixed(2));
    }
    if (height.isFinite && height > 0) {
      roomHeight.value = double.parse(height.toStringAsFixed(2));
    }

    widthController.text = roomWidth.value.toString();
    lengthController.text = roomLength.value.toString();
    heightController.text = roomHeight.value.toString();
  }

  

  
  Future<void> saveLayout(String layoutJson) async {
    _savedLayoutJson = layoutJson;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, layoutJson);
    print('[RoomPlanner] Layout saved (${layoutJson.length} chars)');
  }

  
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _savedLayoutJson = prefs.getString(_storageKey);
    if (_savedLayoutJson != null) {
      print('[RoomPlanner] Found saved layout');
    }
  }

  
  bool get hasSavedLayout => _savedLayoutJson != null && _savedLayoutJson!.isNotEmpty;

  @override
  void onClose() {
    widthController.dispose();
    lengthController.dispose();
    heightController.dispose();
    super.onClose();
  }
}
