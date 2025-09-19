import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

class DataStorageService {
  static const String _roadSystemsKey = 'road_systems';
  static const String _currentSystemKey = 'current_system_id';
  static const String _settingsKey = 'app_settings';

  // Save road system to SharedPreferences
  Future<void> saveRoadSystem(RoadSystem roadSystem) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final systemJson = json.encode(roadSystem.toJson());
      await prefs.setString('road_system_${roadSystem.id}', systemJson);
      
      // Update the list of system IDs
      final systemIds = prefs.getStringList('road_system_ids') ?? [];
      if (!systemIds.contains(roadSystem.id)) {
        systemIds.add(roadSystem.id);
        await prefs.setStringList('road_system_ids', systemIds);
      }
      
      debugPrint('Road system ${roadSystem.name} saved successfully');
    } catch (e) {
      debugPrint('Error saving road system: $e');
      rethrow;
    }
  }

  // Load all road systems from SharedPreferences
  Future<List<RoadSystem>> loadRoadSystems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final systemIds = prefs.getStringList('road_system_ids') ?? [];
      final roadSystems = <RoadSystem>[];
      
      for (final id in systemIds) {
        try {
          final systemData = prefs.getString('road_system_$id');
          if (systemData != null) {
            final systemJson = json.decode(systemData);
            final roadSystem = RoadSystem.fromJson(systemJson);
            roadSystems.add(roadSystem);
          }
        } catch (e) {
          debugPrint('Error loading road system $id: $e');
          // Remove corrupted system ID
          systemIds.remove(id);
          await prefs.remove('road_system_$id');
        }
      }
      
      // Update cleaned system IDs
      await prefs.setStringList('road_system_ids', systemIds);
      
      debugPrint('Loaded ${roadSystems.length} road systems');
      return roadSystems;
    } catch (e) {
      debugPrint('Error loading road systems: $e');
      return [];
    }
  }

  // Load specific road system by ID
  Future<RoadSystem?> loadRoadSystemById(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final systemData = prefs.getString('road_system_$id');
      
      if (systemData != null) {
        final systemJson = json.decode(systemData);
        return RoadSystem.fromJson(systemJson);
      }
      
      return null;
    } catch (e) {
      debugPrint('Error loading road system $id: $e');
      return null;
    }
  }

  // Delete road system
  Future<void> deleteRoadSystem(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('road_system_$id');
      
      // Remove from system IDs list
      final systemIds = prefs.getStringList('road_system_ids') ?? [];
      systemIds.remove(id);
      await prefs.setStringList('road_system_ids', systemIds);
      
      // Clear current system if it was deleted
      final currentSystemId = prefs.getString(_currentSystemKey);
      if (currentSystemId == id) {
        await prefs.remove(_currentSystemKey);
      }
      
      debugPrint('Road system $id deleted successfully');
    } catch (e) {
      debugPrint('Error deleting road system: $e');
      rethrow;
    }
  }

  // Save current system ID
  Future<void> saveCurrentSystemId(String? systemId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (systemId != null) {
        await prefs.setString(_currentSystemKey, systemId);
      } else {
        await prefs.remove(_currentSystemKey);
      }
    } catch (e) {
      debugPrint('Error saving current system ID: $e');
      rethrow;
    }
  }

  // Load current system ID
  Future<String?> loadCurrentSystemId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currentSystemKey);
    } catch (e) {
      debugPrint('Error loading current system ID: $e');
      return null;
    }
  }

  // Export road system to JSON file
  Future<File> exportRoadSystemToJson(RoadSystem roadSystem) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${roadSystem.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');
      
      final jsonString = json.encode(roadSystem.toJson());
      await file.writeAsString(jsonString);
      
      debugPrint('Road system exported to: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('Error exporting road system: $e');
      rethrow;
    }
  }

  // Import road system from JSON file
  Future<RoadSystem> importRoadSystemFromJson(File file) async {
    try {
      final jsonString = await file.readAsString();
      final systemData = json.decode(jsonString);
      final roadSystem = RoadSystem.fromJson(systemData);
      
      debugPrint('Road system imported from: ${file.path}');
      return roadSystem;
    } catch (e) {
      debugPrint('Error importing road system: $e');
      rethrow;
    }
  }

  // Export road system to GeoJSON format
  Future<File> exportRoadSystemToGeoJson(RoadSystem roadSystem) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${roadSystem.name.replaceAll(' ', '_')}_geojson_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');
      
      final geoJson = convertToGeoJson(roadSystem);
      final jsonString = json.encode(geoJson);
      await file.writeAsString(jsonString);
      
      debugPrint('Road system exported to GeoJSON: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('Error exporting to GeoJSON: $e');
      rethrow;
    }
  }

  // Convert road system to GeoJSON format
  Map<String, dynamic> convertToGeoJson(RoadSystem roadSystem) {
    final features = <Map<String, dynamic>>[];
    
    // Add outdoor roads
    for (final road in roadSystem.outdoorRoads) {
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': road.points.map((point) => [point.longitude, point.latitude]).toList(),
        },
        'properties': {
          'type': 'road',
          'name': road.name,
          'id': road.id,
          'roadType': road.type,
          'width': road.width,
          'isOneWay': road.isOneWay,
          'context': 'outdoor',
          ...road.properties,
        }
      });
    }
    
    // Add outdoor landmarks
    for (final landmark in roadSystem.outdoorLandmarks) {
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [landmark.position.longitude, landmark.position.latitude],
        },
        'properties': {
          'type': 'landmark',
          'name': landmark.name,
          'landmarkType': landmark.type,
          'description': landmark.description,
          'id': landmark.id,
          'context': 'outdoor',
          ...landmark.properties,
        }
      });
    }
    
    // Add outdoor intersections
    for (final intersection in roadSystem.outdoorIntersections) {
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [intersection.position.longitude, intersection.position.latitude],
        },
        'properties': {
          'type': 'intersection',
          'name': intersection.name,
          'id': intersection.id,
          'connectedRoads': intersection.connectedRoadIds,
          'context': 'outdoor',
          ...intersection.properties,
        }
      });
    }
    
    // Add buildings and their contents
    for (final building in roadSystem.buildings) {
      // Building polygon
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Polygon',
          'coordinates': [building.boundaryPoints.map((point) => [point.longitude, point.latitude]).toList()],
        },
        'properties': {
          'type': 'building',
          'name': building.name,
          'id': building.id,
          'centerPosition': [building.centerPosition.longitude, building.centerPosition.latitude],
          'floorCount': building.floors.length,
          'defaultFloorLevel': building.defaultFloorLevel,
          'context': 'building',
          ...building.properties,
        }
      });
      
      // Floor contents
      for (final floor in building.floors) {
        // Indoor roads
        for (final road in floor.roads) {
          features.add({
            'type': 'Feature',
            'geometry': {
              'type': 'LineString',
              'coordinates': road.points.map((point) => [point.longitude, point.latitude]).toList(),
            },
            'properties': {
              'type': 'indoor_road',
              'name': road.name,
              'id': road.id,
              'roadType': road.type,
              'width': road.width,
              'isOneWay': road.isOneWay,
              'floorId': road.floorId,
              'floorLevel': floor.level,
              'floorName': floor.name,
              'buildingId': building.id,
              'buildingName': building.name,
              'context': 'indoor',
              ...road.properties,
            }
          });
        }
        
        // Indoor landmarks
        for (final landmark in floor.landmarks) {
          features.add({
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [landmark.position.longitude, landmark.position.latitude],
            },
            'properties': {
              'type': 'indoor_landmark',
              'name': landmark.name,
              'landmarkType': landmark.type,
              'description': landmark.description,
              'id': landmark.id,
              'floorId': landmark.floorId,
              'floorLevel': floor.level,
              'floorName': floor.name,
              'buildingId': landmark.buildingId,
              'buildingName': building.name,
              'isVerticalCirculation': landmark.isVerticalCirculation,
              'connectedFloors': landmark.connectedFloors,
              'context': 'indoor',
              ...landmark.properties,
            }
          });
        }
      }
    }
    
    return {
      'type': 'FeatureCollection',
      'name': roadSystem.name,
      'crs': {
        'type': 'name',
        'properties': {
          'name': 'urn:ogc:def:crs:OGC:1.3:CRS84'
        }
      },
      'features': features,
      'metadata': {
        'systemId': roadSystem.id,
        'systemName': roadSystem.name,
        'centerPosition': [roadSystem.centerPosition.longitude, roadSystem.centerPosition.latitude],
        'zoom': roadSystem.zoom,
        'exportedAt': DateTime.now().toIso8601String(),
        'totalBuildings': roadSystem.buildings.length,
        // FIX: Added explicit type annotation and null safety
        'totalFloors': roadSystem.buildings.fold<int>(0, (sum, b) => sum + (b.floors.length)),
        'totalRoads': roadSystem.outdoorRoads.length + 
                     roadSystem.buildings.fold<int>(0, (sum, b) => 
                       sum + b.floors.fold<int>(0, (floorSum, f) => floorSum + (f.roads.length))),
        'totalLandmarks': roadSystem.outdoorLandmarks.length + 
                          roadSystem.buildings.fold<int>(0, (sum, b) => 
                            sum + b.floors.fold<int>(0, (floorSum, f) => floorSum + (f.landmarks.length))),
      }
    };
  }

  // Save app settings
  Future<void> saveAppSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = json.encode(settings);
      await prefs.setString(_settingsKey, settingsJson);
    } catch (e) {
      debugPrint('Error saving app settings: $e');
      rethrow;
    }
  }

  // Load app settings
  Future<Map<String, dynamic>> loadAppSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);
      
      if (settingsJson != null) {
        return json.decode(settingsJson);
      }
      
      // Return default settings
      return {
        'theme': 'system',
        'mapProvider': 'openstreetmap',
        'showLocationHistory': true,
        'autoSave': true,
        'defaultZoom': 18.0,
        'trackingAccuracy': 'high',
      };
    } catch (e) {
      debugPrint('Error loading app settings: $e');
      return {};
    }
  }

  // Clear all stored data
  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get all road system keys
      final systemIds = prefs.getStringList('road_system_ids') ?? [];
      
      // Remove all road system data
      for (final id in systemIds) {
        await prefs.remove('road_system_$id');
      }
      
      // Remove system management keys
      await prefs.remove('road_system_ids');
      await prefs.remove(_currentSystemKey);
      
      debugPrint('All road system data cleared');
    } catch (e) {
      debugPrint('Error clearing data: $e');
      rethrow;
    }
  }

  // Get storage usage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final systemIds = prefs.getStringList('road_system_ids') ?? [];
      
      int totalSystems = systemIds.length;
      int totalSize = 0;
      int totalBuildings = 0;
      int totalFloors = 0;
      int totalRoads = 0;
      int totalLandmarks = 0;
      
      for (final id in systemIds) {
        final systemJson = prefs.getString('road_system_$id');
        if (systemJson != null) {
          totalSize += systemJson.length;
          
          try {
            final systemData = json.decode(systemJson);
            final roadSystem = RoadSystem.fromJson(systemData);
            
            totalBuildings += roadSystem.buildings.length;
            // FIX: Added explicit type annotation and null safety
            totalFloors += roadSystem.buildings.fold<int>(0, (sum, b) => sum + (b.floors.length));
            totalRoads += roadSystem.outdoorRoads.length + 
                         roadSystem.buildings.fold<int>(0, (sum, b) => 
                           sum + b.floors.fold<int>(0, (floorSum, f) => floorSum + (f.roads.length)));
            totalLandmarks += roadSystem.outdoorLandmarks.length + 
                             roadSystem.buildings.fold<int>(0, (sum, b) => 
                               sum + b.floors.fold<int>(0, (floorSum, f) => floorSum + (f.landmarks.length)));
          } catch (e) {
            debugPrint('Error parsing system for stats: $e');
          }
        }
      }
      
      return {
        'totalSystems': totalSystems,
        'totalSizeBytes': totalSize,
        'totalSizeKB': (totalSize / 1024).round(),
        'totalBuildings': totalBuildings,
        'totalFloors': totalFloors,
        'totalRoads': totalRoads,
        'totalLandmarks': totalLandmarks,
        'averageSystemSize': totalSystems > 0 ? (totalSize / totalSystems).round() : 0,
      };
    } catch (e) {
      debugPrint('Error getting storage stats: $e');
      return {};
    }
  }

  // Backup data to file
  Future<File> backupAllData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'ucroadways_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');
      
      final roadSystems = await loadRoadSystems();
      final settings = await loadAppSettings();
      final currentSystemId = await loadCurrentSystemId();
      
      final backupData = {
        'version': '1.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'roadSystems': roadSystems.map((rs) => rs.toJson()).toList(),
        'currentSystemId': currentSystemId,
        'settings': settings,
      };
      
      final jsonString = json.encode(backupData);
      await file.writeAsString(jsonString);
      
      debugPrint('Data backed up to: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('Error backing up data: $e');
      rethrow;
    }
  }

  // Restore data from backup file
  Future<void> restoreFromBackup(File backupFile) async {
    try {
      final jsonString = await backupFile.readAsString();
      final backupData = json.decode(jsonString);
      
      // Clear existing data
      await clearAllData();
      
      // Restore road systems
      final roadSystemsData = backupData['roadSystems'] as List;
      for (final systemData in roadSystemsData) {
        final roadSystem = RoadSystem.fromJson(systemData);
        await saveRoadSystem(roadSystem);
      }
      
      // Restore current system ID
      final currentSystemId = backupData['currentSystemId'] as String?;
      if (currentSystemId != null) {
        await saveCurrentSystemId(currentSystemId);
      }
      
      // Restore settings
      final settings = backupData['settings'] as Map<String, dynamic>?;
      if (settings != null) {
        await saveAppSettings(settings);
      }
      
      debugPrint('Data restored from backup: ${backupFile.path}');
    } catch (e) {
      debugPrint('Error restoring from backup: $e');
      rethrow;
    }
  }

  // Validate data integrity
  Future<Map<String, dynamic>> validateDataIntegrity() async {
    try {
      final issues = <String>[];
      final warnings = <String>[];
      
      final systemIds = (await SharedPreferences.getInstance()).getStringList('road_system_ids') ?? [];
      
      for (final id in systemIds) {
        try {
          final roadSystem = await loadRoadSystemById(id);
          if (roadSystem == null) {
            issues.add('Road system $id could not be loaded');
            continue;
          }
          
          // Validate road system structure
          final systemIssues = _validateRoadSystemStructure(roadSystem);
          issues.addAll(systemIssues);
          
        } catch (e) {
          issues.add('Error validating road system $id: $e');
        }
      }
      
      return {
        'isValid': issues.isEmpty,
        'issues': issues,
        'warnings': warnings,
        'checkedSystems': systemIds.length,
      };
    } catch (e) {
      return {
        'isValid': false,
        'issues': ['Validation failed: $e'],
        'warnings': [],
        'checkedSystems': 0,
      };
    }
  }

  List<String> _validateRoadSystemStructure(RoadSystem roadSystem) {
    final issues = <String>[];
    final allIds = <String>{};
    
    // Check for duplicate IDs
    void checkId(String id, String type) {
      if (!allIds.add(id)) {
        issues.add('Duplicate ID found: $id ($type)');
      }
    }
    
    // Validate buildings
    for (final building in roadSystem.buildings) {
      checkId(building.id, 'building');
      
      // Validate floors
      for (final floor in building.floors) {
        checkId(floor.id, 'floor');
        
        if (floor.buildingId != building.id) {
          issues.add('Floor ${floor.id} has incorrect building ID');
        }
        
        // Validate roads
        for (final road in floor.roads) {
          checkId(road.id, 'road');
          
          if (road.floorId != floor.id) {
            issues.add('Road ${road.id} has incorrect floor ID');
          }
          
          if (road.points.length < 2) {
            issues.add('Road ${road.id} has insufficient points');
          }
        }
        
        // Validate landmarks
        for (final landmark in floor.landmarks) {
          checkId(landmark.id, 'landmark');
          
          if (landmark.floorId != floor.id) {
            issues.add('Landmark ${landmark.id} has incorrect floor ID');
          }
          
          if (landmark.buildingId != building.id) {
            issues.add('Landmark ${landmark.id} has incorrect building ID');
          }
        }
      }
    }
    
    // Validate outdoor elements
    for (final road in roadSystem.outdoorRoads) {
      checkId(road.id, 'outdoor road');
      if (road.points.length < 2) {
        issues.add('Outdoor road ${road.id} has insufficient points');
      }
    }
    
    for (final landmark in roadSystem.outdoorLandmarks) {
      checkId(landmark.id, 'outdoor landmark');
    }
    
    for (final intersection in roadSystem.outdoorIntersections) {
      checkId(intersection.id, 'intersection');
    }
    
    return issues;
  }
}