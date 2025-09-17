import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/services.dart';

class RoadSystemProvider extends ChangeNotifier {
  List<RoadSystem> _roadSystems = [];
  RoadSystem? _currentSystem;
  bool _isLoading = false;
  String? _error;

  List<RoadSystem> get roadSystems => _roadSystems;
  RoadSystem? get currentSystem => _currentSystem;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadRoadSystems() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _roadSystems = await DataStorageService.loadRoadSystems();
      
      final currentSystemId = await DataStorageService.getCurrentRoadSystemId();
      if (currentSystemId != null) {
        _currentSystem = _roadSystems.firstWhere(
          (system) => system.id == currentSystemId,
          orElse: () => _roadSystems.isNotEmpty ? _roadSystems.first : null,
        );
      } else if (_roadSystems.isNotEmpty) {
        _currentSystem = _roadSystems.first;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> createNewRoadSystem(String name, LatLng centerPosition) async {
    try {
      final newSystem = RoadSystem(
        id: const Uuid().v4(),
        name: name,
        centerPosition: centerPosition,
      );

      _roadSystems.add(newSystem);
      _currentSystem = newSystem;
      
      await _saveRoadSystems();
      await DataStorageService.setCurrentRoadSystem(newSystem.id);
      
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateCurrentSystem(RoadSystem updatedSystem) async {
    if (_currentSystem == null) return;

    try {
      final index = _roadSystems.indexWhere((system) => system.id == updatedSystem.id);
      if (index != -1) {
        _roadSystems[index] = updatedSystem;
        _currentSystem = updatedSystem;
        await _saveRoadSystems();
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> setCurrentSystem(String systemId) async {
    try {
      final system = _roadSystems.firstWhere((s) => s.id == systemId);
      _currentSystem = system;
      await DataStorageService.setCurrentRoadSystem(systemId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteRoadSystem(String systemId) async {
    try {
      _roadSystems.removeWhere((system) => system.id == systemId);
      
      if (_currentSystem?.id == systemId) {
        _currentSystem = _roadSystems.isNotEmpty ? _roadSystems.first : null;
        if (_currentSystem != null) {
          await DataStorageService.setCurrentRoadSystem(_currentSystem!.id);
        }
      }
      
      await _saveRoadSystems();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<String?> exportCurrentSystem() async {
    if (_currentSystem == null) return null;
    
    try {
      return await DataStorageService.exportRoadSystemToJson(_currentSystem!);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> importRoadSystem() async {
    try {
      final importedSystem = await DataStorageService.importRoadSystemFromJson();
      if (importedSystem != null) {
        _roadSystems.add(importedSystem);
        _currentSystem = importedSystem;
        await _saveRoadSystems();
        await DataStorageService.setCurrentRoadSystem(importedSystem.id);
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ROAD MANAGEMENT METHODS
  void addRoadToCurrentSystem(Road road) {
    if (_currentSystem == null) return;

    final updatedRoads = List<Road>.from(_currentSystem!.outdoorRoads)..add(road);
    final updatedSystem = _currentSystem!.copyWith(outdoorRoads: updatedRoads);
    updateCurrentSystem(updatedSystem);
  }

  void updateRoadInCurrentSystem(Road updatedRoad) {
    if (_currentSystem == null) return;

    final roads = List<Road>.from(_currentSystem!.outdoorRoads);
    final index = roads.indexWhere((road) => road.id == updatedRoad.id);
    if (index != -1) {
      roads[index] = updatedRoad;
      final updatedSystem = _currentSystem!.copyWith(outdoorRoads: roads);
      updateCurrentSystem(updatedSystem);
    }
  }

  void removeRoadFromCurrentSystem(String roadId) {
    if (_currentSystem == null) return;

    final updatedRoads = _currentSystem!.outdoorRoads
        .where((road) => road.id != roadId)
        .toList();
    final updatedSystem = _currentSystem!.copyWith(outdoorRoads: updatedRoads);
    updateCurrentSystem(updatedSystem);
  }

  // NEW: INTERSECTION MANAGEMENT METHODS
  void addIntersectionToCurrentSystem(Intersection intersection) {
    if (_currentSystem == null) return;

    final updatedIntersections = List<Intersection>.from(_currentSystem!.outdoorIntersections)
      ..add(intersection);
    final updatedSystem = _currentSystem!.copyWith(outdoorIntersections: updatedIntersections);
    updateCurrentSystem(updatedSystem);
  }

  void updateIntersectionInCurrentSystem(Intersection updatedIntersection) {
    if (_currentSystem == null) return;

    final intersections = List<Intersection>.from(_currentSystem!.outdoorIntersections);
    final index = intersections.indexWhere((intersection) => intersection.id == updatedIntersection.id);
    if (index != -1) {
      intersections[index] = updatedIntersection;
      final updatedSystem = _currentSystem!.copyWith(outdoorIntersections: intersections);
      updateCurrentSystem(updatedSystem);
    }
  }

  void removeIntersectionFromCurrentSystem(String intersectionId) {
    if (_currentSystem == null) return;

    final updatedIntersections = _currentSystem!.outdoorIntersections
        .where((intersection) => intersection.id != intersectionId)
        .toList();
    final updatedSystem = _currentSystem!.copyWith(outdoorIntersections: updatedIntersections);
    updateCurrentSystem(updatedSystem);
  }

  // NEW: ROAD CONNECTION METHODS
  List<Road> getConnectableRoads(LatLng point, {double maxDistance = 10.0}) {
    if (_currentSystem == null) return [];

    final connectableRoads = <Road>[];
    
    for (final road in _currentSystem!.outdoorRoads) {
      if (_isPointNearRoad(point, road, maxDistance)) {
        connectableRoads.add(road);
      }
    }
    
    return connectableRoads;
  }

  bool _isPointNearRoad(LatLng point, Road road, double maxDistance) {
    for (int i = 0; i < road.points.length - 1; i++) {
      final distance = _distanceToLineSegment(point, road.points[i], road.points[i + 1]);
      if (distance <= maxDistance) {
        return true;
      }
    }
    return false;
  }

  double _distanceToLineSegment(LatLng point, LatLng lineStart, LatLng lineEnd) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    // Convert to radians
    final lat1 = point.latitude * (3.14159 / 180);
    final lng1 = point.longitude * (3.14159 / 180);
    final lat2 = lineStart.latitude * (3.14159 / 180);
    final lng2 = lineStart.longitude * (3.14159 / 180);
    final lat3 = lineEnd.latitude * (3.14159 / 180);
    final lng3 = lineEnd.longitude * (3.14159 / 180);
    
    // Simplified distance calculation for small distances
    final dx1 = (lng2 - lng1) * earthRadius * cos(lat1);
    final dy1 = (lat2 - lat1) * earthRadius;
    final dx2 = (lng3 - lng1) * earthRadius * cos(lat1);
    final dy2 = (lat3 - lat1) * earthRadius;
    final dx3 = (lng3 - lng2) * earthRadius * cos(lat2);
    final dy3 = (lat3 - lat2) * earthRadius;
    
    final lineLengthSquared = dx3 * dx3 + dy3 * dy3;
    
    if (lineLengthSquared == 0) {
      return sqrt(dx1 * dx1 + dy1 * dy1);
    }
    
    final t = ((dx1 - dx2) * dx3 + (dy1 - dy2) * dy3) / lineLengthSquared;
    final clampedT = t.clamp(0.0, 1.0);
    
    final projX = dx2 + clampedT * dx3;
    final projY = dy2 + clampedT * dy3;
    
    final distX = dx1 - projX;
    final distY = dy1 - projY;
    
    return sqrt(distX * distX + distY * distY);
  }

  Future<void> connectRoads(List<String> roadIds, LatLng connectionPoint) async {
    if (_currentSystem == null || roadIds.length < 2) return;

    try {
      // Create intersection at connection point
      final intersection = Intersection(
        id: const Uuid().v4(),
        name: 'Auto Intersection ${roadIds.length} roads',
        position: connectionPoint,
        floorId: '', // Outdoor intersection
        connectedRoadIds: roadIds,
        type: 'simple',
        properties: {
          'auto_generated': true,
          'created': DateTime.now().toIso8601String(),
          'connected_roads': roadIds,
        },
      );

      // Add intersection to system
      addIntersectionToCurrentSystem(intersection);

      // Update roads to reference this intersection
      final updatedRoads = _currentSystem!.outdoorRoads.map((road) {
        if (roadIds.contains(road.id)) {
          final updatedConnections = List<String>.from(road.connectedIntersections);
          if (!updatedConnections.contains(intersection.id)) {
            updatedConnections.add(intersection.id);
          }
          return road.copyWith(connectedIntersections: updatedConnections);
        }
        return road;
      }).toList();

      final updatedSystem = _currentSystem!.copyWith(outdoorRoads: updatedRoads);
      await updateCurrentSystem(updatedSystem);

    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // NEW: SMART ROAD CONNECTION ANALYSIS
  Map<String, dynamic> analyzeRoadNetwork() {
    if (_currentSystem == null) return {};

    final analysis = <String, dynamic>{};
    
    // Count total elements
    analysis['total_roads'] = _currentSystem!.outdoorRoads.length;
    analysis['total_intersections'] = _currentSystem!.outdoorIntersections.length;
    analysis['total_buildings'] = _currentSystem!.buildings.length;
    
    // Analyze road connections
    int connectedRoads = 0;
    int isolatedRoads = 0;
    
    for (final road in _currentSystem!.outdoorRoads) {
      if (road.connectedIntersections.isNotEmpty) {
        connectedRoads++;
      } else {
        isolatedRoads++;
      }
    }
    
    analysis['connected_roads'] = connectedRoads;
    analysis['isolated_roads'] = isolatedRoads;
    analysis['connectivity_percentage'] = 
        _currentSystem!.outdoorRoads.isNotEmpty 
            ? (connectedRoads / _currentSystem!.outdoorRoads.length * 100).round()
            : 0;
    
    // Find potential connection points
    final potentialConnections = <Map<String, dynamic>>[];
    
    for (int i = 0; i < _currentSystem!.outdoorRoads.length; i++) {
      for (int j = i + 1; j < _currentSystem!.outdoorRoads.length; j++) {
        final road1 = _currentSystem!.outdoorRoads[i];
        final road2 = _currentSystem!.outdoorRoads[j];
        
        final connectionPoint = _findNearestConnectionPoint(road1, road2);
        if (connectionPoint != null) {
          potentialConnections.add({
            'road1_id': road1.id,
            'road1_name': road1.name,
            'road2_id': road2.id,
            'road2_name': road2.name,
            'connection_point': connectionPoint,
            'distance': _calculateMinimumDistance(road1, road2),
          });
        }
      }
    }
    
    analysis['potential_connections'] = potentialConnections;
    
    return analysis;
  }

  LatLng? _findNearestConnectionPoint(Road road1, Road road2) {
    double minDistance = double.infinity;
    LatLng? nearestPoint;
    
    // Check all combinations of points between the two roads
    for (final point1 in road1.points) {
      for (final point2 in road2.points) {
        final distance = _calculateDistance(point1, point2);
        if (distance < minDistance && distance < 20.0) { // Within 20 meters
          minDistance = distance;
          nearestPoint = LatLng(
            (point1.latitude + point2.latitude) / 2,
            (point1.longitude + point2.longitude) / 2,
          );
        }
      }
    }
    
    return nearestPoint;
  }

  double _calculateMinimumDistance(Road road1, Road road2) {
    double minDistance = double.infinity;
    
    for (final point1 in road1.points) {
      for (final point2 in road2.points) {
        final distance = _calculateDistance(point1, point2);
        if (distance < minDistance) {
          minDistance = distance;
        }
      }
    }
    
    return minDistance;
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000;
    final lat1Rad = point1.latitude * (3.14159 / 180);
    final lat2Rad = point2.latitude * (3.14159 / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (3.14159 / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (3.14159 / 180);

    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // NEW: AUTOMATIC INTERSECTION DETECTION
  Future<List<Intersection>> detectPotentialIntersections() async {
    if (_currentSystem == null) return [];

    final potentialIntersections = <Intersection>[];
    final roads = _currentSystem!.outdoorRoads;

    for (int i = 0; i < roads.length; i++) {
      for (int j = i + 1; j < roads.length; j++) {
        final intersectionPoint = _findRoadIntersection(roads[i], roads[j]);
        
        if (intersectionPoint != null) {
          final intersection = Intersection(
            id: const Uuid().v4(),
            name: 'Detected Intersection',
            position: intersectionPoint,
            floorId: '',
            connectedRoadIds: [roads[i].id, roads[j].id],
            type: 'simple',
            properties: {
              'auto_detected': true,
              'road1_name': roads[i].name,
              'road2_name': roads[j].name,
            },
          );
          
          potentialIntersections.add(intersection);
        }
      }
    }

    return potentialIntersections;
  }

  LatLng? _findRoadIntersection(Road road1, Road road2) {
    const double tolerance = 5.0; // 5 meters tolerance
    
    for (int i = 0; i < road1.points.length - 1; i++) {
      for (int j = 0; j < road2.points.length - 1; j++) {
        final intersection = _lineSegmentIntersection(
          road1.points[i], road1.points[i + 1],
          road2.points[j], road2.points[j + 1],
          tolerance,
        );
        
        if (intersection != null) {
          return intersection;
        }
      }
    }
    
    return null;
  }

  LatLng? _lineSegmentIntersection(LatLng p1, LatLng p2, LatLng p3, LatLng p4, double tolerance) {
    // Simplified intersection detection for GPS coordinates
    // This is a basic implementation - more sophisticated algorithms exist
    
    final denom = (p1.latitude - p2.latitude) * (p3.longitude - p4.longitude) - 
                  (p1.longitude - p2.longitude) * (p3.latitude - p4.latitude);
    
    if (denom.abs() < 0.000001) return null; // Lines are parallel
    
    final t = ((p1.latitude - p3.latitude) * (p3.longitude - p4.longitude) - 
               (p1.longitude - p3.longitude) * (p3.latitude - p4.latitude)) / denom;
    
    final u = -((p1.latitude - p2.latitude) * (p1.latitude - p3.latitude) - 
                (p1.longitude - p2.longitude) * (p1.longitude - p3.longitude)) / denom;
    
    if (t >= 0 && t <= 1 && u >= 0 && u <= 1) {
      final intersectionLat = p1.latitude + t * (p2.latitude - p1.latitude);
      final intersectionLng = p1.longitude + t * (p2.longitude - p1.longitude);
      
      return LatLng(intersectionLat, intersectionLng);
    }
    
    return null;
  }

  Future<void> _saveRoadSystems() async {
    await DataStorageService.saveRoadSystems(_roadSystems);
  }
}