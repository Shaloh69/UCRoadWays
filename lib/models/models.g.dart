// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Road _$RoadFromJson(Map<String, dynamic> json) => Road(
      id: json['id'] as String,
      name: json['name'] as String,
      points: const LatLngListConverter()
          .fromJson(json['points'] as List<dynamic>),
      type: json['type'] as String? ?? 'road',
      width: (json['width'] as num?)?.toDouble() ?? 5.0,
      isOneWay: json['isOneWay'] as bool? ?? false,
      floorId: json['floorId'] as String,
      connectedIntersections: (json['connectedIntersections'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      properties: json['properties'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$RoadToJson(Road instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'points': const LatLngListConverter().toJson(instance.points),
      'type': instance.type,
      'width': instance.width,
      'isOneWay': instance.isOneWay,
      'floorId': instance.floorId,
      'connectedIntersections': instance.connectedIntersections,
      'properties': instance.properties,
    };

Landmark _$LandmarkFromJson(Map<String, dynamic> json) => Landmark(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      position: const LatLngConverter()
          .fromJson(json['position'] as Map<String, dynamic>),
      floorId: json['floorId'] as String,
      description: json['description'] as String? ?? '',
      properties: json['properties'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$LandmarkToJson(Landmark instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      'position': const LatLngConverter().toJson(instance.position),
      'floorId': instance.floorId,
      'description': instance.description,
      'properties': instance.properties,
    };

Floor _$FloorFromJson(Map<String, dynamic> json) => Floor(
      id: json['id'] as String,
      name: json['name'] as String,
      level: (json['level'] as num).toInt(),
      buildingId: json['buildingId'] as String,
      roads: (json['roads'] as List<dynamic>?)
              ?.map((e) => Road.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      landmarks: (json['landmarks'] as List<dynamic>?)
              ?.map((e) => Landmark.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      properties: json['properties'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$FloorToJson(Floor instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'level': instance.level,
      'buildingId': instance.buildingId,
      'roads': instance.roads,
      'landmarks': instance.landmarks,
      'properties': instance.properties,
    };

Building _$BuildingFromJson(Map<String, dynamic> json) => Building(
      id: json['id'] as String,
      name: json['name'] as String,
      centerPosition: const LatLngConverter()
          .fromJson(json['centerPosition'] as Map<String, dynamic>),
      boundaryPoints: const LatLngListConverter()
          .fromJson(json['boundaryPoints'] as List<dynamic>),
      floors: (json['floors'] as List<dynamic>?)
              ?.map((e) => Floor.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      properties: json['properties'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$BuildingToJson(Building instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'centerPosition': const LatLngConverter().toJson(instance.centerPosition),
      'boundaryPoints': const LatLngListConverter().toJson(instance.boundaryPoints),
      'floors': instance.floors,
      'properties': instance.properties,
    };

Intersection _$IntersectionFromJson(Map<String, dynamic> json) => Intersection(
      id: json['id'] as String,
      name: json['name'] as String,
      position: const LatLngConverter()
          .fromJson(json['position'] as Map<String, dynamic>),
      floorId: json['floorId'] as String,
      connectedRoadIds: (json['connectedRoadIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      type: json['type'] as String? ?? 'simple',
      properties: json['properties'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$IntersectionToJson(Intersection instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'position': const LatLngConverter().toJson(instance.position),
      'floorId': instance.floorId,
      'connectedRoadIds': instance.connectedRoadIds,
      'type': instance.type,
      'properties': instance.properties,
    };

RoadSystem _$RoadSystemFromJson(Map<String, dynamic> json) => RoadSystem(
      id: json['id'] as String,
      name: json['name'] as String,
      buildings: (json['buildings'] as List<dynamic>?)
              ?.map((e) => Building.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      outdoorRoads: (json['outdoorRoads'] as List<dynamic>?)
              ?.map((e) => Road.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      outdoorLandmarks: (json['outdoorLandmarks'] as List<dynamic>?)
              ?.map((e) => Landmark.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      outdoorIntersections: (json['outdoorIntersections'] as List<dynamic>?)
              ?.map((e) => Intersection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      centerPosition: const LatLngConverter()
          .fromJson(json['centerPosition'] as Map<String, dynamic>),
      zoom: (json['zoom'] as num?)?.toDouble() ?? 16.0,
      properties: json['properties'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$RoadSystemToJson(RoadSystem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'buildings': instance.buildings,
      'outdoorRoads': instance.outdoorRoads,
      'outdoorLandmarks': instance.outdoorLandmarks,
      'outdoorIntersections': instance.outdoorIntersections,
      'centerPosition': const LatLngConverter().toJson(instance.centerPosition),
      'zoom': instance.zoom,
      'properties': instance.properties,
    };

NavigationRoute _$NavigationRouteFromJson(Map<String, dynamic> json) =>
    NavigationRoute(
      id: json['id'] as String,
      start: const LatLngConverter()
          .fromJson(json['start'] as Map<String, dynamic>),
      end: const LatLngConverter()
          .fromJson(json['end'] as Map<String, dynamic>),
      waypoints: const LatLngListConverter()
          .fromJson(json['waypoints'] as List<dynamic>),
      totalDistance: (json['totalDistance'] as num).toDouble(),
      instructions: json['instructions'] as String? ?? '',
      floorChanges: (json['floorChanges'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$NavigationRouteToJson(NavigationRoute instance) =>
    <String, dynamic>{
      'id': instance.id,
      'start': const LatLngConverter().toJson(instance.start),
      'end': const LatLngConverter().toJson(instance.end),
      'waypoints': const LatLngListConverter().toJson(instance.waypoints),
      'totalDistance': instance.totalDistance,
      'instructions': instance.instructions,
      'floorChanges': instance.floorChanges,
    };