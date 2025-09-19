import 'package:latlong2/latlong.dart';
import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

// Helper function for safe LatLng parsing
LatLng _parseLatLng(dynamic json) {
  if (json == null) {
    throw ArgumentError('LatLng JSON data cannot be null');
  }
  
  if (json is Map<String, dynamic>) {
    // Standard format: {"latitude": 33.9737, "longitude": -117.3281}
    final lat = json['latitude'];
    final lng = json['longitude'];
    
    if (lat == null || lng == null) {
      throw ArgumentError('LatLng JSON must contain latitude and longitude');
    }
    
    return LatLng(
      (lat is num) ? lat.toDouble() : double.parse(lat.toString()),
      (lng is num) ? lng.toDouble() : double.parse(lng.toString()),
    );
  } else if (json is List && json.length >= 2) {
    // Array format: [longitude, latitude] (GeoJSON style)
    return LatLng(
      (json[1] is num) ? json[1].toDouble() : double.parse(json[1].toString()),
      (json[0] is num) ? json[0].toDouble() : double.parse(json[0].toString()),
    );
  } else {
    throw ArgumentError('Invalid LatLng format: $json');
  }
}

// Helper function for safe LatLng list parsing
List<LatLng> _parseLatLngList(dynamic json) {
  if (json == null) return [];
  
  if (json is! List) {
    throw ArgumentError('Expected list for LatLng array parsing');
  }
  
  return (json as List).map((item) => _parseLatLng(item)).toList();
}

@JsonSerializable()
class Road {
  final String id;
  final String name;
  final List<LatLng> points;
  final String type; // 'road', 'walkway', 'corridor'
  final double width;
  final bool isOneWay;
  final String floorId; // Empty string for outdoor roads
  final List<String> connectedIntersections; // NEW: For road network analysis
  final Map<String, dynamic> properties;

  Road({
    required this.id,
    required this.name,
    required this.points,
    this.type = 'road',
    this.width = 5.0,
    this.isOneWay = false,
    required this.floorId,
    this.connectedIntersections = const [],
    this.properties = const {},
  });

