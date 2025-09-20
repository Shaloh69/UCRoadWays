import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import '../models/models.dart';

class BuildingProvider extends ChangeNotifier {
  String? _selectedBuildingId;
  String? _selectedFloorId;
  bool _isIndoorMode = false;
  bool _showFloorPlan = false;
  
  // Cache for performance
  final Map<String, Map<String, dynamic>> _accessibilityCache = {};
  final Map<String, Map<String, dynamic>> _connectivityCache = {};

  // Getters
  String? get selectedBuildingId => _selectedBuildingId;
  String? get selectedFloorId => _selectedFloorId;
  bool get isIndoorMode => _isIndoorMode;
  bool get showFloorPlan => _showFloorPlan;

  // Building selection methods
  void selectBuilding(String? buildingId) {
    if (_selectedBuildingId != buildingId) {
      _selectedBuildingId = buildingId;
      _selectedFloorId = null; // Reset floor selection
      _isIndoorMode = buildingId != null;
      
      // Clear cache for the new building
      _accessibilityCache.clear();
      _connectivityCache.clear();
      
      notifyListeners();
    }
  }

  void selectFloor(String? floorId) {
    if (_selectedFloorId != floorId) {
      _selectedFloorId = floorId;
      notifyListeners();
    }
  }

  void toggleIndoorMode() {
    _isIndoorMode = !_isIndoorMode;
    if (!_isIndoorMode) {
      _selectedBuildingId = null;
      _selectedFloorId = null;
      _showFloorPlan = false;
    }
    notifyListeners();
  }

  void toggleFloorPlan() {
    _showFloorPlan = !_showFloorPlan;
    notifyListeners();
  }

  void exitIndoorMode() {
    _isIndoorMode = false;
    _selectedBuildingId = null;
    _selectedFloorId = null;
    _showFloorPlan = false;
    notifyListeners();
  }

  // Helper methods for getting selected objects
  Building? getSelectedBuilding(RoadSystem? roadSystem) {
    if (roadSystem == null || _selectedBuildingId == null) return null;
    
    try {
      return roadSystem.buildings.firstWhere(
        (building) => building.id == _selectedBuildingId,
      );
    } catch (e) {
      return null;
    }
  }

  Floor? getSelectedFloor(RoadSystem? roadSystem) {
    final building = getSelectedBuilding(roadSystem);
    if (building == null || _selectedFloorId == null) return null;
    
    try {
      return building.floors.firstWhere(
        (floor) => floor.id == _selectedFloorId,
      );
    } catch (e) {
      return null;
    }
  }

  // Auto-select appropriate floor when building is selected
  void autoSelectFloor(Building building) {
    if (building.floors.isEmpty) return;
    
    // Try to select ground floor (level 0) first
    Floor? groundFloor;
    try {
      groundFloor = building.floors.firstWhere((floor) => floor.level == 0);
    } catch (e) {
      // No ground floor, select the first floor
      groundFloor = building.floors.first;
    }
    
    selectFloor(groundFloor.id);
  }

  // Get floors by level for a building
  List<Floor> getFloorsByLevel(Building building) {
    final floors = List<Floor>.from(building.floors);
    floors.sort((a, b) => b.level.compareTo(a.level)); // Highest first
    return floors;
  }

  // Get floors accessible from current floor
  List<Floor> getAccessibleFloors(Floor currentFloor, Building building) {
    final accessibleFloors = <Floor>[];
    
    // Add directly connected floors
    for (final floorId in currentFloor.connectedFloors) {
      try {
        final floor = building.floors.firstWhere((f) => f.id == floorId);
        accessibleFloors.add(floor);
      } catch (e) {
        // Floor not found, skip
      }
    }
    
    // Add floors connected via vertical circulation
    final hasElevator = currentFloor.landmarks.any((l) => l.type == 'elevator');
    final hasStairs = currentFloor.landmarks.any((l) => l.type == 'stairs');
    
    if (hasElevator || hasStairs) {
      for (final floor in building.floors) {
        if (floor.id != currentFloor.id) {
          final targetHasConnection = floor.landmarks.any((l) => 
              (hasElevator && l.type == 'elevator') || 
              (hasStairs && l.type == 'stairs'));
          
          if (targetHasConnection && !accessibleFloors.contains(floor)) {
            accessibleFloors.add(floor);
          }
        }
      }
    }
    
    return accessibleFloors;
  }

