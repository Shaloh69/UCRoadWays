import 'dart:io';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../models/models.dart';

class PermissionService {
  static Future<void> requestPermissions() async {
    await Permission.location.request();
    await Permission.locationWhenInUse.request();
    await Permission.storage.request();
  }

  static Future<bool> hasLocationPermission() async {
    return await Permission.location.isGranted ||
           await Permission.locationWhenInUse.isGranted;
  }

  static Future<bool> hasStoragePermission() async {
    return await Permission.storage.isGranted;
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
    final prefs = await SharedPreferences.getInstance();
    final systemsJson = systems.map((system) => system.toJson()).toList();
    await prefs.setString(_roadSystemsKey, jsonEncode(systemsJson));
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentSystemKey, systemId);
  }

  static Future<String?> getCurrentRoadSystemId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentSystemKey);
  }

  static Future<String> exportRoadSystemToJson(RoadSystem system) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/${system.name}_roadways.json');
    
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
            ...landmark.properties,
          }
        }),
      ],
      'metadata': {
        'name': system.name,
        'center': [system.centerPosition.longitude, system.centerPosition.latitude],
        'zoom': system.zoom,
        'exported': DateTime.now().toIso8601String(),
        'exportedBy': 'UCRoadWays',
      }
    };

    await file.writeAsString(jsonEncode(geoJsonData));
    return file.path;
  }

  static Future<RoadSystem?> importRoadSystemFromJson() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final data = jsonDecode(content);

        // Basic validation
        if (data['type'] != 'FeatureCollection') {
          throw Exception('Invalid GeoJSON format');
        }

        // For now, return a basic road system
        // In a full implementation, you'd parse the GeoJSON features
        return RoadSystem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: data['metadata']?['name'] ?? 'Imported System',
          centerPosition: LatLng(
            data['metadata']?['center']?[1] ?? 0.0,
            data['metadata']?['center']?[0] ?? 0.0,
          ),
        );
      }
    } catch (e) {
      print('Error importing road system: $e');
    }
    return null;
  }
}