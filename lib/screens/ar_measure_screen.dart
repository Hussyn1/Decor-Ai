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
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import '../core/app_theme.dart';
import '../widgets/shimmer_loading.dart';

enum MeasureMode { distance, area, height }

class ArMeasureScreen extends StatefulWidget {
  const ArMeasureScreen({super.key});

  @override
  State<ArMeasureScreen> createState() => _ArMeasureScreenState();
}

class _ArMeasureScreenState extends State<ArMeasureScreen>
    with TickerProviderStateMixin {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;

  List<ARNode> nodes = [];
  List<ARAnchor> anchors = [];
  List<vector.Vector3> worldPositions = [];
  List<ARNode> lineNodes = []; // permanent confirmed lines

  // Live preview
  vector.Vector3? _livePosition;
  ARNode? _liveLineNode;
  bool _isUpdatingPreview = false; // guard against concurrent preview updates
  bool _justPlacedPoint = false;   // cooldown flag after placing a point
  int _lineNodeCounter = 0;        // unique ID counter for line nodes
  Timer? _frameTimer;

  // Dashed line animation
  late AnimationController _dashAnimController;
  late Animation<double> _dashOffset;

  // Crosshair lock animation
  late AnimationController _crosshairPulseController;
  late Animation<double> _crosshairScale;

  MeasureMode _currentMode = MeasureMode.distance;
  double lastDistance = 0.0;
  double _liveDistance = 0.0; // live distance while aiming
  double calculatedArea = 0.0;
  double calculatedHeight = 0.0;
  List<Map<String, dynamic>> measurementHistory = [];
  bool _isSessionReady = false;
  bool _isLockedOnPlane = false; // crosshair hit a plane?

  @override
  void initState() {
    super.initState();

    // Dashed line marching-ants animation
    _dashAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
    _dashOffset = Tween<double>(begin: 0, end: 1).animate(_dashAnimController);

    // Crosshair pulse when locked
    _crosshairPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _crosshairScale = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(
        parent: _crosshairPulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _dashAnimController.dispose();
    _crosshairPulseController.dispose();
    arSessionManager?.dispose();
    super.dispose();
  }

  // ─── AR INIT ──────────────────────────────────────────────────────────────
  void onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;

    this.arSessionManager!.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      showWorldOrigin: false,
      handleTaps: false, // crosshair button owns point placement
    );
    this.arObjectManager!.onInitialize();

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _isSessionReady = true);
        _startFrameLoop();
      }
    });
  }

  // ─── FRAME LOOP: poll center-screen hit every 50ms ────────────────────────
  void _startFrameLoop() {
    _frameTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _updateLivePosition();
    });
  }

  Future<void> _updateLivePosition() async {
    if (arSessionManager == null) return;
    // Skip if we're still processing a previous preview update or in cooldown
    if (_isUpdatingPreview || _justPlacedPoint) return;

    try {
      final results = await arSessionManager!.performHitTest(0.5, 0.5);
      if (results.isEmpty) {
        if (mounted) setState(() => _isLockedOnPlane = false);
        return;
      }

      final hit = results.firstWhere(
        (r) => r.type == ARHitTestResultType.plane,
        orElse: () => results.first,
      );

      final pos = vector.Vector3(
        hit.worldTransform.entry(0, 3),
        hit.worldTransform.entry(1, 3),
        hit.worldTransform.entry(2, 3),
      );

      _livePosition = pos;

      if (worldPositions.isNotEmpty) {
        bool showPreview = true;
        if ((_currentMode == MeasureMode.distance || _currentMode == MeasureMode.height) && 
            worldPositions.length >= 2) {
          showPreview = false;
        }

        if (showPreview) {
          _liveDistance = worldPositions.last.distanceTo(pos);
          await _updateLivePreview(worldPositions.last, pos);
        } else {
          if (_liveLineNode != null) {
            final nodeToRemove = _liveLineNode!;
            _liveLineNode = null;
            await arObjectManager?.removeNode(nodeToRemove);
          }
        }
      }

      if (mounted) setState(() => _isLockedOnPlane = true);
    } catch (_) {
      if (mounted) setState(() => _isLockedOnPlane = false);
    }
  }



  // ─── LIVE PREVIEW LINE (from last point → crosshair) ─────────────────────
  // The "dashed" appearance is simulated in AR by using a very thin,
  // slightly transparent node. The actual dashed visual lives in the
  // Flutter overlay (Canvas) drawn on top of the AR view.
  Future<void> _updateLivePreview(
    vector.Vector3 from,
    vector.Vector3 to,
  ) async {
    // Guard: prevent concurrent updates which cause duplicate nodes
    if (_isUpdatingPreview) return;
    _isUpdatingPreview = true;

    try {
      // Remove old preview first and wait for it to complete
      if (_liveLineNode != null) {
        final oldNode = _liveLineNode!;
        _liveLineNode = null; // clear reference BEFORE async removal
        await arObjectManager?.removeNode(oldNode);
      }

      // Create a new clean preview line using the shared helper
      _liveLineNode = await _createLineNode(from, to, permanent: false);
    } finally {
      _isUpdatingPreview = false;
    }
  }

  // ─── PLACE POINT (crosshair button tapped) ────────────────────────────────
  Future<void> _placePointAtCrosshair() async {
    if (_livePosition == null || !_isLockedOnPlane) return;
    if ((_currentMode == MeasureMode.distance || _currentMode == MeasureMode.height) && 
        worldPositions.length >= 2) {
      return;
    }

    // Activate cooldown: stops the frame loop from creating new preview lines
    // while we're placing a point and promoting the live line
    _justPlacedPoint = true;

    final pos = _livePosition!;
    final matrix = vector.Matrix4.identity()..setTranslation(pos);

    var newAnchor = ARPlaneAnchor(transformation: matrix);
    bool? didAddAnchor = await arAnchorManager!.addAnchor(newAnchor);
    if (didAddAnchor != true) {
      _justPlacedPoint = false;
      return;
    }

    anchors.add(newAnchor);
    worldPositions.add(pos);

    // Permanent endpoint dot — use a unique name
    _lineNodeCounter++;
    var newNode = ARNode(
      type: NodeType.webGLB,
      name: 'point_dot_$_lineNodeCounter',
      uri:
          "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Box/glTF-Binary/Box.glb",
      scale: vector.Vector3(0.018, 0.018, 0.018),
      position: vector.Vector3(0, 0, 0),
      rotation: vector.Vector4(1, 0, 0, 0),
    );
    bool? added = await arObjectManager!.addNode(
      newNode,
      planeAnchor: newAnchor,
    );
    if (added == true) nodes.add(newNode);

    // Promote the current live line to a permanent confirmed line.
    // We need to create a NEW dedicated node for the permanent line
    // (with the final calculated transform) rather than reusing the
    // live preview node — this avoids the frame loop from accidentally
    // removing/modifying it.
    if (worldPositions.length >= 2) {
      // Remove the live preview node — we'll create a clean permanent one
      if (_liveLineNode != null) {
        final previewToRemove = _liveLineNode!;
        _liveLineNode = null;
        await arObjectManager?.removeNode(previewToRemove);
      }

      // Create the permanent line between the last two points
      final from = worldPositions[worldPositions.length - 2];
      final to = worldPositions.last;
      final permanentLine = await _createLineNode(from, to, permanent: true);
      if (permanentLine != null) {
        lineNodes.add(permanentLine);
      }
    }

    _updateMeasurements();
    setState(() {});

    // Brief cooldown to let the AR engine settle before the frame loop
    // starts creating new preview lines again
    await Future.delayed(const Duration(milliseconds: 150));
    _justPlacedPoint = false;
  }

  /// Creates a line (Box.glb stretched) between two world points.
  /// Returns the ARNode if successfully added, null otherwise.
  Future<ARNode?> _createLineNode(
    vector.Vector3 from,
    vector.Vector3 to, {
    bool permanent = false,
  }) async {
    final dist = from.distanceTo(to);
    if (dist < 0.001) return null;

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

    _lineNodeCounter++;
    final prefix = permanent ? 'perm_line' : 'live_line';
    final thickness = permanent ? 0.003 : 0.002;
    final node = ARNode(
      type: NodeType.webGLB,
      name: '${prefix}_$_lineNodeCounter',
      uri:
          "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Box/glTF-Binary/Box.glb",
      transformation: transform,
      scale: vector.Vector3(thickness, thickness, dist),
    );
    await arObjectManager?.addNode(node);
    return node;
  }

  // ─── MEASUREMENTS ─────────────────────────────────────────────────────────
  void _updateMeasurements() {
    if (worldPositions.length < 2) return;
    if (_currentMode == MeasureMode.distance) {
      lastDistance = worldPositions[worldPositions.length - 2].distanceTo(
        worldPositions.last,
      );
    } else if (_currentMode == MeasureMode.area) {
      if (worldPositions.length >= 3) {
        calculatedArea = _calculateArea(worldPositions);
      }
    } else if (_currentMode == MeasureMode.height) {
      if (worldPositions.length == 2) {
        calculatedHeight = (worldPositions[1].y - worldPositions[0].y).abs();
      }
    }
  }

  double _calculateArea(List<vector.Vector3> points) {
    if (points.length < 3) return 0.0;
    double area = 0.0;
    for (int i = 0; i < points.length; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];
      area += (p1.x * p2.z) - (p2.x * p1.z);
    }
    return area.abs() / 2.0;
  }

  // ─── UNDO ─────────────────────────────────────────────────────────────────
  Future<void> _undoLastPoint() async {
    if (worldPositions.isEmpty) return;
    if (nodes.isNotEmpty) {
      arObjectManager?.removeNode(nodes.last);
      nodes.removeLast();
    }
    if (anchors.isNotEmpty) {
      arAnchorManager?.removeAnchor(anchors.last);
      anchors.removeLast();
    }
    if (lineNodes.isNotEmpty) {
      arObjectManager?.removeNode(lineNodes.last);
      lineNodes.removeLast();
    }
    worldPositions.removeLast();
    _updateMeasurements();
    setState(() {});
  }

  // ─── SAVE / EXPORT ────────────────────────────────────────────────────────
  void _saveMeasurement() {
    String value = "";
    String type = "";
    if (_currentMode == MeasureMode.distance) {
      value = "${lastDistance.toStringAsFixed(2)} m";
      type = "Distance";
    } else if (_currentMode == MeasureMode.area) {
      value = "${calculatedArea.toStringAsFixed(2)} m²";
      type = "Area";
    } else if (_currentMode == MeasureMode.height) {
      value = "${calculatedHeight.toStringAsFixed(2)} m";
      type = "Height";
    }
    setState(() {
      measurementHistory.add({
        'type': type,
        'value': value,
        'timestamp': DateTime.now().toString().substring(11, 16),
      });
    });
    
    // Automatically reset the session so user can start a new measurement immediately
    _resetSession();
  }

  Future<void> _exportToPDF() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'AR Measurement Report',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Date: ${DateTime.now()}'),
            pw.Divider(),
            pw.SizedBox(height: 20),
            ...measurementHistory.map(
              (m) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "${m['type']}:",
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(m['value']),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/measurement_report.pdf");
    await file.writeAsBytes(await pdf.save());
    await OpenFilex.open(file.path);
  }

  // ─── RESET ────────────────────────────────────────────────────────────────
  void _resetSession() {
    _frameTimer?.cancel();
    if (_liveLineNode != null) arObjectManager?.removeNode(_liveLineNode!);
    for (var n in nodes) arObjectManager?.removeNode(n);
    for (var a in anchors) arAnchorManager?.removeAnchor(a);
    for (var l in lineNodes) arObjectManager?.removeNode(l);
    setState(() {
      nodes = [];
      anchors = [];
      worldPositions = [];
      lineNodes = [];
      _liveLineNode = null;
      _livePosition = null;
      _liveDistance = 0.0;
      lastDistance = 0.0;
      calculatedArea = 0.0;
      calculatedHeight = 0.0;
      _isLockedOnPlane = false;
      _isUpdatingPreview = false;
      _justPlacedPoint = false;
    });
    _startFrameLoop();
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── AR View (no tap handling — button only) ──
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),

          // ── Dashed line Flutter overlay (marching-ants over AR) ──
          if (worldPositions.isNotEmpty && _isSessionReady)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _dashOffset,
                  builder: (_, __) => CustomPaint(
                    painter: _DashedLinePainter(
                      offset: _dashOffset.value,
                      isLocked: _isLockedOnPlane,
                    ),
                  ),
                ),
              ),
            ),

          // ── Crosshair ──
          Center(child: _buildCrosshair()),

          // ── Top Header ──
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCircleButton(
                      Icons.arrow_back_ios_new,
                      () => Navigator.pop(context),
                    ),
                    _buildModeSelector(),
                    _buildCircleButton(
                      Icons.picture_as_pdf,
                      _exportToPDF,
                      color: Colors.redAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildMeasurementCard(),
              ],
            ),
          ),

          // ── Hint ──
          if (worldPositions.isEmpty && _isSessionReady)
            Positioned(
              bottom: 200,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Point at a surface and press  ⊕  to place',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),
            ),

          // ── Bottom Controls ──
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              children: [
                if (measurementHistory.isNotEmpty) _buildHistoryList(),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildActionFab(
                      Icons.undo,
                      worldPositions.isNotEmpty,
                      _undoLastPoint,
                    ),
                    _buildCrosshairPlaceButton(), // ← THE KEY BUTTON
                    _buildActionFab(
                      Icons.refresh,
                      worldPositions.isNotEmpty,
                      _resetSession,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildPrimaryActionButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Crosshair place button (big center button) ────────────────────────────
  Widget _buildCrosshairPlaceButton() {
    final bool canAdd = _isLockedOnPlane && 
        !((_currentMode == MeasureMode.distance || _currentMode == MeasureMode.height) && worldPositions.length >= 2);

    return GestureDetector(
      onTap: canAdd ? _placePointAtCrosshair : null,
      child: AnimatedBuilder(
        animation: _crosshairScale,
        builder: (_, child) => Transform.scale(
          scale: canAdd ? _crosshairScale.value : 1.0,
          child: child,
        ),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: canAdd ? AppTheme.primaryBlue : Colors.white24,
            border: Border.all(
              color: canAdd ? Colors.white : Colors.white38,
              width: 3,
            ),
            boxShadow: canAdd
                ? [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withOpacity(0.6),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ]
                : [],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 36),
        ),
      ),
    );
  }

  // ── Animated crosshair ────────────────────────────────────────────────────
  Widget _buildCrosshair() {
    return AnimatedBuilder(
      animation: _crosshairScale,
      builder: (_, __) {
        final scale = _isLockedOnPlane ? _crosshairScale.value : 1.0;
        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: 44,
            height: 44,
            child: CustomPaint(
              painter: _CrosshairPainter(
                isLocked: _isLockedOnPlane,
                primaryColor: AppTheme.primaryBlue,
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Mode selector ─────────────────────────────────────────────────────────
  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeBtn(MeasureMode.distance, Icons.straighten),
          _buildModeBtn(MeasureMode.area, Icons.square_foot),
          _buildModeBtn(MeasureMode.height, Icons.vertical_align_top),
        ],
      ),
    );
  }

  Widget _buildModeBtn(MeasureMode mode, IconData icon) {
    final isSelected = _currentMode == mode;
    return GestureDetector(
      onTap: () => setState(() {
        _currentMode = mode;
        _resetSession();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.white70,
          size: 20,
        ),
      ),
    );
  }

  // ── Measurement card ──────────────────────────────────────────────────────
  Widget _buildMeasurementCard() {
    // While aiming (1 point placed), show live distance
    final bool isAiming = worldPositions.isNotEmpty && _liveDistance > 0;

    String value = "--";
    String label = "";
    String? subLabel;

    if (_currentMode == MeasureMode.distance) {
      label = "DISTANCE (m)";
      if (isAiming) {
        value = _liveDistance.toStringAsFixed(2);
        subLabel = "● LIVE";
      } else if (lastDistance > 0) {
        value = lastDistance.toStringAsFixed(2);
      }
    } else if (_currentMode == MeasureMode.area) {
      label = "AREA (m²)";
      value = calculatedArea > 0 ? calculatedArea.toStringAsFixed(2) : "--";
    } else if (_currentMode == MeasureMode.height) {
      label = "HEIGHT (m)";
      if (isAiming && worldPositions.length == 1) {
        value =
            (_livePosition != null
                    ? (_livePosition!.y - worldPositions[0].y).abs()
                    : 0)
                .toStringAsFixed(2);
        subLabel = "● LIVE";
      } else if (calculatedHeight > 0) {
        value = calculatedHeight.toStringAsFixed(2);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
      ),
      child: !_isSessionReady
          ? Column(
              children: [
                ShimmerLoading(width: 120, height: 40, borderRadius: 8),
                const SizedBox(height: 8),
                ShimmerLoading(width: 80, height: 12, borderRadius: 4),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: isAiming ? Colors.orange : AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.grey,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subLabel != null)
                        Text(
                          subLabel,
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHistoryList() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: measurementHistory.length,
        itemBuilder: (context, index) {
          final m = measurementHistory[index];
          return Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  m['value'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  m['type'],
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrimaryActionButton() {
    final readyToSave =
        (_currentMode == MeasureMode.distance && worldPositions.length >= 2) ||
        (_currentMode == MeasureMode.area && worldPositions.length >= 3) ||
        (_currentMode == MeasureMode.height && worldPositions.length == 2);

    return GestureDetector(
      onTap: readyToSave ? _saveMeasurement : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        decoration: BoxDecoration(
          color: readyToSave ? AppTheme.primaryBlue : Colors.white24,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              readyToSave ? Icons.bookmark : Icons.touch_app,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Text(
              readyToSave ? 'SAVE MEASUREMENT' : 'AIM AT A SURFACE',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton(
    IconData icon,
    VoidCallback onTap, {
    Color color = Colors.black45,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildActionFab(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.3,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.black87),
        ),
      ),
    );
  }
}

// ─── CUSTOM PAINTERS ──────────────────────────────────────────────────────────

/// Draws the animated dashed line overlay on the Flutter layer.
/// This is a 2D screen-space approximation — it draws from screen center
/// toward the bottom of the measurement card area to give visual feedback.
/// The real 3D line is handled by the AR node.
class _DashedLinePainter extends CustomPainter {
  final double offset; // 0.0 → 1.0 marching animation
  final bool isLocked;

  const _DashedLinePainter({required this.offset, required this.isLocked});

  @override
  void paint(Canvas canvas, Size size) {
    // Only draw when there's an active measurement in progress —
    // the AR node handles the actual 3D line; this just adds the
    // animated dashed glow overlay on the 2D screen
    final center = Offset(size.width / 2, size.height / 2);

    final paint = Paint()
      ..color = (isLocked ? Colors.orangeAccent : Colors.white).withOpacity(0.7)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw a small pulsing ring around center to indicate "live line active"
    final ringPaint = Paint()
      ..color = (isLocked ? Colors.orangeAccent : Colors.white54).withOpacity(
        0.4 + offset * 0.4,
      )
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, 18 + offset * 6, ringPaint);

    // Dashed arc segments radiating outward (marching ants effect)
    const dashLen = 8.0;
    const gapLen = 6.0;
    const radius = 26.0;
    double angle = offset * 2 * 3.14159;
    for (int i = 0; i < 8; i++) {
      final startAngle = angle + i * (2 * 3.14159 / 8);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashLen / radius,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) =>
      old.offset != offset || old.isLocked != isLocked;
}

/// Custom crosshair that shows locked vs searching state
class _CrosshairPainter extends CustomPainter {
  final bool isLocked;
  final Color primaryColor;

  const _CrosshairPainter({required this.isLocked, required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final color = isLocked ? primaryColor : Colors.white;
    final paint = Paint()
      ..color = color
      ..strokeWidth = isLocked ? 2.5 : 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final r = size.width / 2;
    final gap = r * 0.3; // gap around center dot
    final lineLen = r * 0.45;

    // Four corner L-brackets (like Apple Measure app)
    // Top-left
    canvas.drawLine(
      Offset(center.dx - gap - lineLen, center.dy - gap),
      Offset(center.dx - gap, center.dy - gap),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - gap, center.dy - gap - lineLen),
      Offset(center.dx - gap, center.dy - gap),
      paint,
    );
    // Top-right
    canvas.drawLine(
      Offset(center.dx + gap + lineLen, center.dy - gap),
      Offset(center.dx + gap, center.dy - gap),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + gap, center.dy - gap - lineLen),
      Offset(center.dx + gap, center.dy - gap),
      paint,
    );
    // Bottom-left
    canvas.drawLine(
      Offset(center.dx - gap - lineLen, center.dy + gap),
      Offset(center.dx - gap, center.dy + gap),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - gap, center.dy + gap + lineLen),
      Offset(center.dx - gap, center.dy + gap),
      paint,
    );
    // Bottom-right
    canvas.drawLine(
      Offset(center.dx + gap + lineLen, center.dy + gap),
      Offset(center.dx + gap, center.dy + gap),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + gap, center.dy + gap + lineLen),
      Offset(center.dx + gap, center.dy + gap),
      paint,
    );

    // Center dot
    canvas.drawCircle(
      center,
      isLocked ? 4 : 3,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_CrosshairPainter old) =>
      old.isLocked != isLocked || old.primaryColor != primaryColor;
}