  // FIXED: Building accessibility analysis
  Map<String, dynamic> getBuildingAccessibility(Building building) {
    final cacheKey = 'accessibility_${building.id}';
    if (_accessibilityCache.containsKey(cacheKey)) {
      return _accessibilityCache[cacheKey]!;
    }

    final accessibility = <String, dynamic>{};
    
    // Check for elevators
    final hasElevator = building.floors.any((floor) => 
        floor.landmarks.any((landmark) => landmark.type == 'elevator'));
    accessibility['hasElevator'] = hasElevator;
    
    // Check for accessible entrances
    final hasAccessibleEntrance = building.floors.any((floor) => 
        floor.landmarks.any((landmark) => 
            landmark.type == 'entrance' && 
            (landmark.properties['accessible'] == true || landmark.isAccessible)));
    accessibility['hasAccessibleEntrance'] = hasAccessibleEntrance;
    
    // Check for ramps
    final hasRamps = building.floors.any((floor) => 
        floor.landmarks.any((landmark) => landmark.type == 'ramp'));
    accessibility['hasRamps'] = hasRamps;
    
    // Check for accessible restrooms
    final hasAccessibleRestrooms = building.floors.any((floor) => 
        floor.landmarks.any((landmark) => 
            landmark.type == 'restroom' && 
            (landmark.properties['accessible'] == true || landmark.isAccessible)));
    accessibility['hasAccessibleRestrooms'] = hasAccessibleRestrooms;
    
    // Check for accessible parking
    final hasAccessibleParking = building.floors.any((floor) => 
        floor.landmarks.any((landmark) => 
            landmark.type == 'parking' && 
            (landmark.properties['accessible'] == true || landmark.isAccessible)));
    accessibility['hasAccessibleParking'] = hasAccessibleParking;
    
    // Calculate overall accessibility score
    double score = 0.0;
    int maxPoints = 5;
    
    if (hasElevator || building.floors.length == 1) score += 1.0;
    if (hasAccessibleEntrance) score += 1.0;
    if (hasRamps) score += 0.5;
    if (hasAccessibleRestrooms) score += 1.0;
    if (hasAccessibleParking) score += 0.5;
    
    // Check for stairs as alternative (partial credit)
    final hasStairs = building.floors.any((floor) => 
        floor.landmarks.any((landmark) => landmark.type == 'stairs'));
    if (hasStairs && !hasElevator && building.floors.length > 1) score += 0.3;
    
    accessibility['score'] = (score / maxPoints).clamp(0.0, 1.0);
    accessibility['rating'] = _getAccessibilityRating(accessibility['score']);
    
    // Store accessibility features list
    final features = <String>[];
    if (hasElevator) features.add('Elevator');
    if (hasAccessibleEntrance) features.add('Accessible Entrance');
    if (hasRamps) features.add('Ramps');
    if (hasAccessibleRestrooms) features.add('Accessible Restrooms');
    if (hasAccessibleParking) features.add('Accessible Parking');
    if (hasStairs) features.add('Stairs');
    
    accessibility['features'] = features;
    
    _accessibilityCache[cacheKey] = accessibility;
    return accessibility;
  }

  String _getAccessibilityRating(double score) {
    if (score >= 0.9) return 'Excellent';
    if (score >= 0.7) return 'Good';
    if (score >= 0.5) return 'Fair';
    if (score >= 0.3) return 'Poor';
    return 'Very Poor';
  }

