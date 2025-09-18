import 'package:flutter/material.dart';
import '../models/models.dart';

class BuildingProvider extends ChangeNotifier {
  String? _selectedBuildingId;
  String? _selectedFloorId;
  bool _isIndoorMode = false; // Track if we're in indoor mode
  
  String? get selectedBuildingId => _selectedBuildingId;
  String? get selectedFloorId => _selectedFloorId;
  bool get isIndoorMode => _isIndoorMode;
  bool get isOutdoorMode => !_isIndoorMode;

  void selectBuilding(String? buildingId) {
    _selectedBuildingId = buildingId;
    
    if (buildingId != null) {
      _isIndoorMode = true;
      // Auto-select default floor if available
      final building = _findBuildingInCurrentSystem(buildingId);
      if (building != null) {
        final defaultFloor = building.defaultFloor ?? building.floors.firstOrNull;
        _selectedFloorId = defaultFloor?.id;
      }
    } else {
      _isIndoorMode = false;
      _selectedFloorId = null;
    }
    
    notifyListeners();
  }

  void selectFloor(String? floorId) {
    _selectedFloorId = floorId;
    notifyListeners();
  }

  // Switch to outdoor mode
  void switchToOutdoorMode() {
    _isIndoorMode = false;
    _selectedBuildingId = null;
    _selectedFloorId = null;
    notifyListeners();
  }

  // Switch to indoor mode with specific building/floor
  void switchToIndoorMode(String buildingId, [String? floorId]) {
    _isIndoorMode = true;
    _selectedBuildingId = buildingId;
    _selectedFloorId = floorId;
    notifyListeners();
  }

  // Get current context information
  String getCurrentContextDescription(RoadSystem? roadSystem) {
    if (!_isIndoorMode || _selectedBuildingId == null) {
      return 'Outdoor View';
    }
    
    final building = getSelectedBuilding(roadSystem);
    if (building == null) return 'Indoor View';
    
    final floor = getSelectedFloor(roadSystem);
    if (floor == null) return '${building.name} - Building View';
    
    return '${building.name} - ${floor.name}';
  }

  Building? getSelectedBuilding(RoadSystem? roadSystem) {
    if (_selectedBuildingId == null || roadSystem == null) return null;
    
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
    if (_selectedFloorId == null || building == null) return null;
    
    try {
      return building.floors.firstWhere(
        (floor) => floor.id == _selectedFloorId,
      );
    } catch (e) {
      return null;
    }
  }

  List<Floor> getFloorsForSelectedBuilding(RoadSystem? roadSystem) {
    final building = getSelectedBuilding(roadSystem);
    return building?.sortedFloors ?? [];
  }

  // Get all floors across all buildings
  List<Floor> getAllFloors(RoadSystem? roadSystem) {
    if (roadSystem == null) return [];
    return roadSystem.allFloors;
  }

  // Get buildings with floor count
  List<Map<String, dynamic>> getBuildingsSummary(RoadSystem? roadSystem) {
    if (roadSystem == null) return [];
    
    return roadSystem.buildings.map((building) => {
      'building': building,
      'floorCount': building.floors.length,
      'hasElevator': building.floors.any((f) => 
          f.landmarks.any((l) => l.type == 'elevator')),
      'hasStairs': building.floors.any((f) => 
          f.landmarks.any((l) => l.type == 'stairs')),
      'isSelected': building.id == _selectedBuildingId,
    }).toList();
  }

  // Get floor statistics
  Map<String, int> getFloorStatistics(Floor floor) {
    return {
      'roads': floor.roads.length,
      'landmarks': floor.landmarks.length,
      'elevators': floor.landmarks.where((l) => l.type == 'elevator').length,
      'stairs': floor.landmarks.where((l) => l.type == 'stairs').length,
      'bathrooms': floor.landmarks.where((l) => l.type == 'bathroom').length,
      'classrooms': floor.landmarks.where((l) => l.type == 'classroom').length,
      'offices': floor.landmarks.where((l) => l.type == 'office').length,
    };
  }

  // Check if current floor has vertical circulation
  bool hasVerticalCirculation(RoadSystem? roadSystem) {
    final floor = getSelectedFloor(roadSystem);
    return floor?.verticalCirculation.isNotEmpty ?? false;
  }

  // Get connected floors from current floor
  List<Floor> getConnectedFloors(RoadSystem? roadSystem) {
    final currentFloor = getSelectedFloor(roadSystem);
    final building = getSelectedBuilding(roadSystem);
    
    if (currentFloor == null || building == null) return [];

    final connectedFloorIds = <String>{};
    
    // Add floors connected via vertical circulation
    for (final landmark in currentFloor.verticalCirculation) {
      connectedFloorIds.addAll(landmark.connectedFloors);
    }
    
    // Add explicitly connected floors
    connectedFloorIds.addAll(currentFloor.connectedFloors);
    
    return building.floors.where((f) => connectedFloorIds.contains(f.id)).toList();
  }

  // Navigate to specific floor
  void navigateToFloor(String buildingId, String floorId) {
    _selectedBuildingId = buildingId;
    _selectedFloorId = floorId;
    _isIndoorMode = true;
    notifyListeners();
  }

  // Go to floor above/below
  void goToAdjacentFloor(RoadSystem? roadSystem, bool goUp) {
    final currentFloor = getSelectedFloor(roadSystem);
    final building = getSelectedBuilding(roadSystem);
    
    if (currentFloor == null || building == null) return;
    
    final targetLevel = goUp ? currentFloor.level + 1 : currentFloor.level - 1;
    final targetFloor = building.floors.where((f) => f.level == targetLevel).firstOrNull;
    
    if (targetFloor != null) {
      selectFloor(targetFloor.id);
    }
  }

  // Find nearest elevator/stairs on current floor
  Landmark? findNearestVerticalCirculation(RoadSystem? roadSystem, String type) {
    final floor = getSelectedFloor(roadSystem);
    if (floor == null) return null;
    
    return floor.landmarks
        .where((l) => l.type == type)
        .firstOrNull;
  }

  // Check if user can access a specific floor
  bool canAccessFloor(RoadSystem? roadSystem, String targetFloorId) {
    if (!_isIndoorMode || _selectedFloorId == null) return false;
    
    final currentFloor = getSelectedFloor(roadSystem);
    if (currentFloor == null) return false;
    
    // Same floor
    if (currentFloor.id == targetFloorId) return true;
    
    // Check if connected via vertical circulation
    final connectedFloors = getConnectedFloors(roadSystem);
    return connectedFloors.any((f) => f.id == targetFloorId);
  }

  // Get floor-specific editing context
  String getEditingContext() {
    if (_isIndoorMode && _selectedFloorId != null) {
      return 'indoor';
    }
    return 'outdoor';
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

  // Helper method to find building by ID
  Building? _findBuildingInCurrentSystem(String buildingId) {
    // This would normally access the current road system
    // For now, return null - the caller should pass the road system
    return null;
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
    
    return {
      'hasElevator': hasElevator,
      'hasAccessibleEntrance': hasAccessibleEntrance,
      'multiFloor': building.floors.length > 1,
    };
  }
}

// Extension to add firstOrNull functionality for better null safety
extension IterableExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }
}