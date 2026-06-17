import 'dart:math' as math;

import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import '../../controllers/home_planner_controller.dart';
import '../../core/app_theme.dart';
import 'scan_measurement_review_screen.dart';

class ArRoomScanScreen extends StatefulWidget {
  const ArRoomScanScreen({super.key});
  @override
  State<ArRoomScanScreen> createState() => _ArRoomScanScreenState();
}

class _ArRoomScanScreenState extends State<ArRoomScanScreen> {
  ARSessionManager? _session;
  ARObjectManager? _objectManager;
  ARAnchorManager? _anchorManager;
  final _controller = Get.put(HomePlannerController());
  final List<ARNode> _dotNodes = [];
  final List<ARNode> _lineNodes = [];
  bool _sessionReady = false;
  bool _isPlacingCorner = false;

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  void _onARViewCreated(
    ARSessionManager s,
    ARObjectManager o,
    ARAnchorManager a,
    ARLocationManager l,
  ) {
    _session = s;
    _objectManager = o;
    _anchorManager = a;
    s.onInitialize(
      showFeaturePoints: true,
      showPlanes: true,
      showWorldOrigin: false,
      handleTaps: false,
    );
    o.onInitialize();
    Future.delayed(
      const Duration(seconds: 1),
      () {
        if (mounted) setState(() => _sessionReady = true);
      },
    );
  }

  Future<void> _placeCorner() async {
    if (_session == null ||
        _objectManager == null ||
        _anchorManager == null ||
        !_sessionReady ||
        _isPlacingCorner) {
      return;
    }

    _isPlacingCorner = true;
    try {
      final hits = await _session!.performHitTest(0.5, 0.5);
      if (hits.isEmpty) {
        _showScanMessage('No floor found. Move the phone slowly and try again.');
        return;
      }

      final hit = hits.firstWhere(
        (h) => h.type == ARHitTestResultType.plane,
        orElse: () => hits.first,
      );
      final pos = hit.worldTransform.getTranslation();
      final previousPoint = _controller.cornerPoints.isNotEmpty
          ? vector.Vector3.copy(_controller.cornerPoints.last)
          : null;

      _controller.addCornerPoint(pos);

      final anchorTransform = vector.Matrix4.identity()..setTranslation(pos);
      final anchor = ARPlaneAnchor(transformation: anchorTransform);
      final didAddAnchor = await _anchorManager!.addAnchor(anchor);

      if (didAddAnchor == true) {
        final node = ARNode(
          type: NodeType.localGLTF2,
          uri: 'assets/models/sphere.gltf',
          scale: vector.Vector3(0.08, 0.08, 0.08),
          position: vector.Vector3.zero(),
          rotation: vector.Vector4(1, 0, 0, 0),
          name: 'corner_${_dotNodes.length}',
        );
        final didAddNode = await _objectManager!.addNode(
          node,
          planeAnchor: anchor,
        );
        if (didAddNode == true) {
          _dotNodes.add(node);
        } else {
          _showScanMessage('Point saved, but AR marker could not render.');
        }
      } else {
        _showScanMessage('Point saved, but AR anchor was unstable.');
      }

      if (previousPoint != null) {
        await _addLineNode(previousPoint, pos);
      }

      if (_controller.cornerPoints.length == 4) {
        await _addLineNode(pos, _controller.cornerPoints.first);
      }

      if (mounted) setState(() {});
    } catch (e) {
      _showScanMessage('Could not place point: $e');
    } finally {
      _isPlacingCorner = false;
    }
  }

  Future<void> _addLineNode(vector.Vector3 from, vector.Vector3 to) async {
    final dist = from.distanceTo(to);
    if (dist < 0.02 || _objectManager == null) return;

    final zAxis = (to - from).normalized();
    var up = vector.Vector3(0, 1, 0);
    if (zAxis.dot(up).abs() > 0.99) up = vector.Vector3(1, 0, 0);
    final xAxis = up.cross(zAxis).normalized();
    final yAxis = zAxis.cross(xAxis).normalized();
    final rotation = vector.Matrix4.columns(
      vector.Vector4(xAxis.x, xAxis.y, xAxis.z, 0),
      vector.Vector4(yAxis.x, yAxis.y, yAxis.z, 0),
      vector.Vector4(zAxis.x, zAxis.y, zAxis.z, 0),
      vector.Vector4(0, 0, 0, 1),
    );
    final mid = (from + to) * 0.5;
    final transform = vector.Matrix4.translation(mid) * rotation;
    final node = ARNode(
      type: NodeType.localGLTF2,
      uri: 'assets/models/sphere.gltf',
      transformation: transform,
      scale: vector.Vector3(0.018, 0.018, dist),
      name: 'wall_line_${_lineNodes.length}',
    );
    final didAddNode = await _objectManager!.addNode(node);
    if (didAddNode == true) _lineNodes.add(node);
  }

  void _showScanMessage(String message) {
    if (!mounted) return;
    Get.snackbar(
      'Room scan',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.black87,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
    );
  }

  Future<void> _openFloorPlan() async {
    if (!_controller.hasUsableScannedDimensions) {
      _showScanMessage(
        'The scanned shape is too small or flat. Place four different floor corners.',
      );
      return;
    }

    final room = _controller.roomDimensions.value!;
    await _releaseArSession();
    if (!mounted) return;
    Get.off(
      () => ScanMeasurementReviewScreen(
        widthMeters: room.widthMeters,
        depthMeters: room.depthMeters,
        heightMeters: room.heightMeters,
        points: List<vector.Vector3>.from(_controller.cornerPoints),
      ),
    );
  }

