import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin/models/detected_plane.dart';
import 'package:ar_flutter_plugin/datatypes/surface_type.dart';

class RoomScanOverlay extends StatelessWidget {
  final List<DetectedPlane> planes;

  const RoomScanOverlay({Key? key, required this.planes}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (planes.isEmpty) return const SizedBox.shrink();

    double totalFloorArea = 0;
    double totalWallArea = 0;

    for (var plane in planes) {
      // Rough area estimation using extents (width * height/depth)
      double area = plane.extentX * plane.extentZ;
      if (plane.type == SurfaceType.floor || plane.type == SurfaceType.ceiling) {
        totalFloorArea += area;
      } else if (plane.type == SurfaceType.wall) {
        totalWallArea += area;
      }
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.radar, color: Colors.blueAccent, size: 20),
              SizedBox(width: 8),
              Text(
                "Room Scan Active",
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatRow("Planes Detected", "${planes.length}", Icons.layers),
          const SizedBox(height: 8),
          _buildStatRow("Est. Floor Area", "${totalFloorArea.toStringAsFixed(1)} m²", Icons.square_foot),
          const SizedBox(height: 8),
          _buildStatRow("Est. Wall Area", "${totalWallArea.toStringAsFixed(1)} m²", Icons.ad_units),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }
}

class AiScanningOverlay extends StatefulWidget {
  const AiScanningOverlay({Key? key}) : super(key: key);

  @override
  State<AiScanningOverlay> createState() => _AiScanningOverlayState();
}

class _AiScanningOverlayState extends State<AiScanningOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2500, microseconds: 0),
    );
    _controller.duration = const Duration(seconds: 2);
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.55),
        child: Stack(
          children: [
            // Sweeping Laser Line
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Positioned(
                  top: MediaQuery.of(context).size.height * 0.15 + (MediaQuery.of(context).size.height * 0.65 * _controller.value),
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyan.withOpacity(0.8),
                          blurRadius: 18,
                          spreadRadius: 6,
                        ),
                      ],
                      gradient: LinearGradient(
                        colors: [
                          Colors.cyan.withOpacity(0.01),
                          Colors.cyan,
                          Colors.cyan.withOpacity(0.01),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            
            // Outer Glow Scan Box
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.height * 0.5,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.cyan.withOpacity(0.35), width: 1.5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Stack(
                  children: [
                    // Corner brackets
                    Positioned(
                      top: 10, left: 10,
                      child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.cyan, width: 4), left: BorderSide(color: Colors.cyan, width: 4)))),
                    ),
                    Positioned(
                      top: 10, right: 10,
                      child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.cyan, width: 4), right: BorderSide(color: Colors.cyan, width: 4)))),
                    ),
                    Positioned(
                      bottom: 10, left: 10,
                      child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.cyan, width: 4), left: BorderSide(color: Colors.cyan, width: 4)))),
                    ),
                    Positioned(
                      bottom: 10, right: 10,
                      child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.cyan, width: 4), right: BorderSide(color: Colors.cyan, width: 4)))),
                    ),
                    
                    // Scanning Text and Loading indicator
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyan.withOpacity(0.15),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 44,
                              height: 44,
                              child: CircularProgressIndicator(
                                strokeWidth: 3.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "AI SPATIAL SCANNING",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.cyan.shade300,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Analyzing room dimensions, wall colors, lighting, & placed furniture...",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                height: 1.4,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
