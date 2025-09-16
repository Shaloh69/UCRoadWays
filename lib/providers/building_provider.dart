import 'package:flutter/material.dart';
import '../models/models.dart';

class BuildingProvider extends ChangeNotifier {
  String? _selectedBuildingId;
  String? _selectedFloorId;
  
  String? get selectedBuildingId => _selectedBuildingId;
  String? get selectedFloorId => _selectedFloorId;

  void selectBuilding(String? buildingId) {
    _selectedBuildingId = buildingId;
    _selectedFloorId = null; // Reset floor selection
    notifyListeners();
  }

  void selectFloor(String? floorId) {
    _selectedFloorId = floorId;
    notifyListeners();
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
    return building?.floors ?? [];
  }
}