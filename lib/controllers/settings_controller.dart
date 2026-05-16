import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends GetxController {
  // AR Settings
  var enablePlaneDetection = true.obs;
  var enableHorizontalPlanes = true.obs;
  var enableVerticalPlanes = true.obs;
  var enableLightingEstimation = true.obs;
  var enableAutofocus = true.obs;
  var enableDepthSensing = false.obs;

  // 2D to 3D Settings
  var generationQuality = 'Medium'.obs; // Low, Medium, High
  var textureResolution = '1024'.obs; // 512, 1024, 2048
  var autoScaleModels = true.obs;
  
  // App Settings
  var isDarkMode = false.obs;
  var notificationsEnabled = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // AR
    enablePlaneDetection.value = prefs.getBool('ar_plane_detection') ?? true;
    enableHorizontalPlanes.value = prefs.getBool('ar_horizontal_planes') ?? true;
    enableVerticalPlanes.value = prefs.getBool('ar_vertical_planes') ?? true;
    enableLightingEstimation.value = prefs.getBool('ar_lighting_estimation') ?? true;
    enableAutofocus.value = prefs.getBool('ar_autofocus') ?? true;
    enableDepthSensing.value = prefs.getBool('ar_depth_sensing') ?? false;

    // 2D to 3D
    generationQuality.value = prefs.getString('gen_quality') ?? 'Medium';
    textureResolution.value = prefs.getString('tex_resolution') ?? '1024';
    autoScaleModels.value = prefs.getBool('auto_scale') ?? true;

    // App
    isDarkMode.value = prefs.getBool('dark_mode') ?? false;
    notificationsEnabled.value = prefs.getBool('notifications') ?? true;
  }

  Future<void> updateARSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    
    switch (key) {
      case 'ar_plane_detection': enablePlaneDetection.value = value; break;
      case 'ar_horizontal_planes': enableHorizontalPlanes.value = value; break;
      case 'ar_vertical_planes': enableVerticalPlanes.value = value; break;
      case 'ar_lighting_estimation': enableLightingEstimation.value = value; break;
      case 'ar_autofocus': enableAutofocus.value = value; break;
      case 'ar_depth_sensing': enableDepthSensing.value = value; break;
    }
  }

  Future<void> updateGenSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
      if (key == 'auto_scale') autoScaleModels.value = value;
    } else if (value is String) {
      await prefs.setString(key, value);
      if (key == 'gen_quality') generationQuality.value = value;
      if (key == 'tex_resolution') textureResolution.value = value;
    }
  }

  Future<void> toggleDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
    isDarkMode.value = value;
    Get.changeThemeMode(value ? ThemeMode.dark : ThemeMode.light);
  }
}
