// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Road _$RoadFromJson(Map<String, dynamic> json) => Road(
      id: json['id'] as String,
      name: json['name'] as String,
      points: (json['points'] as List<dynamic>)
          .map((e) => LatLngJson.fromJson(e as Map<String, dynamic>))
          .toList(),
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
      'points': instance.points.map((e) => e.toJson()).toList(),
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
      position: LatLngJson.fromJson(json['position'] as Map<String, dynamic>),
      floorId: json['floorId'] as String,
      description: json['description'] as String? ?? '',
      connectedFloors: (json['connectedFloors'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      buildingId: json['buildingId'] as String? ?? '',
      properties: json['properties'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$LandmarkToJson(Landmark instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      'position': instance.position.toJson(),
      'floorId': instance.floorId,
      'description': instance.description,
      'connectedFloors': instance.connectedFloors,
      'buildingId': instance.buildingId,
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
      connectedFloors: (json['connectedFloors'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      centerPosition: json['centerPosition'] == null
          ? null
          : LatLngJson.fromJson(json['centerPosition'] as Map<String, dynamic>),
      properties: json['properties'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$FloorToJson(Floor instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'level': instance.level,
      'buildingId': instance.buildingId,
      'roads': instance.roads.map((e) => e.toJson()).toList(),
      'landmarks': instance.landmarks.map((e) => e.toJson()).toList(),
      'connectedFloors': instance.connectedFloors,
      'centerPosition': instance.centerPosition?.toJson(),
      'properties': instance.properties,
    };

Building _$BuildingFromJson(Map<String, dynamic> json) => Building(
      id: json['id'] as String,
      name: json['name'] as String,
      centerPosition: LatLngJson.fromJson(json['centerPosition'] as Map<String, dynamic>),
      boundaryPoints: (json['boundaryPoints'] as List<dynamic>?)
              ?.map((e) => LatLngJson.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      floors: (json['floors'] as List<dynamic>?)
              ?.map((e) => Floor.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      entranceFloorIds: (json['entranceFloorIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      defaultFloorLevel: (json['defaultFloorLevel'] as num?)?.toInt() ?? 0,
      properties: json['properties'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$BuildingToJson(Building instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'centerPosition': instance.centerPosition.toJson(),
      'boundaryPoints': instance.boundaryPoints.map((e) => e.toJson()).toList(),
      'floors': instance.floors.map((e) => e.toJson()).toList(),
      'entranceFloorIds': instance.entranceFloorIds,
      'defaultFloorLevel': instance.defaultFloorLevel,
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
      centerPosition: LatLngJson.fromJson(json['centerPosition'] as Map<String, dynamic>),
      zoom: (json['zoom'] as num?)?.toDouble() ?? 16.0,
      properties: json['properties'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$RoadSystemToJson(RoadSystem instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'buildings': instance.buildings.map((e) => e.toJson()).toList(),
      'outdoorRoads': instance.outdoorRoads.map((e) => e.toJson()).toList(),
      'outdoorLandmarks': instance.outdoorLandmarks.map((e) => e.toJson()).toList(),
      'outdoorIntersections': instance.outdoorIntersections.map((e) => e.toJson()).toList(),
      'centerPosition': instance.centerPosition.toJson(),
      'zoom': instance.zoom,
      'properties': instance.properties,
    };

Intersection _$IntersectionFromJson(Map<String, dynamic> json) => Intersection(
      id: json['id'] as String,
      name: json['name'] as String,
      position: LatLngJson.fromJson(json['position'] as Map<String, dynamic>),
      floorId: json['floorId'] as String,
      connectedRoadIds: (json['connectedRoadIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      type: json['type'] as String? ?? 'simple',
      properties: json['properties'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$IntersectionToJson(Intersection instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'position': instance.position.toJson(),
      'floorId': instance.floorId,
      'connectedRoadIds': instance.connectedRoadIds,
      'type': instance.type,
      'properties': instance.properties,
    };

NavigationRoute _$NavigationRouteFromJson(Map<String, dynamic> json) => NavigationRoute(
      id: json['id'] as String,
      start: LatLngJson.fromJson(json['start'] as Map<String, dynamic>),
      end: LatLngJson.fromJson(json['end'] as Map<String, dynamic>),
      waypoints: (json['waypoints'] as List<dynamic>)
          .map((e) => LatLngJson.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalDistance: (json['totalDistance'] as num).toDouble(),
      instructions: json['instructions'] as String? ?? '',
      floorChanges: (json['floorChanges'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      floorTransitions: (json['floorTransitions'] as List<dynamic>?)
              ?.map((e) => FloorTransition.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$NavigationRouteToJson(NavigationRoute instance) => <String, dynamic>{
      'id': instance.id,
      'start': instance.start.toJson(),
      'end': instance.end.toJson(),
      'waypoints': instance.waypoints.map((e) => e.toJson()).toList(),
      'totalDistance': instance.totalDistance,
      'instructions': instance.instructions,
      'floorChanges': instance.floorChanges,
      'floorTransitions': instance.floorTransitions.map((e) => e.toJson()).toList(),
    };

FloorTransition _$FloorTransitionFromJson(Map<String, dynamic> json) => FloorTransition(
      fromFloorId: json['fromFloorId'] as String,
      toFloorId: json['toFloorId'] as String,
      transitionType: json['transitionType'] as String,
      position: LatLngJson.fromJson(json['position'] as Map<String, dynamic>),
      landmarkId: json['landmarkId'] as String,
    );

Map<String, dynamic> _$FloorTransitionToJson(FloorTransition instance) => <String, dynamic>{
      'fromFloorId': instance.fromFloorId,
      'toFloorId': instance.toFloorId,
      'transitionType': instance.transitionType,
      'position': instance.position.toJson(),
      'landmarkId': instance.landmarkId,
    };