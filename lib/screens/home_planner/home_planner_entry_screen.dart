import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_theme.dart';
import '../../controllers/home_planner_controller.dart';
import 'ar_room_scan_screen.dart';
import 'floor_plan_editor_screen.dart';
import '../three_floor_plan_screen.dart';
import '../../controllers/room_planner_controller.dart';

class HomePlannerEntryScreen extends StatelessWidget {
  const HomePlannerEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Reset any leftover state from a previous session
    Get.put(HomePlannerController()).reset();

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Home Planner',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero icon + headline
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.grid_4x4,
                  color: AppTheme.primaryBlue,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Plan your room in 3 steps',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Measure with AR, design on a 2D canvas, then see it real in AR.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Step cards
              _StepCard(
                number: '1',
                numberBg: AppTheme.primaryBlue.withOpacity(0.1),
                numberColor: AppTheme.primaryBlue,
                icon: Icons.camera_alt_outlined,
                title: 'Scan room corners',
                subtitle:
                    'Point at each floor corner and tap to place a marker. 4 corners minimum.',
              ),
              const SizedBox(height: 12),
              _StepCard(
                number: '2',
                numberBg: const Color(0xFFEAF3DE),
                numberColor: const Color(0xFF27500A),
                icon: Icons.grid_on,
                title: 'Build your floor plan',
                subtitle:
                    'Drag furniture, doors, and windows onto a 2D canvas scaled to your room.',
              ),
              const SizedBox(height: 12),
              _StepCard(
                number: '3',
                numberBg: const Color(0xFFFAEEDA),
                numberColor: const Color(0xFF633806),
                icon: Icons.view_in_ar,
                title: 'Preview in AR',
                subtitle:
                    'See every furniture item from your plan placed in your actual room.',
              ),

              const SizedBox(height: 28),

              // Tip banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withOpacity(0.15),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      color: AppTheme.primaryBlue,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tip: walk slowly around the room edges so AR can detect the floor plane before you place corners.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryBlue.withOpacity(0.85),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Primary CTA
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => Get.to(() => const ArRoomScanScreen()),
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  label: const Text(
                    'Start AR scan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Skip to manual
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _showManualEntrySheet(context),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Enter dimensions manually'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showManualEntrySheet(BuildContext context) {
    final wCtrl = TextEditingController(text: '4.0');
    final dCtrl = TextEditingController(text: '3.5');
    final hCtrl = TextEditingController(text: '2.4');
    final planner = Get.find<HomePlannerController>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Room dimensions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Enter approximate measurements — you can adjust in the editor.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _DimField(
                    controller: wCtrl,
                    label: 'Width (m)',
                    hint: '4.0',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DimField(
                    controller: dCtrl,
                    label: 'Depth (m)',
                    hint: '3.5',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DimField(
                    controller: hCtrl,
                    label: 'Height (m)',
                    hint: '2.4',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      planner.setManualDimensions(
                        double.tryParse(wCtrl.text) ?? 4.0,
                        double.tryParse(dCtrl.text) ?? 3.5,
                        h: double.tryParse(hCtrl.text) ?? 2.4,
                      );
                      Navigator.pop(context);
                      Get.to(() => const FloorPlanEditorScreen());
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlue,
                      side: const BorderSide(color: AppTheme.primaryBlue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      '2D Editor',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final plannerCtrl = Get.put(RoomPlannerController());
                      final w = double.tryParse(wCtrl.text) ?? 4.0;
                      final l = double.tryParse(dCtrl.text) ?? 3.5;
                      final h = double.tryParse(hCtrl.text) ?? 2.4;
                      plannerCtrl.roomWidth.value = w;
                      plannerCtrl.roomLength.value = l;
                      plannerCtrl.roomHeight.value = h;

                      Navigator.pop(context);
                      Get.to(() => const ThreeFloorPlanScreen());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      '3D Editor',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step card widget ─────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final String number;
  final Color numberBg;
  final Color numberColor;
  final IconData icon;
  final String title;
  final String subtitle;

  const _StepCard({
    required this.number,
    required this.numberBg,
    required this.numberColor,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: numberBg, shape: BoxShape.circle),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: numberColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dimension text field ─────────────────────────────────────────────────────

class _DimField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const _DimField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      ),
    );
  }
}
