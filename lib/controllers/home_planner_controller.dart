import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/room_dimensions.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

class HomePlannerController extends GetxController {
  
  final currentStep = 0.obs;   

  
  final cornerPoints = <vector.Vector3>[].obs;

  
  final Rx<RoomDimensions?> roomDimensions = Rx(null);

  
  final isProcessing = false.obs;

  

  void addCornerPoint(vector.Vector3 worldPos) {
    cornerPoints.add(worldPos);
    if (cornerPoints.length >= 4) _computeDimensions();
  }

  void _computeDimensions() {
    if (cornerPoints.length < 2) return;

    
    final walls = <WallSegment>[];
    for (int i = 0; i < cornerPoints.length; i++) {
      walls.add(WallSegment(
        start: cornerPoints[i],
        end: cornerPoints[(i + 1) % cornerPoints.length],
      ));
    }

    
    final xs = cornerPoints.map((p) => p.x).toList()..sort();
    final zs = cornerPoints.map((p) => p.z).toList()..sort();
    final width = double.parse((xs.last - xs.first).toStringAsFixed(2));
    final depth = double.parse((zs.last - zs.first).toStringAsFixed(2));

    roomDimensions.value = RoomDimensions(
      projectId: 'current',
      widthMeters: width,
      depthMeters: depth,
      wallSegments: walls,
      elements: [],
    );
  }

  

  void setManualDimensions(double w, double d, {double h = 2.4}) {
    roomDimensions.value = RoomDimensions(
      projectId: roomDimensions.value?.projectId ?? 'current',
      widthMeters: w, depthMeters: d, heightMeters: h,
      wallSegments: roomDimensions.value?.wallSegments ?? [],
      elements: roomDimensions.value?.elements ?? [],
    );
  }

  

  void addElement(FloorPlanElement el) {
    roomDimensions.value?.elements.add(el);
    roomDimensions.refresh();
  }

  void removeElement(String id) {
    roomDimensions.value?.elements.removeWhere((e) => e.id == id);
    roomDimensions.refresh();
  }

  void updateElement(FloorPlanElement updated) {
    final list = roomDimensions.value?.elements;
    if (list == null) return;
    final idx = list.indexWhere((e) => e.id == updated.id);
    if (idx >= 0) list[idx] = updated;
    roomDimensions.refresh();
  }

  

  Future<void> save() async {
    if (roomDimensions.value == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'floor_plan_${roomDimensions.value!.projectId}',
      jsonEncode(roomDimensions.value!.toJson()),
    );
  }

  Future<void> load(String projectId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('floor_plan_$projectId');
    if (raw != null) {
      roomDimensions.value = RoomDimensions.fromJson(jsonDecode(raw));
    }
  }

  void reset() {
    cornerPoints.clear();
    roomDimensions.value = null;
    currentStep.value = 0;
  }
}