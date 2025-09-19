import 'package:flutter/foundation.dart';
import '../models/models.dart';

class BuildingProvider extends ChangeNotifier {
  String? _selectedBuildingId;
  String? _selectedFloorId;
  bool _isIndoorMode = false;

  // Getters
  String? get selectedBuildingId => _selectedBuildingId;
  String? get selectedFloorId => _selectedFloorId;
  bool get isIndoorMode => _isIndoorMode;
  bool get hasSelectedBuilding => _selectedBuildingId != null;
  bool get hasSelectedFloor => _selectedFloorId != null;

  // Select building
  void selectBuilding(String? buildingId) {
    if (_selectedBuildingId != buildingId) {
      _selectedBuildingId = buildingId;
      _selectedFloorId = null; // Clear floor selection when building changes
      notifyListeners();
    }
  }

  // Select floor
  void selectFloor(String? floorId) {
    if (_selectedFloorId != floorId) {
      _selectedFloorId = floorId;
      notifyListeners();
    }
  }

  // Set indoor mode
  void setIndoorMode(bool isIndoor) {
    if (_isIndoorMode != isIndoor) {
      _isIndoorMode = isIndoor;
      
      // If switching to outdoor mode, clear selections
      if (!isIndoor) {
        _selectedBuildingId = null;
        _selectedFloorId = null;
      }
      
      notifyListeners();
    }
  }

  // Toggle indoor/outdoor mode
  void toggleMode() {
    setIndoorMode(!_isIndoorMode);
  }

  // Navigate to specific building and floor
  void navigateToBuilding(String buildingId, {String? floorId}) {
    _selectedBuildingId = buildingId;
    _selectedFloorId = floorId;
    _isIndoorMode = true;
    notifyListeners();
  }

  // Navigate to specific floor (must have building selected)
  void navigateToFloor(String buildingId, String floorId) {
    _selectedBuildingId = buildingId;
    _selectedFloorId = floorId;
    _isIndoorMode = true;
    notifyListeners();
  }

  // Get currently selected building
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

  // Get currently selected floor
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

  // Get floors for selected building
  List<Floor> getSelectedBuildingFloors(RoadSystem? roadSystem) {
    final building = getSelectedBuilding(roadSystem);
    return building?.floors ?? [];
  }

  // Get sorted floors for selected building
  List<Floor> getSortedFloorsForBuilding(Building building) {
    final floors = List<Floor>.from(building.floors);
    floors.sort((a, b) => b.level.compareTo(a.level)); // Highest to lowest
    return floors;
  }

  // Check if current selection is valid
  bool isSelectionValid(RoadSystem? roadSystem) {
    if (!_isIndoorMode) return true; // Outdoor is always valid
    
    if (_selectedBuildingId == null) return false;
    
    final building = getSelectedBuilding(roadSystem);
    if (building == null) return false;
    
    if (_selectedFloorId == null) return building.floors.isNotEmpty;
    
    return getSelectedFloor(roadSystem) != null;
  }

  // Reset to default state
  void reset() {
    _selectedBuildingId = null;
    _selectedFloorId = null;
    _isIndoorMode = false;
    notifyListeners();
  }

  // Switch to outdoor mode
  void goOutdoor() {
    _isIndoorMode = false;
    _selectedBuildingId = null;
    _selectedFloorId = null;
    notifyListeners();
  }

  // Auto-select default floor when building is selected
  void autoSelectDefaultFloor(RoadSystem? roadSystem) {
    final building = getSelectedBuilding(roadSystem);
    if (building != null && _selectedFloorId == null && building.floors.isNotEmpty) {
      // Select default floor or ground floor or first available floor
      Floor? targetFloor = building.defaultFloor;
      targetFloor ??= building.floors.where((f) => f.level == 0).firstOrNull;
      targetFloor ??= building.floors.first;
      
      // ignore: unnecessary_null_comparison
      if (targetFloor != null) {
        _selectedFloorId = targetFloor.id;
        notifyListeners();
      }
    }
  }

