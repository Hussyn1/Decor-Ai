import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import '../../controllers/home_planner_controller.dart';
import '../../controllers/catalog_controller.dart';
import '../../models/room_dimensions.dart';
import '../../services/project_service.dart';
import '../ar_view_screen.dart';
import '../../core/app_theme.dart';

class ArPreviewFromPlanScreen extends StatelessWidget {
  const ArPreviewFromPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final planner = Get.find<HomePlannerController>();
    final catalog = Get.find<CatalogController>();
    final rd = planner.roomDimensions.value;

    // Convert floor plan elements to FurniturePlacement items
    final placements = <FurniturePlacement>[];
    if (rd != null) {
      for (final el in rd.elements.where((e) => e.type == FloorPlanElementType.furniture)) {
        // Match to catalog item or use a fallback GLB
        final catalogMatch = catalog.furnitureItems.firstWhereOrNull((item) {
          final dims = item['dims'] as List?;
          if (dims == null || dims.length < 2) return false;
          return (dims[0] as num).toDouble().abs() - el.widthMeters.abs() < 0.5;
        });
        final uri = catalogMatch?['model'] as String? ??
            'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/SheenChair/glTF-Binary/SheenChair.glb';
        // Map 2D metre-position to 3D world position (Y = floor level)
        import_vector: placements.add(FurniturePlacement(
          modelUri: uri,
          position: vector.Vector3(el.xMeters - rd.widthMeters / 2, 0, el.zMeters - rd.depthMeters / 2),
          rotation: vector.Vector4(0, 0, 0, 1),
          scale: vector.Vector3(1, 1, 1),
        ));
      }
    }

    final project = Project(
      id: 'plan_preview_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Floor plan preview',
      roomType: 'Custom',
      style: 'Modern',
      lastModified: DateTime.now(),
      items: placements,
    );

    return Scaffold(
      body: Stack(children: [
        ArViewScreen(project: project),
        // Overlay badge
        Positioned(top: 100, left: 16, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.grid_on, color: Colors.white, size: 14),
            SizedBox(width: 6),
            Text('From floor plan', style: TextStyle(color: Colors.white, fontSize: 12)),
          ]),
        )),
      ]),
    );
  }
}