  // FIXED: Floor connectivity analysis
  Map<String, dynamic> getFloorConnectivity(Building building) {
    final cacheKey = 'connectivity_${building.id}';
    if (_connectivityCache.containsKey(cacheKey)) {
      return _connectivityCache[cacheKey]!;
    }

    final connectivity = <String, dynamic>{};
    
    if (building.floors.length <= 1) {
      connectivity['isFullyConnected'] = true;
      connectivity['isolatedFloors'] = <Floor>[];
      connectivity['connectionMatrix'] = <String, List<String>>{};
      connectivity['verticalCirculationPoints'] = <Map<String, dynamic>>[];
      connectivity['shortestPaths'] = <String, Map<String, int>>{};
      _connectivityCache[cacheKey] = connectivity;
      return connectivity;
    }

    // Build connection matrix
    final connectionMatrix = <String, List<String>>{};
    final verticalCirculationPoints = <Map<String, dynamic>>[];
    
    for (final floor in building.floors) {
      connectionMatrix[floor.id] = <String>[];
      
      // Direct connections
      for (final connectedFloorId in floor.connectedFloors) {
        if (!connectionMatrix[floor.id]!.contains(connectedFloorId)) {
          connectionMatrix[floor.id]!.add(connectedFloorId);
        }
      }
      
      // Connections via vertical circulation
      final elevators = floor.landmarks.where((l) => l.type == 'elevator').toList();
      final stairs = floor.landmarks.where((l) => l.type == 'stairs').toList();
      final escalators = floor.landmarks.where((l) => l.type == 'escalator').toList();
      
      for (final elevator in elevators) {
        verticalCirculationPoints.add({
          'type': 'elevator',
          'floorId': floor.id,
          'landmark': elevator,
          'position': elevator.position,
        });
        
        // Find other floors with elevators nearby (same building)
        for (final otherFloor in building.floors) {
          if (otherFloor.id != floor.id) {
            final nearbyElevators = otherFloor.landmarks.where((l) => 
                l.type == 'elevator' && 
                _calculateDistance(elevator.position, l.position) <= 10 // 10 meters tolerance
            ).toList();
            
            if (nearbyElevators.isNotEmpty && !connectionMatrix[floor.id]!.contains(otherFloor.id)) {
              connectionMatrix[floor.id]!.add(otherFloor.id);
            }
          }
        }
      }
      
      for (final stair in stairs) {
        verticalCirculationPoints.add({
          'type': 'stairs',
          'floorId': floor.id,
          'landmark': stair,
          'position': stair.position,
        });
        
        // Find other floors with stairs nearby
        for (final otherFloor in building.floors) {
          if (otherFloor.id != floor.id) {
            final nearbyStairs = otherFloor.landmarks.where((l) => 
                l.type == 'stairs' && 
                _calculateDistance(stair.position, l.position) <= 10
            ).toList();
            
            if (nearbyStairs.isNotEmpty && !connectionMatrix[floor.id]!.contains(otherFloor.id)) {
              connectionMatrix[floor.id]!.add(otherFloor.id);
            }
          }
        }
      }
      
      for (final escalator in escalators) {
        verticalCirculationPoints.add({
          'type': 'escalator',
          'floorId': floor.id,
          'landmark': escalator,
          'position': escalator.position,
        });
        
        // Escalators typically connect adjacent floors
        final targetLevel = escalator.properties['direction'] == 'up' 
            ? floor.level + 1 
            : floor.level - 1;
        
        try {
          final targetFloor = building.floors.firstWhere((f) => f.level == targetLevel);
          if (!connectionMatrix[floor.id]!.contains(targetFloor.id)) {
            connectionMatrix[floor.id]!.add(targetFloor.id);
          }
        } catch (e) {
          // Target floor doesn't exist
        }
      }
    }
    
    // Find isolated floors using graph traversal
    final visited = <String>{};
    final isolatedFloors = <Floor>[];
    
    void dfs(String floorId) {
      visited.add(floorId);
      for (final connectedFloorId in connectionMatrix[floorId] ?? []) {
        if (!visited.contains(connectedFloorId)) {
          dfs(connectedFloorId);
        }
      }
    }
    
    if (building.floors.isNotEmpty) {
      // Start DFS from ground floor or first floor
      Floor startFloor;
      try {
        startFloor = building.floors.firstWhere((f) => f.level == 0);
      } catch (e) {
        startFloor = building.floors.first;
      }
      
      dfs(startFloor.id);
      
      // Find floors not visited
      for (final floor in building.floors) {
        if (!visited.contains(floor.id)) {
          isolatedFloors.add(floor);
        }
      }
    }
    
    // Calculate shortest paths between floors
    final shortestPaths = <String, Map<String, int>>{};
    for (final floor in building.floors) {
      shortestPaths[floor.id] = _calculateShortestPaths(floor.id, connectionMatrix);
    }
    
    connectivity['isFullyConnected'] = isolatedFloors.isEmpty;
    connectivity['isolatedFloors'] = isolatedFloors;
    connectivity['connectionMatrix'] = connectionMatrix;
    connectivity['verticalCirculationPoints'] = verticalCirculationPoints;
    connectivity['shortestPaths'] = shortestPaths;
    connectivity['connectivityScore'] = _calculateConnectivityScore(building, isolatedFloors);
    
    _connectivityCache[cacheKey] = connectivity;
    return connectivity;
  }

