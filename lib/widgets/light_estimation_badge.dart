import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin/models/light_estimate.dart';

class LightEstimationBadge extends StatelessWidget {
  final LightEstimate? estimate;

  const LightEstimationBadge({Key? key, this.estimate}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (estimate == null) return const SizedBox.shrink();

    // Map pixel intensity (0.0 to 1.0) to a visual state
    // Below 0.2: Too Dark
    // 0.2 - 0.7: Good
    // Above 0.7: Very Bright
    IconData icon;
    Color color;
    String label;

    if (estimate!.pixelIntensity < 0.2) {
      icon = Icons.nights_stay;
      color = Colors.indigo.shade300;
      label = "Too Dark";
    } else if (estimate!.pixelIntensity > 0.7) {
      icon = Icons.wb_sunny;
      color = Colors.amber;
      label = "Bright";
    } else {
      icon = Icons.lightbulb;
      color = Colors.tealAccent;
      label = "Good Lighting";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
