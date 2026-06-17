import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

import '../../controllers/home_planner_controller.dart';
import '../../controllers/room_planner_controller.dart';
import '../../core/app_theme.dart';
import '../three_floor_plan_screen.dart';

class ScanMeasurementReviewScreen extends StatefulWidget {
  final double widthMeters;
  final double depthMeters;
  final double heightMeters;
  final List<vector.Vector3> points;

  const ScanMeasurementReviewScreen({
    super.key,
    required this.widthMeters,
    required this.depthMeters,
    required this.heightMeters,
    required this.points,
  });

  @override
  State<ScanMeasurementReviewScreen> createState() =>
      _ScanMeasurementReviewScreenState();
}

class _ScanMeasurementReviewScreenState
    extends State<ScanMeasurementReviewScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _widthCtrl;
  late final TextEditingController _depthCtrl;
  late final TextEditingController _heightCtrl;

  // Mutable copy of points to allow manual corrections
  late List<vector.Vector3> _editablePoints;

  late AnimationController _animController;
  late Animation<double> _drawingProgress;
  bool _isBuilding = false;

  // Track index of currently dragged node
  int? _trackedPointIndex;

  @override
  void initState() {
    super.initState();
    _widthCtrl = TextEditingController(
      text: widget.widthMeters.toStringAsFixed(2),
    );
    _depthCtrl = TextEditingController(
      text: widget.depthMeters.toStringAsFixed(2),
    );
    _heightCtrl = TextEditingController(
      text: widget.heightMeters.toStringAsFixed(2),
    );

    // Clone the points so we don't modify the original widget property directly
    _editablePoints = List<vector.Vector3>.from(widget.points);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _drawingProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _widthCtrl.dispose();
    _depthCtrl.dispose();
    _heightCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  // Maps touch gestures to coordinates and finds the closest point
  void _handlePanStart(
    Offset localPos,
    Size constraintSize,
    double scaleX,
    double scaleZ,
  ) {
    if (_editablePoints.isEmpty) return;

    final layoutInfo = _getLayoutInfo(constraintSize, scaleX, scaleZ);
    double closestDistance =
        24.0; // Interactive touch radius threshold (hit-test)
    int? targetIndex;

    for (int i = 0; i < _editablePoints.length; i++) {
      final nodeCanvasPos = _toCanvas(_editablePoints[i], layoutInfo);
      final dist = (localPos - nodeCanvasPos).distance;
      if (dist < closestDistance) {
        closestDistance = dist;
        targetIndex = i;
      }
    }

    setState(() {
      _trackedPointIndex = targetIndex;
    });
  }

  void _handlePanUpdate(
    Offset localPos,
    Size constraintSize,
    double scaleX,
    double scaleZ,
  ) {
    final activeIndex = _trackedPointIndex;
    if (activeIndex == null) return;

    final layoutInfo = _getLayoutInfo(constraintSize, scaleX, scaleZ);

    // Reverse the canvas projection equation back into Vector space
    final double invertedX =
        ((localPos.dx - layoutInfo.origin.dx) / layoutInfo.scale) / scaleX +
        layoutInfo.minX;
    final double invertedZ =
        ((localPos.dy - layoutInfo.origin.dy) / layoutInfo.scale) / scaleZ +
        layoutInfo.minZ;

    setState(() {
      _editablePoints[activeIndex] = vector.Vector3(
        invertedX,
        _editablePoints[activeIndex].y,
        invertedZ,
      );
    });
  }

  _LayoutCalculationInfo _getLayoutInfo(
    Size size,
    double scaleX,
    double scaleZ,
  ) {
    final xs = _editablePoints.map((p) => p.x).toList();
    final zs = _editablePoints.map((p) => p.z).toList();
    final minX = xs.isEmpty ? 0.0 : xs.reduce(math.min);
    final maxX = xs.isEmpty ? 0.0 : xs.reduce(math.max);
    final minZ = zs.isEmpty ? 0.0 : zs.reduce(math.min);
    final maxZ = zs.isEmpty ? 0.0 : zs.reduce(math.max);

    final originalSpanX = math.max(maxX - minX, 0.25);
    final originalSpanZ = math.max(maxZ - minZ, 0.25);
    final currentSpanX = originalSpanX * scaleX;
    final currentSpanZ = originalSpanZ * scaleZ;

    final scale =
        math.min(size.width / currentSpanX, size.height / currentSpanZ) * 0.72;
    final origin = Offset(
      (size.width - (currentSpanX * scale)) / 2,
      (size.height - (currentSpanZ * scale)) / 2,
    );

    return _LayoutCalculationInfo(
      minX: minX,
      minZ: minZ,
      scale: scale,
      origin: origin,
    );
  }

  Offset _toCanvas(vector.Vector3 p, _LayoutCalculationInfo layout) {
    return Offset(
      layout.origin.dx + (p.x - layout.minX) * layout.scale,
      layout.origin.dy + (p.z - layout.minZ) * layout.scale,
    );
  }

  Future<void> _buildFloorPlan() async {
    final width = double.tryParse(_widthCtrl.text.trim()) ?? 0;
    final depth = double.tryParse(_depthCtrl.text.trim()) ?? 0;
    final height = double.tryParse(_heightCtrl.text.trim()) ?? 0;

    if (width < 0.2 || depth < 0.2 || height <= 0) {
      Get.snackbar(
        'Check measurements',
        'Width, depth, and height must be valid.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    FocusScope.of(context).unfocus();
    final homePlanner = Get.isRegistered<HomePlannerController>()
        ? Get.find<HomePlannerController>()
        : Get.put(HomePlannerController());
    homePlanner.setManualDimensions(width, depth, h: height);

    final roomPlanner = Get.isRegistered<RoomPlannerController>()
        ? Get.find<RoomPlannerController>()
        : Get.put(RoomPlannerController());
    roomPlanner.setDimensionsFromScan(
      width: width,
      length: depth,
      height: height,
    );

    setState(() => _isBuilding = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    Get.off(() => const ThreeFloorPlanScreen());
  }

  @override
  Widget build(BuildContext context) {
    final area = _safeParse(_widthCtrl.text) * _safeParse(_depthCtrl.text);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Review room scan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: _isBuilding ? null : () => Get.back(),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Interactive Node Drag Area
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final renderBoxSize = Size(
                              constraints.maxWidth,
                              190,
                            );
                            final targetW =
                                double.tryParse(_widthCtrl.text.trim()) ??
                                widget.widthMeters;
                            final targetD =
                                double.tryParse(_depthCtrl.text.trim()) ??
                                widget.depthMeters;
                            final scaleFactorX = widget.widthMeters > 0
                                ? (targetW / widget.widthMeters)
                                : 1.0;
                            final scaleFactorZ = widget.depthMeters > 0
                                ? (targetD / widget.depthMeters)
                                : 1.0;

                            return GestureDetector(
                              onPanStart: (details) => _handlePanStart(
                                details.localPosition,
                                renderBoxSize,
                                scaleFactorX,
                                scaleFactorZ,
                              ),
                              onPanUpdate: (details) => _handlePanUpdate(
                                details.localPosition,
                                renderBoxSize,
                                scaleFactorX,
                                scaleFactorZ,
                              ),
                              onPanEnd: (_) =>
                                  setState(() => _trackedPointIndex = null),
                              child: Container(
                                color: Colors
                                    .transparent, // Ensures the entire canvas boundary intercepts touches
                                height: renderBoxSize.height,
                                child: AnimatedBuilder(
                                  animation: _drawingProgress,
                                  builder: (context, _) {
                                    return CustomPaint(
                                      painter: _ScanTracePainter(
                                        points: _editablePoints,
                                        progress: _drawingProgress.value,
                                        scaleX: scaleFactorX,
                                        scaleZ: scaleFactorZ,
                                      ),
                                      child: const SizedBox.expand(),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _MetricTile(
                                label: 'Width',
                                value:
                                    '${_safeParse(_widthCtrl.text).toStringAsFixed(2)} m',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MetricTile(
                                label: 'Depth',
                                value:
                                    '${_safeParse(_depthCtrl.text).toStringAsFixed(2)} m',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MetricTile(
                                label: 'Area',
                                value: '${area.toStringAsFixed(1)} m²',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Confirm measurements',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MeasurementField(
                          controller: _widthCtrl,
                          label: 'Width',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MeasurementField(
                          controller: _depthCtrl,
                          label: 'Depth',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _MeasurementField(
                    controller: _heightCtrl,
                    label: 'Height',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isBuilding ? null : _buildFloorPlan,
                      icon: const Icon(Icons.grid_view, color: Colors.white),
                      label: const Text(
                        'Build 3D floor plan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isBuilding) const _BuildingOverlay(),
        ],
      ),
    );
  }

  double _safeParse(String value) => double.tryParse(value.trim()) ?? 0.0;
}

// Data holder class for layout projections
class _LayoutCalculationInfo {
  final double minX;
  final double minZ;
  final double scale;
  final Offset origin;
  _LayoutCalculationInfo({
    required this.minX,
    required this.minZ,
    required this.scale,
    required this.origin,
  });
}

class _ScanTracePainter extends CustomPainter {
  final List<vector.Vector3> points;
  final double progress;
  final double scaleX;
  final double scaleZ;

  const _ScanTracePainter({
    required this.points,
    required this.progress,
    required this.scaleX,
    required this.scaleZ,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final xs = points.map((p) => p.x).toList();
    final zs = points.map((p) => p.z).toList();
    final minX = xs.reduce(math.min);
    final maxX = xs.reduce(math.max);
    final minZ = zs.reduce(math.min);
    final maxZ = zs.reduce(math.max);

    final originalSpanX = math.max(maxX - minX, 0.25);
    final originalSpanZ = math.max(maxZ - minZ, 0.25);
    final currentSpanX = originalSpanX * scaleX;
    final currentSpanZ = originalSpanZ * scaleZ;

    final scale =
        math.min(size.width / currentSpanX, size.height / currentSpanZ) * 0.72;
    final origin = Offset(
      (size.width - (currentSpanX * scale)) / 2,
      (size.height - (currentSpanZ * scale)) / 2,
    );

    Offset toCanvas(vector.Vector3 p) {
      return Offset(
        origin.dx + (p.x - minX) * scaleX * scale,
        origin.dy + (p.z - minZ) * scaleZ * scale,
      );
    }

    final canvasPoints = points.map(toCanvas).toList();
    final completePath = Path()
      ..moveTo(canvasPoints.first.dx, canvasPoints.first.dy);
    for (final point in canvasPoints.skip(1)) {
      completePath.lineTo(point.dx, point.dy);
    }
    if (canvasPoints.length >= 4) completePath.close();

    Path animatedPath = Path();
    for (final PathMetric metric in completePath.computeMetrics()) {
      animatedPath.addPath(
        metric.extractPath(0.0, metric.length * progress),
        Offset.zero,
      );
    }

    canvas.drawPath(
      animatedPath,
      Paint()
        ..color = AppTheme.primaryBlue.withOpacity(0.06 * progress)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      animatedPath,
      Paint()
        ..color = AppTheme.primaryBlue
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    final double totalPointsToShow = canvasPoints.length * progress;
    for (int i = 0; i < canvasPoints.length; i++) {
      if (i > totalPointsToShow) break;
      final point = canvasPoints[i];
      canvas.drawCircle(point, 9, Paint()..color = Colors.white);
      canvas.drawCircle(point, 5.5, Paint()..color = AppTheme.successGreen);
    }
  }

  @override
  bool shouldRepaint(_ScanTracePainter oldDelegate) => true;
}

// Re-using original UI components
class _MeasurementField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;
  const _MeasurementField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: '$label (m)',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textGrey),
          ),
        ],
      ),
    );
  }
}

class _BuildingOverlay extends StatelessWidget {
  const _BuildingOverlay();
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: const Color(0xEE0F172A),
        child: Center(
          child: Container(
            width: 250,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: CircularProgressIndicator(strokeWidth: 4),
                ),
                SizedBox(height: 20),
                Text(
                  'Building 3D floor plan',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 8),
                Text(
                  'Preparing room geometry...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textGrey, height: 1.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
