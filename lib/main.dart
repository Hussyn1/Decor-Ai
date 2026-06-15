import 'package:decor_ar_fyp/controllers/notification_controller.dart';
import 'package:decor_ar_fyp/controllers/project_controller_firestore.dart';
import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'package:get/get.dart';
import 'screens/auth/splash_screen.dart';
import 'controllers/catalog_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/three_d_generator_controller.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();

  Get.put(SettingsController());
    Get.put(NotificationController()); 

  runApp(const ARInteriorApp());

  Future.microtask(() async {
    await FcmService().init();
  });
}

class ARInteriorApp extends StatelessWidget {
  const ARInteriorApp({super.key});
  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsController>();

    return Obx(
      () => GetMaterialApp(
        title: 'AR Interior Design',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: settingsController.isDarkMode.value
            ? ThemeMode.dark
            : ThemeMode.light,
        initialBinding: BindingsBuilder(() {
          Get.put(CatalogController());
          Get.put(ProjectController());
          Get.put(ThreeDGeneratorController());
        }),
        home: const SplashScreen(),
      ),
    );
  }
}