  double _calculateConnectivityScore(Building building, List<Floor> isolatedFloors) {
    if (building.floors.length <= 1) return 1.0;
    
    final connectedFloors = building.floors.length - isolatedFloors.length;
    final baseScore = connectedFloors / building.floors.length;
    
    // Bonus for having multiple types of vertical circulation
    double bonus = 0.0;
    final hasElevator = building.floors.any((f) => f.landmarks.any((l) => l.type == 'elevator'));
    final hasStairs = building.floors.any((f) => f.landmarks.any((l) => l.type == 'stairs'));
    final hasEscalator = building.floors.any((f) => f.landmarks.any((l) => l.type == 'escalator'));
    
    int circulationTypes = 0;
    if (hasElevator) circulationTypes++;
    if (hasStairs) circulationTypes++;
    if (hasEscalator) circulationTypes++;
    
    bonus = (circulationTypes - 1) * 0.1; // Up to 20% bonus
    
    return (baseScore + bonus).clamp(0.0, 1.0);
  }

  Map<String, int> _calculateShortestPaths(String startFloorId, Map<String, List<String>> connectionMatrix) {
    final distances = <String, int>{};
    final queue = <String>[startFloorId];
    distances[startFloorId] = 0;
    
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final currentDistance = distances[current]!;
      
      for (final neighbor in connectionMatrix[current] ?? []) {
        if (!distances.containsKey(neighbor)) {
          distances[neighbor] = currentDistance + 1;
          queue.add(neighbor);
        }
      }
    }
    
    return distances;
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // meters
    final double lat1Rad = point1.latitude * math.pi / 180;
    final double lat2Rad = point2.latitude * math.pi / 180;
    final double deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180;
    final double deltaLngRad = (point2.longitude - point1.longitude) * math.pi / 180;

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  // FIXED: Get navigation path between floors
  List<Floor> getNavigationPath(Floor startFloor, Floor endFloor, Building building) {
    final connectivity = getFloorConnectivity(building);
    final shortestPaths = connectivity['shortestPaths'] as Map<String, Map<String, int>>;
    
    if (!shortestPaths.containsKey(startFloor.id) || 
        !shortestPaths[startFloor.id]!.containsKey(endFloor.id)) {
      return []; // No path exists
    }
    
    // Reconstruct path using BFS
    final connectionMatrix = connectivity['connectionMatrix'] as Map<String, List<String>>;
    final path = _reconstructPath(startFloor.id, endFloor.id, connectionMatrix);
    
    final floorPath = <Floor>[];
    for (final floorId in path) {
      try {
        final floor = building.floors.firstWhere((f) => f.id == floorId);
        floorPath.add(floor);
      } catch (e) {
        // Floor not found, skip
      }
    }
    
    return floorPath;
  }

  List<String> _reconstructPath(String start, String end, Map<String, List<String>> connectionMatrix) {
    final queue = <List<String>>[[start]];
    final visited = <String>{start};
    
    while (queue.isNotEmpty) {
      final path = queue.removeAt(0);
      final current = path.last;
      
      if (current == end) {
        return path;
      }
      
      for (final neighbor in connectionMatrix[current] ?? []) {
        if (!visited.contains(neighbor)) {
          visited.add(neighbor);
          queue.add([...path, neighbor]);
        }
      }
    }
    
    return []; // No path found
  }

  // FIXED: Get landmarks near position  
  List<Landmark> getLandmarksNearPosition(LatLng position, Building building, {double radiusMeters = 50.0}) {
    final nearbyLandmarks = <Landmark>[];
    
    for (final floor in building.floors) {
      for (final landmark in floor.landmarks) {
        final distance = _calculateDistance(position, landmark.position);
        if (distance <= radiusMeters) {
          nearbyLandmarks.add(landmark);
        }
      }
    }
    
    // Sort by distance
    nearbyLandmarks.sort((a, b) {
      final distanceA = _calculateDistance(position, a.position);
      final distanceB = _calculateDistance(position, b.position);
      return distanceA.compareTo(distanceB);
    });
    
    return nearbyLandmarks;
  }

