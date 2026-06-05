import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import '../services/room_scan_service.dart';
import '../services/ai_recommendation_service.dart' as ai_rec;
import 'catalog_controller.dart';

class RoomScanController extends GetxController {
  final RoomScanService _scanService = RoomScanService();
  final CatalogController _catalogController = Get.find<CatalogController>();

  final RxBool isScanning = false.obs;
  final RxBool hasScanned = false.obs;
  final Rx<RoomScanResult?> scanResult = Rx<RoomScanResult?>(null);

  Future<void> scanRoom(ARSessionManager sessionManager, List<ARNode> placedNodes) async {
    try {
      isScanning.value = true;
      scanResult.value = null;

      // Allow the UI to render the scanning overlay and start the animation loop smoothly first
      await Future.delayed(const Duration(milliseconds: 350));

      print("RoomScanController: Capturing AR view snapshot...");
      final imageProvider = await sessionManager.snapshot();
      
      if (imageProvider is! MemoryImage) {
        throw Exception("Captured snapshot is not a MemoryImage. Unable to retrieve bytes.");
      }

      final Uint8List bytes = imageProvider.bytes;
      
      // Perform base64 encoding in a background isolate using compute to prevent UI thread lag
      final String base64Image = await compute(base64Encode, bytes);

      print("RoomScanController: Gathering metadata of placed furniture...");
      final List<ai_rec.FurnitureMetadata> placedMetadata = [];

      for (var node in placedNodes) {
        // Find matching item in catalog
        final catalogItem = _catalogController.furnitureItems.firstWhereOrNull((item) {
          final String modelPath = (item['model'] as String?) ?? '';
          return modelPath.endsWith(node.uri) || node.uri.endsWith(modelPath.split('/').last);
        });

        if (catalogItem != null) {
          final List<double> dimensions = [];
          if (catalogItem['dims'] is List) {
            for (var d in catalogItem['dims']) {
              dimensions.add((d as num).toDouble());
            }
          } else {
            dimensions.addAll([node.scale.x, node.scale.y, node.scale.z]);
          }

          placedMetadata.add(ai_rec.FurnitureMetadata(
            id: catalogItem['id'] ?? node.name,
            name: catalogItem['name'] ?? 'Unnamed Furniture',
            style: catalogItem['style'] ?? 'Modern',
            baseColor: catalogItem['color'] ?? 'Unknown',
            dimensions: dimensions,
            price: (catalogItem['price'] as num?)?.toDouble() ?? 0.0,
          ));
        } else {
          // Fallback to basic metadata from node
          placedMetadata.add(ai_rec.FurnitureMetadata(
            id: node.name,
            name: node.uri.split('.').first,
            style: 'Modern',
            baseColor: 'Unknown',
            dimensions: [node.scale.x, node.scale.y, node.scale.z],
            price: 0.0,
          ));
        }
      }

      print("RoomScanController: Calling room scan API backend service...");
      final result = await _scanService.scanRoom(
        imageBase64: base64Image,
        placedFurniture: placedMetadata,
      );

      if (result != null) {
        scanResult.value = result;
        hasScanned.value = true;
        print("RoomScanController: Room scan completed successfully. Harmony Score: ${result.harmonyScore}");
      } else {
        print("RoomScanController: Scan service returned null result.");
      }
    } catch (e) {
      print("RoomScanController error: $e");
      Get.snackbar(
        "Scan Failed",
        "Could not analyze the room: ${e.toString()}",
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isScanning.value = false;
    }
  }

  void filterCatalogBySuggestion(String type, String value) {
    if (type.toLowerCase() == 'style') {
      _catalogController.filterByStyle(value);
    } else if (type.toLowerCase() == 'color') {
      _catalogController.filterByColor(value);
    }
  }

  void resetCatalogFilters() {
    _catalogController.resetFilters();
  }

  void dismissResult() {
    scanResult.value = null;
    resetCatalogFilters();
  }
}
