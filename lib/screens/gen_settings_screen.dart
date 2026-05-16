import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../core/app_theme.dart';

class GenSettingsScreen extends StatelessWidget {
  const GenSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsController controller = Get.find<SettingsController>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('2D to 3D Settings'),
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
            _buildSectionHeader('Processing Preferences'),
            _buildSettingCard([
              _buildDropdownTile(
                'Generation Quality',
                'Higher quality takes more time',
                Icons.high_quality_outlined,
                controller.generationQuality,
                ['Low', 'Medium', 'High'],
                (val) => controller.updateGenSetting('gen_quality', val),
              ),
              const Divider(height: 1, indent: 56),
              _buildDropdownTile(
                'Texture Resolution',
                'Resolution of the generated model texture',
                Icons.texture_outlined,
                controller.textureResolution,
                ['512', '1024', '2048'],
                (val) => controller.updateGenSetting('tex_resolution', val),
              ),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('AR Integration'),
            _buildSettingCard([
              _buildSwitchTile(
                'Auto-Scale Models',
                'Automatically fit models to real-world scale',
                Icons.aspect_ratio_outlined,
                controller.autoScaleModels,
                (val) => controller.updateGenSetting('auto_scale', val),
              ),
            ]),
            const SizedBox(height: 32),
            _buildInfoBox(),
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
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.purple, size: 22),
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
            activeColor: Colors.purple,
          ),
        ));
  }

  Widget _buildDropdownTile(
    String title,
    String subtitle,
    IconData icon,
    RxString value,
    List<String> options,
    Function(String?) onChanged,
  ) {
    return Obx(() => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.purple, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
          ),
          trailing: DropdownButton<String>(
            value: value.value,
            underline: const SizedBox(),
            icon: const Icon(Icons.keyboard_arrow_down),
            items: options.map((String opt) {
              return DropdownMenuItem<String>(
                value: opt,
                child: Text(opt, style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ));
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Generated models are processed using our cloud AI. Higher quality requires more computational resources.',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
          ),
        ],
      ),
    );
  }
}
