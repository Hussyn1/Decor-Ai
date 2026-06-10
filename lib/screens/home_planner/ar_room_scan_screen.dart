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
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import '../../controllers/home_planner_controller.dart';
import '../../core/app_theme.dart';
import 'floor_plan_editor_screen.dart';

class ArRoomScanScreen extends StatefulWidget {
  const ArRoomScanScreen({super.key});
  @override State<ArRoomScanScreen> createState() => _ArRoomScanScreenState();
}

class _ArRoomScanScreenState extends State<ArRoomScanScreen> {
  ARSessionManager? _session;
  ARObjectManager? _objectManager;
  ARAnchorManager? _anchorManager;
  final _controller = Get.put(HomePlannerController());
  final List<ARNode> _dotNodes = [];
  bool _sessionReady = false;

  @override
  void dispose() { _session?.dispose(); super.dispose(); }

  void _onARViewCreated(ARSessionManager s, ARObjectManager o,
      ARAnchorManager a, ARLocationManager l) {
    _session = s; _objectManager = o; _anchorManager = a;
    s.onInitialize(showFeaturePoints: true, showPlanes: true,
        showWorldOrigin: false, handleTaps: false);
    o.onInitialize();
    Future.delayed(const Duration(seconds: 1),
        () => setState(() => _sessionReady = true));
  }

  Future<void> _placeCorner() async {
    if (_session == null || !_sessionReady) return;
    final hits = await _session!.performHitTest(0.5, 0.5);
    if (hits.isEmpty) return;
    final hit = hits.firstWhere(
      (h) => h.type == ARHitTestResultType.plane,
      orElse: () => hits.first,
    );
    final pos = hit.worldTransform.getTranslation();
    _controller.addCornerPoint(pos);

    // Place a visual dot
    final anchor = ARPlaneAnchor(transformation: hit.worldTransform);
    await _anchorManager!.addAnchor(anchor);
    final node = ARNode(
      type: NodeType.localGLTF2,
      uri: 'assets/models/sphere.gltf',
      scale: vector.Vector3(0.05, 0.05, 0.05),
      position: vector.Vector3.zero(),
      rotation: vector.Vector4(1, 0, 0, 0),
      name: 'corner_${_dotNodes.length}',
    );
    await _objectManager!.addNode(node, planeAnchor: anchor);
    _dotNodes.add(node);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        ARView(
          onARViewCreated: _onARViewCreated,
          planeDetectionConfig: PlaneDetectionConfig.horizontal,
        ),

        // Crosshair
        const Center(child: _Crosshair()),

        // Top bar
        Positioned(top: 52, left: 16, right: 16, child: Row(children: [
          _CircleBtn(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
          const SizedBox(width: 12),
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: Colors.black54,
                borderRadius: BorderRadius.circular(20)),
            child: Obx(() => Text(
              _controller.cornerPoints.isEmpty
                ? 'Tap a floor corner to start'
                : '${_controller.cornerPoints.length} corners placed'
                  '${_controller.cornerPoints.length >= 4 ? " · Ready!" : ""}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            )),
          )),
        ])),

        // Instructions
        Obx(() => _controller.cornerPoints.length < 4
          ? Positioned(bottom: 160, left: 0, right: 0, child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(color: Colors.black54,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                  'Walk to each wall corner and tap ⊕',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              )))
          : const SizedBox.shrink()),

        // Bottom controls
        Positioned(bottom: 40, left: 0, right: 0, child: Column(children: [
          // Place button
          GestureDetector(
            onTap: _sessionReady ? _placeCorner : null,
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _sessionReady ? AppTheme.primaryBlue : Colors.white24,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(height: 16),
          // Proceed button
          Obx(() => AnimatedOpacity(
            opacity: _controller.cornerPoints.length >= 4 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: ElevatedButton.icon(
              onPressed: _controller.cornerPoints.length >= 4
                ? () => Get.to(() => const FloorPlanEditorScreen())
                : null,
              icon: const Icon(Icons.grid_on),
              label: const Text('Build floor plan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successGreen,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
            ),
          )),
          const SizedBox(height: 8),
          // Skip: enter manually
          TextButton(
            onPressed: () => _showManualEntry(),
            child: const Text('Enter dimensions manually',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ])),
      ]),
    );
  }

  void _showManualEntry() {
    final wCtrl = TextEditingController(text: '4.0');
    final dCtrl = TextEditingController(text: '3.5');
    showModalBottomSheet(context: context, builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Room dimensions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: TextField(controller: wCtrl,
            decoration: const InputDecoration(labelText: 'Width (m)', border: OutlineInputBorder()),
            keyboardType: TextInputType.number)),
          const SizedBox(width: 16),
          Expanded(child: TextField(controller: dCtrl,
            decoration: const InputDecoration(labelText: 'Depth (m)', border: OutlineInputBorder()),
            keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            _controller.setManualDimensions(
              double.tryParse(wCtrl.text) ?? 4.0,
              double.tryParse(dCtrl.text) ?? 3.5,
            );
            Navigator.pop(context);
            Get.to(() => const FloorPlanEditorScreen());
          },
          child: const Text('Continue'),
        ),
      ]),
    ));
  }
}

class _Crosshair extends StatelessWidget {
  const _Crosshair();
  @override Widget build(BuildContext context) => Container(
    width: 28, height: 28,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
      color: Colors.white24,
    ),
    child: const Center(child: Icon(Icons.add, color: Colors.white, size: 14)),
  );
}

class _CircleBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _CircleBtn(this.icon, this.onTap);
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 20)));
}