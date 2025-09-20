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

  /// Reset all selections and clear indoor mode
  void reset() {
    _selectedBuildingId = null;
    _selectedFloorId = null;
    _isIndoorMode = false;
    _showFloorPlan = false;
    _accessibilityCache.clear();
    _connectivityCache.clear();
    notifyListeners();
  }

  /// Get display name for a floor (handles basement levels and special naming)
  String getFloorDisplayName(Floor floor) {
    if (floor.level == 0) {
      return 'Ground Floor';
    } else if (floor.level < 0) {
      final basementLevel = floor.level.abs();
      if (basementLevel == 1) {
        return 'Basement';
      } else {
        return 'B$basementLevel';
      }
    } else {
      // Positive levels
      if (floor.level == 1) {
        return '1st Floor';
      } else if (floor.level == 2) {
        return '2nd Floor';
      } else if (floor.level == 3) {
        return '3rd Floor';
      } else {
        return '${floor.level}th Floor';
      }
    }
  }

  /// Get floor display name with custom name if available
  String getFloorDisplayNameWithCustom(Floor floor) {
    if (floor.name.isNotEmpty && floor.name != getFloorDisplayName(floor)) {
      return '${getFloorDisplayName(floor)} (${floor.name})';
    }
    return getFloorDisplayName(floor);
  }

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

  /// Get building accessibility analysis
  Map<String, dynamic> getBuildingAccessibility(Building building) {
    final cacheKey = 'accessibility_${building.id}';
    if (_accessibilityCache.containsKey(cacheKey)) {
      return _accessibilityCache[cacheKey]!;
    }

    int accessibleFloors = 0;
    int elevatorsCount = 0;
    int rampCount = 0;
    int accessibleEntrances = 0;
    final List<String> accessibilityFeatures = [];

    for (final floor in building.floors) {
      bool floorIsAccessible = false;
      
      // Check for elevators
      final floorElevators = floor.landmarks.where((l) => l.type == 'elevator').length;
      elevatorsCount += floorElevators;
      if (floorElevators > 0) {
        floorIsAccessible = true;
      }

      // Check for ramps
      final floorRamps = floor.landmarks.where((l) => l.type == 'ramp').length;
      rampCount += floorRamps;
      if (floorRamps > 0) {
        floorIsAccessible = true;
      }

      // Check for accessible entrances
      final entrances = floor.landmarks.where((l) => 
          l.type == 'entrance' && l.name.toLowerCase().contains('accessible')).length;
      accessibleEntrances += entrances;
      if (entrances > 0) {
        floorIsAccessible = true;
      }

      if (floorIsAccessible) {
        accessibleFloors++;
      }
    }

    // Determine accessibility features
    if (elevatorsCount > 0) accessibilityFeatures.add('Elevators Available');
    if (rampCount > 0) accessibilityFeatures.add('Wheelchair Ramps');
    if (accessibleEntrances > 0) accessibilityFeatures.add('Accessible Entrances');

    final result = {
      'accessibleFloors': accessibleFloors,
      'totalFloors': building.floors.length,
      'elevators': elevatorsCount,
      'ramps': rampCount,
      'accessibleEntrances': accessibleEntrances,
      'features': accessibilityFeatures,
      'accessibilityScore': building.floors.isNotEmpty 
          ? (accessibleFloors / building.floors.length * 100).round()
          : 0,
    };

    _accessibilityCache[cacheKey] = result;
    return result;
  }

  /// Get building connectivity analysis
  Map<String, dynamic> getBuildingConnectivity(Building building) {
    final cacheKey = 'connectivity_${building.id}';
    if (_connectivityCache.containsKey(cacheKey)) {
      return _connectivityCache[cacheKey]!;
    }

    final floorConnections = <String, List<String>>{};
    int totalConnections = 0;
    final verticalTransportFloors = <String>{};

    for (final floor in building.floors) {
      final connections = <String>[];
      
      // Direct connections
      connections.addAll(floor.connectedFloors);
      
      // Vertical connections (elevators/stairs)
      final hasVerticalTransport = floor.landmarks.any((l) => 
          l.type == 'elevator' || l.type == 'stairs');
      
      if (hasVerticalTransport) {
        verticalTransportFloors.add(floor.id);
        
        // Find other floors with vertical transport
        for (final otherFloor in building.floors) {
          if (otherFloor.id != floor.id) {
            final otherHasTransport = otherFloor.landmarks.any((l) => 
                l.type == 'elevator' || l.type == 'stairs');
            
            if (otherHasTransport && !connections.contains(otherFloor.id)) {
              connections.add(otherFloor.id);
            }
          }
        }
      }
      
      floorConnections[floor.id] = connections;
      totalConnections += connections.length;
    }

    final result = {
      'floorConnections': floorConnections,
      'totalConnections': totalConnections,
      'floorsWithVerticalTransport': verticalTransportFloors.length,
      'totalFloors': building.floors.length,
      'connectivityScore': building.floors.isNotEmpty
          ? (verticalTransportFloors.length / building.floors.length * 100).round()
          : 0,
    };

    _connectivityCache[cacheKey] = result;
    return result;
  }

  /// Check if a point is within building bounds
  bool isPointInBuilding(LatLng point, Building building) {
    if (building.boundaryPoints.isEmpty) return false;

    int intersections = 0;
    final vertices = building.boundaryPoints;

    for (int i = 0; i < vertices.length; i++) {
      final j = (i + 1) % vertices.length;
      final vertex1 = vertices[i];
      final vertex2 = vertices[j];

      if (((vertex1.latitude > point.latitude) != (vertex2.latitude > point.latitude)) &&
          (point.longitude < (vertex2.longitude - vertex1.longitude) * 
          (point.latitude - vertex1.latitude) / (vertex2.latitude - vertex1.latitude) + vertex1.longitude)) {
        intersections++;
      }
    }

    return intersections % 2 == 1;
  }

  /// Get the closest floor to a given level
  Floor? getClosestFloor(Building building, int targetLevel) {
    if (building.floors.isEmpty) return null;

    Floor? closestFloor;
    int minDifference = double.maxFinite.toInt();

    for (final floor in building.floors) {
      final difference = (floor.level - targetLevel).abs();
      if (difference < minDifference) {
        minDifference = difference;
        closestFloor = floor;
      }
    }

    return closestFloor;
  }

  /// Get floors within a level range
  List<Floor> getFloorsInRange(Building building, int minLevel, int maxLevel) {
    return building.floors.where((floor) => 
        floor.level >= minLevel && floor.level <= maxLevel).toList();
  }

  /// Validate building structure and report issues
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
        f.landmarks.any((l) => l.type == 'entrance' && 
        l.name.toLowerCase().contains('accessible')));
    if (!hasAccessibleEntrance && building.floors.length > 0) {
      issues.add('Building lacks accessible entrance');
    }
    
    // Check for emergency exits
    final hasEmergencyExit = building.floors.any((f) => 
        f.landmarks.any((l) => l.type == 'emergency_exit'));
    if (!hasEmergencyExit) {
      issues.add('Building lacks emergency exits');
    }
    
    // Check floor numbering consistency
    final floorLevels = building.floors.map((f) => f.level).toSet();
    if (floorLevels.length != building.floors.length) {
      issues.add('Duplicate floor levels detected');
    }
    
    // Check boundary definition
    if (building.boundaryPoints.isEmpty) {
      issues.add('Building boundary not defined');
    } else if (building.boundaryPoints.length < 3) {
      issues.add('Building boundary needs at least 3 points');
    }
    
    return issues;
  }

  /// Calculate comprehensive building statistics
  Map<String, dynamic> getBuildingStatistics(Building building) {
    final stats = <String, dynamic>{
      'totalFloors': building.floors.length,
      'highestFloor': building.floors.isNotEmpty 
          ? building.floors.map((f) => f.level).reduce(math.max)
          : 0,
      'lowestFloor': building.floors.isNotEmpty 
          ? building.floors.map((f) => f.level).reduce(math.min)
          : 0,
      'totalLandmarks': building.floors.fold<int>(0, (sum, floor) => sum + floor.landmarks.length),
      'totalRoads': building.floors.fold<int>(0, (sum, floor) => sum + floor.roads.length),
      'floorsWithElevators': building.floors.where((f) => 
          f.landmarks.any((l) => l.type == 'elevator')).length,
      'floorsWithStairs': building.floors.where((f) => 
          f.landmarks.any((l) => l.type == 'stairs')).length,
      'floorsWithRestrooms': building.floors.where((f) => 
          f.landmarks.any((l) => l.type == 'restroom')).length,
    };

    // Calculate total area if boundary points exist
    if (building.boundaryPoints.isNotEmpty) {
      stats['estimatedArea'] = _calculatePolygonArea(building.boundaryPoints);
    } else {
      stats['estimatedArea'] = 0.0;
    }

    // Calculate road network length
    double totalRoadLength = 0.0;
    for (final floor in building.floors) {
      for (final road in floor.roads) {
        for (int i = 0; i < road.points.length - 1; i++) {
          totalRoadLength += _calculateDistance(road.points[i], road.points[i + 1]);
        }
      }
    }
    stats['totalRoadLength'] = totalRoadLength;

    // Accessibility features
    final accessibility = getBuildingAccessibility(building);
    stats['accessibilityScore'] = accessibility['accessibilityScore'];
    stats['accessibleFloors'] = accessibility['accessibleFloors'];

    // Connectivity analysis
    final connectivity = getBuildingConnectivity(building);
    stats['connectivityScore'] = connectivity['connectivityScore'];
    stats['floorsWithVerticalTransport'] = connectivity['floorsWithVerticalTransport'];

    // Floor distribution
    final floorLevels = building.floors.map((f) => f.level).toList()..sort();
    stats['floorRange'] = floorLevels.isNotEmpty ? floorLevels.last - floorLevels.first + 1 : 0;

    // Landmark distribution by type
    final landmarkTypes = <String, int>{};
    for (final floor in building.floors) {
      for (final landmark in floor.landmarks) {
        landmarkTypes[landmark.type] = (landmarkTypes[landmark.type] ?? 0) + 1;
      }
    }
    stats['landmarkTypes'] = landmarkTypes;

    // Validation issues
    final validationIssues = validateBuilding(building);
    stats['validationIssues'] = validationIssues;
    stats['isValid'] = validationIssues.isEmpty;

    return stats;
  }

  /// Calculate floor-specific statistics
  Map<String, dynamic> getFloorStatistics(Floor floor) {
    final stats = <String, dynamic>{
      'floorLevel': floor.level,
      'floorName': floor.name,
      'totalRoads': floor.roads.length,
      'totalLandmarks': floor.landmarks.length,
      'connectedFloors': floor.connectedFloors.length,
    };

    // Calculate total road length on this floor
    double totalRoadLength = 0.0;
    for (final road in floor.roads) {
      for (int i = 0; i < road.points.length - 1; i++) {
        totalRoadLength += _calculateDistance(road.points[i], road.points[i + 1]);
      }
    }
    stats['totalRoadLength'] = totalRoadLength;

    // Landmark types on this floor
    final landmarkTypes = <String, int>{};
    for (final landmark in floor.landmarks) {
      landmarkTypes[landmark.type] = (landmarkTypes[landmark.type] ?? 0) + 1;
    }
    stats['landmarkTypes'] = landmarkTypes;

    // Accessibility features
    final accessibleLandmarks = floor.landmarks.where((l) => 
        l.type == 'elevator' || l.type == 'ramp' || 
        l.name.toLowerCase().contains('accessible')).length;
    stats['accessibleFeatures'] = accessibleLandmarks;

    // Vertical circulation
    final elevators = floor.landmarks.where((l) => l.type == 'elevator').length;
    final stairs = floor.landmarks.where((l) => l.type == 'stairs').length;
    final escalators = floor.landmarks.where((l) => l.type == 'escalator').length;
    
    stats['elevators'] = elevators;
    stats['stairs'] = stairs;
    stats['escalators'] = escalators;
    stats['hasVerticalCirculation'] = elevators > 0 || stairs > 0 || escalators > 0;

    // Entrances and exits
    final entrances = floor.landmarks.where((l) => l.type == 'entrance').length;
    final exits = floor.landmarks.where((l) => l.type == 'exit').length;
    stats['entrances'] = entrances;
    stats['exits'] = exits;

    // Important services
    final restrooms = floor.landmarks.where((l) => l.type == 'restroom').length;
    final emergencyExits = floor.landmarks.where((l) => l.type == 'emergency_exit').length;
    stats['restrooms'] = restrooms;
    stats['emergencyExits'] = emergencyExits;

    // Floor area estimation (if building has boundary points)
    stats['estimatedFloorArea'] = 0.0; // Would need floor-specific boundary data

    return stats;
  }

  /// Navigate to a specific floor
  bool navigateToFloor(String floorId, RoadSystem? roadSystem) {
    if (roadSystem == null) return false;

    // Find the building and floor
    Building? targetBuilding;
    Floor? targetFloor;

    for (final building in roadSystem.buildings) {
      try {
        targetFloor = building.floors.firstWhere((f) => f.id == floorId);
        targetBuilding = building;
        break;
      } catch (e) {
        // Floor not found in this building, continue searching
      }
    }

    if (targetBuilding == null || targetFloor == null) {
      return false; // Floor not found
    }

    // Select the building and floor
    selectBuilding(targetBuilding.id);
    selectFloor(targetFloor.id);
    
    // Enable indoor mode if not already enabled
    if (!_isIndoorMode) {
      _isIndoorMode = true;
    }

    notifyListeners();
    return true;
  }

  /// Clear all caches (useful when building data changes)
  void clearCaches() {
    _accessibilityCache.clear();
    _connectivityCache.clear();
  }

  /// Calculate the area of a polygon defined by LatLng points
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

  /// Calculate distance between two LatLng points using Haversine formula
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth radius in meters

    final double lat1Rad = point1.latitude * math.pi / 180;
    final double lat2Rad = point2.latitude * math.pi / 180;
    final double deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180;
    final double deltaLngRad = (point2.longitude - point1.longitude) * math.pi / 180;

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  /// Validate building selection
  bool isValidSelection(RoadSystem? roadSystem) {
    if (roadSystem == null) return false;
    
    final building = getSelectedBuilding(roadSystem);
    if (building == null) return false;
    
    if (_selectedFloorId != null) {
      final floor = getSelectedFloor(roadSystem);
      return floor != null;
    }
    
    return true;
  }

  String getCurrentContextDescription(RoadSystem? roadSystem) {
  if (roadSystem == null) return 'No road system selected';
  if (!_isIndoorMode) return 'Outdoor navigation mode';
  
  final building = getSelectedBuilding(roadSystem);
  if (building == null) return 'Indoor mode - No building selected';
  
  final floor = getSelectedFloor(roadSystem);
  if (floor == null) return 'Building: ${building.name} - No floor selected';
  
  final floorName = getFloorDisplayName(floor);
  return 'Building: ${building.name} - $floorName';
}

  /// Get navigation context for current selection
  Map<String, dynamic>? getNavigationContext(RoadSystem? roadSystem) {
    final building = getSelectedBuilding(roadSystem);
    if (building == null) return null;

    final floor = getSelectedFloor(roadSystem);
    
    return {
      'building': building,
      'floor': floor,
      'isIndoorMode': _isIndoorMode,
      'showFloorPlan': _showFloorPlan,
      'availableFloors': building.floors,
      'accessibleFloors': floor != null ? getAccessibleFloors(floor, building) : <Floor>[],
      'buildingStats': getBuildingStatistics(building),
      'floorStats': floor != null ? getFloorStatistics(floor) : null,
      'validationIssues': validateBuilding(building),
    };
  }
}