  factory Road.fromJson(Map<String, dynamic> json) {
    try {
      return Road(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        points: _parseLatLngList(json['points']),
        type: json['type']?.toString() ?? 'road',
        width: (json['width'] is num) ? json['width'].toDouble() : 5.0,
        isOneWay: json['isOneWay'] == true,
        floorId: json['floorId']?.toString() ?? '',
        connectedIntersections: (json['connectedIntersections'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? const [],
        properties: (json['properties'] as Map<String, dynamic>?) ?? const {},
      );
    } catch (e) {
      throw FormatException('Failed to parse Road from JSON: $e');
    }
  }

  Map<String, dynamic> toJson() => _$RoadToJson(this);

  // NEW: Helper methods
  bool get isIndoor => floorId.isNotEmpty;
  bool get isOutdoor => floorId.isEmpty;

  Road copyWith({
    String? name,
    List<LatLng>? points,
    String? type,
    double? width,
    bool? isOneWay,
    List<String>? connectedIntersections,
    Map<String, dynamic>? properties,
  }) {
    return Road(
      id: id,
      name: name ?? this.name,
      points: points ?? this.points,
      type: type ?? this.type,
      width: width ?? this.width,
      isOneWay: isOneWay ?? this.isOneWay,
      floorId: floorId,
      connectedIntersections: connectedIntersections ?? this.connectedIntersections,
      properties: properties ?? this.properties,
    );
  }
}

@JsonSerializable()
class Landmark {
  final String id;
  final String name;
  final String type; // 'bathroom', 'classroom', 'office', 'entrance', 'elevator', 'stairs'
  final LatLng position;
  final String floorId; // Empty string for outdoor landmarks
  final String description;
  final List<String> connectedFloors; // NEW: For vertical circulation
  final String buildingId; // NEW: Link to building
  final Map<String, dynamic> properties;

  Landmark({
    required this.id,
    required this.name,
    required this.type,
    required this.position,
    required this.floorId,
    this.description = '',
    this.connectedFloors = const [],
    this.buildingId = '',
    this.properties = const {},
  });

  factory Landmark.fromJson(Map<String, dynamic> json) {
    try {
      return Landmark(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        position: _parseLatLng(json['position']),
        floorId: json['floorId']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        connectedFloors: (json['connectedFloors'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? const [],
        buildingId: json['buildingId']?.toString() ?? '',
        properties: (json['properties'] as Map<String, dynamic>?) ?? const {},
      );
    } catch (e) {
      throw FormatException('Failed to parse Landmark from JSON: $e');
    }
  }

  Map<String, dynamic> toJson() => _$LandmarkToJson(this);

  // NEW: Helper methods
  bool get isIndoor => floorId.isNotEmpty;
  bool get isOutdoor => floorId.isEmpty;
  bool get isVerticalCirculation => type == 'elevator' || type == 'stairs';
  bool get isAccessible => properties['accessible'] == true || type == 'elevator';

  Landmark copyWith({
    String? name,
    String? type,
    LatLng? position,
    String? description,
    List<String>? connectedFloors,
    String? buildingId,
    Map<String, dynamic>? properties,
  }) {
    return Landmark(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      position: position ?? this.position,
      floorId: floorId,
      description: description ?? this.description,
      connectedFloors: connectedFloors ?? this.connectedFloors,
      buildingId: buildingId ?? this.buildingId,
      properties: properties ?? this.properties,
    );
  }
}

@JsonSerializable()
class Floor {
  final String id;
  final String name;
  final int level; // 0 for ground floor, negative for basement, positive for upper floors
  final String buildingId;
  final List<Road> roads;
  final List<Landmark> landmarks;
  final List<String> connectedFloors; // NEW: Floors accessible from this floor
  final LatLng? centerPosition; // NEW: Center point for floor
  final Map<String, dynamic> properties;

  Floor({
    required this.id,
    required this.name,
    required this.level,
    required this.buildingId,
    this.roads = const [],
    this.landmarks = const [],
    this.connectedFloors = const [],
    this.centerPosition,
    this.properties = const {},
  });

  factory Floor.fromJson(Map<String, dynamic> json) {
    try {
      return Floor(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        level: (json['level'] is num) ? json['level'].toInt() : 0,
        buildingId: json['buildingId']?.toString() ?? '',
        roads: (json['roads'] as List<dynamic>?)
            ?.map((e) => Road.fromJson(e as Map<String, dynamic>))
            .toList() ?? const [],
        landmarks: (json['landmarks'] as List<dynamic>?)
            ?.map((e) => Landmark.fromJson(e as Map<String, dynamic>))
            .toList() ?? const [],
        connectedFloors: (json['connectedFloors'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? const [],
        centerPosition: json['centerPosition'] != null 
            ? _parseLatLng(json['centerPosition'])
            : null,
        properties: (json['properties'] as Map<String, dynamic>?) ?? const {},
      );
    } catch (e) {
      throw FormatException('Failed to parse Floor from JSON: $e');
    }
  }

  Map<String, dynamic> toJson() => _$FloorToJson(this);

  // NEW: Helper methods
  List<Landmark> get verticalCirculation => 
      landmarks.where((l) => l.isVerticalCirculation).toList();
  
  List<Landmark> get entrances => 
      landmarks.where((l) => l.type == 'entrance').toList();
  
  List<Landmark> get accessibleFeatures => 
      landmarks.where((l) => l.isAccessible).toList();

  Floor copyWith({
    String? name,
    int? level,
    List<Road>? roads,
    List<Landmark>? landmarks,
    List<String>? connectedFloors,
    LatLng? centerPosition,
    Map<String, dynamic>? properties,
  }) {
    return Floor(
      id: id,
      name: name ?? this.name,
      level: level ?? this.level,
      buildingId: buildingId,
      roads: roads ?? this.roads,
      landmarks: landmarks ?? this.landmarks,
      connectedFloors: connectedFloors ?? this.connectedFloors,
      centerPosition: centerPosition ?? this.centerPosition,
      properties: properties ?? this.properties,
    );
  }
}

@JsonSerializable()
class Building {
  final String id;
  final String name;
  final LatLng centerPosition;
  final List<LatLng> boundaryPoints;
  final List<Floor> floors;
  final List<String> entranceFloorIds; // NEW: Main entrance floors
  final int defaultFloorLevel; // NEW: Default floor to show
  final Map<String, dynamic> properties;

  Building({
    required this.id,
    required this.name,
    required this.centerPosition,
    this.boundaryPoints = const [],
    this.floors = const [],
    this.entranceFloorIds = const [],
    this.defaultFloorLevel = 0,
    this.properties = const {},
  });

  factory Building.fromJson(Map<String, dynamic> json) {
    try {
      return Building(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        centerPosition: _parseLatLng(json['centerPosition']),
        boundaryPoints: _parseLatLngList(json['boundaryPoints']),
        floors: (json['floors'] as List<dynamic>?)
            ?.map((e) => Floor.fromJson(e as Map<String, dynamic>))
            .toList() ?? const [],
        entranceFloorIds: (json['entranceFloorIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? const [],
        defaultFloorLevel: (json['defaultFloorLevel'] is num) 
            ? json['defaultFloorLevel'].toInt() 
            : 0,
        properties: (json['properties'] as Map<String, dynamic>?) ?? const {},
      );
    } catch (e) {
      throw FormatException('Failed to parse Building from JSON: $e');
    }
  }

  Map<String, dynamic> toJson() => _$BuildingToJson(this);

  // NEW: Helper methods
  Floor? get defaultFloor => floors.where((f) => f.level == defaultFloorLevel).firstOrNull;
  List<Floor> get sortedFloors => [...floors]..sort((a, b) => b.level.compareTo(a.level));
  List<Landmark> get allVerticalCirculation => 
      floors.expand((f) => f.verticalCirculation).toList();

  Building copyWith({
    String? name,
    LatLng? centerPosition,
    List<LatLng>? boundaryPoints,
    List<Floor>? floors,
    List<String>? entranceFloorIds,
    int? defaultFloorLevel,
    Map<String, dynamic>? properties,
  }) {
    return Building(
      id: id,
      name: name ?? this.name,
      centerPosition: centerPosition ?? this.centerPosition,
      boundaryPoints: boundaryPoints ?? this.boundaryPoints,
      floors: floors ?? this.floors,
      entranceFloorIds: entranceFloorIds ?? this.entranceFloorIds,
      defaultFloorLevel: defaultFloorLevel ?? this.defaultFloorLevel,
      properties: properties ?? this.properties,
    );
  }
}

@JsonSerializable()
class RoadSystem {
  final String id;
  final String name;
  final List<Building> buildings;
  final List<Road> outdoorRoads;
  final List<Landmark> outdoorLandmarks;
  final List<Intersection> outdoorIntersections; // NEW: For road network
  final LatLng centerPosition;
  final double zoom;
  final Map<String, dynamic> properties;

  RoadSystem({
    required this.id,
    required this.name,
    this.buildings = const [],
    this.outdoorRoads = const [],
    this.outdoorLandmarks = const [],
    this.outdoorIntersections = const [],
    required this.centerPosition,
    this.zoom = 16.0,
    this.properties = const {},
  });

  factory RoadSystem.fromJson(Map<String, dynamic> json) {
    try {
      return RoadSystem(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        buildings: (json['buildings'] as List<dynamic>?)
            ?.map((e) => Building.fromJson(e as Map<String, dynamic>))
            .toList() ?? const [],
        outdoorRoads: (json['outdoorRoads'] as List<dynamic>?)
            ?.map((e) => Road.fromJson(e as Map<String, dynamic>))
            .toList() ?? const [],
        outdoorLandmarks: (json['outdoorLandmarks'] as List<dynamic>?)
            ?.map((e) => Landmark.fromJson(e as Map<String, dynamic>))
            .toList() ?? const [],
        outdoorIntersections: (json['outdoorIntersections'] as List<dynamic>?)
            ?.map((e) => Intersection.fromJson(e as Map<String, dynamic>))
            .toList() ?? const [],
        centerPosition: _parseLatLng(json['centerPosition']),
        zoom: (json['zoom'] is num) ? json['zoom'].toDouble() : 16.0,
        properties: (json['properties'] as Map<String, dynamic>?) ?? const {},
      );
    } catch (e) {
      throw FormatException('Failed to parse RoadSystem from JSON: $e');
    }
  }

  Map<String, dynamic> toJson() => _$RoadSystemToJson(this);

  // NEW: Helper methods for comprehensive data access
  List<Road> get allRoads => [
    ...outdoorRoads,
    ...buildings.expand((b) => b.floors.expand((f) => f.roads)),
  ];

  List<Landmark> get allLandmarks => [
    ...outdoorLandmarks,
    ...buildings.expand((b) => b.floors.expand((f) => f.landmarks)),
  ];

  List<Floor> get allFloors => buildings.expand((b) => b.floors).toList();

  RoadSystem copyWith({
    String? name,
    List<Building>? buildings,
    List<Road>? outdoorRoads,
    List<Landmark>? outdoorLandmarks,
    List<Intersection>? outdoorIntersections,
    LatLng? centerPosition,
    double? zoom,
    Map<String, dynamic>? properties,
  }) {
    return RoadSystem(
      id: id,
      name: name ?? this.name,
      buildings: buildings ?? this.buildings,
      outdoorRoads: outdoorRoads ?? this.outdoorRoads,
      outdoorLandmarks: outdoorLandmarks ?? this.outdoorLandmarks,
      outdoorIntersections: outdoorIntersections ?? this.outdoorIntersections,
      centerPosition: centerPosition ?? this.centerPosition,
      zoom: zoom ?? this.zoom,
      properties: properties ?? this.properties,
    );
  }
}

// Additional model classes (keeping existing ones)

@JsonSerializable()
class Intersection {
  final String id;
  final String name;
  final LatLng position;
  final String floorId;
  final List<String> connectedRoadIds;
  final String type; // 'simple', 'traffic_light', 'stop_sign', 'roundabout'
  final Map<String, dynamic> properties;

  Intersection({
    required this.id,
    required this.name,
    required this.position,
    required this.floorId,
    this.connectedRoadIds = const [],
    this.type = 'simple',
    this.properties = const {},
  });

  factory Intersection.fromJson(Map<String, dynamic> json) {
    try {
      return Intersection(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        position: _parseLatLng(json['position']),
        floorId: json['floorId']?.toString() ?? '',
        connectedRoadIds: (json['connectedRoadIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? const [],
        type: json['type']?.toString() ?? 'simple',
        properties: (json['properties'] as Map<String, dynamic>?) ?? const {},
      );
    } catch (e) {
      throw FormatException('Failed to parse Intersection from JSON: $e');
    }
  }

  Map<String, dynamic> toJson() => _$IntersectionToJson(this);

  bool get isIndoor => floorId.isNotEmpty;
  bool get isOutdoor => floorId.isEmpty;
}

@JsonSerializable()
class NavigationRoute {
  final String id;
  final LatLng start;
  final LatLng end;
  final List<LatLng> waypoints;
  final double totalDistance;
  final String instructions;
  final List<String> floorChanges;
  final List<FloorTransition> floorTransitions;

  NavigationRoute({
    required this.id,
    required this.start,
    required this.end,
    required this.waypoints,
    required this.totalDistance,
    this.instructions = '',
    this.floorChanges = const [],
    this.floorTransitions = const [],
  });

  factory NavigationRoute.fromJson(Map<String, dynamic> json) {
    try {
      return NavigationRoute(
        id: json['id']?.toString() ?? '',
        start: _parseLatLng(json['start']),
        end: _parseLatLng(json['end']),
        waypoints: _parseLatLngList(json['waypoints']),
        totalDistance: (json['totalDistance'] is num) 
            ? json['totalDistance'].toDouble() 
            : 0.0,
        instructions: json['instructions']?.toString() ?? '',
        floorChanges: (json['floorChanges'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? const [],
        floorTransitions: (json['floorTransitions'] as List<dynamic>?)
            ?.map((e) => FloorTransition.fromJson(e as Map<String, dynamic>))
            .toList() ?? const [],
      );
    } catch (e) {
      throw FormatException('Failed to parse NavigationRoute from JSON: $e');
    }
  }

  Map<String, dynamic> toJson() => _$NavigationRouteToJson(this);
}

@JsonSerializable()
class FloorTransition {
  final String fromFloorId;
  final String toFloorId;
  final String buildingId;
  final LatLng transitionPoint;
  final String transitionType; // 'elevator', 'stairs', 'escalator', 'ramp'
  final String landmarkId; // ID of the elevator/stairs landmark
  final String instructions;

  FloorTransition({
    required this.fromFloorId,
    required this.toFloorId,
    required this.buildingId,
    required this.transitionPoint,
    required this.transitionType,
    required this.landmarkId,
    this.instructions = '',
  });

  factory FloorTransition.fromJson(Map<String, dynamic> json) {
    try {
      return FloorTransition(
        fromFloorId: json['fromFloorId']?.toString() ?? '',
        toFloorId: json['toFloorId']?.toString() ?? '',
        buildingId: json['buildingId']?.toString() ?? '',
        transitionPoint: _parseLatLng(json['transitionPoint']),
        transitionType: json['transitionType']?.toString() ?? '',
        landmarkId: json['landmarkId']?.toString() ?? '',
        instructions: json['instructions']?.toString() ?? '',
      );
    } catch (e) {
      throw FormatException('Failed to parse FloorTransition from JSON: $e');
    }
  }

  Map<String, dynamic> toJson() => _$FloorTransitionToJson(this);
}

// Extension to add firstOrNull functionality for better null safety
extension IterableExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }
}