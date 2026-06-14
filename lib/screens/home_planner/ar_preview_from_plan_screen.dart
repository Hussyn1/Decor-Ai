import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'dart:math' as math;
import '../../controllers/home_planner_controller.dart';
import '../../controllers/catalog_controller.dart';
import '../../models/room_dimensions.dart';
import '../../core/app_theme.dart';








class ArPreviewFromPlanScreen extends StatefulWidget {
  const ArPreviewFromPlanScreen({super.key});

  @override
  State<ArPreviewFromPlanScreen> createState() =>
      _ArPreviewFromPlanScreenState();
}

class _ArPreviewFromPlanScreenState extends State<ArPreviewFromPlanScreen> {
  ARSessionManager? _session;
  ARObjectManager? _objects;
  ARAnchorManager? _anchors;

  final HomePlannerController _planner = Get.find<HomePlannerController>();
  final CatalogController _catalog = Get.find<CatalogController>();

  bool _grounded = false; 
  bool _spawning = false; 
  int _spawnedCount = 0;
  int _totalToSpawn = 0;
  String _statusMsg = 'Tap your floor to place the room';

  
  final List<ARNode> _spawnedNodes = [];
  final List<ARAnchor> _spawnedAnchors = [];

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          
          ARView(
            onARViewCreated: _onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontal,
          ),

          
          Positioned(
            top: 52,
            left: 16,
            right: 16,
            child: Row(
              children: [
                
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.grid_on, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text(
                        '3D Room Preview',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                
                if (_grounded)
                  GestureDetector(
                    onTap: _resetScene,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.refresh,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          
          Positioned(
            bottom: 80,
            left: 24,
            right: 24,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _spawning ? _buildProgressBar() : _buildStatusBadge(),
            ),
          ),

          
          if (_grounded && !_spawning)
            Positioned(top: 120, right: 16, child: _buildLegend()),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Center(
      child: Container(
        key: ValueKey(_statusMsg),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.touch_app, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Text(
              _statusMsg,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final pct = _totalToSpawn == 0 ? 0.0 : _spawnedCount / _totalToSpawn;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Placing room... $_spawnedCount / $_totalToSpawn',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryBlue),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _legendItem(Colors.white.withOpacity(0.5), 'Wall'),
          const SizedBox(height: 6),
          _legendItem(AppTheme.primaryBlue.withOpacity(0.7), 'Furniture'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ],
  );

  

  void _onARViewCreated(
    ARSessionManager session,
    ARObjectManager objects,
    ARAnchorManager anchors,
    ARLocationManager location,
  ) {
    _session = session;
    _objects = objects;
    _anchors = anchors;

    session.onPlaneOrPointTap = _onTap;
    session.onInitialize(
      showFeaturePoints: true,
      showPlanes: true,
      showWorldOrigin: false,
      handleTaps: true,
      handlePans: false,
      handleRotation: false,
    );
    objects.onInitialize();
  }

  

  Future<void> _onTap(List<ARHitTestResult> hits) async {
    if (_grounded || _spawning) return;
    if (hits.isEmpty) return;

    final hit = hits.firstWhere(
      (h) => h.type == ARHitTestResultType.plane,
      orElse: () => hits.first,
    );

    setState(() {
      _grounded = true;
      _spawning = true;
      _statusMsg = 'Placing room...';
    });

    final tapPos = hit.worldTransform.getTranslation();
    await _spawnRoom(tapPos);

    setState(() {
      _spawning = false;
      _statusMsg = 'Walk around your room 🏠';
    });
  }

  

  Future<void> _spawnRoom(vector.Vector3 tapPos) async {
    final rd = _planner.roomDimensions.value;
    if (rd == null || _objects == null || _anchors == null) return;

    
    final furnitureEls = rd.elements
        .where((e) => e.type == FloorPlanElementType.furniture)
        .toList();

    
    _totalToSpawn = 4 + furnitureEls.length;
    _spawnedCount = 0;

    final W = rd.widthMeters;
    final D = rd.depthMeters;
    final wallH = rd.heightMeters ?? 2.4;
    const wallT = 0.05; 

    
    
    
    
    
    const cubeUri =
        'https://github.com/KhronosGroup/glTF-Sample-Models/raw/main/2.0/Box/glTF-Binary/Box.glb';

    
    final walls = [
      
      _WallDef(
        pos: vector.Vector3(tapPos.x, tapPos.y + wallH / 2, tapPos.z),
        scale: vector.Vector3(W, wallH, wallT),
        label: 'North',
      ),
      
      _WallDef(
        pos: vector.Vector3(tapPos.x, tapPos.y + wallH / 2, tapPos.z + D),
        scale: vector.Vector3(W, wallH, wallT),
        label: 'South',
      ),
      
      _WallDef(
        pos: vector.Vector3(
          tapPos.x - W / 2,
          tapPos.y + wallH / 2,
          tapPos.z + D / 2,
        ),
        scale: vector.Vector3(wallT, wallH, D),
        label: 'West',
      ),
      
      _WallDef(
        pos: vector.Vector3(
          tapPos.x + W / 2,
          tapPos.y + wallH / 2,
          tapPos.z + D / 2,
        ),
        scale: vector.Vector3(wallT, wallH, D),
        label: 'East',
      ),
    ];

    for (final wall in walls) {
      await _spawnNode(
        uri: cubeUri,
        isRemote: true,
        position: wall.pos,
        scale: wall.scale,
        rotation: vector.Vector4(0, 0, 0, 1),
        name: 'wall_${wall.label}',
        anchorAt: vector.Vector3(wall.pos.x, tapPos.y, wall.pos.z),
      );
      setState(() => _spawnedCount++);
      await Future.delayed(const Duration(milliseconds: 200));
    }

    
    for (final el in furnitureEls) {
      final catalogMatch = _catalog.furnitureItems.firstWhereOrNull((item) {
        final dims = item['dims'] as List?;
        if (dims == null || dims.length < 2) return false;
        return ((dims[0] as num).toDouble() - el.widthMeters).abs() < 0.5;
      });

      final uri =
          catalogMatch?['model'] as String? ??
          'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/SheenChair/glTF-Binary/SheenChair.glb';
      final isRemote = uri.startsWith('http');
      final safeUri = isRemote
          ? uri
          : (uri.contains('/') ? uri.split('/').last : uri);

      
      
      final worldX = tapPos.x + (el.xMeters - W / 2);
      final worldZ = tapPos.z + (el.zMeters - D / 2);
      final worldPos = vector.Vector3(worldX, tapPos.y, worldZ);

      final scale = catalogMatch != null
          ? vector.Vector3(1.0, 1.0, 1.0)
          : vector.Vector3(
              el.widthMeters.clamp(0.3, 2.0),
              1.0,
              el.depthMeters.clamp(0.3, 2.0),
            );

      await _spawnNode(
        uri: safeUri,
        isRemote: isRemote,
        position: worldPos,
        scale: scale,
        rotation: vector.Vector4(0, 0, 0, 1),
        name: 'furniture_${el.id}',
        anchorAt: worldPos,
      );

      setState(() => _spawnedCount++);
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  Future<void> _spawnNode({
    required String uri,
    required bool isRemote,
    required vector.Vector3 position,
    required vector.Vector3 scale,
    required vector.Vector4 rotation,
    required String name,
    required vector.Vector3 anchorAt,
  }) async {
    if (_objects == null || _anchors == null) return;

    try {
      
      final anchorMatrix = vector.Matrix4.identity()..setTranslation(anchorAt);
      final anchor = ARPlaneAnchor(transformation: anchorMatrix);
      if (await _anchors!.addAnchor(anchor) != true) return;
      _spawnedAnchors.add(anchor);

      
      final relPos = position - anchorAt;

      final node = ARNode(
        type: isRemote ? NodeType.webGLB : NodeType.fileSystemAppFolderGLB,
        uri: uri,
        position: relPos,
        scale: scale,
        rotation: rotation,
        name: name,
      );

      final ok = await _objects!.addNode(node, planeAnchor: anchor);
      if (ok == true) _spawnedNodes.add(node);
    } catch (e) {
      print('[AR-PLAN] Spawn error for $name: $e');
    }
  }

  Future<void> _resetScene() async {
    for (final a in _spawnedAnchors) _anchors?.removeAnchor(a);
    _spawnedAnchors.clear();
    _spawnedNodes.clear();
    setState(() {
      _grounded = false;
      _spawning = false;
      _spawnedCount = 0;
      _totalToSpawn = 0;
      _statusMsg = 'Tap your floor to place the room';
    });
  }
}



class _WallDef {
  final vector.Vector3 pos;
  final vector.Vector3 scale;
  final String label;
  const _WallDef({required this.pos, required this.scale, required this.label});
}
