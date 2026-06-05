import 'package:get/get.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import '../models/ar_operation_state.dart';

/// Controller for AR View state management
///
/// Manages all AR-related state including nodes, anchors, selections,
/// UI toggles, and world position tracking. Uses GetX for reactive state.
class ArViewController extends GetxController {
  // ===== AR SCENE STATE =====

  /// All AR nodes currently in the scene
  final nodes = <ARNode>[].obs;

  /// All AR anchors currently in the scene
  final anchors = <ARAnchor>[].obs;

  /// Vertical plane anchors (walls) detected in the scene
  final verticalAnchors = <ARAnchor>[].obs;

  /// Currently selected node for manipulation
  final Rx<ARNode?> selectedNode = Rx<ARNode?>(null);

  /// Global lock to prevent multiple simultaneous placements across sessions
  final RxBool isPlacementInProgress = false.obs;

  /// Tracks the last placed world position to prevent "ghost" stacking
  final Rx<vector.Vector3?> lastPlacedPosition = Rx<vector.Vector3?>(null);
  final Rx<DateTime?> lastPlacedTime = Rx<DateTime?>(null);

  /// World position tracking map for accurate collision detection
  /// Maps node name to its world-space position
  final worldPositions = <String, vector.Vector3>{}.obs;

  // ===== UI STATE =====

  /// Whether the selected node is locked (prevents manipulation)
  final isLocked = false.obs;

  /// Whether to show AR plane detection overlays
  final showPlanes = true.obs;

  /// Whether LiDAR depth mesh scanning is enabled
  final useLiDAR = false.obs;

  /// Whether physics-based collisions are enabled
  final usePhysics = false.obs;

  /// Whether the device supports LiDAR/depth mesh
  final isLiDARSupported = false.obs;

  /// Currently selected furniture index from carousel
  final selectedFurnitureIndex = 0.obs;

  // ===== PROJECT STATE =====

  /// Whether the project has been restored/loaded
  final isRestored = false.obs;

  /// Whether the AR session is currently scanning for planes
  final isScanning = false.obs;

  // ===== UNDO/REDO STATE =====

  /// Stack of previous states for undo functionality
  final undoStack = <Map<String, dynamic>>[].obs;

  /// Stack of undone states for redo functionality
  final redoStack = <Map<String, dynamic>>[].obs;

  // ===== OPERATION STATES =====

  /// State of object placement operations
  final placementState = const ArOperationState().obs;

  /// State of AI analysis operations
  final aiAnalysisState = const ArOperationState().obs;

  /// State of cloud anchor operations
  final anchorState = const ArOperationState().obs;

  // ===== METHODS =====

  /// Toggle the lock state of the selected node
  void toggleLock() {
    isLocked.value = !isLocked.value;
  }

  /// Toggle plane detection visibility
  void togglePlanes() {
    showPlanes.value = !showPlanes.value;
  }

  /// Toggle LiDAR mesh scanning
  void toggleLiDAR() {
    useLiDAR.value = !useLiDAR.value;
  }

  /// Toggle physics-based collisions
  void togglePhysics() {
    usePhysics.value = !usePhysics.value;
  }

  /// Select a furniture item from the carousel
  void selectFurniture(int index) {
    selectedFurnitureIndex.value = index;
  }

  /// Add a node to the scene
  void addNode(ARNode node, vector.Vector3 worldPosition) {
    nodes.add(node);
    worldPositions[node.name] = worldPosition;
  }

  /// Remove a node from the scene
  void removeNode(ARNode node) {
    nodes.remove(node);
    worldPositions.remove(node.name);
  }

  /// Clear all nodes and anchors from the scene and reset all project state
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

  /// Update the world position of a node
  void updateNodePosition(String nodeName, vector.Vector3 position) {
    worldPositions[nodeName] = position;
  }

  @override
  void onClose() {
    // Clear all state to prevent memory leaks
    clearScene();
    undoStack.clear();
    redoStack.clear();
    super.onClose();
  }
}
