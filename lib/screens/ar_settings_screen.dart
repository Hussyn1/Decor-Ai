import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../core/app_theme.dart';

class ArSettingsScreen extends StatelessWidget {
  const ArSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsController controller = Get.find<SettingsController>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('AR Core Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Plane Detection'),
            _buildSettingCard([
              _buildSwitchTile(
                'Enable Plane Detection',
                'Allow AR to detect surfaces',
                Icons.grid_on,
                controller.enablePlaneDetection,
                (val) => controller.updateARSetting('ar_plane_detection', val),
              ),
              Obx(() => controller.enablePlaneDetection.value
                  ? Column(
                      children: [
                        const Divider(height: 1, indent: 56),
                        _buildSwitchTile(
                          'Horizontal Planes',
                          'Detect floors and tables',
                          Icons.maximize,
                          controller.enableHorizontalPlanes,
                          (val) => controller.updateARSetting('ar_horizontal_planes', val),
                        ),
                        const Divider(height: 1, indent: 56),
                        _buildSwitchTile(
                          'Vertical Planes',
                          'Detect walls',
                          Icons.view_column,
                          controller.enableVerticalPlanes,
                          (val) => controller.updateARSetting('ar_vertical_planes', val),
                        ),
                      ],
                    )
                  : const SizedBox.shrink()),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('Visual Enhancements'),
            _buildSettingCard([
              _buildSwitchTile(
                'Lighting Estimation',
                'Adjust model lighting based on environment',
                Icons.lightbulb_outline,
                controller.enableLightingEstimation,
                (val) => controller.updateARSetting('ar_lighting_estimation', val),
              ),
              const Divider(height: 1, indent: 56),
              _buildSwitchTile(
                'Autofocus',
                'Keep camera focus sharp',
                Icons.center_focus_strong,
                controller.enableAutofocus,
                (val) => controller.updateARSetting('ar_autofocus', val),
              ),
              const Divider(height: 1, indent: 56),
              _buildSwitchTile(
                'Depth Sensing',
                'Better occlusion and distance accuracy',
                Icons.layers_outlined,
                controller.enableDepthSensing,
                (val) => controller.updateARSetting('ar_depth_sensing', val),
              ),
            ]),
            const SizedBox(height: 32),
            const Center(
              child: Text(
                'Note: Some features depend on your device hardware support.',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.textGrey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    RxBool value,
    Function(bool) onChanged,
  ) {
    return Obx(() => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryBlue, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
          ),
          trailing: Switch(
            value: value.value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryBlue,
          ),
        ));
  }
}