  // FIXED: Get landmarks by type in building
  List<Landmark> getLandmarksByType(Building building, String type) {
    final landmarks = <Landmark>[];
    
    for (final floor in building.floors) {
      landmarks.addAll(floor.landmarks.where((landmark) => landmark.type == type));
    }
    
    return landmarks;
  }

  // FIXED: Check if building has specific feature
  bool buildingHasFeature(Building building, String feature) {
    return building.floors.any((floor) => 
        floor.landmarks.any((landmark) => 
            landmark.type == feature || 
            landmark.properties.containsKey(feature) ||
            landmark.properties['features']?.contains(feature) == true));
  }

  // FIXED: Get building statistics
  Map<String, dynamic> getBuildingStats(Building building) {
    final stats = <String, dynamic>{};
    
    stats['totalFloors'] = building.floors.length;
    stats['totalLandmarks'] = building.floors.fold<int>(0, (sum, floor) => sum + floor.landmarks.length);
    stats['totalRoads'] = building.floors.fold<int>(0, (sum, floor) => sum + floor.roads.length);
    
    // Floor distribution
    final floorLevels = building.floors.map((f) => f.level).toList()..sort();
    stats['lowestFloor'] = floorLevels.isNotEmpty ? floorLevels.first : 0;
    stats['highestFloor'] = floorLevels.isNotEmpty ? floorLevels.last : 0;
    stats['floorRange'] = floorLevels.isNotEmpty ? floorLevels.last - floorLevels.first + 1 : 0;
    
    // Landmark types
    final landmarkTypes = <String, int>{};
    for (final floor in building.floors) {
      for (final landmark in floor.landmarks) {
        landmarkTypes[landmark.type] = (landmarkTypes[landmark.type] ?? 0) + 1;
      }
    }
    stats['landmarkTypes'] = landmarkTypes;
    
    // Road network
    double totalRoadLength = 0.0;
    for (final floor in building.floors) {
      for (final road in floor.roads) {
        for (int i = 0; i < road.points.length - 1; i++) {
          totalRoadLength += _calculateDistance(road.points[i], road.points[i + 1]);
        }
      }
    }
    stats['totalRoadLength'] = totalRoadLength;
    
    // Building area estimation (rough calculation)
    if (building.boundaryPoints.isNotEmpty) {
      stats['estimatedArea'] = _calculatePolygonArea(building.boundaryPoints);
    } else {
      stats['estimatedArea'] = 0.0;
    }
    
    return stats;
  }

  double _calculatePolygonArea(List<LatLng> points) {
    if (points.length < 3) return 0.0;
    
    double area = 0.0;
    for (int i = 0; i < points.length; i++) {
      final j = (i + 1) % points.length;
      area += points[i].longitude * points[j].latitude;
      area -= points[j].longitude * points[i].latitude;
    }
    return (area.abs() / 2.0) * 111319.9 * 111319.9; // Rough conversion to square meters
  }

  // FIXED: Building validation
  List<String> validateBuilding(Building building) {
    final issues = <String>[];
    
    // Check for empty building
    if (building.floors.isEmpty) {
      issues.add('Building has no floors');
      return issues;
    }
    
    // Check for ground floor
    final hasGroundFloor = building.floors.any((f) => f.level == 0);
    if (!hasGroundFloor) {
      issues.add('Building lacks ground floor (level 0)');
    }
    
    // Check for entrances
    final hasEntrance = building.floors.any((f) => 
        f.landmarks.any((l) => l.type == 'entrance'));
    if (!hasEntrance) {
      issues.add('Building has no marked entrances');
    }
    
    // Check multi-floor accessibility
    if (building.floors.length > 1) {
      final hasElevator = building.floors.any((f) => 
          f.landmarks.any((l) => l.type == 'elevator'));
      final hasStairs = building.floors.any((f) => 
          f.landmarks.any((l) => l.type == 'stairs'));
      
      if (!hasElevator && !hasStairs) {
        issues.add('Multi-floor building lacks vertical circulation');
      }
      
      if (!hasElevator) {
        issues.add('Multi-floor building lacks elevator access');
      }
    }
    
    // Check for accessible entrance
    final hasAccessibleEntrance = building.floors.any((f) => 
        f.landmarks.any((l) => l.type == 'entrance' && l.isAccessible));
    if (!hasAccessibleEntrance) {
      issues.add('Building has no marked accessible entrance');
    }
    
    // Check for duplicate floor levels
    final levels = building.floors.map((f) => f.level).toList();
    final uniqueLevels = levels.toSet();
    if (levels.length != uniqueLevels.length) {
      issues.add('Building has duplicate floor levels');
    }
    
    // Check for orphaned floors (no connections and no circulation)
    final connectivity = getFloorConnectivity(building);
    final isolatedFloors = connectivity['isolatedFloors'] as List<Floor>;
    if (isolatedFloors.isNotEmpty) {
      issues.add('Building has ${isolatedFloors.length} isolated floor(s)');
    }
    
    // Check landmark connectivity within floors
    for (final floor in building.floors) {
      if (floor.landmarks.isNotEmpty && floor.roads.isEmpty) {
        issues.add('Floor "${floor.name}" has landmarks but no roads');
      }
    }
    
    return issues;
  }

