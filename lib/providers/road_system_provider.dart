import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../models/models.dart';
import '../services/services.dart';

class RoadSystemProvider extends ChangeNotifier {
  List<RoadSystem> _roadSystems = [];
  RoadSystem? _currentSystem;
  bool _isLoading = false;
  String? _error;
  final DataStorageService _storageService = DataStorageService();

  // Getters
  List<RoadSystem> get roadSystems => _roadSystems;
  RoadSystem? get currentSystem => _currentSystem;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasCurrentSystem => _currentSystem != null;

  // Constructor
  RoadSystemProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    await loadRoadSystems();
  }

  // Load road systems from storage
  Future<void> loadRoadSystems() async {
    try {
      _setLoading(true);
      _clearError();
      
      final prefs = await SharedPreferences.getInstance();
      final systemIds = prefs.getStringList('road_system_ids') ?? [];
      final currentSystemId = prefs.getString('current_system_id');
      
      _roadSystems.clear();
      
      for (final id in systemIds) {
        try {
          final systemData = prefs.getString('road_system_$id');
          if (systemData != null) {
            final systemJson = json.decode(systemData);
            final system = RoadSystem.fromJson(systemJson);
            _roadSystems.add(system);
            
            // Set current system if it matches
            if (currentSystemId == id) {
              _currentSystem = system;
            }
          }
        } catch (e) {
          debugPrint('Error loading road system $id: $e');
          // Remove corrupted system ID
          systemIds.remove(id);
          prefs.remove('road_system_$id');
        }
      }
      
      // Update the clean system IDs list
      await prefs.setStringList('road_system_ids', systemIds);
      
      // If no current system but systems exist, set the first one
      if (_currentSystem == null && _roadSystems.isNotEmpty) {
        _currentSystem = _roadSystems.first;
        await prefs.setString('current_system_id', _currentSystem!.id);
      }
      
    } catch (e) {
      _setError('Failed to load road systems: $e');
      debugPrint('Error in loadRoadSystems: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Save road systems to storage
  Future<void> saveRoadSystems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final systemIds = _roadSystems.map((s) => s.id).toList();
      
      await prefs.setStringList('road_system_ids', systemIds);
      
      for (final system in _roadSystems) {
        final systemJson = json.encode(system.toJson());
        await prefs.setString('road_system_${system.id}', systemJson);
      }
      
      if (_currentSystem != null) {
        await prefs.setString('current_system_id', _currentSystem!.id);
      }
      
    } catch (e) {
      _setError('Failed to save road systems: $e');
      debugPrint('Error in saveRoadSystems: $e');
    }
  }

  // Create a new road system
  Future<RoadSystem> createRoadSystem(String name, LatLng centerPosition) async {
    try {
      final newSystem = RoadSystem(
        id: const Uuid().v4(),
        name: name,
        centerPosition: centerPosition,
        zoom: 18.0,
      );
      
      _roadSystems.add(newSystem);
      _currentSystem = newSystem;
      
      await saveRoadSystems();
      notifyListeners();
      
      return newSystem;
    } catch (e) {
      _setError('Failed to create road system: $e');
      rethrow;
    }
  }

  // Set current system
  Future<void> setCurrentSystem(String systemId) async {
    try {
      final system = _roadSystems.where((s) => s.id == systemId).firstOrNull;
      if (system != null) {
        _currentSystem = system;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_system_id', systemId);
        
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to set current system: $e');
    }
  }

  // Update current system
  Future<void> updateCurrentSystem(RoadSystem updatedSystem) async {
    try {
      final index = _roadSystems.indexWhere((s) => s.id == updatedSystem.id);
      if (index != -1) {
        _roadSystems[index] = updatedSystem;
        
        if (_currentSystem?.id == updatedSystem.id) {
          _currentSystem = updatedSystem;
        }
        
        await saveRoadSystems();
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to update system: $e');
    }
  }

  // Delete a road system
  Future<void> deleteRoadSystem(String systemId) async {
    try {
      _roadSystems.removeWhere((s) => s.id == systemId);
      
      // If deleted system was current, set new current system
      if (_currentSystem?.id == systemId) {
        _currentSystem = _roadSystems.isNotEmpty ? _roadSystems.first : null;
      }
      
      // Remove from storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('road_system_$systemId');
      
      await saveRoadSystems();
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete system: $e');
    }
  }

  // Duplicate a road system
  Future<RoadSystem> duplicateRoadSystem(String systemId, String newName) async {
    try {
      final originalSystem = _roadSystems.where((s) => s.id == systemId).firstOrNull;
      if (originalSystem == null) {
        throw Exception('Original system not found');
      }
      
      // Create a deep copy with new ID
      final duplicatedSystem = RoadSystem(
        id: const Uuid().v4(),
        name: newName,
        buildings: _duplicateBuildings(originalSystem.buildings),
        outdoorRoads: _duplicateRoads(originalSystem.outdoorRoads),
        outdoorLandmarks: _duplicateLandmarks(originalSystem.outdoorLandmarks),
        outdoorIntersections: _duplicateIntersections(originalSystem.outdoorIntersections),
        centerPosition: originalSystem.centerPosition,
        zoom: originalSystem.zoom,
        properties: Map<String, dynamic>.from(originalSystem.properties),
      );
      
      _roadSystems.add(duplicatedSystem);
      await saveRoadSystems();
      notifyListeners();
      
      return duplicatedSystem;
    } catch (e) {
      _setError('Failed to duplicate system: $e');
      rethrow;
    }
  }

  // Helper methods for duplication
  List<Building> _duplicateBuildings(List<Building> buildings) {
    return buildings.map((building) => Building(
      id: const Uuid().v4(),
      name: building.name,
      centerPosition: building.centerPosition,
      boundaryPoints: List<LatLng>.from(building.boundaryPoints),
      floors: _duplicateFloors(building.floors),
      entranceFloorIds: List<String>.from(building.entranceFloorIds),
      defaultFloorLevel: building.defaultFloorLevel,
      properties: Map<String, dynamic>.from(building.properties),
    )).toList();
  }

  List<Floor> _duplicateFloors(List<Floor> floors) {
    return floors.map((floor) => Floor(
      id: const Uuid().v4(),
      name: floor.name,
      level: floor.level,
      buildingId: floor.buildingId, // This will be updated when building is created
      roads: _duplicateRoads(floor.roads),
      landmarks: _duplicateLandmarks(floor.landmarks),
      connectedFloors: List<String>.from(floor.connectedFloors),
      centerPosition: floor.centerPosition,
      properties: Map<String, dynamic>.from(floor.properties),
    )).toList();
  }

  List<Road> _duplicateRoads(List<Road> roads) {
    return roads.map((road) => Road(
      id: const Uuid().v4(),
      name: road.name,
      points: List<LatLng>.from(road.points),
      type: road.type,
      width: road.width,
      isOneWay: road.isOneWay,
      floorId: road.floorId, // Will be updated when floor is created
      connectedIntersections: List<String>.from(road.connectedIntersections),
      properties: Map<String, dynamic>.from(road.properties),
    )).toList();
  }

  List<Landmark> _duplicateLandmarks(List<Landmark> landmarks) {
    return landmarks.map((landmark) => Landmark(
      id: const Uuid().v4(),
      name: landmark.name,
      type: landmark.type,
      position: landmark.position,
      floorId: landmark.floorId, // Will be updated when floor is created
      description: landmark.description,
      connectedFloors: List<String>.from(landmark.connectedFloors),
      buildingId: landmark.buildingId, // Will be updated when building is created
      properties: Map<String, dynamic>.from(landmark.properties),
    )).toList();
  }

  List<Intersection> _duplicateIntersections(List<Intersection> intersections) {
    return intersections.map((intersection) => Intersection(
      id: const Uuid().v4(),
      name: intersection.name,
      position: intersection.position,
      floorId: intersection.floorId,
      connectedRoadIds: List<String>.from(intersection.connectedRoadIds),
      type: intersection.type,
      properties: Map<String, dynamic>.from(intersection.properties),
    )).toList();
  }

  // Import road system from JSON
  Future<RoadSystem> importRoadSystem(Map<String, dynamic> systemData) async {
    try {
      final roadSystem = RoadSystem.fromJson(systemData);
      
      // Generate new ID to avoid conflicts
      final importedSystem = RoadSystem(
        id: const Uuid().v4(),
        name: '${roadSystem.name} (Imported)',
        buildings: roadSystem.buildings,
        outdoorRoads: roadSystem.outdoorRoads,
        outdoorLandmarks: roadSystem.outdoorLandmarks,
        outdoorIntersections: roadSystem.outdoorIntersections,
        centerPosition: roadSystem.centerPosition,
        zoom: roadSystem.zoom,
        properties: roadSystem.properties,
      );
      
      _roadSystems.add(importedSystem);
      await saveRoadSystems();
      notifyListeners();
      
      return importedSystem;
    } catch (e) {
      _setError('Failed to import system: $e');
      rethrow;
    }
  }

  // Export road system to JSON
  String exportToJson(String systemId) {
    try {
      final system = _roadSystems.where((s) => s.id == systemId).firstOrNull;
      if (system == null) {
        throw Exception('System not found');
      }
      
      return json.encode(system.toJson());
    } catch (e) {
      _setError('Failed to export system: $e');
      rethrow;
    }
  }

  // Get system statistics
  Map<String, dynamic> getSystemStatistics(String systemId) {
    final system = _roadSystems.where((s) => s.id == systemId).firstOrNull;
    if (system == null) return {};
    
    // FIX: Added explicit type annotation and proper null safety
    final totalFloors = system.buildings.fold<int>(0, (sum, building) => sum + building.floors.length);
    final totalIndoorRoads = system.buildings
        .expand((b) => b.floors)
        .fold<int>(0, (sum, floor) => sum + floor.roads.length);
    final totalIndoorLandmarks = system.buildings
        .expand((b) => b.floors)
        .fold<int>(0, (sum, floor) => sum + floor.landmarks.length);
    
    return {
      'buildings': system.buildings.length,
      'floors': totalFloors,
      'outdoorRoads': system.outdoorRoads.length,
      'indoorRoads': totalIndoorRoads,
      'totalRoads': system.outdoorRoads.length + totalIndoorRoads,
      'outdoorLandmarks': system.outdoorLandmarks.length,
      'indoorLandmarks': totalIndoorLandmarks,
      'totalLandmarks': system.outdoorLandmarks.length + totalIndoorLandmarks,
      'intersections': system.outdoorIntersections.length,
    };
  }

  // Search functionality
  List<Map<String, dynamic>> searchAll(String query) {
    if (_currentSystem == null || query.isEmpty) return [];
    
    final results = <Map<String, dynamic>>[];
    final lowerQuery = query.toLowerCase();
    
    // Search buildings
    for (final building in _currentSystem!.buildings) {
      if (building.name.toLowerCase().contains(lowerQuery)) {
        results.add({
          'type': 'building',
          'id': building.id,
          'name': building.name,
          'position': building.centerPosition,
          'buildingId': building.id,
        });
      }
      
      // Search floors
      for (final floor in building.floors) {
        if (floor.name.toLowerCase().contains(lowerQuery)) {
          results.add({
            'type': 'floor',
            'id': floor.id,
            'name': '${building.name} - ${floor.name}',
            'position': floor.centerPosition ?? building.centerPosition,
            'buildingId': building.id,
            'floorId': floor.id,
          });
        }
        
        // Search indoor roads
        for (final road in floor.roads) {
          if (road.name.toLowerCase().contains(lowerQuery)) {
            results.add({
              'type': 'indoor_road',
              'id': road.id,
              'name': '${building.name} - ${floor.name}: ${road.name}',
              'position': road.points.isNotEmpty ? road.points.first : building.centerPosition,
              'buildingId': building.id,
              'floorId': floor.id,
            });
          }
        }
        
        // Search indoor landmarks
        for (final landmark in floor.landmarks) {
          if (landmark.name.toLowerCase().contains(lowerQuery) ||
              landmark.description.toLowerCase().contains(lowerQuery)) {
            results.add({
              'type': 'indoor_landmark',
              'id': landmark.id,
              'name': '${building.name} - ${floor.name}: ${landmark.name}',
              'position': landmark.position,
              'buildingId': building.id,
              'floorId': floor.id,
            });
          }
        }
      }
    }
    
    // Search outdoor roads
    for (final road in _currentSystem!.outdoorRoads) {
      if (road.name.toLowerCase().contains(lowerQuery)) {
        results.add({
          'type': 'outdoor_road',
          'id': road.id,
          'name': road.name,
          'position': road.points.isNotEmpty ? road.points.first : _currentSystem!.centerPosition,
        });
      }
    }
    
    // Search outdoor landmarks
    for (final landmark in _currentSystem!.outdoorLandmarks) {
      if (landmark.name.toLowerCase().contains(lowerQuery) ||
          landmark.description.toLowerCase().contains(lowerQuery)) {
        results.add({
          'type': 'outdoor_landmark',
          'id': landmark.id,
          'name': landmark.name,
          'position': landmark.position,
        });
      }
    }
    
    return results;
  }

  // Validation methods
  bool validateSystem(RoadSystem system) {
    try {
      // Check for duplicate IDs
      final allIds = <String>{};
      
      // Building IDs
      for (final building in system.buildings) {
        if (!allIds.add(building.id)) return false;
        
        // Floor IDs
        for (final floor in building.floors) {
          if (!allIds.add(floor.id)) return false;
          
          // Road IDs
          for (final road in floor.roads) {
            if (!allIds.add(road.id)) return false;
          }
          
          // Landmark IDs
          for (final landmark in floor.landmarks) {
            if (!allIds.add(landmark.id)) return false;
          }
        }
      }
      
      // Outdoor road IDs
      for (final road in system.outdoorRoads) {
        if (!allIds.add(road.id)) return false;
      }
      
      // Outdoor landmark IDs
      for (final landmark in system.outdoorLandmarks) {
        if (!allIds.add(landmark.id)) return false;
      }
      
      // Intersection IDs
      for (final intersection in system.outdoorIntersections) {
        if (!allIds.add(intersection.id)) return false;
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // Clear all data
  Future<void> clearAllData() async {
    try {
      _roadSystems.clear();
      _currentSystem = null;
      
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => 
          key.startsWith('road_system_') || 
          key == 'road_system_ids' || 
          key == 'current_system_id').toList();
      
      for (final key in keys) {
        await prefs.remove(key);
      }
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to clear data: $e');
    }
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    if (loading) _clearError();
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  // Refresh current system
  void refresh() {
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}