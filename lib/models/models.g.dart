// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$RoadToJson(Road instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'points': instance.points.map((e) => {
        'latitude': e.latitude,
        'longitude': e.longitude,
      }).toList(),
      'type': instance.type,
      'width': instance.width,
      'isOneWay': instance.isOneWay,
      'floorId': instance.floorId,
      'connectedIntersections': instance.connectedIntersections,
      'properties': instance.properties,
    };

Map<String, dynamic> _$LandmarkToJson(Landmark instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      'position': {
        'latitude': instance.position.latitude,
        'longitude': instance.position.longitude,
      },
      'floorId': instance.floorId,
      'description': instance.description,
      'connectedFloors': instance.connectedFloors,
      'buildingId': instance.buildingId,
      'properties': instance.properties,
    };

Map<String, dynamic> _$FloorToJson(Floor instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'level': instance.level,
      'buildingId': instance.buildingId,
      'roads': instance.roads.map((e) => e.toJson()).toList(),
      'landmarks': instance.landmarks.map((e) => e.toJson()).toList(),
      'connectedFloors': instance.connectedFloors,
      'centerPosition': instance.centerPosition != null ? {
        'latitude': instance.centerPosition!.latitude,
        'longitude': instance.centerPosition!.longitude,
      } : null,
      'properties': instance.properties,
    };

Map<String, dynamic> _$BuildingToJson(Building instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'centerPosition': {
        'latitude': instance.centerPosition.latitude,
        'longitude': instance.centerPosition.longitude,
      },
      'boundaryPoints': instance.boundaryPoints.map((e) => {
        'latitude': e.latitude,
        'longitude': e.longitude,
      }).toList(),
      'floors': instance.floors.map((e) => e.toJson()).toList(),
      'entranceFloorIds': instance.entranceFloorIds,
      'defaultFloorLevel': instance.defaultFloorLevel,
      'properties': instance.properties,
    };

Map<String, dynamic> _$RoadSystemToJson(RoadSystem instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'buildings': instance.buildings.map((e) => e.toJson()).toList(),
      'outdoorRoads': instance.outdoorRoads.map((e) => e.toJson()).toList(),
      'outdoorLandmarks': instance.outdoorLandmarks.map((e) => e.toJson()).toList(),
      'outdoorIntersections': instance.outdoorIntersections.map((e) => e.toJson()).toList(),
      'centerPosition': {
        'latitude': instance.centerPosition.latitude,
        'longitude': instance.centerPosition.longitude,
      },
      'zoom': instance.zoom,
      'properties': instance.properties,
    };

Map<String, dynamic> _$IntersectionToJson(Intersection instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'position': {
        'latitude': instance.position.latitude,
        'longitude': instance.position.longitude,
      },
      'floorId': instance.floorId,
      'connectedRoadIds': instance.connectedRoadIds,
      'type': instance.type,
      'properties': instance.properties,
    };

Map<String, dynamic> _$NavigationRouteToJson(NavigationRoute instance) => <String, dynamic>{
      'id': instance.id,
      'start': {
        'latitude': instance.start.latitude,
        'longitude': instance.start.longitude,
      },
      'end': {
        'latitude': instance.end.latitude,
        'longitude': instance.end.longitude,
      },
      'waypoints': instance.waypoints.map((e) => {
        'latitude': e.latitude,
        'longitude': e.longitude,
      }).toList(),
      'totalDistance': instance.totalDistance,
      'instructions': instance.instructions,
      'floorChanges': instance.floorChanges,
      'floorTransitions': instance.floorTransitions.map((e) => e.toJson()).toList(),
    };

Map<String, dynamic> _$FloorTransitionToJson(FloorTransition instance) => <String, dynamic>{
      'fromFloorId': instance.fromFloorId,
      'toFloorId': instance.toFloorId,
      'buildingId': instance.buildingId,
      'transitionPoint': {
        'latitude': instance.transitionPoint.latitude,
        'longitude': instance.transitionPoint.longitude,
      },
      'transitionType': instance.transitionType,
      'landmarkId': instance.landmarkId,
      'instructions': instance.instructions,
    };