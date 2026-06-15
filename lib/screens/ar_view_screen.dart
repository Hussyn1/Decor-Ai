import 'dart:ui';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import 'package:decor_ar_fyp/controllers/project_controller_firestore.dart';
import '../constants/ar_constants.dart';
import '../services/firestore_project_service.dart';
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
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'dart:async';

import '../core/app_theme.dart';
import '../controllers/settings_controller.dart';
import 'package:gal/gal.dart';

import 'package:get/get.dart';
import '../widgets/ar_control_panel.dart';
import '../widgets/furniture_carousel.dart';

import '../widgets/light_estimation_badge.dart';
import 'package:ar_flutter_plugin/datatypes/surface_type.dart';
import '../services/tripoSr.dart';
import 'package:ar_flutter_plugin/models/light_estimate.dart';
import '../controllers/ar_view_controller.dart';
import '../services/ar_core_bridge.dart';
import '../controllers/catalog_controller.dart';
import '../controllers/room_scan_controller.dart';
import '../widgets/room_scan_overlay.dart';
import '../widgets/room_scan_result_panel.dart';

class ArViewScreen extends StatefulWidget {
  final Project? project;
  final String? initialModelUrl;

  const ArViewScreen({super.key, this.project, this.initialModelUrl});

  @override
  State<ArViewScreen> createState() => _ArViewScreenState();
}

