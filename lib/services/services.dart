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
  static const String _currentSystemKey = 'current_system';

  static Future<void> saveRoadSystems(List<RoadSystem> systems) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final systemsJson = systems.map((system) => system.toJson()).toList();
      await prefs.setString(_roadSystemsKey, jsonEncode(systemsJson));
    } catch (e) {
      print('Error saving road systems: $e');
      rethrow;
    }
  }

  static Future<List<RoadSystem>> loadRoadSystems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final systemsJson = prefs.getString(_roadSystemsKey);
      if (systemsJson != null) {
        final List<dynamic> systemsList = jsonDecode(systemsJson);
        return systemsList
            .map((json) => RoadSystem.fromJson(json))
            .toList();
      }
    } catch (e) {
      print('Error loading road systems: $e');
    }
    return [];
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

  static Future<String?> exportRoadSystemToJson(RoadSystem system) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${system.name.replaceAll(' ', '_')}_roadways_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');
      
      final geoJsonData = {
        'type': 'FeatureCollection',
        'features': [
          // Buildings
          ...system.buildings.map((building) => {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [building.centerPosition.longitude, building.centerPosition.latitude],
            },
            'properties': {
              'type': 'building',
              'name': building.name,
              'id': building.id,
              'floors': building.floors.length,
              ...building.properties,
            }
          }),
          // Outdoor roads
          ...system.outdoorRoads.map((road) => {
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
              'floorId': road.floorId,
              ...road.properties,
            }
          }),
          // Outdoor landmarks
          ...system.outdoorLandmarks.map((landmark) => {
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
              'floorId': landmark.floorId,
              ...landmark.properties,
            }
          }),
          // Indoor elements from all buildings and floors
          ...system.buildings.expand((building) => 
            building.floors.expand((floor) => [
              // Indoor roads
              ...floor.roads.map((road) => {
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
                  'buildingId': building.id,
                  'buildingName': building.name,
                  'floorName': floor.name,
                  'floorLevel': floor.level,
                  ...road.properties,
                }
              }),
              // Indoor landmarks
              ...floor.landmarks.map((landmark) => {
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
                  'buildingId': building.id,
                  'buildingName': building.name,
                  'floorName': floor.name,
                  'floorLevel': floor.level,
                  ...landmark.properties,
                }
              }),
            ])
          ),
        ],
        'metadata': {
          'name': system.name,
          'id': system.id,
          'center': [system.centerPosition.longitude, system.centerPosition.latitude],
          'zoom': system.zoom,
          'exported': DateTime.now().toIso8601String(),
          'exportedBy': 'UCRoadWays',
          'version': '1.0.0',
          'buildingCount': system.buildings.length,
          'outdoorRoadCount': system.outdoorRoads.length,
          'outdoorLandmarkCount': system.outdoorLandmarks.length,
          ...system.properties,
        }
      };

      await file.writeAsString(jsonEncode(geoJsonData));
      return file.path;
    } catch (e) {
      print('Error exporting road system: $e');
      return null;
    }
  }

  static Future<RoadSystem?> importRoadSystemFromJson() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final data = jsonDecode(content);

        // Basic validation
        if (data['type'] != 'FeatureCollection') {
          throw Exception('Invalid GeoJSON format');
        }

        // Extract metadata
        final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
        final systemName = metadata['name'] as String? ?? 'Imported System';
        final systemId = metadata['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
        
        // Extract center coordinates
        final centerCoords = metadata['center'] as List<dynamic>?;
        final centerPosition = centerCoords != null && centerCoords.length >= 2
            ? LatLng(centerCoords[1].toDouble(), centerCoords[0].toDouble())
            : const LatLng(33.9737, -117.3281); // Default to UC Riverside
        
        final zoom = (metadata['zoom'] as num?)?.toDouble() ?? 16.0;

        // For now, create a basic road system with just the metadata
        // In a full implementation, you'd parse all the features
        final importedSystem = RoadSystem(
          id: systemId,
          name: systemName,
          centerPosition: centerPosition,
          zoom: zoom,
          properties: Map<String, dynamic>.from(metadata)..remove('center'),
        );

        return importedSystem;
      }
    } catch (e) {
      print('Error importing road system: $e');
      rethrow;
    }
    return null;
  }
}