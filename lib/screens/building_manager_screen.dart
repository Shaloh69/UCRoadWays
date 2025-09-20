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

  /// Calculate building statistics
  Map<String, dynamic> getBuildingStatistics(Building building) {
    final stats = {
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

    return stats;
  }

  /// Clear all caches (useful when building data changes)
  void clearCaches() {
    _accessibilityCache.clear();
    _connectivityCache.clear();
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
    };
  }
}