  // Get floor display name with level indication
  String getFloorDisplayName(Floor floor) {
    final levelPrefix = floor.level > 0 
        ? '${floor.level}F' 
        : floor.level == 0 
            ? 'GF' 
            : 'B${-floor.level}';
    return '$levelPrefix: ${floor.name}';
  }

  // Get building accessibility information
  Map<String, bool> getBuildingAccessibility(Building building) {
    final hasElevator = building.floors.any((f) => 
        f.landmarks.any((l) => l.type == 'elevator'));
    
    final hasAccessibleEntrance = building.floors.any((f) => 
        f.landmarks.any((l) => l.type == 'entrance' && l.isAccessible));
    
    final hasStairs = building.floors.any((f) => 
        f.landmarks.any((l) => l.type == 'stairs'));
    
    return {
      'hasElevator': hasElevator,
      'hasStairs': hasStairs,
      'hasAccessibleEntrance': hasAccessibleEntrance,
      'multiFloor': building.floors.length > 1,
      'isAccessible': hasElevator || (building.floors.length == 1),
    };
  }

  // Get floor connectivity analysis
  Map<String, dynamic> getFloorConnectivity(Building building) {
    final connectivity = <String, List<String>>{};
    final isolatedFloors = <Floor>[];
    
    for (final floor in building.floors) {
      final connections = <String>[];
      
      // Check vertical circulation landmarks
      for (final landmark in floor.landmarks) {
        if (landmark.isVerticalCirculation && landmark.connectedFloors.isNotEmpty) {
          connections.addAll(landmark.connectedFloors);
        }
      }
      
      connectivity[floor.id] = connections;
      
      // Check if floor is isolated (no connections and not ground floor)
      if (connections.isEmpty && floor.level != 0) {
        isolatedFloors.add(floor);
      }
    }
    
    return {
      'connectivity': connectivity,
      'isolatedFloors': isolatedFloors,
      'isFullyConnected': isolatedFloors.isEmpty,
    };
  }

  // Get navigation path between floors
  List<Floor> getFloorPath(Building building, Floor fromFloor, Floor toFloor) {
    if (fromFloor.id == toFloor.id) return [fromFloor];
    
    // Simple implementation - find common vertical circulation
    final fromCirculation = fromFloor.verticalCirculation;
    final toCirculation = toFloor.verticalCirculation;
    
    // Check for direct connection
    for (final fromLandmark in fromCirculation) {
      if (fromLandmark.connectedFloors.contains(toFloor.id)) {
        return [fromFloor, toFloor];
      }
    }
    
    // Check for indirect connection through common circulation
    for (final fromLandmark in fromCirculation) {
      for (final toLandmark in toCirculation) {
        final commonFloors = fromLandmark.connectedFloors
            .where((id) => toLandmark.connectedFloors.contains(id))
            .toList();
        
        if (commonFloors.isNotEmpty) {
          // Find the intermediate floor
          final intermediateFloor = building.floors
              .where((f) => commonFloors.contains(f.id))
              .firstOrNull;
          
          if (intermediateFloor != null) {
            return [fromFloor, intermediateFloor, toFloor];
          }
        }
      }
    }
    
    // No path found
    return [];
  }

  // Get current context description
  String getCurrentContextDescription(RoadSystem? roadSystem) {
    if (!_isIndoorMode) {
      return 'Outdoor Mode';
    }
    
    final building = getSelectedBuilding(roadSystem);
    final floor = getSelectedFloor(roadSystem);
    
    if (building == null) {
      return 'Indoor Mode - No Building Selected';
    }
    
    if (floor == null) {
      return 'Indoor Mode - ${building.name}';
    }
    
    return 'Indoor Mode - ${building.name}, ${getFloorDisplayName(floor)}';
  }

  // Check if can navigate to floor
  bool canNavigateToFloor(Building building, Floor targetFloor) {
    final connectivity = getFloorConnectivity(building);
    final isolatedFloors = connectivity['isolatedFloors'] as List<Floor>;
    
    return !isolatedFloors.any((f) => f.id == targetFloor.id);
  }