  Future<void> _releaseArSession() async {
    final session = _session;
    _session = null;
    _objectManager = null;
    _anchorManager = null;
    _sessionReady = false;
    await (session?.dispose() ?? Future.value()).timeout(
      const Duration(milliseconds: 700),
      onTimeout: () {},
    );
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

          const Center(child: _Crosshair()),

          Obx(
            () => _controller.cornerPoints.isEmpty
                ? const SizedBox.shrink()
                : Positioned(
                    right: 16,
                    top: 116,
                    child: _TracePreview(points: _controller.cornerPoints),
                  ),
          ),

          Positioned(
            top: 52,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _CircleBtn(
                  Icons.arrow_back_ios_new,
                  () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Obx(
                      () => Text(
                        _controller.cornerPoints.isEmpty
                            ? 'Tap a floor corner to start'
                            : '${_controller.cornerPoints.length} corners placed'
                                  '${_controller.cornerPoints.length >= 4 ? " - Ready!" : ""}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Obx(
            () => _controller.cornerPoints.length < 4
                ? Positioned(
                    bottom: 160,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Walk to each wall corner and tap +',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _sessionReady ? _placeCorner : null,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _sessionReady
                          ? AppTheme.primaryBlue
                          : Colors.white24,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(height: 16),

                Obx(
                  () => AnimatedOpacity(
                    opacity: _controller.cornerPoints.length >= 4 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: ElevatedButton.icon(
                      onPressed: _controller.cornerPoints.length >= 4
                          ? _openFloorPlan
                          : null,
                      icon: const Icon(Icons.grid_on),
                      label: const Text('Review measurements'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                TextButton(
                  onPressed: () => _showManualEntry(),
                  child: const Text(
                    'Enter dimensions manually',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showManualEntry() {
    final wCtrl = TextEditingController(text: '4.0');
    final dCtrl = TextEditingController(text: '3.5');
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Room dimensions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: wCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Width (m)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: dCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Depth (m)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                _controller.setManualDimensions(
                  double.tryParse(wCtrl.text) ?? 4.0,
                  double.tryParse(dCtrl.text) ?? 3.5,
                );
                final room = _controller.roomDimensions.value;
                if (room == null) return;
                Navigator.pop(context);
                await _releaseArSession();
                if (!mounted) return;
                Get.off(
                  () => ScanMeasurementReviewScreen(
                    widthMeters: room.widthMeters,
                    depthMeters: room.depthMeters,
                    heightMeters: room.heightMeters,
                    points: List<vector.Vector3>.from(_controller.cornerPoints),
                  ),
                );
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Crosshair extends StatelessWidget {
  const _Crosshair();
  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
      color: Colors.white24,
    ),
    child: const Center(child: Icon(Icons.add, color: Colors.white, size: 14)),
  );
}

class _TracePreview extends StatelessWidget {
  final List<vector.Vector3> points;

  const _TracePreview({required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: CustomPaint(
        painter: _TracePainter(points: List<vector.Vector3>.from(points)),
      ),
    );
  }
}

class _TracePainter extends CustomPainter {
  final List<vector.Vector3> points;

  const _TracePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final xs = points.map((p) => p.x).toList();
    final zs = points.map((p) => p.z).toList();
    final minX = xs.reduce(math.min);
    final maxX = xs.reduce(math.max);
    final minZ = zs.reduce(math.min);
    final maxZ = zs.reduce(math.max);
    final spanX = math.max(maxX - minX, 0.25);
    final spanZ = math.max(maxZ - minZ, 0.25);
    final scale = math.min(size.width / spanX, size.height / spanZ) * 0.76;
    final usedW = spanX * scale;
    final usedH = spanZ * scale;
    final origin = Offset((size.width - usedW) / 2, (size.height - usedH) / 2);

    Offset toCanvas(vector.Vector3 p) {
      return Offset(
        origin.dx + (p.x - minX) * scale,
        origin.dy + (p.z - minZ) * scale,
      );
    }

    final linePaint = Paint()
      ..color = AppTheme.successGreen
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final guidePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    final fillPaint = Paint()
      ..color = AppTheme.successGreen.withOpacity(0.14)
      ..style = PaintingStyle.fill;

    final rect = Rect.fromLTWH(origin.dx, origin.dy, usedW, usedH);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      guidePaint..style = PaintingStyle.stroke,
    );

    final canvasPoints = points.map(toCanvas).toList();
    if (canvasPoints.length >= 2) {
      final path = Path()..moveTo(canvasPoints.first.dx, canvasPoints.first.dy);
      for (final point in canvasPoints.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      if (canvasPoints.length >= 4) path.close();
      if (canvasPoints.length >= 3) canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, linePaint);
    }

    for (int i = 0; i < canvasPoints.length; i++) {
      final point = canvasPoints[i];
      canvas.drawCircle(point, 7, Paint()..color = Colors.white);
      canvas.drawCircle(point, 4.5, Paint()..color = AppTheme.primaryBlue);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        point + Offset(10, -textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_TracePainter oldDelegate) => true;
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}