  // FIXED: Get improvement suggestions
  List<String> getBuildingImprovementSuggestions(Building building) {
    final suggestions = <String>[];
    final accessibility = getBuildingAccessibility(building);
    
    // Accessibility suggestions
    if (building.floors.length > 1 && !accessibility['hasElevator']!) {
      suggestions.add('Add elevator for better accessibility');
    }
    
    if (!accessibility['hasAccessibleEntrance']!) {
      suggestions.add('Mark or add accessible entrance');
    }
    
    if (!accessibility['hasAccessibleRestrooms']!) {
      suggestions.add('Add accessible restroom facilities');
    }
    
    // Connectivity suggestions
    final connectivity = getFloorConnectivity(building);
    final isolatedFloors = connectivity['isolatedFloors'] as List<Floor>;
    if (isolatedFloors.isNotEmpty) {
      suggestions.add('Add vertical circulation to ${isolatedFloors.length} isolated floor(s)');
    }
    
    // Wayfinding suggestions
    for (final floor in building.floors) {
      if (floor.landmarks.where((l) => l.type == 'information').isEmpty) {
        suggestions.add('Add information/directory landmark to ${floor.name}');
      }
      
      if (floor.landmarks.where((l) => l.type == 'restroom').isEmpty && floor.level >= 0) {
        suggestions.add('Consider adding restroom facilities to ${floor.name}');
      }
    }
    
    // Emergency preparedness
    final hasEmergencyExit = building.floors.any((f) => 
        f.landmarks.any((l) => l.type == 'emergency_exit'));
    if (!hasEmergencyExit) {
      suggestions.add('Mark emergency exits for safety');
    }
    
    // Parking suggestions
    if (!accessibility['hasAccessibleParking']!) {
      suggestions.add('Consider adding accessible parking spaces');
    }
    
    return suggestions;
  }

  // Clear caches when data changes
  void clearCaches() {
    _accessibilityCache.clear();
    _connectivityCache.clear();
    notifyListeners();
  }

  // Get floor by level
  Floor? getFloorByLevel(Building building, int level) {
    try {
      return building.floors.firstWhere((floor) => floor.level == level);
    } catch (e) {
      return null;
    }
  }

  // Get floors in level order
  List<Floor> getFloorsInOrder(Building building) {
    final floors = List<Floor>.from(building.floors);
    floors.sort((a, b) => a.level.compareTo(b.level));
    return floors;
  }

  // Check if floor is accessible from another floor
  bool isFloorAccessible(Floor fromFloor, Floor toFloor, Building building) {
    if (fromFloor.id == toFloor.id) return true;
    
    final connectivity = getFloorConnectivity(building);
    final shortestPaths = connectivity['shortestPaths'] as Map<String, Map<String, int>>;
    
    return shortestPaths[fromFloor.id]?.containsKey(toFloor.id) ?? false;
  }

  // Get distance between floors (in terms of connections)
  int? getFloorDistance(Floor fromFloor, Floor toFloor, Building building) {
    if (fromFloor.id == toFloor.id) return 0;
    
    final connectivity = getFloorConnectivity(building);
    final shortestPaths = connectivity['shortestPaths'] as Map<String, Map<String, int>>;
    
    return shortestPaths[fromFloor.id]?[toFloor.id];
  }
}