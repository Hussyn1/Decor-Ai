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
