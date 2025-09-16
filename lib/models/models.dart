import 'package:latlong2/latlong.dart';
import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

@JsonSerializable()
class Road {
  final String id;
  final String name;
  final List<LatLng> points;
  final String type; // 'road', 'walkway', 'corridor'
  final double width;
  final bool isOneWay;
  final String floorId;
  final Map<String, dynamic> properties;

  Road({
    required this.id,
    required this.name,
    required this.points,
    this.type = 'road',
    this.width = 5.0,
    this.isOneWay = false,
    required this.floorId,
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
  final LatLng centerPosition;
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
class RoadSystem {
  final String id;
  final String name;
  final List<Building> buildings;
  final List<Road> outdoorRoads;
  final List<Landmark> outdoorLandmarks;
  final LatLng centerPosition;
  final double zoom;
  final Map<String, dynamic> properties;

  RoadSystem({
    required this.id,
    required this.name,
    this.buildings = const [],
    this.outdoorRoads = const [],
    this.outdoorLandmarks = const [],
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
      centerPosition: centerPosition ?? this.centerPosition,
      zoom: zoom ?? this.zoom,
      properties: properties ?? this.properties,
    );
  }
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