class _ArViewScreenState extends State<ArViewScreen> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  final ProjectController _projectController = Get.put(ProjectController());
  late final ArViewController _arController;
  late final RoomScanController _scanController;
  final CatalogController _catalogController = Get.find<CatalogController>();
  final SettingsController _settingsController = Get.find<SettingsController>();
  Uint8List? _pendingThumbnailBytes;
  ARAnchorManager? arAnchorManager;
  final _centerSurfaceNotifier = ValueNotifier<SurfaceType>(
    SurfaceType.unknown,
  );
  ARLocationManager? arLocationManager;

  final ArCoreBridge _arBridge = ArCoreBridge();

  final Map<int, Offset> _pointerPositions = {};
  double _initialPinchDistance = 0.0;
  double _initialNodeScale = 1.0;

  final Map<String, ARAnchor> _nodeAnchors = {};

  List<Map<String, dynamic>> get _furniture =>
      _catalogController.furnitureItems;

  bool _useLiDAR = false;
  bool _usePhysics = false;
  bool _isLiDARSupported = false;
  bool _isProcessingTap = false;
  bool _isLoadingItems = false;
  bool _isModelCaching = false;
  String? _generatedModelUri;
  int _lastTapTimestamp = 0;
  bool _isCapturing = false;
  bool _showShutterFlash = false;

  late String _sessionId;

  Timer? _centerHitTimer;
  SurfaceType _currentCenterSurface = SurfaceType.unknown;
  LightEstimate? _currentLightEstimate;

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

  PlaneDetectionConfig get _planeConfig {
    final h = _settingsController.enableHorizontalPlanes.value;
    final v = _settingsController.enableVerticalPlanes.value;
    if (h && v) return PlaneDetectionConfig.horizontalAndVertical;
    if (h) return PlaneDetectionConfig.horizontal;
    if (v) return PlaneDetectionConfig.vertical;
    return PlaneDetectionConfig.none;
  }

  double get _currentScale =>
      _furniture[_selectedFurnitureIndex]['scale'] as double;

  late Project _currentProject;

  @override
  void initState() {
    super.initState();
    _arController = Get.put(ArViewController());
    _scanController = Get.put(RoomScanController());
    _sessionId =
        "session_${DateTime.now().millisecondsSinceEpoch.toString().split('').reversed.join('').substring(0, 5)}";

    print("BREADCRUMB [$_sessionId]: initState START");

    _isRestored = false;
    _isScanning = false;
    _arController.clearScene();

    if (widget.initialModelUrl != null) {
      _selectedFurnitureIndex = 0;
      _isModelCaching = true;
      _preCacheModel(widget.initialModelUrl!);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLiDARSupport());

    if (widget.project != null) {
      _currentProject = widget.project!;
      print(
        "BREADCRUMB [$_sessionId]: Loaded project: ${_currentProject.name} "
        "(ID: ${_currentProject.id}, items: ${_currentProject.items.length})",
      );
    } else {
      _currentProject = Project(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        name: "Quick Design ${DateTime.now().hour}:${DateTime.now().minute}",
        roomType: "Living Room",
        style: "Modern",
        lastModified: DateTime.now(),
        items: [],
      );
      print(
        "BREADCRUMB [$_sessionId]: Created temp project: ${_currentProject.name}",
      );
    }

    if (_currentProject.items.isEmpty) {
      _isRestored = true;
      _isScanning = true;
      print("BREADCRUMB [$_sessionId]: Empty project — skipping restoration");
    } else {
      _isRestored = false;
      _isScanning = false;
      print(
        "BREADCRUMB [$_sessionId]: Has ${_currentProject.items.length} items — entering restoration",
      );
    }

    _setupErrorListener();
  }

  Future<void> _checkLiDARSupport() async {
    _isLiDARSupported = await _arBridge.isDepthMeshSupported();
    if (mounted) setState(() {});
  }

  Future<void> _preCacheModel(String url) async {
    setState(() => _isModelCaching = true);
    try {
      final result = await FurnitureAiService.downloadToCache(url);
      if (!mounted) return;
      final filename = result.contains('/') ? result.split('/').last : result;
      setState(() {
        _generatedModelUri = filename;
        _isModelCaching = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _generatedModelUri = url;
          _isModelCaching = false;
        });
    }
  }

  @override
  void dispose() {
    print("BREADCRUMB [$_sessionId]: DISPOSING");
    _centerHitTimer?.cancel();
    arSessionManager?.dispose();
    _centerSurfaceNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: _planeConfig,
          ),

          if (_isModelCaching)
            Positioned(
              bottom: 180,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        "Preparing model for AR...",
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (selectedNode != null && !isLocked)
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) {
                _pointerPositions[e.pointer] = e.position;
                if (_pointerPositions.length == 2) {
                  final list = _pointerPositions.values.toList();
                  _initialPinchDistance = (list[0] - list[1]).distance;
                  _initialNodeScale = selectedNode!.scale.x;
                  _saveStateToUndo();
                }
              },
              onPointerMove: (e) {
                _pointerPositions[e.pointer] = e.position;
                if (_pointerPositions.length == 2 &&
                    _initialPinchDistance > 0) {
                  final list = _pointerPositions.values.toList();
                  final zoom =
                      (list[0] - list[1]).distance / _initialPinchDistance;
                  final s = (_initialNodeScale * zoom).clamp(
                    ArConstants.minScale,
                    ArConstants.maxScale,
                  );
                  selectedNode!.scale = vector.Vector3(s, s, s);
                }
              },
              onPointerUp: (e) {
                _pointerPositions.remove(e.pointer);
                if (_pointerPositions.length < 2) _initialPinchDistance = 0;
              },
              onPointerCancel: (e) {
                _pointerPositions.remove(e.pointer);
                if (_pointerPositions.length < 2) _initialPinchDistance = 0;
              },
            ),

          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: RepaintBoundary(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0x1AFFFFFF),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0x33FFFFFF), width: 1),
                ),
                child: Row(
                  children: [
                    Hero(
                      tag: 'project_ar_${_currentProject.id}',
                      child: Material(
                        color: Colors.transparent,
                        child: _buildCircleButton(
                          Icons.arrow_back_ios_new,
                          () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _currentProject.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildCircleButton(
                      Icons.save_rounded,
                      _saveProject,
                      color: AppTheme.primaryBlue.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 8),
                    _buildCircleButton(
                      Icons.share,
                      _shareProject,
                      color: Colors.greenAccent.withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Obx(
            () => ArControlPanel(
              selectedNode: selectedNode,
              isLocked: isLocked,
              showPlanes: _showPlanes,
              useLiDAR: _useLiDAR,
              usePhysics: _usePhysics,
              canUndo: undoStack.isNotEmpty,
              canRedo: redoStack.isNotEmpty,
              isLiDARSupported: _isLiDARSupported,
              onToggleLock: () => setState(() => isLocked = !isLocked),
              onUndo: _performUndo,
              onRedo: _performRedo,
              onToggleLiDAR: _toggleLiDAR,
              onTogglePhysics: _togglePhysics,
            ),
          ),

          Obx(
            () => nodes.isEmpty
                ? const SizedBox.shrink()
                : Positioned(
                    right: 20,
                    bottom: 220,
                    child: _buildSmallCircleButton(
                      Icons.delete,
                      color: Colors.redAccent.withValues(alpha: 0.8),
                      onTap: removeAllAnchors,
                    ),
                  ),
          ),

          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildGlassCircleButton(Icons.photo_library, _saveToGallery),
                const SizedBox(width: 24),
                _buildCaptureButton(),
                const SizedBox(width: 24),
                _buildGlassCircleButton(Icons.radar, () {
                  if (arSessionManager != null) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _scanController.scanRoom(arSessionManager!, nodes),
                    );
                  } else {
                    Get.snackbar(
                      "Scan Unavailable",
                      "Wait for AR session to initialize.",
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  }
                }),
              ],
            ),
          ),

          Obx(
            () => FurnitureCarousel(
              furniture: _furniture,
              selectedIndex: _selectedFurnitureIndex,
              onFurnitureSelected: (i) =>
                  setState(() => _selectedFurnitureIndex = i),
            ),
          ),

          Obx(() {
            if (_arController.anchorState.value.isLoading) {
              return Container(
                color: Colors.black45,
                child: const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryBlue),
                ),
              );
            }
            return const SizedBox.shrink();
          }),

          if (!isLocked && selectedNode == null)
            Center(
              child: ValueListenableBuilder<SurfaceType>(
                valueListenable: _centerSurfaceNotifier,
                builder: (_, surface, __) => Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _getCrosshairColorFor(surface),
                      width: 2,
                    ),
                    color: _getCrosshairColorFor(
                      surface,
                    ).withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),

          if (_currentLightEstimate != null &&
              _currentLightEstimate!.pixelIntensity < 0.2)
            Positioned(
              top: 140,
              left: 0,
              right: 0,
              child: Center(
                child: LightEstimationBadge(estimate: _currentLightEstimate!),
              ),
            ),

          Obx(
            () => _scanController.isScanning.value
                ? const AiScanningOverlay()
                : const SizedBox.shrink(),
          ),

          Obx(() {
            final result = _scanController.scanResult.value;
            return result != null
                ? RoomScanResultPanel(result: result)
                : const SizedBox.shrink();
          }),

          if (_showShutterFlash)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(color: Colors.white.withOpacity(0.85)),
              ),
            ),
        ],
      ),
    );
  }

  Color _getCrosshairColorFor(SurfaceType surface) {
    final expected =
        _furniture[_selectedFurnitureIndex]['surface'] as SurfaceType? ??
        SurfaceType.floor;
    if (surface == SurfaceType.unknown) return Colors.white;
    return surface == expected ? Colors.greenAccent : Colors.redAccent;
  }

  void onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) {
    print(
      "BREADCRUMB [$_sessionId]: onARViewCreated START for ${_currentProject.name}",
    );

    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;
    this.arLocationManager = arLocationManager;

    this.arSessionManager!.onPlaneOrPointTap = onPlaneOrPointTap;
    this.arSessionManager!.onInitialize(
      showFeaturePoints: false,
      showPlanes: _showPlanes,
      showWorldOrigin: false,
      handleTaps: true,
      handlePans: true,
      handleRotation: true,
    );
    this.arObjectManager!.onInitialize();

    this.arSessionManager!.onLightEstimate = (LightEstimate estimate) {
      if (!mounted) return;
      final crossed =
          (_currentLightEstimate?.pixelIntensity ?? 0) < 0.2 !=
          estimate.pixelIntensity < 0.2;
      if (crossed) {
        setState(() => _currentLightEstimate = estimate);
      } else {
        _currentLightEstimate = estimate;
      }
    };

    _centerHitTimer = Timer.periodic(const Duration(milliseconds: 500), (
      _,
    ) async {
      if (!mounted || this.arSessionManager == null || isLocked) return;
      try {
        final hits = await this.arSessionManager!.performHitTest(0.5, 0.5);
        if (hits.isEmpty) return;
        final valid = hits.firstWhere(
          (h) => h.type == ARHitTestResultType.plane,
          orElse: () => hits.first,
        );
        final surface = valid.surfaceType;
        if (_currentCenterSurface != surface) {
          if (surface != SurfaceType.unknown) HapticFeedback.lightImpact();
          _currentCenterSurface = surface;
          _centerSurfaceNotifier.value = surface;
        }
      } catch (_) {}
    });

    this.arObjectManager!.onNodeTap = onNodeTap;
    this.arObjectManager!.onPanStart = onPanStart;
    this.arObjectManager!.onPanChange = onPanChange;
    this.arObjectManager!.onPanEnd = onPanEnd;
    this.arObjectManager!.onRotationStart = onRotationStart;
    this.arObjectManager!.onRotationChange = onRotationChange;
    this.arObjectManager!.onRotationEnd = onRotationEnd;

    _enableRealismFeatures();

    if (widget.project == null || _currentProject.items.isEmpty) {
      _isRestored = true;
    }

    print("BREADCRUMB [$_sessionId]: onARViewCreated DONE");
  }

  Future<void> onPlaneOrPointTap(List<ARHitTestResult> hitTestResults) async {
    if (_isModelCaching) {
      _showStatus("Model still loading...");
      return;
    }

    final now = DateTime.now();
    if (_isProcessingTap ||
        _arController.isPlacementInProgress.value ||
        (_arController.lastPlacedTime.value != null &&
            now.difference(_arController.lastPlacedTime.value!).inMilliseconds <
                500)) {
      return;
    }

    _isProcessingTap = true;
    _arController.isPlacementInProgress.value = true;

    try {
      print(
        "BREADCRUMB [$_sessionId]: tap START — hits:${hitTestResults.length} restored:$_isRestored",
      );

      if (hitTestResults.isEmpty || isLocked) return;

      if (!_isRestored && widget.project != null) {
        _isRestored = true;
        await _groundDesign(hitTestResults.first);
        return;
      }

      final expectedSurface =
          _furniture[_selectedFurnitureIndex]['surface'] as SurfaceType? ??
          SurfaceType.floor;

      ARHitTestResult? validHit;
      for (final hit in hitTestResults) {
        if (hit.type != ARHitTestResultType.plane) continue;
        if (hit.surfaceType == expectedSurface) {
          validHit = hit;
          break;
        }
        if (hit.surfaceType == SurfaceType.unknown) {
          if (expectedSurface == SurfaceType.floor &&
              hit.worldTransform.entry(1, 1).abs() > 0.7) {
            validHit = hit;
            break;
          }
          if (expectedSurface == SurfaceType.wall &&
              hit.worldTransform.entry(1, 1).abs() < 0.3) {
            validHit = hit;
            break;
          }
        }
      }
      if (validHit == null) {
        _showStatus("Place on ${expectedSurface.name.toUpperCase()} surface");
        return;
      }

      final currentPos = validHit.worldTransform.getTranslation();
      if (_arController.lastPlacedPosition.value != null &&
          (_arController.lastPlacedPosition.value! - currentPos).length <
              0.05) {
        return;
      }

      if (_checkCollision(currentPos, null)) {
        _showStatus("Too close to existing furniture!");
        return;
      }

      final newAnchor = ARPlaneAnchor(transformation: validHit.worldTransform);
      if (await arAnchorManager!.addAnchor(newAnchor) != true) return;
      anchors.add(newAnchor);

      _arController.placementState.value = ArOperationState.loading();

      final bool isLocal =
          _selectedFurnitureIndex == 0 && _generatedModelUri != null
          ? !_generatedModelUri!.startsWith('http')
          : !(_furniture[_selectedFurnitureIndex]['model'] as String)
                .startsWith('http');

      String modelUri =
          _selectedFurnitureIndex == 0 && _generatedModelUri != null
          ? _generatedModelUri!
          : _furniture[_selectedFurnitureIndex]['model'] as String;

      final safeUri = (isLocal && modelUri.contains('/'))
          ? modelUri.split('/').last
          : modelUri;

      final newNode = ARNode(
        type: isLocal ? NodeType.fileSystemAppFolderGLB : NodeType.webGLB,
        uri: safeUri,
        scale: vector.Vector3(_currentScale, _currentScale, _currentScale),
        position: vector.Vector3.zero(),
        rotation: vector.Vector4(1, 0, 0, 0),
        name: "furniture_${DateTime.now().millisecondsSinceEpoch}",
      );

      final didAdd = await Future.microtask(
        () => arObjectManager!.addNode(newNode, planeAnchor: newAnchor),
      );

      if (didAdd == true) {
        print("BREADCRUMB [$_sessionId]: placed ${newNode.name}");
        nodes.add(newNode);
        _nodeAnchors[newNode.name] = newAnchor;

        _worldPositions[newNode.name] = currentPos;

        HapticFeedback.mediumImpact();
        _saveStateToUndo();
        _arController.placementState.value = ArOperationState.success();
        _arController.lastPlacedPosition.value = currentPos;
        _arController.lastPlacedTime.value = DateTime.now();
        selectedNode = newNode;
      } else {
        _arController.placementState.value = ArOperationState.error(
          "Failed to place",
        );
        _showStatus("Failed to place — try a different surface");
      }
    } catch (e) {
      print("CRITICAL ERROR in placement: $e");
    } finally {
      _isProcessingTap = false;
      _arController.isPlacementInProgress.value = false;
      print("BREADCRUMB [$_sessionId]: tap END");
    }
  }

  Future<void> _saveProject() async {
    final List<ARNode> nodeSnapshot = List<ARNode>.from(nodes);
    final Map<String, vector.Vector3> posSnapshot = {
      for (final n in nodeSnapshot)
        n.name: vector.Vector3.copy(
          _worldPositions[n.name] ?? vector.Vector3.zero(),
        ),
    };
    final Map<String, vector.Vector3> scaleSnapshot = {
      for (final n in nodeSnapshot) n.name: n.scale,
    };

    if (nodeSnapshot.isEmpty) {
      _currentProject.items = [];
      _currentProject.lastModified = DateTime.now();
      await _projectController.saveProject(_currentProject);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project saved (empty scene) ✅')),
        );
      return;
    }

    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saving...')));

    final anchor = posSnapshot[nodeSnapshot.first.name]!;

    print('[AR-SAVE] ${nodeSnapshot.length} items. Anchor (item 0): $anchor');

    final List<FurniturePlacement> placements = [];
    for (int i = 0; i < nodeSnapshot.length; i++) {
      final node = nodeSnapshot[i];
      final worldPos = posSnapshot[node.name]!;

      final relPos = worldPos - anchor;

      vector.Vector4 rot;
      try {
        final q = vector.Quaternion.fromRotation(node.rotation);
        rot = vector.Vector4(q.x, q.y, q.z, q.w);
      } catch (e) {
        print('[AR-SAVE] Error converting rotation to quaternion: $e');
        rot = vector.Vector4(0, 0, 0, 1);
      }

      print(
        '[AR-SAVE]   [$i] ${node.uri.split('/').last} world=$worldPos rel=$relPos',
      );

      placements.add(
        FurniturePlacement(
          modelUri: node.uri,
          position: relPos,
          rotation: rot,
          scale: scaleSnapshot[node.name] ?? node.scale,
        ),
      );
    }

    try {
      _currentProject.items = placements;
      _currentProject.lastModified = DateTime.now();
      await _projectController.saveProject(_currentProject);
     // Auto-capture thumbnail if none taken manually
if (_pendingThumbnailBytes == null && arSessionManager != null) {
  try {
    final image = await arSessionManager!.snapshot();
    final bytes = await _imageProviderToBytes(image);
    if (bytes.isNotEmpty) {
      _pendingThumbnailBytes = bytes;
      print('[AR-SAVE] Auto-snapshot captured: ${bytes.length} bytes');
    } else {
      print('[AR-SAVE] Auto-snapshot returned empty bytes, skipping');
    }
  } catch (e) {
    print('[AR-SAVE] Auto-snapshot failed: $e');
  }
}

      if (_pendingThumbnailBytes != null) {
        try {
          final url = await FirestoreProjectService().uploadThumbnail(
            _currentProject.id,
            _pendingThumbnailBytes!,
          );
          if (mounted) setState(() => _currentProject.thumbnailPath = url);
          _pendingThumbnailBytes = null;
          final i = _projectController.projects.indexWhere(
            (p) => p.id == _currentProject.id,
          );
          if (i >= 0) {
            _projectController.projects[i].thumbnailPath = url;
            _projectController.projects.refresh();
          }
        } catch (e) {
          print('[AR-SAVE] Thumbnail upload failed (non-fatal): $e');
        }
      }

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved ${placements.length} item${placements.length == 1 ? "" : "s"} ✅',
            ),
          ),
        );
    } catch (e, st) {
      print('[AR-SAVE] Error: $e\n$st');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  Future<void> _loadProjectItems({ARHitTestResult? groundingHit}) async {
    if (arObjectManager == null || arAnchorManager == null) return;
    if (_isLoadingItems) return;
    _isLoadingItems = true;

    print('[AR-RESTORE] Starting — ${_currentProject.items.length} items');

    try {
      if (_currentProject.items.isEmpty) return;
      if (groundingHit == null) {
        _showStatus('Tap your floor to restore the design 📍');
        return;
      }

      final tapPos = groundingHit.worldTransform.getTranslation();
      print('[AR-RESTORE] Tap pos: $tapPos');

      final rootAnchor = ARPlaneAnchor(
        transformation: vector.Matrix4.identity()..setTranslation(tapPos),
      );
      if (await arAnchorManager!.addAnchor(rootAnchor) != true) {
        _showStatus('Surface unstable — scan more floor first 🛰️');
        return;
      }
      anchors.add(rootAnchor);

      int ok = 0;
      for (final item in _currentProject.items) {
        if (!mounted) break;
        try {
          final isRemote = item.modelUri.startsWith('http');
          final safeUri = isRemote
              ? item.modelUri
              : (item.modelUri.contains('/')
                    ? item.modelUri.split('/').last
                    : item.modelUri);

          print(
            '[AR-RESTORE]   ${safeUri.split('/').last} offset=${item.position}',
          );

          final q = vector.Quaternion(
            item.rotation.x,
            item.rotation.y,
            item.rotation.z,
            item.rotation.w,
          );
          final transformation = vector.Matrix4.compose(
            item.position,
            q,
            item.scale,
          );

          final newNode = ARNode(
            type: isRemote ? NodeType.webGLB : NodeType.fileSystemAppFolderGLB,
            uri: safeUri,
            transformation: transformation,
            name: 'furniture_${DateTime.now().microsecondsSinceEpoch}',
          );

          final didAdd = await Future.microtask(
            () => arObjectManager!.addNode(newNode, planeAnchor: rootAnchor),
          );

          if (didAdd == true) {
            nodes.add(newNode);
            _nodeAnchors[newNode.name] = rootAnchor;
            _worldPositions[newNode.name] = tapPos + item.position;
            ok++;
            _showStatus('Restored $ok/${_currentProject.items.length}...');
            print('[AR-RESTORE]   ✅ world=${tapPos + item.position}');
          } else {
            print('[AR-RESTORE]   ❌ addNode returned false');
          }

          await Future.delayed(const Duration(milliseconds: 300));
        } catch (e) {
          print('[AR-RESTORE] Error: $e');
        }
      }

      _showStatus(
        ok == _currentProject.items.length
            ? 'Design restored! ✅'
            : 'Restored $ok/${_currentProject.items.length} ⚠️',
      );
    } finally {
      _isLoadingItems = false;
      print('[AR-RESTORE] Finished');
    }
  }

  Future<void> _groundDesign(ARHitTestResult hit) async {
    if (_currentProject.items.isEmpty) {
      _isRestored = true;
      return;
    }
    if (!mounted) return;

    final shouldRestore =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text("Resume design?"),
            content: Text(
              "${_currentProject.items.length} saved items.\n\n"
              "Tap where you want to place them.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  "Start fresh",
                  style: TextStyle(color: Colors.red),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Restore items"),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldRestore) {
      _currentProject.items.clear();
      _isRestored = true;
      _showStatus("Starting fresh 🌱");
      return;
    }

    await _loadProjectItems(groundingHit: hit);
    _isRestored = true;
  }

  void onNodeTap(List<String> nodeNames) {
    if (isLocked || nodeNames.isEmpty) return;
    final name = nodeNames.first;
    if (name.contains('selection_ring')) return;
    try {
      selectedNode = nodes.firstWhere((n) => n.name == name);
    } catch (_) {}
  }

  void onPanStart(String nodeName) {
    if (isLocked) {
      _showStatus("Locked 🔒");
      return;
    }
    _saveStateToUndo();
  }

  void onPanChange(String nodeName) {}
  void onPanEnd(String nodeName, vector.Matrix4 transform) {
    final node = selectedNode;
    if (node == null || node.name != nodeName) return;
    if (isLocked) {
      _performUndo();
      _showStatus("Locked 🔒");
      return;
    }

    final anchor = _nodeAnchors[nodeName];
    final worldPos = anchor != null
        ? (anchor.transformation * transform).getTranslation()
        : transform.getTranslation();

    _worldPositions[nodeName] = worldPos;
    _nodeAnchors[nodeName] = _nodeAnchors[nodeName] ?? anchors.last;
    _applyMagneticWallSnapping(selectedNode!);
    if (_checkCollision(worldPos, selectedNode)) {
      _showStatus("Overlapping furniture!");
      _performUndo();
    }
  }

  void onRotationStart(String n) {
    if (isLocked) {
      _showStatus("Locked 🔒");
      return;
    }
    _saveStateToUndo();
  }

  void onRotationChange(String n) {}
  void onRotationEnd(String nodeName, vector.Matrix4 transform) {
    final node = selectedNode;
    if (node == null || node.name != nodeName) return;
    if (isLocked) {
      _performUndo();
      _showStatus("Locked 🔒");
      return;
    }

    selectedNode!.rotation = transform.getRotation();

    final anchor = _nodeAnchors[nodeName];
    final worldPos = anchor != null
        ? (anchor.transformation * transform).getTranslation()
        : transform.getTranslation();

    _worldPositions[nodeName] = worldPos;
  }

  void _performUndo() {
    if (undoStack.isEmpty) {
      _showStatus("Nothing to undo");
      return;
    }
    redoStack.add(_getCurrentState());
    _applyState(undoStack.removeLast());
    setState(() {});
  }

  void _performRedo() {
    if (redoStack.isEmpty) {
      _showStatus("Nothing to redo");
      return;
    }
    undoStack.add(_getCurrentState());
    _applyState(redoStack.removeLast());
    setState(() {});
  }

  Map<String, dynamic> _getCurrentState() {
    return {
      'positions': {
        for (final n in nodes) n.name: vector.Vector3.copy(n.position),
      },
      'worldPositions': {
        for (final n in nodes)
          if (_worldPositions.containsKey(n.name))
            n.name: vector.Vector3.copy(_worldPositions[n.name]!),
      },
    };
  }

  void _applyState(Map<String, dynamic> state) {
    final positions = state['positions'] as Map<String, vector.Vector3>;
    final world = state['worldPositions'] as Map<String, vector.Vector3>? ?? {};
    for (final node in nodes) {
      if (positions.containsKey(node.name))
        node.position = positions[node.name]!;
      if (world.containsKey(node.name))
        _worldPositions[node.name] = world[node.name]!;
    }
  }

  void _saveStateToUndo() {
    undoStack.add(_getCurrentState());
    if (undoStack.length > ArConstants.maxUndoStackSize) undoStack.removeAt(0);
    redoStack.clear();
  }

  bool _checkCollision(vector.Vector3 pos, ARNode? exclude) {
    for (final node in nodes) {
      if (node == exclude) continue;
      if ((_worldPositions[node.name] ?? node.position).distanceTo(pos) <
          ArConstants.collisionThreshold)
        return true;
    }
    return false;
  }

  void _applyMagneticWallSnapping(ARNode node) {
    if (_verticalAnchors.isEmpty) return;
    const threshold = 0.3;
    final pos = _worldPositions[node.name] ?? node.position;
    ARPlaneAnchor? nearest;
    double minDist = double.infinity;
    for (final wall in _verticalAnchors) {
      final d = wall.transformation.getTranslation().distanceTo(pos);
      if (d < minDist && d < threshold) {
        minDist = d;
        nearest = wall;
      }
    }
    if (nearest != null) {
      final wallPos = nearest.transformation.getTranslation();
      final normal = nearest.transformation.up;
      final dist = (pos - wallPos).dot(normal);
      _worldPositions[node.name] = pos - (normal * dist);
      _showStatus("Snapped to wall 🧲");
    }
  }

  Future<void> removeAllAnchors() async {
    for (final a in anchors) arAnchorManager!.removeAnchor(a);
    anchors.clear();
    nodes.clear();
    selectedNode = null;
    undoStack.clear();
    redoStack.clear();
    setState(() {});
  }

  void _setupErrorListener() {
    ever(_arController.placementState, (ArOperationState state) {
      if (state.isError)
        _showError("Placement Failed", state.errorMessage ?? "Unknown");
    });
  }

  void _showStatus(String message) {
    print("STATUS: $message");
    if (mounted) {
      _arController.anchorState.value = ArOperationState(
        status: ArOperationStatus.success,
        errorMessage: message,
      );
      if (message.contains("Scan"))
        _isScanning = true;
      else if (message.contains("Found") || message.contains("detected"))
        _isScanning = false;
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
    await _saveProject();
    Get.defaultDialog(
      title: 'Share Design',
      content: Column(
        children: [
          const Text('Share this code:'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _currentProject.id,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      confirm: ElevatedButton(
        onPressed: () => Get.back(),
        child: const Text('Done'),
      ),
    );
  }

  Future<void> _toggleLiDAR() async {
    if (_isLiDARSupported) {
      setState(() => _useLiDAR = !_useLiDAR);
      await _arBridge.enableDepthMesh(_useLiDAR);
      _showStatus(_useLiDAR ? "LiDAR active 🛰️" : "LiDAR disabled");
    } else {
      _showStatus("LiDAR not supported 🚫");
    }
  }

  void _togglePhysics() {
    setState(() => _usePhysics = !_usePhysics);
    _showStatus(_usePhysics ? "Physics enabled ⚡" : "Physics disabled");
  }

  Future<void> _enableRealismFeatures() async {
    try {
      await _arBridge.enableOcclusion(true);
      await _arBridge.enableLightEstimation(
        _settingsController.enableLightingEstimation.value,
      );
      _showStatus("Phase 1: Visual Realism active 👁️");
      print("DEBUG: Realism features enabled successfully");
    } catch (e) {
      print("DEBUG: Realism features unavailable: $e");
    }
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: _isCapturing
          ? null
          : () async {
              setState(() {
                _isCapturing = true;
                _showShutterFlash = true;
              });
              HapticFeedback.mediumImpact();
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) setState(() => _showShutterFlash = false);
              });
              try {
                final image = await arSessionManager!.snapshot();
                if (!mounted) return;
                try {
                  final bytes = await _imageProviderToBytes(image);
                  _pendingThumbnailBytes = bytes;
                  if (!_currentProject.id.startsWith('temp_'))
                    _uploadThumbnail(bytes);
                } catch (e) {
                  print("Snapshot encode error: $e");
                }
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    backgroundColor: Colors.grey[900],
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          child: Image(image: image),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              "Close",
                              style: TextStyle(
                                color: Colors.cyan,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } catch (e) {
                _showStatus("Snapshot failed: $e");
              } finally {
                if (mounted) setState(() => _isCapturing = false);
              }
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
          child: _isCapturing
              ? const Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  ),
                )
              : const Icon(Icons.camera_alt, color: Colors.black, size: 40),
        ),
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap, {Color? color}) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color ?? const Color(0x26FFFFFF),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildGlassCircleButton(IconData icon, VoidCallback onTap) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0x26FFFFFF),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildSmallCircleButton(
    IconData icon, {
    Color color = Colors.white30,
    VoidCallback? onTap,
  }) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color == Colors.white30
                ? const Color(0x26FFFFFF)
                : color.withValues(alpha: 0.6),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Future<Uint8List> _imageProviderToBytes(ImageProvider provider) async {
    final completer = Completer<Uint8List>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo frame, bool sync) async {
        final data = await frame.image.toByteData(format: ImageByteFormat.png);
        stream.removeListener(listener);
        if (data != null)
          completer.complete(data.buffer.asUint8List());
        else
          completer.completeError(Exception("Image to bytes failed"));
      },
      onError: (e, st) {
        stream.removeListener(listener);
        completer.completeError(e);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  Future<void> _uploadThumbnail(Uint8List bytes) async {
    try {
      final url = await FirestoreProjectService().uploadThumbnail(
        _currentProject.id,
        bytes,
      );
      if (mounted) setState(() => _currentProject.thumbnailPath = url);

      // Update the controller's cached list so home screen shows it immediately
      final i = _projectController.projects.indexWhere(
        (p) => p.id == _currentProject.id,
      );
      if (i >= 0) {
        _projectController.projects[i].thumbnailPath = url;
        _projectController.projects.refresh(); // triggers Obx rebuild
      }
    } catch (e) {
      print("[AR-LOG] Thumbnail upload failed: $e");
    }
  }

  Future<void> _saveToGallery() async {
    if (arSessionManager == null) {
      Get.snackbar('Not Ready', 'AR not ready');
      return;
    }
    setState(() => _isCapturing = true);
    HapticFeedback.mediumImpact();
    try {
      final image = await arSessionManager!.snapshot();
      final bytes = await _imageProviderToBytes(image);
      await Gal.putImageBytes(
        bytes,
        name: 'DecorAR_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      Get.snackbar(
        'Saved!',
        'Snapshot saved to gallery 📸',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.black87,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not save: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }
}
