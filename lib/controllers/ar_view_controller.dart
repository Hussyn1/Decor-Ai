import 'package:get/get.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import '../models/ar_operation_state.dart';





class ArViewController extends GetxController {
  

  
  final nodes = <ARNode>[].obs;

  
  final anchors = <ARAnchor>[].obs;

  
  final verticalAnchors = <ARAnchor>[].obs;

  
  final Rx<ARNode?> selectedNode = Rx<ARNode?>(null);

  
  final RxBool isPlacementInProgress = false.obs;

  
  final Rx<vector.Vector3?> lastPlacedPosition = Rx<vector.Vector3?>(null);
  final Rx<DateTime?> lastPlacedTime = Rx<DateTime?>(null);

  
  
  final worldPositions = <String, vector.Vector3>{}.obs;

  

  
  final isLocked = false.obs;

  
  final showPlanes = true.obs;

  
  final useLiDAR = false.obs;

  
  final usePhysics = false.obs;

  
  final isLiDARSupported = false.obs;

  
  final selectedFurnitureIndex = 0.obs;

  

  
  final isRestored = false.obs;

  
  final isScanning = false.obs;

  

  
  final undoStack = <Map<String, dynamic>>[].obs;

  
  final redoStack = <Map<String, dynamic>>[].obs;

  

  
  final placementState = const ArOperationState().obs;

  
  final aiAnalysisState = const ArOperationState().obs;

  
  final anchorState = const ArOperationState().obs;

  

  
  void toggleLock() {
    isLocked.value = !isLocked.value;
  }

  
  void togglePlanes() {
    showPlanes.value = !showPlanes.value;
  }

  
  void toggleLiDAR() {
    useLiDAR.value = !useLiDAR.value;
  }

  
  void togglePhysics() {
    usePhysics.value = !usePhysics.value;
  }

  
  void selectFurniture(int index) {
    selectedFurnitureIndex.value = index;
  }

  
  void addNode(ARNode node, vector.Vector3 worldPosition) {
    nodes.add(node);
    worldPositions[node.name] = worldPosition;
  }

  
  void removeNode(ARNode node) {
    nodes.remove(node);
    worldPositions.remove(node.name);
  }

  
  void clearScene() {
    nodes.clear();
    anchors.clear();
    verticalAnchors.clear();
    worldPositions.clear();
    selectedNode.value = null;
    isLocked.value = false;
    isRestored.value = false;
    isScanning.value = false;
    isPlacementInProgress.value = false;
    lastPlacedPosition.value = null;
    lastPlacedTime.value = null;
    undoStack.clear();
    redoStack.clear();
    placementState.value = const ArOperationState();
    aiAnalysisState.value = const ArOperationState();
    anchorState.value = const ArOperationState();
  }

  
  void updateNodePosition(String nodeName, vector.Vector3 position) {
    worldPositions[nodeName] = position;
  }

  @override
  void onClose() {
    
    clearScene();
    undoStack.clear();
    redoStack.clear();
    super.onClose();
  }
}
