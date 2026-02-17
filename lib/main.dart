import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'package:get/get.dart';


import 'screens/auth/splash_screen.dart';

void main() {
  runApp(const ARInteriorApp());
}


class ARInteriorApp extends StatelessWidget {
  const ARInteriorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'AR Interior Design',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
