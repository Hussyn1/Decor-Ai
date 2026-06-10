import 'package:vector_math/vector_math_64.dart' as vector;

class WallSegment {
  final vector.Vector3 start;
  final vector.Vector3 end;
  
  WallSegment({required this.start, required this.end});
  
  double get length => start.distanceTo(end);
  
  Map<String, dynamic> toJson() => {
    'start': [start.x, start.y, start.z],
    'end':   [end.x,   end.y,   end.z],
  };
  
  factory WallSegment.fromJson(Map<String, dynamic> j) {
    List<double> s = (j['start'] as List).map((e) => (e as num).toDouble()).toList();
    List<double> e = (j['end']   as List).map((e) => (e as num).toDouble()).toList();
    return WallSegment(
      start: vector.Vector3(s[0], s[1], s[2]),
      end:   vector.Vector3(e[0], e[1], e[2]),
    );
  }
}

enum FloorPlanElementType { door, window, furniture }

class FloorPlanElement {
  final String id;
  final FloorPlanElementType type;
  final String? modelUri;      // for furniture items
  final String? catalogItemId; // links back to CatalogController
  double xMeters;              // position within room (metres from top-left)
  double zMeters;
  double widthMeters;
  double depthMeters;
  double rotationDeg;

  FloorPlanElement({
    required this.id,
    required this.type,
    this.modelUri,
    this.catalogItemId,
    this.xMeters = 0,
    this.zMeters = 0,
    this.widthMeters = 1,
    this.depthMeters = 1,
    this.rotationDeg = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'type': type.name,
    'modelUri': modelUri, 'catalogItemId': catalogItemId,
    'x': xMeters, 'z': zMeters,
    'w': widthMeters, 'd': depthMeters, 'rot': rotationDeg,
  };

  factory FloorPlanElement.fromJson(Map<String, dynamic> j) => FloorPlanElement(
    id: j['id'], type: FloorPlanElementType.values.byName(j['type']),
    modelUri: j['modelUri'], catalogItemId: j['catalogItemId'],
    xMeters: (j['x'] as num).toDouble(), zMeters: (j['z'] as num).toDouble(),
    widthMeters: (j['w'] as num).toDouble(), depthMeters: (j['d'] as num).toDouble(),
    rotationDeg: (j['rot'] as num).toDouble(),
  );
}

class RoomDimensions {
  final String projectId;
  final double widthMeters;
  final double depthMeters;
  final double heightMeters;
  final List<WallSegment> wallSegments;
  List<FloorPlanElement> elements;

  RoomDimensions({
    required this.projectId,
    required this.widthMeters,
    required this.depthMeters,
    this.heightMeters = 2.4,
    this.wallSegments = const [],
    this.elements = const [],
  });

  double get floorArea => widthMeters * depthMeters;

  Map<String, dynamic> toJson() => {
    'projectId': projectId,
    'widthMeters': widthMeters, 'depthMeters': depthMeters,
    'heightMeters': heightMeters,
    'wallSegments': wallSegments.map((s) => s.toJson()).toList(),
    'elements': elements.map((e) => e.toJson()).toList(),
  };

  factory RoomDimensions.fromJson(Map<String, dynamic> j) => RoomDimensions(
    projectId: j['projectId'],
    widthMeters: (j['widthMeters'] as num).toDouble(),
    depthMeters: (j['depthMeters'] as num).toDouble(),
    heightMeters: (j['heightMeters'] as num?)?.toDouble() ?? 2.4,
    wallSegments: (j['wallSegments'] as List? ?? [])
        .map((s) => WallSegment.fromJson(s)).toList(),
    elements: (j['elements'] as List? ?? [])
        .map((e) => FloorPlanElement.fromJson(e)).toList(),
  );
}