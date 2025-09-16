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
          // ignore: cast_from_null_always_fails
          orElse: () => _roadSystems.isNotEmpty ? _roadSystems.first : null as RoadSystem,
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

  Future<void> _saveRoadSystems() async {
    await DataStorageService.saveRoadSystems(_roadSystems);
  }
}
