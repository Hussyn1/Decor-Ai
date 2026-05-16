import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'package:get/get.dart';
import 'screens/auth/splash_screen.dart';
import 'controllers/catalog_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/project_controller.dart';
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(SettingsController());
  runApp(const ARInteriorApp());
}
class ARInteriorApp extends StatelessWidget {
  const ARInteriorApp({super.key});
  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsController>();
    
    return Obx(() => GetMaterialApp(
      title: 'AR Interior Design',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settingsController.isDarkMode.value ? ThemeMode.dark : ThemeMode.light,
      initialBinding: BindingsBuilder(() {
        Get.put(CatalogController());
        Get.put(ProjectController());
      }),
      home: const SplashScreen(),
    ));
  }
}
