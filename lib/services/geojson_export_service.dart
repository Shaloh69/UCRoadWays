import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

/// Service for exporting UCRoadWays data to GeoJSON format.
///
/// This service provides methods to export road systems, buildings, roads,
/// and landmarks to GeoJSON format compatible with OpenLayers and other
/// mapping libraries. It supports both single-file and multi-layer exports.
class GeoJsonExportService {
  /// Exports a road system to GeoJSON format optimized for OpenLayers.
  ///
  /// Parameters:
  /// - [roadSystem]: The road system to export
  /// - [includeIndoorData]: Whether to include indoor navigation data (default: true)
  /// - [includeMetadata]: Whether to include metadata about the export (default: true)
  /// - [layerFilter]: Optional list of layer names to include (null = all layers)
  ///
  /// Returns a [File] containing the exported GeoJSON data.
  ///
  /// Throws an exception if the export fails.
  static Future<File> exportToGeoJSON(RoadSystem roadSystem, {
    bool includeIndoorData = true,
    bool includeMetadata = true,
    List<String>? layerFilter,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = '${roadSystem.name}_$timestamp.geojson';
      final file = File('${directory.path}/$fileName');
      
      final geoJsonContent = _generateGeoJSON(
        roadSystem,
        includeIndoorData: includeIndoorData,
        includeMetadata: includeMetadata,
        layerFilter: layerFilter,
      );
      
      await file.writeAsString(json.encode(geoJsonContent));
      debugPrint('GeoJSON exported to: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('Error exporting to GeoJSON: $e');
      rethrow;
    }
  }

  /// Exports multiple layer files for complex OpenLayers applications.
  ///
  /// This method creates separate GeoJSON files for each data layer:
  /// - buildings: Building footprints and floor data
  /// - outdoor_roads: Outdoor road network
  /// - indoor_roads: Indoor corridors and pathways
  /// - landmarks: Points of interest
  /// - entrances: Building entrances and access points
  /// - accessibility: Accessibility features
  ///
  /// Returns a Map where keys are layer names and values are the exported files.
  static Future<Map<String, File>> exportToLayeredGeoJSON(RoadSystem roadSystem) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final baseFileName = '${roadSystem.name}_$timestamp';
      
      final files = <String, File>{};
      
      // Export separate layers
      final layers = {
        'buildings': _generateBuildingsGeoJSON(roadSystem),
        'outdoor_roads': _generateOutdoorRoadsGeoJSON(roadSystem),
        'indoor_roads': _generateIndoorRoadsGeoJSON(roadSystem),
        'landmarks': _generateLandmarksGeoJSON(roadSystem),
        'entrances': _generateEntrancesGeoJSON(roadSystem),
        'accessibility': _generateAccessibilityGeoJSON(roadSystem),
      };
      
      for (final entry in layers.entries) {
        final file = File('${directory.path}/${baseFileName}_${entry.key}.geojson');
        await file.writeAsString(json.encode(entry.value));
        files[entry.key] = file;
        debugPrint('Layer ${entry.key} exported to: ${file.path}');
      }
      
      return files;
    } catch (e) {
      debugPrint('Error exporting layered GeoJSON: $e');
      rethrow;
    }
  }

  /// Generate complete GeoJSON FeatureCollection
  static Map<String, dynamic> _generateGeoJSON(
    RoadSystem roadSystem, {
    bool includeIndoorData = true,
    bool includeMetadata = true,
    List<String>? layerFilter,
  }) {
    final features = <Map<String, dynamic>>[];
    
    // Filter layers if specified
    bool shouldInclude(String layer) => 
        layerFilter == null || layerFilter.contains(layer);
    
    // Add buildings as polygons
    if (shouldInclude('buildings')) {
      features.addAll(_getBuildingFeatures(roadSystem));
    }
    
    // Add outdoor roads as linestrings
    if (shouldInclude('outdoor_roads')) {
      features.addAll(_getOutdoorRoadFeatures(roadSystem));
    }
    
    // Add indoor roads if requested
    if (includeIndoorData && shouldInclude('indoor_roads')) {
      features.addAll(_getIndoorRoadFeatures(roadSystem));
    }
    
    // Add landmarks as points
    if (shouldInclude('landmarks')) {
      features.addAll(_getLandmarkFeatures(roadSystem, includeIndoorData));
    }
    
    // Add building entrances
    if (shouldInclude('entrances')) {
      features.addAll(_getEntranceFeatures(roadSystem));
    }
    
    // Add accessibility features
    if (shouldInclude('accessibility')) {
      features.addAll(_getAccessibilityFeatures(roadSystem));
    }
    
    final geoJson = {
      'type': 'FeatureCollection',
      'features': features,
    };
    
    if (includeMetadata) {
      geoJson['metadata'] = _generateMetadata(roadSystem);
      geoJson['crs'] = {
        'type': 'name',
        'properties': {
          'name': 'EPSG:4326'
        }
      };
    }
    
    return geoJson;
  }

  /// Generate buildings layer GeoJSON
  static Map<String, dynamic> _generateBuildingsGeoJSON(RoadSystem roadSystem) {
    return {
      'type': 'FeatureCollection',
      'features': _getBuildingFeatures(roadSystem),
      'metadata': {
        'layer': 'buildings',
        'description': 'Building footprints and boundaries',
        'style': _getBuildingStyle(),
      }
    };
  }

  /// Generate outdoor roads layer GeoJSON
  static Map<String, dynamic> _generateOutdoorRoadsGeoJSON(RoadSystem roadSystem) {
    return {
      'type': 'FeatureCollection',
      'features': _getOutdoorRoadFeatures(roadSystem),
      'metadata': {
        'layer': 'outdoor_roads',
        'description': 'Outdoor road network',
        'style': _getRoadStyle(),
      }
    };
  }

  /// Generate indoor roads layer GeoJSON
  static Map<String, dynamic> _generateIndoorRoadsGeoJSON(RoadSystem roadSystem) {
    return {
      'type': 'FeatureCollection',
      'features': _getIndoorRoadFeatures(roadSystem),
      'metadata': {
        'layer': 'indoor_roads',
        'description': 'Indoor corridors and pathways',
        'style': _getIndoorRoadStyle(),
      }
    };
  }

  /// Generate landmarks layer GeoJSON
  static Map<String, dynamic> _generateLandmarksGeoJSON(RoadSystem roadSystem) {
    return {
      'type': 'FeatureCollection',
      'features': _getLandmarkFeatures(roadSystem, true),
      'metadata': {
        'layer': 'landmarks',
        'description': 'Points of interest and landmarks',
        'style': _getLandmarkStyle(),
      }
    };
  }

  /// Generate entrances layer GeoJSON
  static Map<String, dynamic> _generateEntrancesGeoJSON(RoadSystem roadSystem) {
    return {
      'type': 'FeatureCollection',
      'features': _getEntranceFeatures(roadSystem),
      'metadata': {
        'layer': 'entrances',
        'description': 'Building entrances and access points',
        'style': _getEntranceStyle(),
      }
    };
  }

  /// Generate accessibility layer GeoJSON
  static Map<String, dynamic> _generateAccessibilityGeoJSON(RoadSystem roadSystem) {
    return {
      'type': 'FeatureCollection',
      'features': _getAccessibilityFeatures(roadSystem),
      'metadata': {
        'layer': 'accessibility',
        'description': 'Accessibility features and barriers',
        'style': _getAccessibilityStyle(),
      }
    };
  }

  /// Convert buildings to GeoJSON features
  static List<Map<String, dynamic>> _getBuildingFeatures(RoadSystem roadSystem) {
    final features = <Map<String, dynamic>>[];
    
    for (final building in roadSystem.buildings) {
      // Building boundary polygon
      final coordinates = building.boundaryPoints.isNotEmpty
          ? [building.boundaryPoints.map((point) => [point.longitude, point.latitude]).toList()]
          : [_generateDefaultBuildingBoundary(building.centerPosition)];
      
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Polygon',
          'coordinates': coordinates,
        },
        'properties': {
          'id': building.id,
          'name': building.name,
          'type': 'building',
          'floor_count': building.floors.length,
          'default_floor_level': building.defaultFloorLevel,
          'has_elevator': building.floors.any((f) => 
              f.landmarks.any((l) => l.type == 'elevator')),
          'has_accessible_entrance': building.floors.any((f) => 
              f.landmarks.any((l) => l.type == 'entrance' && l.isAccessible)),
          'entrance_floor_ids': building.entranceFloorIds,
          'center_lat': building.centerPosition.latitude,
          'center_lng': building.centerPosition.longitude,
          'properties': building.properties,
          'style': _getBuildingStyleForBuilding(building),
        }
      });
      
      // Add floor polygons if detailed indoor data is needed
      for (final floor in building.floors) {
        if (floor.level != 0) { // Skip ground floor as it's covered by building
          features.add({
            'type': 'Feature',
            'geometry': {
              'type': 'Polygon',
              'coordinates': [_generateFloorBoundary(building.centerPosition, floor.level)],
            },
            'properties': {
              'id': floor.id,
              'name': floor.name,
              'type': 'floor',
              'building_id': building.id,
              'building_name': building.name,
              'level': floor.level,
              'landmark_count': floor.landmarks.length,
              'road_count': floor.roads.length,
              'connected_floors': floor.connectedFloors,
              'style': _getFloorStyle(floor.level),
            }
          });
        }
      }
    }
    
    return features;
  }

  /// Convert outdoor roads to GeoJSON features
  static List<Map<String, dynamic>> _getOutdoorRoadFeatures(RoadSystem roadSystem) {
    final features = <Map<String, dynamic>>[];
    
    for (final road in roadSystem.outdoorRoads) {
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': road.points.map((point) => [point.longitude, point.latitude]).toList(),
        },
        'properties': {
          'id': road.id,
          'name': road.name,
          'type': road.type,
          'category': 'outdoor_road',
          'width': road.width,
          'is_one_way': road.isOneWay,
          'length_meters': _calculateRoadLength(road),
          'connected_intersections': road.connectedIntersections,
          'surface_type': road.properties['surface_type'] ?? 'unknown',
          'accessibility': road.properties['accessibility'] ?? 'unknown',
          'properties': road.properties,
          'style': _getRoadStyleForType(road.type),
        }
      });
    }
    
    return features;
  }

  /// Convert indoor roads to GeoJSON features
  static List<Map<String, dynamic>> _getIndoorRoadFeatures(RoadSystem roadSystem) {
    final features = <Map<String, dynamic>>[];
    
    for (final building in roadSystem.buildings) {
      for (final floor in building.floors) {
        for (final road in floor.roads) {
          features.add({
            'type': 'Feature',
            'geometry': {
              'type': 'LineString',
              'coordinates': road.points.map((point) => [point.longitude, point.latitude]).toList(),
            },
            'properties': {
              'id': road.id,
              'name': road.name,
              'type': road.type,
              'category': 'indoor_road',
              'building_id': building.id,
              'building_name': building.name,
              'floor_id': floor.id,
              'floor_name': floor.name,
              'floor_level': floor.level,
              'width': road.width,
              'is_one_way': road.isOneWay,
              'length_meters': _calculateRoadLength(road),
              'connected_intersections': road.connectedIntersections,
              'properties': road.properties,
              'style': _getIndoorRoadStyleForType(road.type),
            }
          });
        }
      }
    }
    
    return features;
  }

  /// Convert landmarks to GeoJSON features
  static List<Map<String, dynamic>> _getLandmarkFeatures(RoadSystem roadSystem, bool includeIndoor) {
    final features = <Map<String, dynamic>>[];
    
    for (final building in roadSystem.buildings) {
      for (final floor in building.floors) {
        // Skip indoor landmarks if not requested
        if (!includeIndoor && floor.level != 0) continue;
        
        for (final landmark in floor.landmarks) {
          features.add({
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [landmark.position.longitude, landmark.position.latitude],
            },
            'properties': {
              'id': landmark.id,
              'name': landmark.name,
              'type': landmark.type,
              'category': 'landmark',
              'description': landmark.description,
              'building_id': building.id,
              'building_name': building.name,
              'floor_id': floor.id,
              'floor_name': floor.name,
              'floor_level': floor.level,
              'is_accessible': landmark.isAccessible,
              'is_vertical_circulation': landmark.isVerticalCirculation,
              'connected_floors': landmark.connectedFloors,
              'properties': landmark.properties,
              'style': _getLandmarkStyleForType(landmark.type),
            }
          });
        }
      }
    }
    
    return features;
  }

  /// Get entrance-specific features
  static List<Map<String, dynamic>> _getEntranceFeatures(RoadSystem roadSystem) {
    final features = <Map<String, dynamic>>[];
    
    for (final building in roadSystem.buildings) {
      for (final floor in building.floors) {
        final entrances = floor.landmarks.where((l) => l.type == 'entrance');
        
        for (final entrance in entrances) {
          features.add({
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [entrance.position.longitude, entrance.position.latitude],
            },
            'properties': {
              'id': entrance.id,
              'name': entrance.name,
              'type': 'entrance',
              'category': 'entrance',
              'building_id': building.id,
              'building_name': building.name,
              'floor_level': floor.level,
              'is_accessible': entrance.isAccessible,
              'is_main_entrance': building.entranceFloorIds.contains(floor.id),
              'entrance_type': entrance.properties['entrance_type'] ?? 'standard',
              'operating_hours': entrance.properties['operating_hours'],
              'access_control': entrance.properties['access_control'] ?? false,
              'style': _getEntranceStyleForType(entrance),
            }
          });
        }
      }
    }
    
    return features;
  }

  /// Get accessibility-specific features
  static List<Map<String, dynamic>> _getAccessibilityFeatures(RoadSystem roadSystem) {
    final features = <Map<String, dynamic>>[];
    
    for (final building in roadSystem.buildings) {
      for (final floor in building.floors) {
        final accessibilityLandmarks = floor.landmarks.where((l) => 
            l.isAccessible || 
            ['elevator', 'ramp', 'accessible_restroom', 'accessible_parking'].contains(l.type)
        );
        
        for (final landmark in accessibilityLandmarks) {
          features.add({
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [landmark.position.longitude, landmark.position.latitude],
            },
            'properties': {
              'id': landmark.id,
              'name': landmark.name,
              'type': landmark.type,
              'category': 'accessibility',
              'building_id': building.id,
              'building_name': building.name,
              'floor_level': floor.level,
              'accessibility_type': _getAccessibilityType(landmark),
              'compliance_level': landmark.properties['compliance_level'] ?? 'unknown',
              'features': landmark.properties['accessibility_features'] ?? [],
              'style': _getAccessibilityStyleForType(landmark.type),
            }
          });
        }
      }
    }
    
    return features;
  }

  /// Generate metadata for the GeoJSON
  static Map<String, dynamic> _generateMetadata(RoadSystem roadSystem) {
    return {
      'name': roadSystem.name,
      'exported_at': DateTime.now().toIso8601String(),
      'export_version': '1.0',
      'coordinate_system': 'WGS84',
      'bounds': _calculateBounds(roadSystem),
      'statistics': {
        'building_count': roadSystem.buildings.length,
        'outdoor_road_count': roadSystem.outdoorRoads.length,
        'total_road_count': roadSystem.allRoads.length,
        'landmark_count': roadSystem.allLandmarks.length,
        'floor_count': roadSystem.allFloors.length,
      },
      'layers': [
        'buildings',
        'outdoor_roads', 
        'indoor_roads',
        'landmarks',
        'entrances',
        'accessibility'
      ],
      'recommended_zoom': {
        'min': 15,
        'max': 22,
        'default': 18
      }
    };
  }

  /// Calculate bounding box for the road system
  static Map<String, dynamic> _calculateBounds(RoadSystem roadSystem) {
    if (roadSystem.buildings.isEmpty) {
      return {
        'southwest': [0.0, 0.0],
        'northeast': [0.0, 0.0]
      };
    }
    
    double minLat = roadSystem.buildings.first.centerPosition.latitude;
    double maxLat = roadSystem.buildings.first.centerPosition.latitude;
    double minLng = roadSystem.buildings.first.centerPosition.longitude;
    double maxLng = roadSystem.buildings.first.centerPosition.longitude;
    
    // Check building positions
    for (final building in roadSystem.buildings) {
      final pos = building.centerPosition;
      minLat = minLat < pos.latitude ? minLat : pos.latitude;
      maxLat = maxLat > pos.latitude ? maxLat : pos.latitude;
      minLng = minLng < pos.longitude ? minLng : pos.longitude;
      maxLng = maxLng > pos.longitude ? maxLng : pos.longitude;
    }
    
    // Check road points
    for (final road in roadSystem.allRoads) {
      for (final point in road.points) {
        minLat = minLat < point.latitude ? minLat : point.latitude;
        maxLat = maxLat > point.latitude ? maxLat : point.latitude;
        minLng = minLng < point.longitude ? minLng : point.longitude;
        maxLng = maxLng > point.longitude ? maxLng : point.longitude;
      }
    }
    
    return {
      'southwest': [minLng, minLat],
      'northeast': [maxLng, maxLat]
    };
  }

  // Helper methods for styling (OpenLayers compatible)
  
  static Map<String, dynamic> _getBuildingStyle() {
    return {
      'fill': {'color': 'rgba(150, 150, 150, 0.3)'},
      'stroke': {'color': '#666666', 'width': 2},
    };
  }

  static Map<String, dynamic> _getRoadStyle() {
    return {
      'stroke': {'color': '#4CAF50', 'width': 4},
    };
  }

  static Map<String, dynamic> _getIndoorRoadStyle() {
    return {
      'stroke': {'color': '#9C27B0', 'width': 3},
    };
  }

  static Map<String, dynamic> _getLandmarkStyle() {
    return {
      'image': {
        'type': 'circle',
        'radius': 6,
        'fill': {'color': '#FF5722'},
        'stroke': {'color': '#FFFFFF', 'width': 2},
      }
    };
  }

  static Map<String, dynamic> _getEntranceStyle() {
    return {
      'image': {
        'type': 'circle',
        'radius': 8,
        'fill': {'color': '#4CAF50'},
        'stroke': {'color': '#FFFFFF', 'width': 2},
      }
    };
  }

  static Map<String, dynamic> _getAccessibilityStyle() {
    return {
      'image': {
        'type': 'circle',
        'radius': 7,
        'fill': {'color': '#2196F3'},
        'stroke': {'color': '#FFFFFF', 'width': 2},
      }
    };
  }

  // Specific styling methods
  
  static Map<String, dynamic> _getBuildingStyleForBuilding(Building building) {
    final hasElevator = building.floors.any((f) => 
        f.landmarks.any((l) => l.type == 'elevator'));
    
    return {
      'fill': {'color': hasElevator ? 'rgba(76, 175, 80, 0.3)' : 'rgba(150, 150, 150, 0.3)'},
      'stroke': {'color': hasElevator ? '#4CAF50' : '#666666', 'width': 2},
    };
  }

  static Map<String, dynamic> _getFloorStyle(int level) {
    final opacity = level == 0 ? 0.3 : 0.1;
    return {
      'fill': {'color': 'rgba(33, 150, 243, $opacity)'},
      'stroke': {'color': '#2196F3', 'width': 1},
    };
  }

  static Map<String, dynamic> _getRoadStyleForType(String type) {
    final colors = {
      'road': '#666666',
      'path': '#8BC34A',
      'walkway': '#2196F3',
      'sidewalk': '#9E9E9E',
    };
    
    return {
      'stroke': {'color': colors[type] ?? '#666666', 'width': 4},
    };
  }

  static Map<String, dynamic> _getIndoorRoadStyleForType(String type) {
    final colors = {
      'corridor': '#9C27B0',
      'hallway': '#673AB7',
      'stairwell': '#FF9800',
    };
    
    return {
      'stroke': {'color': colors[type] ?? '#9C27B0', 'width': 3},
    };
  }

  static Map<String, dynamic> _getLandmarkStyleForType(String type) {
    final colors = {
      'entrance': '#4CAF50',
      'elevator': '#2196F3', 
      'stairs': '#FF9800',
      'restroom': '#00BCD4',
      'information': '#9C27B0',
      'emergency_exit': '#F44336',
      'parking': '#795548',
    };
    
    return {
      'image': {
        'type': 'circle',
        'radius': 6,
        'fill': {'color': colors[type] ?? '#FF5722'},
        'stroke': {'color': '#FFFFFF', 'width': 2},
      }
    };
  }

  static Map<String, dynamic> _getEntranceStyleForType(Landmark entrance) {
    final isAccessible = entrance.isAccessible;
    return {
      'image': {
        'type': 'circle',
        'radius': isAccessible ? 9 : 7,
        'fill': {'color': isAccessible ? '#4CAF50' : '#FFC107'},
        'stroke': {'color': '#FFFFFF', 'width': 2},
      }
    };
  }

  static Map<String, dynamic> _getAccessibilityStyleForType(String type) {
    final colors = {
      'elevator': '#2196F3',
      'ramp': '#4CAF50',
      'accessible_restroom': '#00BCD4',
      'accessible_parking': '#795548',
    };
    
    return {
      'image': {
        'type': 'circle',
        'radius': 7,
        'fill': {'color': colors[type] ?? '#2196F3'},
        'stroke': {'color': '#FFFFFF', 'width': 2},
      }
    };
  }

  // Helper methods
  
  static List<List<double>> _generateDefaultBuildingBoundary(LatLng center) {
    const double size = 0.0001;
    return [
      [center.longitude - size, center.latitude - size],
      [center.longitude + size, center.latitude - size],
      [center.longitude + size, center.latitude + size],
      [center.longitude - size, center.latitude + size],
      [center.longitude - size, center.latitude - size],
    ];
  }

  static List<List<double>> _generateFloorBoundary(LatLng center, int level) {
    const double size = 0.00008;
    return [
      [center.longitude - size, center.latitude - size],
      [center.longitude + size, center.latitude - size],
      [center.longitude + size, center.latitude + size],
      [center.longitude - size, center.latitude + size],
      [center.longitude - size, center.latitude - size],
    ];
  }

  static double _calculateRoadLength(Road road) {
    if (road.points.length < 2) return 0.0;
    
    double length = 0.0;
    for (int i = 0; i < road.points.length - 1; i++) {
      length += _calculateDistance(road.points[i], road.points[i + 1]);
    }
    return length;
  }

  static double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000;
    final double lat1Rad = point1.latitude * math.pi / 180;
    final double lat2Rad = point2.latitude * math.pi / 180;
    final double deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180;
    final double deltaLngRad = (point2.longitude - point1.longitude) * math.pi / 180;

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  static String _getAccessibilityType(Landmark landmark) {
    if (landmark.type == 'elevator') return 'vertical_access';
    if (landmark.type == 'ramp') return 'ramp_access';
    if (landmark.type.contains('accessible')) return 'accessible_facility';
    if (landmark.isAccessible) return 'accessible_feature';
    return 'accessibility_related';
  }

  /// Export OpenLayers configuration file
  static Future<File> exportOpenLayersConfig(RoadSystem roadSystem) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = '${roadSystem.name}_openlayers_config_$timestamp.json';
      final file = File('${directory.path}/$fileName');
      
      final bounds = _calculateBounds(roadSystem);
      
      final config = {
        'name': roadSystem.name,
        'description': 'OpenLayers configuration for ${roadSystem.name}',
        'bounds': bounds,
        'defaultZoom': 18,
        'minZoom': 15,
        'maxZoom': 22,
        'center': [
          (bounds['southwest'][0] + bounds['northeast'][0]) / 2,
          (bounds['southwest'][1] + bounds['northeast'][1]) / 2,
        ],
        'layers': [
          {
            'name': 'buildings',
            'type': 'vector',
            'source': '${roadSystem.name}_${timestamp}_buildings.geojson',
            'style': 'buildingStyle',
            'visible': true,
            'opacity': 0.7,
          },
          {
            'name': 'outdoor_roads',
            'type': 'vector', 
            'source': '${roadSystem.name}_${timestamp}_outdoor_roads.geojson',
            'style': 'roadStyle',
            'visible': true,
            'opacity': 1.0,
          },
          {
            'name': 'indoor_roads',
            'type': 'vector',
            'source': '${roadSystem.name}_${timestamp}_indoor_roads.geojson', 
            'style': 'indoorRoadStyle',
            'visible': false,
            'opacity': 0.8,
          },
          {
            'name': 'landmarks',
            'type': 'vector',
            'source': '${roadSystem.name}_${timestamp}_landmarks.geojson',
            'style': 'landmarkStyle', 
            'visible': true,
            'opacity': 1.0,
          },
          {
            'name': 'entrances',
            'type': 'vector',
            'source': '${roadSystem.name}_${timestamp}_entrances.geojson',
            'style': 'entranceStyle',
            'visible': true,
            'opacity': 1.0,
          },
          {
            'name': 'accessibility',
            'type': 'vector', 
            'source': '${roadSystem.name}_${timestamp}_accessibility.geojson',
            'style': 'accessibilityStyle',
            'visible': false,
            'opacity': 1.0,
          },
        ],
        'controls': {
          'zoom': true,
          'attribution': true,
          'layerSwitcher': true,
          'fullScreen': true,
          'mousePosition': true,
        },
        'interactions': {
          'select': true,
          'hover': true,
          'popup': true,
        }
      };
      
      await file.writeAsString(json.encode(config));
      debugPrint('OpenLayers config exported to: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('Error exporting OpenLayers config: $e');
      rethrow;
    }
  }
}