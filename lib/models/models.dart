import 'package:latlong2/latlong.dart';
import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

// Custom converter for LatLng
class LatLngConverter implements JsonConverter<LatLng, Map<String, dynamic>> {
  const LatLngConverter();

  @override
  LatLng fromJson(Map<String, dynamic> json) {
    return LatLng(
      (json['latitude'] as num).toDouble(),
      (json['longitude'] as num).toDouble(),
    );
  }

  @override
  Map<String, dynamic> toJson(LatLng latLng) {
    return {
      'latitude': latLng.latitude,
      'longitude': latLng.longitude,
    };
  }
}

// Custom converter for List<LatLng>
class LatLngListConverter implements JsonConverter<List<LatLng>, List<dynamic>> {
  const LatLngListConverter();

  @override
  List<LatLng> fromJson(List<dynamic> json) {
    return json.map((e) => const LatLngConverter().fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  List<dynamic> toJson(List<LatLng> latLngs) {
    return latLngs.map((e) => const LatLngConverter().toJson(e)).toList();
  }
}

@JsonSerializable()
class Road {
  final String id;
  final String name;
  
  @LatLngListConverter()
  final List<LatLng> points;
  
  final String type; // 'road', 'walkway', 'corridor'
  final double width;
  final bool isOneWay;
  final String floorId;
  final List<String> connectedIntersections; // Connected intersection IDs
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

  factory Road.fromJson(Map<String, dynamic> json) => _$RoadFromJson(json);
  Map<String, dynamic> toJson() => _$RoadToJson(this);

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
  
  @LatLngConverter()
  final LatLng position;
  
  final String floorId;
  final String description;
  final Map<String, dynamic> properties;

  Landmark({
    required this.id,
    required this.name,
    required this.type,
    required this.position,
    required this.floorId,
    this.description = '',
    this.properties = const {},
  });

  factory Landmark.fromJson(Map<String, dynamic> json) => _$LandmarkFromJson(json);
  Map<String, dynamic> toJson() => _$LandmarkToJson(this);

  Landmark copyWith({
    String? name,
    String? type,
    LatLng? position,
    String? description,
    Map<String, dynamic>? properties,
  }) {
    return Landmark(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      position: position ?? this.position,
      floorId: floorId,
      description: description ?? this.description,
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
  final Map<String, dynamic> properties;

  Floor({
    required this.id,
    required this.name,
    required this.level,
    required this.buildingId,
    this.roads = const [],
    this.landmarks = const [],
    this.properties = const {},
  });

  factory Floor.fromJson(Map<String, dynamic> json) => _$FloorFromJson(json);
  Map<String, dynamic> toJson() => _$FloorToJson(this);

  Floor copyWith({
    String? name,
    int? level,
    List<Road>? roads,
    List<Landmark>? landmarks,
    Map<String, dynamic>? properties,
  }) {
    return Floor(
      id: id,
      name: name ?? this.name,
      level: level ?? this.level,
      buildingId: buildingId,
      roads: roads ?? this.roads,
      landmarks: landmarks ?? this.landmarks,
      properties: properties ?? this.properties,
    );
  }
}

@JsonSerializable()
class Building {
  final String id;
  final String name;
  
  @LatLngConverter()
  final LatLng centerPosition;
  
  @LatLngListConverter()
  final List<LatLng> boundaryPoints;
  
  final List<Floor> floors;
  final Map<String, dynamic> properties;

  Building({
    required this.id,
    required this.name,
    required this.centerPosition,
    this.boundaryPoints = const [],
    this.floors = const [],
    this.properties = const {},
  });

  factory Building.fromJson(Map<String, dynamic> json) => _$BuildingFromJson(json);
  Map<String, dynamic> toJson() => _$BuildingToJson(this);

  Building copyWith({
    String? name,
    LatLng? centerPosition,
    List<LatLng>? boundaryPoints,
    List<Floor>? floors,
    Map<String, dynamic>? properties,
  }) {
    return Building(
      id: id,
      name: name ?? this.name,
      centerPosition: centerPosition ?? this.centerPosition,
      boundaryPoints: boundaryPoints ?? this.boundaryPoints,
      floors: floors ?? this.floors,
      properties: properties ?? this.properties,
    );
  }
}

@JsonSerializable()
class Intersection {
  final String id;
  final String name;
  
  @LatLngConverter()
  final LatLng position;
  
  final String floorId;
  final List<String> connectedRoadIds;
  final String type;
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

  factory Intersection.fromJson(Map<String, dynamic> json) => _$IntersectionFromJson(json);
  Map<String, dynamic> toJson() => _$IntersectionToJson(this);

  Intersection copyWith({
    String? name,
    LatLng? position,
    List<String>? connectedRoadIds,
    String? type,
    Map<String, dynamic>? properties,
  }) {
    return Intersection(
      id: id,
      name: name ?? this.name,
      position: position ?? this.position,
      floorId: floorId,
      connectedRoadIds: connectedRoadIds ?? this.connectedRoadIds,
      type: type ?? this.type,
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
  final List<Intersection> outdoorIntersections; // Outdoor intersections
  
  @LatLngConverter()
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

  factory RoadSystem.fromJson(Map<String, dynamic> json) => _$RoadSystemFromJson(json);
  Map<String, dynamic> toJson() => _$RoadSystemToJson(this);

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

@JsonSerializable()
class NavigationRoute {
  final String id;
  
  @LatLngConverter()
  final LatLng start;
  
  @LatLngConverter()
  final LatLng end;
  
  @LatLngListConverter()
  final List<LatLng> waypoints;
  
  final double totalDistance;
  final String instructions;
  final List<String> floorChanges;

  NavigationRoute({
    required this.id,
    required this.start,
    required this.end,
    required this.waypoints,
    required this.totalDistance,
    this.instructions = '',
    this.floorChanges = const [],
  });

  factory NavigationRoute.fromJson(Map<String, dynamic> json) => _$NavigationRouteFromJson(json);
  Map<String, dynamic> toJson() => _$NavigationRouteToJson(this);
}