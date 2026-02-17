import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import '../constants/ar_constants.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import '../models/ar_operation_state.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'dart:async'; // Add this for Completer

import '../core/debouncer.dart';
import '../core/app_theme.dart';
import '../services/ai_recommendation_service.dart';
import '../services/project_service.dart';
import 'package:get/get.dart';
import '../controllers/project_controller.dart';
import '../widgets/ar_control_panel.dart';
import '../widgets/furniture_carousel.dart';
import '../widgets/ai_insights_overlay.dart';
import '../controllers/ar_view_controller.dart';
import '../services/ar_core_bridge.dart';
import '../core/ar_data.dart';

class ArViewScreen extends StatefulWidget {
  final Project? project;
  const ArViewScreen({super.key, this.project});

  @override
  State<ArViewScreen> createState() => _ArViewScreenState();
}

class _ArViewScreenState extends State<ArViewScreen> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  final ProjectController _projectController = Get.put(ProjectController());
  final ArViewController _arController = Get.put(ArViewController());
  ARAnchorManager? arAnchorManager;
  ARLocationManager? arLocationManager;

  final ArCoreBridge _arBridge = ArCoreBridge();
  final Debouncer _aiDebouncer = Debouncer(milliseconds: 1500);

  // Advanced State
  // Scaling Logic Tracking
  final Map<int, Offset> _pointerPositions = {};
  double _initialPinchDistance = 0.0;
  double _initialNodeScale = 1.0;

  vector.Vector3 _restorationOffset = vector.Vector3.zero();

  // Track the relationship between Nodes and Anchors for Cloud persistence
  final Map<String, ARAnchor> _nodeAnchors = {};
  // Async handling for Cloud Anchors
  final Map<String, dynamic> _pendingUploads =
      {}; // Map<String, Completer<String>>
  final Map<String, dynamic> _pendingDownloads =
      {}; // Map<String, Completer<ARAnchor>>

  final List<Map<String, dynamic>> _furniture = ArData.furniture;
  final List<Map<String, dynamic>> _materialSwatches = ArData.materialSwatches;
  int _selectedColorIndex = 0;

  final AiRecommendationService _aiService = AiRecommendationService();
  List<AiInsight> _activeInsights = [];
  bool _isAnalyzing = false;
  bool _useLiDAR = false;
  bool _usePhysics = false;
  bool _isLiDARSupported = false;
  bool _isProcessingTap =
      false; // Prevents multiple rapid taps or phantom events
  bool _isLoadingItems = false; // Guard for project restoration

  // Unique session ID to track logs for this specific instance
  late String _sessionId;

  // Helper getters for controller state (for gradual migration)
  List<ARNode> get nodes => _arController.nodes;
  List<ARAnchor> get anchors => _arController.anchors;
  List<ARPlaneAnchor> get _verticalAnchors =>
      _arController.verticalAnchors.cast<ARPlaneAnchor>();
  ARNode? get selectedNode => _arController.selectedNode.value;
  set selectedNode(ARNode? node) => _arController.selectedNode.value = node;
  bool get isLocked => _arController.isLocked.value;
  set isLocked(bool value) => _arController.isLocked.value = value;
  bool get _showPlanes => _arController.showPlanes.value;
  set _showPlanes(bool value) => _arController.showPlanes.value = value;
  Map<String, vector.Vector3> get _worldPositions =>
      _arController.worldPositions;
  List<Map<String, dynamic>> get undoStack => _arController.undoStack;
  List<Map<String, dynamic>> get redoStack => _arController.redoStack;
  int get _selectedFurnitureIndex => _arController.selectedFurnitureIndex.value;
  set _selectedFurnitureIndex(int value) =>
      _arController.selectedFurnitureIndex.value = value;
  bool get _isRestored => _arController.isRestored.value;
  set _isRestored(bool value) => _arController.isRestored.value = value;
  bool get _isScanning => _arController.isScanning.value;
  set _isScanning(bool value) => _arController.isScanning.value = value;

  // Helper cast for data access
  double get _currentScale =>
      _furniture[_selectedFurnitureIndex]['scale'] as double;

  late Project _currentProject;

  @override
  void initState() {
    super.initState();
    _sessionId =
        "session_${DateTime.now().millisecondsSinceEpoch.toString().split('').reversed.join('').substring(0, 5)}";

    print("BREADCRUMB [$_sessionId]: initState START");

    // CRITICAL: Clear existing AR state before starting a new session
    _isRestored = false;
    _isScanning = false;
    _arController.clearScene();

    // Initialize project
    if (widget.project != null) {
      _currentProject = widget.project!;
      print(
        "BREADCRUMB [$_sessionId]: Loaded Existing Project: ${_currentProject.name} (ID: ${_currentProject.id})",
      );
      print(
        "BREADCRUMB [$_sessionId]: Items count in project: ${_currentProject.items.length}",
      );
    } else {
      // Create a temporary "Quick Session" project
      _currentProject = Project(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        name: "Quick Design ${DateTime.now().hour}:${DateTime.now().minute}",
        roomType: "Living Room",
        style: "Modern",
        lastModified: DateTime.now(),
        items: [],
      );
      print(
        "BREADCRUMB [$_sessionId]: Created NEW Temporary Project: ${_currentProject.name}",
      );
    }

    // If no items, we consider it "restored" (nothing to restore) so user can start placing directly
    if (_currentProject.items.isEmpty) {
      _isRestored = true;
      _isScanning = true;
      print(
        "BREADCRUMB [$_sessionId]: Project is empty - Skipping restoration phase",
      );
    } else {
      // If there are items, we need to ground the design first
      _isRestored = false;
      _isScanning = false;
      print(
        "BREADCRUMB [$_sessionId]: Project has items - Entering restoration phase",
      );
    }
    _setupErrorListener();
  }

  Future<void> _checkLiDARSupport() async {
    _isLiDARSupported = await _arBridge.isDepthMeshSupported();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    print("BREADCRUMB: ArViewScreen DISPOSING - Cleaning up resources");
    // Dispose AI debouncer
    _aiDebouncer.dispose();

    // Controller cleanup (handles nodes, anchors, world positions, etc.)
    _arController.onClose();

    // Clear AI insights
    _activeInsights.clear();

    // Dispose AR session manager
    arSessionManager?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Real AR View Component (Baseline)
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),

          // 2. Transparent Interaction Layer for Passive Scaling
          if (selectedNode != null && !isLocked)
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) {
                _pointerPositions[event.pointer] = event.position;
                if (_pointerPositions.length == 2) {
                  final list = _pointerPositions.values.toList();
                  _initialPinchDistance = (list[0] - list[1]).distance;
                  _initialNodeScale = selectedNode!.scale.x;
                  _saveStateToUndo();
                }
              },
              onPointerMove: (event) {
                _pointerPositions[event.pointer] = event.position;
                if (_pointerPositions.length == 2 &&
                    _initialPinchDistance > 0) {
                  final list = _pointerPositions.values.toList();
                  final currentDistance = (list[0] - list[1]).distance;
                  final zoomFactor = currentDistance / _initialPinchDistance;

                  double newScale = (_initialNodeScale * zoomFactor).clamp(
                    ArConstants.minScale,
                    ArConstants.maxScale,
                  );
                  // PERFORMANCE: Update node scale directly without setState to avoid UI lag
                  // This communicates with the AR engine via platform channels immediately.
                  selectedNode!.scale = vector.Vector3(
                    newScale,
                    newScale,
                    newScale,
                  );
                }
              },
              onPointerUp: (event) {
                _pointerPositions.remove(event.pointer);
                if (_pointerPositions.length < 2) _initialPinchDistance = 0.0;
              },
              onPointerCancel: (event) {
                _pointerPositions.remove(event.pointer);
                if (_pointerPositions.length < 2) _initialPinchDistance = 0.0;
              },
            ),

          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Row(
              children: [
                _buildCircleButton(
                  Icons.arrow_back_ios_new,
                  () => Navigator.pop(context),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _currentProject.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                _buildCircleButton(
                  Icons.save_rounded,
                  _saveProject,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(width: 12),
                _buildCircleButton(
                  Icons.share,
                  _shareProject,
                  color: Colors.greenAccent.withOpacity(0.8),
                ),
                const SizedBox(width: 12),
                _buildCircleButton(Icons.settings, () {}),
              ],
            ),
          ),

          // Selection Indicator & Controls
          ArControlPanel(
            selectedNode: selectedNode,
            isLocked: isLocked,
            showPlanes: _showPlanes,
            useLiDAR: _useLiDAR,
            usePhysics: _usePhysics,
            canUndo: undoStack.isNotEmpty,
            canRedo: redoStack.isNotEmpty,
            isLiDARSupported: _isLiDARSupported,
            onToggleLock: () => setState(() => isLocked = !isLocked),
            onSnapToWall: _snapToNearestWall,
            onUndo: _performUndo,
            onRedo: _performRedo,
            onTogglePlanes: _togglePlanes,
            onToggleLiDAR: _toggleLiDAR,
            onTogglePhysics: _togglePhysics,
          ),

          // Remove Button (Visible if nodes exist)
          if (nodes.isNotEmpty)
            Positioned(
              right: 20,
              bottom: 220,
              child: _buildSmallCircleButton(
                Icons.delete,
                color: Colors.redAccent.withOpacity(0.8),
                onTap: removeAllAnchors,
              ),
            ),

          // Camera Controls
          Positioned(
            bottom: 110,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCircleButton(Icons.photo_library, () {}),
                const SizedBox(width: 24),
                _buildCaptureButton(),
                const SizedBox(width: 24),
                _buildCircleButton(Icons.view_in_ar, () {}),
              ],
            ),
          ),

          // Material Swapper (Visible if object selected)
          if (selectedNode != null)
            Positioned(
              bottom: 220, // Moved up to avoid overlap with Camera Controls
              left: 40,
              right: 80,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.palette, color: Colors.white, size: 16),
                      const SizedBox(width: 12),
                      ...List.generate(
                        _materialSwatches.length,
                        (index) => _buildSwatchItem(index),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Furniture Carousel
          FurnitureCarousel(
            furniture: _furniture,
            selectedIndex: _selectedFurnitureIndex,
            onFurnitureSelected: (index) {
              setState(() {
                _selectedFurnitureIndex = index;
              });
            },
          ),

          // AI Insight Overlay (Must be last to render on top)
          RepaintBoundary(
            child: AiInsightsOverlay(
              activeInsights: _activeInsights,
              totalBudget: _calculateTotalBudget(),
              isAnalyzing: _isAnalyzing,
              nodesCount: nodes.length,
              onMagicArrange: _magicArrange,
              onDismissInsight: (insight) {
                setState(() {
                  _activeInsights.remove(insight);
                });
              },
            ),
          ),

          // Global Loading Overlay
          Obx(() {
            final isAnchoring = _arController.anchorState.value.isLoading;

            if (isAnchoring) {
              return Container(
                color: Colors.black45,
                child: const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryBlue),
                ),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  void onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) {
    print(
      "BREADCRUMB [$_sessionId]: onARViewCreated STARTing for ${_currentProject.name}",
    );

    // Redundant safety clear to catch any mid-init data injection
    _arController.clearScene();

    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;
    this.arLocationManager = arLocationManager;

    // Initialize callbacks BEFORE calling onInitialize
    this.arSessionManager!.onPlaneOrPointTap = onPlaneOrPointTap;

    print("BREADCRUMB: Initializing AR Session Manager");
    this.arSessionManager!.onInitialize(
      showFeaturePoints: false,
      showPlanes: _showPlanes,
      showWorldOrigin: false,
      handleTaps: true,
      handlePans: true,
      handleRotation: true,
    );
    this.arObjectManager!.onInitialize();
    print("BREADCRUMB: AR Managers Initialized");

    _checkCloudSupport();

    this.arObjectManager!.onNodeTap = onNodeTap;
    this.arObjectManager!.onPanStart = onPanStart;
    this.arObjectManager!.onPanChange = onPanChange;
    this.arObjectManager!.onPanEnd = onPanEnd;
    this.arObjectManager!.onRotationStart = onRotationStart;
    this.arObjectManager!.onRotationChange = onRotationChange;
    this.arObjectManager!.onRotationEnd = onRotationEnd;

    // Phase 1: Enable Occlusion and Light Estimation via Platform Bridge
    _enableRealismFeatures();

    // Register Cloud Anchor Callbacks BEFORE initialization
    print("BREADCRUMB: Registering Cloud Anchor Callbacks");
    this.arAnchorManager!.onAnchorUploaded = (anchor) {
      String? name = anchor.name;
      String? cloudId;
      try {
        dynamic dAnchor = anchor;
        cloudId = dAnchor.cloudAnchorId ?? dAnchor.cloudanchorid;
      } catch (e) {
        print("DEBUG: Anchor object lacks cloudAnchorId property: $e");
      }

      print(
        "DEBUG: ARCore Callback - Anchor Uploaded Status Received for: $name",
      );
      print("DEBUG: ARCore Callback - Cloud ID: $cloudId");

      if (_pendingUploads.containsKey(name)) {
        if (cloudId != null) {
          _pendingUploads[name].complete(cloudId);
        } else {
          // If no ID on object, use name as fallback (common in some versions)
          _pendingUploads[name].complete(name);
        }
        _pendingUploads.remove(name);
      }
    };

    this.arAnchorManager!.onAnchorDownloaded =
        (Map<String, dynamic> anchorMap) {
          final String? name = anchorMap['name'];
          final String? cloudId =
              anchorMap['cloudanchorid'] ?? anchorMap['cloudAnchorId'];

          print("DEBUG: ARCore Callback - Anchor Downloaded Map: $anchorMap");

          final ARAnchor anchor = ARAnchor.fromJson(anchorMap);

          final String? key = cloudId ?? name;

          if (key != null && _pendingDownloads.containsKey(key)) {
            print("DEBUG: Resolving pending download for key: $key");
            _pendingDownloads[key].complete(anchor);
            _pendingDownloads.remove(key);
          } else {
            print("DEBUG: Received download callback for unexpected key: $key");
          }
          return anchor;
        };

    // Initialize Cloud Anchor Mode AFTER callbacks are registered
    try {
      print("BREADCRUMB: Initializing Cloud Anchor Mode");
      this.arAnchorManager!.initGoogleCloudAnchorMode();
      print("BREADCRUMB: Cloud Anchor Mode Initialized Successfully");
      _showStatus("Cloud Anchor mode initialized 🌩️");
    } catch (e) {
      print("CRITICAL ERROR initializing Cloud Anchors: $e");
      _showStatus("⚠️ Cloud Anchor initialization failed: $e");
    }

    // We no longer load immediately. We wait for ground detection.
    if (widget.project == null) _isRestored = true;
  }

  // --- PLACEMENT & INTERACTION HANDLERS ---
  Future<void> onPlaneOrPointTap(List<ARHitTestResult> hitTestResults) async {
    if (_isProcessingTap) {
      print(
        "BREADCRUMB [$_sessionId]: Tap IGNORED - Already processing a tap.",
      );
      return;
    }
    _isProcessingTap = true;

    print(
      "BREADCRUMB [$_sessionId]: onPlaneOrPointTap START - Hits: ${hitTestResults.length} | Restored: $_isRestored",
    );

    if (hitTestResults.isEmpty || isLocked) {
      _isProcessingTap = false;
      return;
    }

    // If we haven't restored the design yet, this tap is for grounding
    if (!_isRestored && widget.project != null) {
      await _groundDesign(hitTestResults.first);
      _isProcessingTap = false;
      return;
    }

    // Filter for horizontal planes
    ARHitTestResult? horizontalHit;
    for (var hit in hitTestResults) {
      if (hit.type == ARHitTestResultType.plane) {
        if (hit.worldTransform.entry(1, 1).abs() > 0.7) {
          horizontalHit = hit;
          break;
        }
      }
    }

    if (horizontalHit == null) {
      _showStatus("Please tap on a flat surface.");
      return;
    }

    // Collision Check
    vector.Vector3 potentialPos = vector.Vector3(
      horizontalHit.worldTransform.entry(0, 3),
      horizontalHit.worldTransform.entry(1, 3),
      horizontalHit.worldTransform.entry(2, 3),
    );

    if (_checkCollision(potentialPos, null)) {
      _showStatus("Cannot place here: Too close to existing furniture!");
      return;
    }

    var newAnchor = ARPlaneAnchor(transformation: horizontalHit.worldTransform);
    bool? didAddAnchor = await arAnchorManager!.addAnchor(newAnchor);
    if (didAddAnchor == true) {
      anchors.add(newAnchor);

      // Start loading state
      _arController.placementState.value = ArOperationState.loading();

      var newNode = ARNode(
        type: NodeType.webGLB,
        uri: _furniture[_selectedFurnitureIndex]['model']!,
        scale: vector.Vector3(_currentScale, _currentScale, _currentScale),
        position: vector.Vector3(0, 0, 0),
        rotation: vector.Vector4(1, 0, 0, 0),
        name: "furniture_${DateTime.now().millisecondsSinceEpoch}",
      );

      bool? didAddNodeToAnchor = await arObjectManager!.addNode(
        newNode,
        planeAnchor: newAnchor,
      );
      if (didAddNodeToAnchor == true) {
        print(
          "BREADCRUMB [$_sessionId]: Node placement SUCCESS: ${newNode.name}",
        );
        nodes.add(newNode);
        _nodeAnchors[newNode.name] = newAnchor; // Track anchor
        _worldPositions[newNode.name] = potentialPos; // Track world pos
        _saveStateToUndo();

        // Success state
        _arController.placementState.value = ArOperationState.success();

        _aiDebouncer.run(
          () => _runAiAnalysis(),
        ); // Trigger AI check after placement
        if (mounted) {
          setState(() => selectedNode = newNode);
        }
      } else {
        // Error handling
        _arController.placementState.value = ArOperationState.error(
          "Failed to place object",
        );
        _showStatus("Failed to place object");
      }
    }
    _isProcessingTap = false;
    print("BREADCRUMB [$_sessionId]: onPlaneOrPointTap FINISHED");
  }

  void onNodeTap(List<String> nodeNames) {
    if (isLocked || nodeNames.isEmpty) return;
    var tappedNodeName = nodeNames.first;
    if (tappedNodeName.contains('selection_ring')) return;

    ARNode? tappedNode;
    try {
      tappedNode = nodes.firstWhere((n) => n.name == tappedNodeName);
    } catch (e) {
      return;
    }

    setState(() {
      selectedNode = tappedNode;
    });
    _checkLiDARSupport();
  }

  void onPanStart(String nodeName) {
    if (isLocked && selectedNode?.name == nodeName) {
      _showStatus("Object is locked");
      return;
    }
    _saveStateToUndo();
  }

  void onPanChange(String nodeName) {}

  void onPanEnd(String nodeName, vector.Matrix4 transform) async {
    final node = selectedNode;
    if (node == null || node.name != nodeName) return;

    if (isLocked) {
      _performUndo();
      _showStatus("Movement blocked: Object is locked.");
      return;
    }

    // DYNAMIC RE-ANCHORING: Rebind to the physical floor at the new location
    final worldTransform = transform;
    final worldPos = worldTransform.getTranslation();

    // 1. Create a new anchor at this spot
    var newAnchor = ARPlaneAnchor(transformation: worldTransform);
    bool? didAddAnchor = await arAnchorManager!.addAnchor(newAnchor);

    if (didAddAnchor == true) {
      // 2. Remove node from old anchor by re-adding it to the new one
      // The plugin automatically handles parent switching when addNode is called with a new anchor
      bool? didReAnchor = await arObjectManager!.addNode(
        selectedNode!,
        planeAnchor: newAnchor,
      );

      if (didReAnchor == true) {
        anchors.add(newAnchor);
        selectedNode!.position = vector.Vector3(
          0,
          0,
          0,
        ); // Reset local to new anchor origin
        _nodeAnchors[nodeName] = newAnchor; // Update anchor mapping
        _worldPositions[nodeName] = worldPos;
        _showStatus("Anchor updated 📍");
      }
    }

    // Magnetic Wall Snapping Logic
    _applyMagneticWallSnapping(selectedNode!);

    if (_checkCollision(worldPos, selectedNode)) {
      _showStatus("Warning: Overlapping furniture!");
      _performUndo();
    } else {
      _runAiAnalysis(); // Trigger AI check after significant move
    }
  }

  void onRotationStart(String nodeName) {
    _saveStateToUndo();
  }

  void onRotationChange(String nodeName) {}
  void onRotationEnd(String nodeName, vector.Matrix4 transform) async {
    final node = selectedNode;
    if (node == null || node.name != nodeName) return;

    // Extract rotation
    selectedNode!.rotation = transform.getRotation();

    // DYNAMIC RE-ANCHORING on rotation too
    var newAnchor = ARPlaneAnchor(transformation: transform);
    bool? didAddAnchor = await arAnchorManager!.addAnchor(newAnchor);
    if (didAddAnchor == true) {
      bool? didReAnchor = await arObjectManager!.addNode(
        selectedNode!,
        planeAnchor: newAnchor,
      );
      if (didReAnchor == true) {
        anchors.add(newAnchor);
        selectedNode!.position = vector.Vector3(0, 0, 0);
        _nodeAnchors[nodeName] = newAnchor; // Update anchor mapping
        _worldPositions[nodeName] = transform.getTranslation();
      }
    }
    _aiDebouncer.run(() => _runAiAnalysis());
  }

  void _togglePlanes() {
    setState(() {
      _showPlanes = !_showPlanes;
    });
    // Logic to update plane visibility in session manager if supported
    _showStatus(_showPlanes ? "Surface Guides: ON" : "Surface Guides: OFF");
  }

  void _applyMagneticWallSnapping(ARNode node) {
    if (_verticalAnchors.isEmpty) return;

    const double snapThreshold = 0.3; // 30cm
    final nodeWorldPos = _worldPositions[node.name] ?? node.position;

    ARPlaneAnchor? nearestWall;
    double minDistance = double.infinity;

    for (var wall in _verticalAnchors) {
      final wallPos = wall.transformation.getTranslation();
      final distance = wallPos.distanceTo(nodeWorldPos);
      if (distance < minDistance && distance < snapThreshold) {
        minDistance = distance;
        nearestWall = wall;
      }
    }

    if (nearestWall != null) {
      // Perform snapping: Align node to wall's plane
      // For now, we align the position. Ideally, we should align rotation too.
      final wallPos = nearestWall.transformation.getTranslation();
      final wallNormal =
          nearestWall.transformation.up; // Assuming up is normal for vertical

      // Calculate projected point on plane
      final offset = nodeWorldPos - wallPos;
      final distToPlane = offset.dot(wallNormal);
      final snappedWorldPos = nodeWorldPos - (wallNormal * distToPlane);

      // We don't update the node.position directly because it might be attached to an anchor.
      // We should ideally re-anchor to the wall, but for furniture, we stay on the floor
      // and just snap the world coordinate.
      _worldPositions[node.name] = snappedWorldPos;

      // If it's the selected node, we might need a visual jump or re-anchor
      _showStatus("Snapped to wall 🧲");
    }
  }

  void _snapToNearestWall() async {
    if (selectedNode == null || isLocked) return;
    _applyMagneticWallSnapping(selectedNode!);
  }

  // --- UNDO / REDO SYSTEM ---
  void _performUndo() {
    if (undoStack.isEmpty) {
      _showStatus("No history to undo");
      return;
    }
    redoStack.add(_getCurrentState());
    _applyState(undoStack.removeLast());
    setState(() {});
  }

  void _performRedo() {
    if (redoStack.isEmpty) {
      _showStatus("No history to redo");
      return;
    }
    undoStack.add(_getCurrentState());
    _applyState(redoStack.removeLast());
    setState(() {});
  }

  Map<String, dynamic> _getCurrentState() {
    Map<String, vector.Vector3> positions = {};
    Map<String, vector.Vector3> worldPositions = {};
    for (var node in nodes) {
      positions[node.name] = vector.Vector3.copy(node.position);
      if (_worldPositions.containsKey(node.name)) {
        worldPositions[node.name] = vector.Vector3.copy(
          _worldPositions[node.name]!,
        );
      }
    }
    return {'positions': positions, 'worldPositions': worldPositions};
  }

  void _applyState(Map<String, dynamic> state) {
    Map<String, vector.Vector3> positions = state['positions'];
    Map<String, vector.Vector3> worldPositions = state['worldPositions'] ?? {};
    for (var node in nodes) {
      if (positions.containsKey(node.name)) {
        node.position = positions[node.name]!;
      }
      if (worldPositions.containsKey(node.name)) {
        _worldPositions[node.name] = worldPositions[node.name]!;
      }
    }
  }

  void _saveStateToUndo() {
    undoStack.add(_getCurrentState());
    if (undoStack.length > ArConstants.maxUndoStackSize) undoStack.removeAt(0);
    redoStack.clear();
  }

  // --- HELPER METHODS ---
  bool _checkCollision(vector.Vector3 worldPosition, ARNode? excludingNode) {
    for (var node in nodes) {
      if (node == excludingNode) continue;

      // Use the shadow map for true world coordinates
      final nodeWorldPos = _worldPositions[node.name] ?? node.position;

      if (nodeWorldPos.distanceTo(worldPosition) <
          ArConstants.collisionThreshold) {
        return true;
      }
    }
    return false;
  }

  Future<void> removeAllAnchors() async {
    for (var anchor in anchors) {
      arAnchorManager!.removeAnchor(anchor);
    }
    anchors.clear();
    nodes.clear();
    selectedNode = null;
    undoStack.clear();
    redoStack.clear();
    setState(() {});
  }

  // --- UI HELPER WIDGETS ---
  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: () async {
        var image = await arSessionManager!.snapshot();
        showDialog(
          context: context,
          builder: (_) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image(image: image),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.camera_alt, color: Colors.black, size: 40),
        ),
      ),
    );
  }

  Widget _buildSwatchItem(int index) {
    bool isSelected = _selectedColorIndex == index;
    var material = _materialSwatches[index];

    return GestureDetector(
      onTap: () {
        setState(() => _selectedColorIndex = index);
        if (selectedNode != null) {
          _applyMaterial(index);
        }
      },
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: material['color'],
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : Colors.white24,
            width: isSelected ? 3 : 1,
          ),
          image: material['texture'] != null
              ? DecorationImage(
                  image: NetworkImage(material['texture']),
                  fit: BoxFit.cover,
                  opacity: 0.8,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withOpacity(0.5),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  Future<void> _applyMaterial(int index) async {
    if (selectedNode == null) return;

    var material = _materialSwatches[index];
    _showStatus("Applying ${material['name']} material...");

    if (material['texture'] != null) {
      await _arBridge.updateNodeTexture(
        selectedNode!.name,
        material['texture'],
      );
    } else {
      // Revert to default/base
      _showStatus("Reverted to base material.");
    }
  }

  // --- AI RECOMMENDATION LOGIC ---
  Future<void> _runAiAnalysis() async {
    if (_arController.aiAnalysisState.value.isLoading) return;
    print("AR View: Starting AI Spatial Analysis...");

    _arController.aiAnalysisState.value = ArOperationState.loading();
    // Keep local for UI updates if needed, but rely on controller for overlay
    setState(() => _isAnalyzing = true);

    try {
      // 1. Map placed nodes to metadata
      List<FurnitureMetadata> placedItems = [];
      for (var node in nodes) {
        var meta = _furniture.firstWhere(
          (f) => f['model'] == node.uri,
          orElse: () => {},
        );
        if (meta.isNotEmpty) {
          placedItems.add(
            FurnitureMetadata(
              id: meta['id'],
              name: meta['name'],
              style: meta['style'],
              baseColor: meta['color'],
              dimensions: (meta['dims'] as List)
                  .map((e) => (e as num).toDouble())
                  .toList(),
              price: (meta['price'] as num).toDouble(),
            ),
          );
        }
      }
      print("AR View: ${placedItems.length} items identified for analysis.");

      // 2. Map catalog
      List<FurnitureMetadata> catalogItems = _furniture
          .map(
            (f) => FurnitureMetadata(
              id: f['id'],
              name: f['name'],
              style: f['style'],
              baseColor: f['color'],
              dimensions: (f['dims'] as List)
                  .map((e) => (e as num).toDouble())
                  .toList(),
              price: (f['price'] as num).toDouble(),
            ),
          )
          .toList();

      // 3. Create Context
      final context = SpatialContext(
        roomArea: 15.0,
        placedFurniture: placedItems,
        availableCatalog: catalogItems,
      );

      // 4. Request Analysis
      final insights = await _aiService.analyzeRoom(context);
      print("AR View: AI Analysis returned ${insights.length} insights.");

      _arController.aiAnalysisState.value = ArOperationState.success();

      if (mounted) {
        setState(() {
          _activeInsights = insights;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      print("AR View: AI Analysis failed - $e");
      _arController.aiAnalysisState.value = ArOperationState.error(
        e.toString(),
      );
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _magicArrange(AiInsight insight) async {
    if (insight.suggestedPosition == null || nodes.isEmpty) return;

    final suggestion = insight.suggestedPosition!;
    final targetPos = vector.Vector3(
      suggestion[0],
      suggestion[1],
      suggestion[2],
    );

    _showStatus("Magic Arrange: Optimizing layout... ✨");

    // For demo, we move the last added node or a specific targeted node if we had IDs
    // Since AI is general, we find the "worst" item or just move the selected one
    final targetNode = selectedNode ?? nodes.last;

    _saveStateToUndo();

    setState(() {
      targetNode.position = targetPos;
      _worldPositions[targetNode.name] = targetPos; // Update shadow map
    });

    _showStatus("Layout optimized! How does it look?");
    _runAiAnalysis(); // Re-analyze after move
  }

  // --- PROJECT PERSISTENCE ---
  Future<void> _loadProjectItems({ARHitTestResult? groundingHit}) async {
    if (arObjectManager == null || arAnchorManager == null) return;
    if (_isLoadingItems) {
      print(
        "BREADCRUMB [$_sessionId]: _loadProjectItems BLOCKED - Already loading.",
      );
      return;
    }
    _isLoadingItems = true;
    print(
      "BREADCRUMB [$_sessionId]: _loadProjectItems STARTing for project ${_currentProject.id}",
    );

    try {
      // Give AR engine a brief moment to stabilize
      await Future.delayed(const Duration(milliseconds: 300));

      // PHASE 4: Try to resolve Cloud Anchors first
      bool cloudAnchorsResolved = false;
      // Set to track which item indices were resolved via cloud to prevent duplication
      final Set<int> resolvedIndices = {};

      print(
        "DEBUG: Checking ${_currentProject.items.length} items for Cloud Anchors...",
      );
      for (int i = 0; i < _currentProject.items.length; i++) {
        final item = _currentProject.items[i];
        if (item.cloudAnchorId != null && item.cloudAnchorId!.isNotEmpty) {
          print("DEBUG: Attempting to resolve Cloud ID: ${item.cloudAnchorId}");
          try {
            // Initiate Download
            final completer = Completer<ARAnchor?>();
            _pendingDownloads[item.cloudAnchorId!] = completer;

            bool initiated =
                await arAnchorManager!.downloadAnchor(item.cloudAnchorId!) ??
                false;

            if (!initiated) {
              print(
                "DEBUG: Failed to initiate download for ${item.cloudAnchorId}",
              );
              _pendingDownloads.remove(item.cloudAnchorId!);
              continue;
            }

            // Wait for callback with increased timeout (30s)
            final resolvedAnchor = await completer.future.timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                print("DEBUG: Timeout resolving anchor: ${item.cloudAnchorId}");
                return null; // Return null to signal timeout
              },
            );

            if (resolvedAnchor != null) {
              print(
                "DEBUG: SUCCESS! Cloud Anchor resolved: ${item.cloudAnchorId}",
              );
              _showStatus("Resolved persistent anchor 📍");
              cloudAnchorsResolved = true;
              resolvedIndices.add(i); // Mark as resolved
              anchors.add(resolvedAnchor);

              var newNode = ARNode(
                type: NodeType.webGLB,
                uri: item.modelUri,
                scale: item.scale,
                position: vector.Vector3(0, 0, 0),
                rotation: item.rotation,
                name: "furniture_${DateTime.now().microsecondsSinceEpoch}",
              );

              // Re-anchoring logic for resolved cloud anchor
              bool? didAdd = await arObjectManager!.addNode(
                newNode,
                planeAnchor: (resolvedAnchor is ARPlaneAnchor)
                    ? resolvedAnchor
                    : null,
              );

              if (didAdd == true) {
                nodes.add(newNode);
                _nodeAnchors[newNode.name] = resolvedAnchor;
                _worldPositions[newNode.name] = resolvedAnchor.transformation
                    .getTranslation();
              }
            }
          } catch (e) {
            print("DEBUG: Error processing cloud anchor: $e");
          }
        }
      }

      if (groundingHit == null && !cloudAnchorsResolved) {
        if (_currentProject.items.isNotEmpty) {
          _showStatus("Tip: Tap a surface to restore the design layout.");
        }
        return;
      }

      // Fallback: Group restoration (Relative to first item)
      // Only proceed if there are items left to restore that weren't resolved via Cloud
      if (_currentProject.items.isEmpty) return;

      final tapPos =
          groundingHit?.worldTransform.getTranslation() ??
          vector.Vector3.zero();

      // We only perform grounding if we haven't already restored EVERYTHING via cloud
      if (resolvedIndices.length == _currentProject.items.length) {
        print(
          "DEBUG: All items restored via Cloud. Skipping fallback grounding.",
        );
        if (nodes.isNotEmpty) _runAiAnalysis();
        return;
      }

      // Fallback: Group restoration (Phase 2 style) if no cloud anchors hit
      final stableTransform = vector.Matrix4.identity()..setTranslation(tapPos);

      var rootAnchor = ARPlaneAnchor(transformation: stableTransform);
      bool? didAddRoot = await arAnchorManager!.addAnchor(rootAnchor);

      if (didAddRoot != true) {
        _showStatus("Surface too unstable. Please scan more. 🛰️");
        return;
      }
      anchors.add(rootAnchor);

      final referencePos = _currentProject.items.first.position;

      for (int i = 0; i < _currentProject.items.length; i++) {
        if (resolvedIndices.contains(i)) {
          print(
            "DEBUG: Skipping item $i during fallback because it was resolved via Cloud.",
          );
          continue;
        }
        final item = _currentProject.items[i];
        if (!mounted) return;
        try {
          var localPos = item.position - referencePos;

          var newNode = ARNode(
            type: NodeType.webGLB,
            uri: item.modelUri,
            scale: item.scale,
            position: localPos,
            rotation: item.rotation,
            name: "furniture_${DateTime.now().microsecondsSinceEpoch}",
          );

          bool? didAdd = await arObjectManager!.addNode(
            newNode,
            planeAnchor: rootAnchor,
          );

          if (didAdd == true) {
            nodes.add(newNode);
            _worldPositions[newNode.name] = tapPos + localPos;
            _showStatus("Restored: ${item.modelUri.split('/').last} 🛋️");
          }
          await Future.delayed(const Duration(milliseconds: 150));
        } catch (e) {
          print("Error loading item: $e");
        }
      }

      // Scan loaded items for AI
      if (nodes.isNotEmpty) _runAiAnalysis();
    } finally {
      _isLoadingItems = false;
      print("BREADCRUMB [$_sessionId]: _loadProjectItems FINISHED");
    }
  }

  Future<void> _groundDesign(ARHitTestResult hit) async {
    // 1. Calculate Restoration Offset
    // We align the FIRST saved item to the user's grounding tap
    if (_currentProject.items.isNotEmpty) {
      final tapPos = hit.worldTransform.getTranslation();
      final originalPos = _currentProject.items.first.position;

      // Offset = (Where user tapped) - (Where first item used to be)
      // This "re-centers" the entire layout around the tap.
      setState(() {
        _restorationOffset = tapPos - originalPos;
      });
      print(
        "DEBUG: Relative Restoration Offset calculated: $_restorationOffset",
      );
    }

    setState(() {
      _isRestored = true;
    });

    _showStatus("Grounding design... Please wait. ⏳");

    // 2. Load the items immediately with Anchored Loading
    await _loadProjectItems(groundingHit: hit);

    _showStatus("Design restored successfully! ✅");
  }

  Future<void> _saveProject() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Saving project...")));

    print("DEBUG: Attempting to save project ${_currentProject.id}");
    print("DEBUG: Total nodes in scene: ${nodes.length}");

    // 0. Upload Anchors
    _showStatus("Syncing with Cloud... ☁️");
    Map<String, String> uploadedIds = {};
    try {
      uploadedIds = await _uploadAnchors();
      _showStatus("Cloud Sync Complete.");
    } catch (e) {
      print("Warning: Cloud upload failed: $e");
    }

    try {
      List<FurniturePlacement> currentItems = [];
      for (var node in nodes) {
        // Ensure name is not null
        // Use Shadow Map if available, otherwise fallback to node.position
        vector.Vector3 worldPos = _worldPositions[node.name] ?? node.position;
        print("DEBUG: Saving node ${node.name} at world pos $worldPos");

        // Handle rotation correctly (Vector4 vs Matrix3)
        vector.Vector4 rot;
        if (node.rotation is vector.Vector4) {
          rot = node.rotation as vector.Vector4;
        } else {
          final q = vector.Quaternion.fromRotation(node.rotation as dynamic);
          rot = vector.Vector4(q.x, q.y, q.z, q.w);
        }

        // Uploaded Cloud Anchor ID (if available from previous save or upload)
        // We will inject the new ones from the _uploadAnchors map passed in (if we refactor _saveProject signature)
        // BUT, better to assume _nodeAnchors has the LIVE anchors which we just uploaded.
        // Wait, _uploadAnchors needs to return the IDs.

        currentItems.add(
          FurniturePlacement(
            modelUri: node.uri,
            position: worldPos,
            rotation: rot,
            scale: node.scale,
            cloudAnchorId: uploadedIds[node.name] ?? _findExistingCloudId(node),
          ),
        );
      }

      print("DEBUG: Total items to save: ${currentItems.length}");

      _currentProject.items = currentItems;
      _currentProject.lastModified = DateTime.now();

      await _projectController.saveProject(_currentProject);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Project saved successfully! ✅")),
      );
    } catch (e, stack) {
      print("ERROR saving project: $e");
      print(stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Error Listener
  void _setupErrorListener() {
    ever(_arController.aiAnalysisState, (ArOperationState state) {
      if (state.isError) {
        _showError(
          "AI Analysis Failed",
          state.errorMessage ?? "Unknown error",
          onRetry: _runAiAnalysis,
        );
      }
    });

    ever(_arController.placementState, (ArOperationState state) {
      if (state.isError) {
        _showError("Placement Failed", state.errorMessage ?? "Unknown error");
      }
    });
  }

  double _calculateTotalBudget() {
    double totalBudget = 0;
    for (var node in nodes) {
      var meta = _furniture.firstWhere(
        (f) => f['model'] == node.uri,
        orElse: () => {},
      );
      if (meta.isNotEmpty) {
        totalBudget += (meta['price'] as num).toDouble();
      }
    }
    return totalBudget;
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color ?? Colors.black.withOpacity(0.3),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildSmallCircleButton(
    IconData icon, {
    Color color = Colors.white30,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color == Colors.white30
              ? Colors.black.withOpacity(0.3)
              : color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Future<void> _checkCloudSupport() async {
    print("BREADCRUMB: Checking Cloud Anchor Support");
    try {
      final supported = await _arBridge.isCloudAnchorSupported();
      if (!supported) {
        print("DEBUG: Cloud Anchors NOT supported on this device.");
        _showStatus("⚠️ Cloud Anchors not supported on this device");
      } else {
        print("DEBUG: Cloud Anchors supported on this device.");
      }
    } catch (e) {
      print("CRITICAL ERROR checking cloud support: $e");
    }
  }

  void _showStatus(String message) {
    print("DEBUG STATUS: $message"); // Added explicit console log
    if (mounted) {
      _arController.anchorState.value = ArOperationState(
        status: ArOperationStatus.success,
        errorMessage: message,
      );

      if (message.contains("Scan")) {
        _isScanning = true;
      } else if (message.contains("Found") || message.contains("detected")) {
        _isScanning = false;
      }
    }
  }

  void _showError(String title, String message, {VoidCallback? onRetry}) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.redAccent)),
        content: Text(message),
        backgroundColor: Colors.grey[900],
        titleTextStyle: const TextStyle(
          color: Colors.redAccent,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(color: Colors.white70),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Dismiss"),
          ),
          if (onRetry != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                onRetry();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
              ),
              child: const Text("Retry"),
            ),
        ],
      ),
    );
  }

  Future<void> _shareProject() async {
    final projectController = Get.find<ProjectController>();
    _showStatus("Phase 4: Preparing shared session... ☁️");

    // 1. Host all local anchors to Cloud
    // _uploadAnchors returns a map of NodeName -> CloudID
    final uploadedMap = await _uploadAnchors();

    // 2. Save project with new Cloud IDs
    // We update the current project data first?
    // Actually, _saveProject calls _uploadAnchors internally now.
    // If we want to share, we should probably just call _saveProject().
    // But sticking to the pattern:
    await _saveProject();
    final project = _currentProject;

    _showStatus("Room synced to Cloud! ID: ${project.id}");

    // Show a share dialog (conceptual)
    Get.defaultDialog(
      title: "Share Design",
      content: Column(
        children: [
          const Text("Share this code with your friends:"),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              project.id,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "They can use this to join your session!",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      confirm: ElevatedButton(
        onPressed: () => Get.back(),
        child: const Text("Done"),
      ),
    );
  }

  Future<Map<String, String>> _uploadAnchors() async {
    print("BREADCRUMB: _uploadAnchors starting for ${nodes.length} nodes");
    Map<String, String> uploadedIds = {};

    for (var node in nodes) {
      if (!mounted) {
        print("DEBUG: Upload aborted - widget unmounted");
        return uploadedIds;
      }

      final anchor = _nodeAnchors[node.name];
      if (anchor == null) {
        print(
          "DEBUG: No local anchor found for node ${node.name} - skipping upload",
        );
        continue;
      }

      String? existingId;
      try {
        final dynamic dAnchor = anchor;
        existingId = dAnchor.cloudAnchorId ?? dAnchor.cloudanchorid;
      } catch (e) {
        print("DEBUG: Could not read cloud ID from anchor object: $e");
      }

      if (existingId != null && existingId.isNotEmpty) {
        print(
          "DEBUG: Anchor for ${node.name} already has Cloud ID: $existingId",
        );
        uploadedIds[node.name] = existingId;
        continue;
      }

      print(
        "DEBUG: Initiating upload for anchor associated with ${node.name}...",
      );
      try {
        final completer = Completer<String>();
        _pendingUploads[anchor.name] = completer;

        final bool initiated =
            await arAnchorManager!.uploadAnchor(anchor) ?? false;

        if (initiated) {
          final cloudId = await completer.future.timeout(
            const Duration(seconds: 15), // Increased timeout
            onTimeout: () => throw TimeoutException("Upload timed out"),
          );

          print("DEBUG: Upload SUCCESS! Cloud ID: $cloudId");
          uploadedIds[node.name] = cloudId;
        } else {
          print("DEBUG: Upload initiation REJECTED by native ARCore");
          _pendingUploads.remove(anchor.name);
        }
      } catch (e) {
        print("DEBUG: Upload error for ${node.name}: $e");
        _pendingUploads.remove(anchor.name);
      }
    }
    print(
      "BREADCRUMB: _uploadAnchors session finished. Count: ${uploadedIds.length}",
    );
    return uploadedIds;
  }

  String? _findExistingCloudId(ARNode node) {
    // Helper to find ID if we didn't just upload it (e.g. from load)
    final anchor = _nodeAnchors[node.name];
    if (anchor == null) return null;

    try {
      // ignore: avoid_dynamic_calls
      final dynamic dAnchor = anchor;
      // Use try-catch or safe access for plugin-specific properties
      return dAnchor.cloudAnchorId ?? dAnchor.cloudanchorid;
    } catch (e) {
      // If the getter doesn't exist, we fall back to the anchor name
      // (which is often set to the Cloud ID for resolved anchors)
      return anchor.name.startsWith("furniture_") ? null : anchor.name;
    }
  }

  Future<void> _toggleLiDAR() async {
    if (_isLiDARSupported) {
      setState(() => _useLiDAR = !_useLiDAR);
      await _arBridge.enableDepthMesh(_useLiDAR);
      _showStatus(_useLiDAR ? "LiDAR Mesh active 🛰️" : "LiDAR Mesh disabled");
    } else {
      _showStatus("LiDAR not supported on this device 🚫");
    }
  }

  void _togglePhysics() {
    setState(() => _usePhysics = !_usePhysics);
    _showStatus(
      _usePhysics ? "Physics collisions enabled ⚡" : "Physics disabled",
    );
  }

  Future<void> _enableRealismFeatures() async {
    print("BREADCRUMB: Enabling AR Realism Features (Occlusion/Lights)");
    try {
      await _arBridge.enableOcclusion(true);
      await _arBridge.enableLightEstimation(true);
      print("DEBUG: Realism features enabled successfully");
      _showStatus("Phase 1: Visual Realism active 👁️");
    } catch (e) {
      print("DEBUG: Realism features failed (device might not support): $e");
    }
  }
}
