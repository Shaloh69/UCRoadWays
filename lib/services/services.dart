import 'dart:io';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';

class PermissionService {
  static Future<void> requestPermissions() async {
    await Permission.location.request();
    await Permission.locationWhenInUse.request();
    if (Platform.isAndroid) {
      await Permission.storage.request();
    }
  }

  static Future<bool> hasLocationPermission() async {
    return await Permission.location.isGranted ||
           await Permission.locationWhenInUse.isGranted;
  }

  static Future<bool> hasStoragePermission() async {
    if (Platform.isAndroid) {
      return await Permission.storage.isGranted;
    }
    return true; // iOS doesn't need explicit storage permission for app documents
  }
}

class LocationService {
  static Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  static Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1, // Update every meter
      ),
    );
  }

  static Future<double> distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) async {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }
}

class DataStorageService {
  static const String _roadSystemsKey = 'road_systems';
  static const String _currentSystemKey = 'current_system_id';

  /// Save road systems with enhanced error handling
  static Future<void> saveRoadSystems(List<RoadSystem> systems) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final systemsJson = systems.map((system) {
        try {
          return system.toJson();
        } catch (e) {
          print('Error serializing road system ${system.id}: $e');
          return null;
        }
      }).where((json) => json != null).toList();
      
      final jsonString = jsonEncode(systemsJson);
      await prefs.setString(_roadSystemsKey, jsonString);
      print('Successfully saved ${systemsJson.length} road systems');
    } catch (e) {
      print('Error saving road systems: $e');
      rethrow;
    }
  }

  /// Load road systems with enhanced error handling and data validation
  static Future<List<RoadSystem>> loadRoadSystems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final systemsJson = prefs.getString(_roadSystemsKey);
      
      if (systemsJson != null && systemsJson.isNotEmpty) {
        final List<dynamic> systemsList = jsonDecode(systemsJson);
        final List<RoadSystem> loadedSystems = [];
        
        for (int i = 0; i < systemsList.length; i++) {
          try {
            final systemData = systemsList[i];
            if (systemData != null && systemData is Map<String, dynamic>) {
              // Validate required fields before parsing
              if (_validateRoadSystemData(systemData)) {
                final system = RoadSystem.fromJson(systemData);
                loadedSystems.add(system);
              } else {
                print('Skipping invalid road system at index $i: missing required fields');
              }
            } else {
              print('Skipping malformed road system data at index $i');
            }
          } catch (e) {
            print('Error parsing road system at index $i: $e');
            // Continue loading other systems even if one fails
          }
        }
        
        print('Successfully loaded ${loadedSystems.length} road systems');
        return loadedSystems;
      }
    } catch (e) {
      print('Error loading road systems: $e');
    }
    return [];
  }

  /// Validate road system data before parsing
  static bool _validateRoadSystemData(Map<String, dynamic> data) {
    // Check required fields
    if (data['id'] == null || data['name'] == null || data['centerPosition'] == null) {
      return false;
    }
    
    // Validate centerPosition format
    final centerPos = data['centerPosition'];
    if (centerPos is Map<String, dynamic>) {
      if (centerPos['latitude'] == null || centerPos['longitude'] == null) {
        return false;
      }
    } else if (centerPos is List) {
      if (centerPos.length < 2) {
        return false;
      }
    } else {
      return false;
    }
    
    return true;
  }

  /// Validate and fix coordinate data
  static Map<String, dynamic> _sanitizeCoordinateData(Map<String, dynamic> data) {
    // Fix centerPosition if needed
    if (data['centerPosition'] != null) {
      data['centerPosition'] = _sanitizeLatLngData(data['centerPosition']);
    }
    
    // Fix boundaryPoints if present
    if (data['boundaryPoints'] is List) {
      final List<dynamic> points = data['boundaryPoints'];
      data['boundaryPoints'] = points.map((point) => _sanitizeLatLngData(point)).toList();
    }
    
    // Fix building coordinates
    if (data['buildings'] is List) {
      final List<dynamic> buildings = data['buildings'];
      data['buildings'] = buildings.map((building) {
        if (building is Map<String, dynamic>) {
          return _sanitizeCoordinateData(building);
        }
        return building;
      }).toList();
    }
    
    // Fix outdoor roads
    if (data['outdoorRoads'] is List) {
      final List<dynamic> roads = data['outdoorRoads'];
      data['outdoorRoads'] = roads.map((road) {
        if (road is Map<String, dynamic> && road['points'] is List) {
          final List<dynamic> points = road['points'];
          road['points'] = points.map((point) => _sanitizeLatLngData(point)).toList();
        }
        return road;
      }).toList();
    }
    
    return data;
  }

  /// Sanitize individual LatLng data
  static dynamic _sanitizeLatLngData(dynamic latlngData) {
    if (latlngData == null) return null;
    
    if (latlngData is Map<String, dynamic>) {
      // Standard format: {"latitude": 33.9737, "longitude": -117.3281}
      return latlngData;
    } else if (latlngData is List && latlngData.length >= 2) {
      // Convert array format to standard format
      return {
        'latitude': latlngData[1],
        'longitude': latlngData[0],
      };
    }
    
    return latlngData;
  }

  static Future<void> setCurrentRoadSystem(String systemId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentSystemKey, systemId);
    } catch (e) {
      print('Error setting current road system: $e');
      rethrow;
    }
  }

  static Future<String?> getCurrentRoadSystemId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currentSystemKey);
    } catch (e) {
      print('Error getting current road system ID: $e');
      return null;
    }
  }

  /// Export road system to JSON with error handling
  static Future<String?> exportRoadSystemToJson(RoadSystem system) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${system.name.replaceAll(' ', '_')}_roadways_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');
      
      final geoJsonData = _buildGeoJsonData(system);
      final jsonString = const JsonEncoder.withIndent('  ').convert(geoJsonData);
      
      await file.writeAsString(jsonString);
      return file.path;
    } catch (e) {
      print('Error exporting road system: $e');
      return null;
    }
  }

  /// Build GeoJSON data with safe coordinate handling
  static Map<String, dynamic> _buildGeoJsonData(RoadSystem system) {
    final features = <Map<String, dynamic>>[];
    
    try {
      // Buildings
      for (final building in system.buildings) {
        try {
          features.add({
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [
                building.centerPosition.longitude,
                building.centerPosition.latitude
              ],
            },
            'properties': {
              'type': 'building',
              'name': building.name,
              'id': building.id,
              'floors': building.floors.length,
              ...building.properties,
            }
          });
        } catch (e) {
          print('Error processing building ${building.id}: $e');
        }
      }
      
      // Outdoor roads
      for (final road in system.outdoorRoads) {
        try {
          if (road.points.isNotEmpty) {
            features.add({
              'type': 'Feature',
              'geometry': {
                'type': 'LineString',
                'coordinates': road.points.map((point) => 
                    [point.longitude, point.latitude]).toList(),
              },
              'properties': {
                'type': 'road',
                'name': road.name,
                'id': road.id,
                'roadType': road.type,
                'width': road.width,
                'isOneWay': road.isOneWay,
                'floorId': road.floorId,
                ...road.properties,
              }
            });
          }
        } catch (e) {
          print('Error processing outdoor road ${road.id}: $e');
        }
      }
      
      // Outdoor landmarks
      for (final landmark in system.outdoorLandmarks) {
        try {
          features.add({
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [
                landmark.position.longitude,
                landmark.position.latitude
              ],
            },
            'properties': {
              'type': 'landmark',
              'name': landmark.name,
              'landmarkType': landmark.type,
              'description': landmark.description,
              'id': landmark.id,
              'floorId': landmark.floorId,
              ...landmark.properties,
            }
          });
        } catch (e) {
          print('Error processing outdoor landmark ${landmark.id}: $e');
        }
      }
      
      // Indoor elements from all buildings and floors
      for (final building in system.buildings) {
        for (final floor in building.floors) {
          // Indoor roads
          for (final road in floor.roads) {
            try {
              if (road.points.isNotEmpty) {
                features.add({
                  'type': 'Feature',
                  'geometry': {
                    'type': 'LineString',
                    'coordinates': road.points.map((point) => 
                        [point.longitude, point.latitude]).toList(),
                  },
                  'properties': {
                    'type': 'indoor_road',
                    'name': road.name,
                    'id': road.id,
                    'roadType': road.type,
                    'width': road.width,
                    'isOneWay': road.isOneWay,
                    'floorId': road.floorId,
                    'buildingId': building.id,
                    'floorLevel': floor.level,
                    'floorName': floor.name,
                    ...road.properties,
                  }
                });
              }
            } catch (e) {
              print('Error processing indoor road ${road.id}: $e');
            }
          }
          
          // Indoor landmarks
          for (final landmark in floor.landmarks) {
            try {
              features.add({
                'type': 'Feature',
                'geometry': {
                  'type': 'Point',
                  'coordinates': [
                    landmark.position.longitude,
                    landmark.position.latitude
                  ],
                },
                'properties': {
                  'type': 'indoor_landmark',
                  'name': landmark.name,
                  'landmarkType': landmark.type,
                  'description': landmark.description,
                  'id': landmark.id,
                  'floorId': landmark.floorId,
                  'buildingId': building.id,
                  'floorLevel': floor.level,
                  'floorName': floor.name,
                  'isVerticalCirculation': landmark.isVerticalCirculation,
                  'connectedFloors': landmark.connectedFloors,
                  ...landmark.properties,
                }
              });
            } catch (e) {
              print('Error processing indoor landmark ${landmark.id}: $e');
            }
          }
        }
      }
    } catch (e) {
      print('Error building GeoJSON features: $e');
    }
    
    return {
      'type': 'FeatureCollection',
      'name': '${system.name} - UC RoadWays Export',
      'crs': {
        'type': 'name',
        'properties': {
          'name': 'urn:ogc:def:crs:OGC:1.3:CRS84'
        }
      },
      'features': features,
      'metadata': {
        'exported_at': DateTime.now().toIso8601String(),
        'system_id': system.id,
        'system_name': system.name,
        'center_latitude': system.centerPosition.latitude,
        'center_longitude': system.centerPosition.longitude,
        'building_count': system.buildings.length,
        'outdoor_road_count': system.outdoorRoads.length,
        'outdoor_landmark_count': system.outdoorLandmarks.length,
        'total_floors': system.allFloors.length,
        'app_version': '1.0.0',
      }
    };
  }

  /// Import road system from JSON with enhanced validation
  static Future<RoadSystem?> importRoadSystemFromJson() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        
        try {
          final Map<String, dynamic> jsonData = jsonDecode(jsonString);
          
          // Validate and sanitize the data
          if (_validateRoadSystemData(jsonData)) {
            final sanitizedData = _sanitizeCoordinateData(jsonData);
            return RoadSystem.fromJson(sanitizedData);
          } else {
            print('Invalid road system data format');
            return null;
          }
        } catch (e) {
          print('Error parsing JSON data: $e');
          return null;
        }
      }
    } catch (e) {
      print('Error importing road system: $e');
    }
    return null;
  }

  /// Clear all data with confirmation
  static Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_roadSystemsKey);
      await prefs.remove(_currentSystemKey);
      print('All road system data cleared');
    } catch (e) {
      print('Error clearing data: $e');
      rethrow;
    }
  }

  /// Get storage size information
  static Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final systemsJson = prefs.getString(_roadSystemsKey);
      
      final info = {
        'has_data': systemsJson != null,
        'data_size_bytes': systemsJson?.length ?? 0,
        'data_size_kb': ((systemsJson?.length ?? 0) / 1024).toStringAsFixed(2),
      };
      
      if (systemsJson != null) {
        try {
          final List<dynamic> systemsList = jsonDecode(systemsJson);
          info['system_count'] = systemsList.length;
        } catch (e) {
          info['system_count'] = 0;
          info['parse_error'] = e.toString();
        }
      }
      
      return info;
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}