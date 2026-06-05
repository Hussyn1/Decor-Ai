import 'package:ar_flutter_plugin/datatypes/surface_type.dart';
import 'package:ar_flutter_plugin/utils/json_converters.dart';
import 'package:vector_math/vector_math_64.dart';

class DetectedPlane {
  final SurfaceType type;
  final Matrix4 centerPose;
  final double extentX;
  final double extentZ;
  final List<double> polygon; // 2D points (x, z)
  final int trackingState;

  DetectedPlane({
    required this.type,
    required this.centerPose,
    required this.extentX,
    required this.extentZ,
    required this.polygon,
    required this.trackingState,
  });

  static DetectedPlane fromJson(Map<String, dynamic> json) {
    SurfaceType parseSurfaceType(int? value) {
      switch (value) {
        case 0:
          return SurfaceType.floor;
        case 1:
          return SurfaceType.ceiling;
        case 2:
          return SurfaceType.wall;
        default:
          return SurfaceType.unknown;
      }
    }

    return DetectedPlane(
      type: parseSurfaceType(json['type'] as int?),
      centerPose: const MatrixConverter().fromJson(json['centerPose'] as List),
      extentX: (json['extentX'] as num).toDouble(),
      extentZ: (json['extentZ'] as num).toDouble(),
      polygon: (json['polygon'] as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
      trackingState: json['trackingState'] as int? ?? 0,
    );
  }
}
