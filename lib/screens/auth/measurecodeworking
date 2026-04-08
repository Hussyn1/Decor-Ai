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

class _ArMeasureScreenState extends State<ArMeasureScreen> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;

  List<ARNode> nodes = [];
  List<ARAnchor> anchors = [];
  List<vector.Vector3> worldPositions = [];
  List<ARNode> lineNodes = [];

  // New State for enhancements
  MeasureMode _currentMode = MeasureMode.distance;
  double lastDistance = 0.0;
  double calculatedArea = 0.0;
  double calculatedHeight = 0.0;
  List<Map<String, dynamic>> measurementHistory = [];
  bool _isSessionReady = false;

  @override
  void dispose() {
    arSessionManager?.dispose();
    super.dispose();
  }

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
      handleTaps: true,
    );
    this.arObjectManager!.onInitialize();

    this.arSessionManager!.onPlaneOrPointTap = onPlaneOrPointTap;

    // Smooth transition for session ready
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _isSessionReady = true);
    });
  }

  Future<void> onPlaneOrPointTap(List<ARHitTestResult> hitTestResults) async {
    if (hitTestResults.isEmpty) return;

    var singleHitTestResult = hitTestResults.firstWhere(
      (hitTestResult) => hitTestResult.type == ARHitTestResultType.plane,
      orElse: () => hitTestResults.first,
    );

    if (singleHitTestResult != null) {
      await _addNodeAtHitResult(singleHitTestResult);
    }
  }

  Future<void> _addNodeAtHitResult(ARHitTestResult hitResult) async {
    var newAnchor = ARPlaneAnchor(transformation: hitResult.worldTransform);
    bool? didAddAnchor = await arAnchorManager!.addAnchor(newAnchor);

    if (didAddAnchor == true) {
      anchors.add(newAnchor);

      vector.Vector3 worldPos = vector.Vector3(
        hitResult.worldTransform.entry(0, 3),
        hitResult.worldTransform.entry(1, 3),
        hitResult.worldTransform.entry(2, 3),
      );
      worldPositions.add(worldPos);

      var newNode = ARNode(
        type: NodeType.webGLB,
        uri:
            "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Box/glTF-Binary/Box.glb",
        scale: vector.Vector3(0.012, 0.012, 0.012),
        position: vector.Vector3(0, 0, 0),
        rotation: vector.Vector4(1, 0, 0, 0),
      );

      bool? didAddNodeToAnchor = await arObjectManager!.addNode(
        newNode,
        planeAnchor: newAnchor,
      );
      if (didAddNodeToAnchor == true) {
        nodes.add(newNode);

        if (worldPositions.length >= 2) {
          _updateMeasurements();
        }
        setState(() {});
      }
    }
  }

  void _updateMeasurements() {
    if (worldPositions.length < 2) return;

    if (_currentMode == MeasureMode.distance) {
      vector.Vector3 p1 = worldPositions[worldPositions.length - 2];
      vector.Vector3 p2 = worldPositions.last;
      lastDistance = p1.distanceTo(p2);
      _drawLineBetweenPoints(p1, p2);
    } else if (_currentMode == MeasureMode.area) {
      // Area requires at least 3 points
      if (worldPositions.length >= 2) {
        vector.Vector3 p1 = worldPositions[worldPositions.length - 2];
        vector.Vector3 p2 = worldPositions.last;
        _drawLineBetweenPoints(p1, p2);
      }
      if (worldPositions.length >= 3) {
        calculatedArea = _calculateArea(worldPositions);
      }
    } else if (_currentMode == MeasureMode.height) {
      if (worldPositions.length == 2) {
        vector.Vector3 p1 = worldPositions[0];
        vector.Vector3 p2 = worldPositions[1];
        calculatedHeight = (p2.y - p1.y).abs();
        _drawLineBetweenPoints(p1, p2, isVertical: true);
      }
    }
  }

  double _calculateArea(List<vector.Vector3> points) {
    if (points.length < 3) return 0.0;
    double area = 0.0;
    for (int i = 0; i < points.length; i++) {
      vector.Vector3 p1 = points[i];
      vector.Vector3 p2 = points[(i + 1) % points.length];
      // Shoelace formula in 2D (using X and Z for floor area)
      area += (p1.x * p2.z) - (p2.x * p1.z);
    }
    return (area.abs() / 2.0);
  }

  Future<void> _drawLineBetweenPoints(
    vector.Vector3 p1,
    vector.Vector3 p2, {
    bool isVertical = false,
  }) async {
    vector.Vector3 midpoint = (p1 + p2) * 0.5;
    double distance = p1.distanceTo(p2);

    vector.Vector3 zAxis = (p2 - p1).normalized();
    vector.Vector3 up = isVertical
        ? vector.Vector3(1, 0, 0)
        : vector.Vector3(0, 1, 0);

    if (zAxis.dot(up).abs() > 0.99) {
      up = isVertical ? vector.Vector3(0, 1, 0) : vector.Vector3(1, 0, 0);
    }
    vector.Vector3 xAxis = up.cross(zAxis).normalized();
    vector.Vector3 yAxis = zAxis.cross(xAxis).normalized();

    vector.Matrix4 rotation = vector.Matrix4.columns(
      vector.Vector4(xAxis.x, xAxis.y, xAxis.z, 0),
      vector.Vector4(yAxis.x, yAxis.y, yAxis.z, 0),
      vector.Vector4(zAxis.x, zAxis.y, zAxis.z, 0),
      vector.Vector4(0, 0, 0, 1),
    );

    vector.Matrix4 transform = vector.Matrix4.translation(midpoint) * rotation;

    var newLine = ARNode(
      type: NodeType.webGLB,
      uri:
          "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Box/glTF-Binary/Box.glb",
      transformation: transform,
      scale: vector.Vector3(0.003, 0.003, distance),
    );

    await arObjectManager!.addNode(newLine);
    lineNodes.add(newLine);
  }

  Future<void> _undoLastPoint() async {
    if (worldPositions.isNotEmpty) {
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
  }

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
  }

  Future<void> _exportToPDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'AR Interior Design - Measurement Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Date: ${DateTime.now().toString()}'),
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
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/measurement_report.pdf");
    await file.writeAsBytes(await pdf.save());

    await OpenFilex.open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),

          // Crosshair
          Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),

          // Top Header & Mode Selector
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

          // Bottom Controls
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
                    _buildPrimaryActionButton(),
                    _buildActionFab(
                      Icons.refresh,
                      worldPositions.isNotEmpty,
                      _resetSession,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
    bool isSelected = _currentMode == mode;
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

  Widget _buildMeasurementCard() {
    String value = "--";
    String label = "";
    if (_currentMode == MeasureMode.distance) {
      value = lastDistance > 0 ? lastDistance.toStringAsFixed(2) : "--";
      label = "DISTANCE (m)";
    } else if (_currentMode == MeasureMode.area) {
      value = calculatedArea > 0 ? calculatedArea.toStringAsFixed(2) : "--";
      label = "AREA (m²)";
    } else if (_currentMode == MeasureMode.height) {
      value = calculatedHeight > 0 ? calculatedHeight.toStringAsFixed(2) : "--";
      label = "HEIGHT (m)";
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
          : Column(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
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
    bool readyToSave =
        (_currentMode == MeasureMode.distance && worldPositions.length >= 2) ||
        (_currentMode == MeasureMode.area && worldPositions.length >= 3) ||
        (_currentMode == MeasureMode.height && worldPositions.length == 2);

    return GestureDetector(
      onTap: readyToSave ? _saveMeasurement : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        decoration: BoxDecoration(
          color: readyToSave ? AppTheme.primaryBlue : Colors.white24,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(
              readyToSave ? Icons.bookmark : Icons.add_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Text(
              readyToSave ? 'SAVE DATA' : 'ADD POINT',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _resetSession() {
    for (var node in nodes) {
      arObjectManager?.removeNode(node);
    }
    for (var anchor in anchors) {
      arAnchorManager?.removeAnchor(anchor);
    }
    for (var line in lineNodes) {
      arObjectManager?.removeNode(line);
    }
    setState(() {
      nodes = [];
      anchors = [];
      worldPositions = [];
      lineNodes = [];
      lastDistance = 0.0;
      calculatedArea = 0.0;
      calculatedHeight = 0.0;
    });
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
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.black87),
        ),
      ),
    );
  }
}
