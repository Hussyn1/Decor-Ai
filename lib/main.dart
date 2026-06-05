// python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload      
import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'package:get/get.dart';
import 'screens/auth/splash_screen.dart';
import 'controllers/catalog_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/project_controller.dart';
import 'controllers/three_d_generator_controller.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();
  await FcmService().init();
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
        Get.put(ThreeDGeneratorController());
      }),
      home: const SplashScreen(),
    ));
  }
}