  // Get available floors for navigation from current floor
  List<Floor> getNavigableFloors(RoadSystem? roadSystem) {
    final building = getSelectedBuilding(roadSystem);
    final currentFloor = getSelectedFloor(roadSystem);
    
    if (building == null || currentFloor == null) {
      return building?.floors ?? [];
    }
    
    final navigableFloors = <Floor>[];
    
    for (final floor in building.floors) {
      if (floor.id == currentFloor.id) {
        navigableFloors.add(floor); // Always include current floor
      } else if (canNavigateToFloor(building, floor)) {
        // Check if there's a path from current floor
        final path = getFloorPath(building, currentFloor, floor);
        if (path.isNotEmpty) {
          navigableFloors.add(floor);
        }
      }
    }
    
    return navigableFloors;
  }

  // Get floor statistics
  Map<String, int> getFloorStatistics(Floor floor) {
    return {
      'roads': floor.roads.length,
      'landmarks': floor.landmarks.length,
      'verticalCirculation': floor.verticalCirculation.length,
      'entrances': floor.entrances.length,
      'accessibleFeatures': floor.accessibleFeatures.length,
    };
  }

  // Get building statistics
  Map<String, dynamic> getBuildingStatistics(Building building) {
    final floorStats = building.floors.map(getFloorStatistics).toList();
    final accessibility = getBuildingAccessibility(building);
    final connectivity = getFloorConnectivity(building);
    
    return {
      'floors': building.floors.length,
      'totalRoads': floorStats.fold<int>(0, (sum, stats) => sum + (stats['roads'] ?? 0)),
      'totalLandmarks': floorStats.fold<int>(0, (sum, stats) => sum + (stats['landmarks'] ?? 0)),
      'verticalCirculation': floorStats.fold<int>(0, (sum, stats) => sum + (stats['verticalCirculation'] ?? 0)),
      'accessibility': accessibility,
      'connectivity': connectivity,
      'minLevel': building.floors.isNotEmpty ? building.floors.map((f) => f.level).reduce((a, b) => a < b ? a : b) : 0,
      'maxLevel': building.floors.isNotEmpty ? building.floors.map((f) => f.level).reduce((a, b) => a > b ? a : b) : 0,
    };
  }

  // Validate building structure
  List<String> validateBuildingStructure(Building building) {
    final issues = <String>[];
    
    // Check for floors without vertical circulation (except ground floor)
    for (final floor in building.floors) {
      if (floor.level != 0 && floor.verticalCirculation.isEmpty) {
        issues.add('Floor "${floor.name}" (Level ${floor.level}) has no vertical circulation access');
      }
    }
    
    // Check for isolated floors
    final connectivity = getFloorConnectivity(building);
    final isolatedFloors = connectivity['isolatedFloors'] as List<Floor>;
    for (final floor in isolatedFloors) {
      issues.add('Floor "${floor.name}" is isolated - no connections to other floors');
    }
    
    // Check for accessibility issues
    final accessibility = getBuildingAccessibility(building);
    if (building.floors.length > 1 && !accessibility['hasElevator']!) {
      issues.add('Multi-floor building lacks elevator access');
    }
    
    if (!accessibility['hasAccessibleEntrance']!) {
      issues.add('Building has no marked accessible entrance');
    }
    
    // Check for duplicate floor levels
    final levels = building.floors.map((f) => f.level).toList();
    final uniqueLevels = levels.toSet();
    if (levels.length != uniqueLevels.length) {
      issues.add('Building has duplicate floor levels');
    }
    
    return issues;
  }

  // Get suggestions for improving building
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
    
    // Connectivity suggestions
    final connectivity = getFloorConnectivity(building);
    final isolatedFloors = connectivity['isolatedFloors'] as List<Floor>;
    if (isolatedFloors.isNotEmpty) {
      suggestions.add('Add vertical circulation to isolated floors');
    }
    
    // Wayfinding suggestions
    for (final floor in building.floors) {
      if (floor.landmarks.where((l) => l.type == 'information').isEmpty) {
        suggestions.add('Add information/directory landmark to ${floor.name}');
      }
    }
    
    return suggestions;
  }
}

// Note: IterableExtension is now defined in models.dart to avoid conflicts