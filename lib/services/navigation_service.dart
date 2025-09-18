import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';

class NavigationService {
  static const double _walkingSpeed = 1.4; // m/s
  static const double _earthRadius = 6371000; // Earth's radius in meters
  static const double _floorChangeTime = 30.0; // seconds for elevator/stairs

  /// Calculate the shortest route between two points in a road system
  /// Now with comprehensive multi-floor support
  static Future<NavigationRoute?> calculateRoute({
    required LatLng start,
    required LatLng end,
    required RoadSystem roadSystem,
    String? startFloorId,
    String? endFloorId,
    String? startBuildingId,
    String? endBuildingId,
    bool preferElevator = true, // For accessibility
  }) async {
    try {
      final waypoints = <LatLng>[];
      final floorChanges = <String>[];
      final floorTransitions = <FloorTransition>[];
      
      // Determine navigation context
      final navContext = _analyzeNavigationContext(
        start, end, roadSystem,
        startFloorId, endFloorId,
        startBuildingId, endBuildingId,
      );
      
      NavigationRoute? route;
      
      switch (navContext.type) {
        case NavigationType.sameFloor:
          route = await _calculateSameFloorRoute(start, end, navContext);
          break;
        case NavigationType.sameBuilding:
          route = await _calculateSameBuildingRoute(start, end, navContext, preferElevator);
          break;
        case NavigationType.differentBuildings:
          route = await _calculateMultiBuildingRoute(start, end, navContext, preferElevator);
          break;
        case NavigationType.indoorToOutdoor:
          route = await _calculateIndoorToOutdoorRoute(start, end, navContext);
          break;
        case NavigationType.outdoorToIndoor:
          route = await _calculateOutdoorToIndoorRoute(start, end, navContext);
          break;
        case NavigationType.outdoorOnly:
          route = await _calculateOutdoorRoute(start, end, navContext);
          break;
      }
      
      return route;
    } catch (e) {
      print('Error calculating route: $e');
      return null;
    }
  }

  /// Analyze the type of navigation required
  static NavigationContext _analyzeNavigationContext(
    LatLng start, LatLng end, RoadSystem roadSystem,
    String? startFloorId, String? endFloorId,
    String? startBuildingId, String? endBuildingId,
  ) {
    // Determine building and floor context
    final startBuilding = startBuildingId != null 
        ? roadSystem.buildings.where((b) => b.id == startBuildingId).firstOrNull
        : null;
    final endBuilding = endBuildingId != null 
        ? roadSystem.buildings.where((b) => b.id == endBuildingId).firstOrNull
        : null;
    
    final startFloor = startBuilding?.floors.where((f) => f.id == startFloorId).firstOrNull;
    final endFloor = endBuilding?.floors.where((f) => f.id == endFloorId).firstOrNull;
    
    NavigationType type;
    
    if (startFloorId == null && endFloorId == null) {
      type = NavigationType.outdoorOnly;
    } else if (startFloorId != null && endFloorId != null) {
      if (startFloorId == endFloorId) {
        type = NavigationType.sameFloor;
      } else if (startBuildingId == endBuildingId) {
        type = NavigationType.sameBuilding;
      } else {
        type = NavigationType.differentBuildings;
      }
    } else if (startFloorId != null && endFloorId == null) {
      type = NavigationType.indoorToOutdoor;
    } else {
      type = NavigationType.outdoorToIndoor;
    }
    
    return NavigationContext(
      type: type,
      roadSystem: roadSystem,
      startBuilding: startBuilding,
      endBuilding: endBuilding,
      startFloor: startFloor,
      endFloor: endFloor,
    );
  }

  /// Same floor navigation - optimized pathfinding
  static Future<NavigationRoute?> _calculateSameFloorRoute(
    LatLng start, LatLng end, NavigationContext context
  ) async {
    final waypoints = <LatLng>[start];
    
    if (context.startFloor != null) {
      // Indoor navigation on same floor
      final path = _findIndoorPath(start, end, context.startFloor!);
      waypoints.addAll(path);
    } else {
      // Outdoor navigation
      final path = _findOutdoorPath(start, end, context.roadSystem);
      waypoints.addAll(path);
    }
    
    waypoints.add(end);
    
    final totalDistance = _calculateTotalDistance(waypoints);
    final instructions = _generateDetailedInstructions(waypoints, [], context);
    
    return NavigationRoute(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      start: start,
      end: end,
      waypoints: waypoints,
      totalDistance: totalDistance,
      instructions: instructions,
      floorChanges: [],
      floorTransitions: [],
    );
  }

  /// Same building, different floors navigation
  static Future<NavigationRoute?> _calculateSameBuildingRoute(
    LatLng start, LatLng end, NavigationContext context, bool preferElevator
  ) async {
    final building = context.startBuilding!;
    final startFloor = context.startFloor!;
    final endFloor = context.endFloor!;
    
    final waypoints = <LatLng>[start];
    final floorChanges = <String>[];
    final floorTransitions = <FloorTransition>[];
    
    // Find best vertical circulation on start floor
    final circulation = _findBestVerticalCirculation(
      start, startFloor, endFloor.id, preferElevator
    );
    
    if (circulation == null) {
      throw Exception('No vertical circulation found between floors');
    }
    
    // Path to circulation point on start floor
    final pathToCirculation = _findIndoorPath(start, circulation.position, startFloor);
    waypoints.addAll(pathToCirculation);
    waypoints.add(circulation.position);
    
    // Create floor transition
    final transition = FloorTransition(
      fromFloorId: startFloor.id,
      toFloorId: endFloor.id,
      buildingId: building.id,
      transitionPoint: circulation.position,
      transitionType: circulation.type,
      landmarkId: circulation.id,
      instructions: _generateFloorChangeInstruction(startFloor, endFloor, circulation),
    );
    floorTransitions.add(transition);
    floorChanges.add(transition.instructions);
    
    // Find corresponding circulation on end floor
    final endCirculation = _findCorrespondingCirculation(circulation, endFloor);
    if (endCirculation != null) {
      waypoints.add(endCirculation.position);
      
      // Path from circulation to end point on end floor
      final pathFromCirculation = _findIndoorPath(endCirculation.position, end, endFloor);
      waypoints.addAll(pathFromCirculation);
    }
    
    waypoints.add(end);
    
    final totalDistance = _calculateTotalDistance(waypoints);
    final instructions = _generateDetailedInstructions(waypoints, floorChanges, context);
    
    return NavigationRoute(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      start: start,
      end: end,
      waypoints: waypoints,
      totalDistance: totalDistance,
      instructions: instructions,
      floorChanges: floorChanges,
      floorTransitions: floorTransitions,
    );
  }

  /// Multi-building navigation
  static Future<NavigationRoute?> _calculateMultiBuildingRoute(
    LatLng start, LatLng end, NavigationContext context, bool preferElevator
  ) async {
    final startBuilding = context.startBuilding!;
    final endBuilding = context.endBuilding!;
    final startFloor = context.startFloor!;
    final endFloor = context.endFloor!;
    
    final waypoints = <LatLng>[start];
    final floorChanges = <String>[];
    final floorTransitions = <FloorTransition>[];
    
    // 1. Navigate to building exit from start floor
    final exitPoint = _findBuildingExit(start, startBuilding, startFloor);
    if (exitPoint != null) {
      final pathToExit = _findIndoorPath(start, exitPoint.position, startFloor);
      waypoints.addAll(pathToExit);
      waypoints.add(exitPoint.position);
      
      // Exit building transition
      if (startFloor.level != 0) {
        final groundFloor = startBuilding.floors.where((f) => f.level == 0).firstOrNull;
        if (groundFloor != null) {
          final circulation = _findBestVerticalCirculation(
            exitPoint.position, startFloor, groundFloor.id, preferElevator
          );
          if (circulation != null) {
            final transition = FloorTransition(
              fromFloorId: startFloor.id,
              toFloorId: groundFloor.id,
              buildingId: startBuilding.id,
              transitionPoint: circulation.position,
              transitionType: circulation.type,
              landmarkId: circulation.id,
              instructions: 'Take ${circulation.type} to ground floor to exit building',
            );
            floorTransitions.add(transition);
            floorChanges.add(transition.instructions);
          }
        }
      }
      
      floorChanges.add('Exit ${startBuilding.name}');
    }
    
    // 2. Outdoor navigation between buildings
    final outdoorPath = _findOutdoorPath(
      waypoints.last, 
      endBuilding.centerPosition, 
      context.roadSystem
    );
    waypoints.addAll(outdoorPath);
    
    // 3. Enter end building
    final entrancePoint = _findBuildingEntrance(waypoints.last, endBuilding);
    if (entrancePoint != null) {
      waypoints.add(entrancePoint.position);
      floorChanges.add('Enter ${endBuilding.name}');
      
      // Navigate to target floor if not ground floor
      if (endFloor.level != 0) {
        final groundFloor = endBuilding.floors.where((f) => f.level == 0).firstOrNull;
        if (groundFloor != null) {
          final circulation = _findBestVerticalCirculation(
            entrancePoint.position, groundFloor, endFloor.id, preferElevator
          );
          if (circulation != null) {
            final pathToCirculation = _findIndoorPath(
              entrancePoint.position, circulation.position, groundFloor
            );
            waypoints.addAll(pathToCirculation);
            
            final transition = FloorTransition(
              fromFloorId: groundFloor.id,
              toFloorId: endFloor.id,
              buildingId: endBuilding.id,
              transitionPoint: circulation.position,
              transitionType: circulation.type,
              landmarkId: circulation.id,
              instructions: _generateFloorChangeInstruction(groundFloor, endFloor, circulation),
            );
            floorTransitions.add(transition);
            floorChanges.add(transition.instructions);
            
            // Path from circulation to end point
            final endCirculation = _findCorrespondingCirculation(circulation, endFloor);
            if (endCirculation != null) {
              waypoints.add(endCirculation.position);
              final pathFromCirculation = _findIndoorPath(endCirculation.position, end, endFloor);
              waypoints.addAll(pathFromCirculation);
            }
          }
        }
      } else {
        // Same floor (ground floor)
        final pathToEnd = _findIndoorPath(entrancePoint.position, end, endFloor);
        waypoints.addAll(pathToEnd);
      }
    }
    
    waypoints.add(end);
    
    final totalDistance = _calculateTotalDistance(waypoints);
    final instructions = _generateDetailedInstructions(waypoints, floorChanges, context);
    
    return NavigationRoute(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      start: start,
      end: end,
      waypoints: waypoints,
      totalDistance: totalDistance,
      instructions: instructions,
      floorChanges: floorChanges,
      floorTransitions: floorTransitions,
    );
  }

  /// Indoor to outdoor navigation
  static Future<NavigationRoute?> _calculateIndoorToOutdoorRoute(
    LatLng start, LatLng end, NavigationContext context
  ) async {
    final building = context.startBuilding!;
    final floor = context.startFloor!;
    
    final waypoints = <LatLng>[start];
    final floorChanges = <String>[];
    final floorTransitions = <FloorTransition>[];
    
    // Find nearest exit
    final exitPoint = _findBuildingExit(start, building, floor);
    if (exitPoint != null) {
      final pathToExit = _findIndoorPath(start, exitPoint.position, floor);
      waypoints.addAll(pathToExit);
      waypoints.add(exitPoint.position);
      
      // Handle floor changes if not on ground floor
      if (floor.level != 0) {
        final groundFloor = building.floors.where((f) => f.level == 0).firstOrNull;
        if (groundFloor != null) {
          // Add floor transition logic
          floorChanges.add('Take stairs/elevator to ground floor');
        }
      }
      
      floorChanges.add('Exit building');
      
      // Outdoor path to destination
      final outdoorPath = _findOutdoorPath(exitPoint.position, end, context.roadSystem);
      waypoints.addAll(outdoorPath);
    }
    
    waypoints.add(end);
    
    final totalDistance = _calculateTotalDistance(waypoints);
    final instructions = _generateDetailedInstructions(waypoints, floorChanges, context);
    
    return NavigationRoute(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      start: start,
      end: end,
      waypoints: waypoints,
      totalDistance: totalDistance,
      instructions: instructions,
      floorChanges: floorChanges,
      floorTransitions: floorTransitions,
    );
  }

  /// Outdoor to indoor navigation
  static Future<NavigationRoute?> _calculateOutdoorToIndoorRoute(
    LatLng start, LatLng end, NavigationContext context
  ) async {
    final building = context.endBuilding!;
    final floor = context.endFloor!;
    
    final waypoints = <LatLng>[start];
    final floorChanges = <String>[];
    final floorTransitions = <FloorTransition>[];
    
    // Outdoor path to building
    final outdoorPath = _findOutdoorPath(start, building.centerPosition, context.roadSystem);
    waypoints.addAll(outdoorPath);
    
    // Find entrance
    final entrance = _findBuildingEntrance(waypoints.last, building);
    if (entrance != null) {
      waypoints.add(entrance.position);
      floorChanges.add('Enter ${building.name}');
      
      // Navigate to target floor
      if (floor.level != 0) {
        // Add floor change navigation
        floorChanges.add('Take stairs/elevator to ${floor.name}');
      }
      
      // Indoor path to destination
      final indoorPath = _findIndoorPath(entrance.position, end, floor);
      waypoints.addAll(indoorPath);
    }
    
    waypoints.add(end);
    
    final totalDistance = _calculateTotalDistance(waypoints);
    final instructions = _generateDetailedInstructions(waypoints, floorChanges, context);
    
    return NavigationRoute(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      start: start,
      end: end,
      waypoints: waypoints,
      totalDistance: totalDistance,
      instructions: instructions,
      floorChanges: floorChanges,
      floorTransitions: floorTransitions,
    );
  }

  /// Pure outdoor navigation
  static Future<NavigationRoute?> _calculateOutdoorRoute(
    LatLng start, LatLng end, NavigationContext context
  ) async {
    final waypoints = <LatLng>[start];
    
    final path = _findOutdoorPath(start, end, context.roadSystem);
    waypoints.addAll(path);
    waypoints.add(end);
    
    final totalDistance = _calculateTotalDistance(waypoints);
    final instructions = _generateDetailedInstructions(waypoints, [], context);
    
    return NavigationRoute(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      start: start,
      end: end,
      waypoints: waypoints,
      totalDistance: totalDistance,
      instructions: instructions,
    );
  }

  /// Find the best vertical circulation (elevator/stairs) between floors
  static Landmark? _findBestVerticalCirculation(
    LatLng userPosition, Floor startFloor, String targetFloorId, bool preferElevator
  ) {
    final circulation = startFloor.landmarks.where(
      (l) => (l.type == 'elevator' || l.type == 'stairs') && 
             l.connectedFloors.contains(targetFloorId)
    ).toList();
    
    if (circulation.isEmpty) return null;
    
    // Sort by preference and distance
    circulation.sort((a, b) {
      // Prefer elevators if specified
      if (preferElevator) {
        if (a.type == 'elevator' && b.type != 'elevator') return -1;
        if (b.type == 'elevator' && a.type != 'elevator') return 1;
      }
      
      // Then by distance
      final distA = calculateDistance(userPosition, a.position);
      final distB = calculateDistance(userPosition, b.position);
      return distA.compareTo(distB);
    });
    
    return circulation.first;
  }

  /// Find corresponding circulation on target floor
  static Landmark? _findCorrespondingCirculation(Landmark circulation, Floor targetFloor) {
    // Look for circulation with same name or similar position
    return targetFloor.landmarks.where(
      (l) => l.type == circulation.type && 
             (l.name.contains(circulation.name.split(' ').first) ||
              calculateDistance(l.position, circulation.position) < 5.0)
    ).firstOrNull;
  }

  /// Find building exit nearest to user position
  static Landmark? _findBuildingExit(LatLng userPosition, Building building, Floor floor) {
    final exits = floor.landmarks.where((l) => l.type == 'entrance').toList();
    
    if (exits.isEmpty) return null;
    
    exits.sort((a, b) {
      final distA = calculateDistance(userPosition, a.position);
      final distB = calculateDistance(userPosition, b.position);
      return distA.compareTo(distB);
    });
    
    return exits.first;
  }

  /// Find building entrance nearest to approach point
  static Landmark? _findBuildingEntrance(LatLng approachPoint, Building building) {
    // Look for entrances on ground floor
    final groundFloor = building.floors.where((f) => f.level == 0).firstOrNull;
    if (groundFloor == null) return null;
    
    final entrances = groundFloor.landmarks.where((l) => l.type == 'entrance').toList();
    
    if (entrances.isEmpty) return null;
    
    entrances.sort((a, b) {
      final distA = calculateDistance(approachPoint, a.position);
      final distB = calculateDistance(approachPoint, b.position);
      return distA.compareTo(distB);
    });
    
    return entrances.first;
  }

  /// Find indoor path using simplified pathfinding
  static List<LatLng> _findIndoorPath(LatLng start, LatLng end, Floor floor) {
    // Simplified: direct path if no obstacles, otherwise basic waypoint routing
    // In production, this would use A* with floor layout consideration
    return _findDirectPath(start, end, floor.roads);
  }

  /// Find outdoor path using road network
  static List<LatLng> _findOutdoorPath(LatLng start, LatLng end, RoadSystem roadSystem) {
    // Simplified: find nearest roads and route through them
    // In production, this would use A* on the road graph
    return _findDirectPath(start, end, roadSystem.outdoorRoads);
  }

  /// Simplified pathfinding - direct path with basic road snapping
  static List<LatLng> _findDirectPath(LatLng start, LatLng end, List<Road> roads) {
    final path = <LatLng>[];
    
    if (roads.isNotEmpty) {
      // Find nearest road points
      final startRoad = _findNearestRoadPoint(start, roads);
      final endRoad = _findNearestRoadPoint(end, roads);
      
      if (startRoad != null) path.add(startRoad);
      if (endRoad != null && endRoad != startRoad) path.add(endRoad);
    }
    
    return path;
  }

  /// Find nearest point on road network
  static LatLng? _findNearestRoadPoint(LatLng point, List<Road> roads) {
    LatLng? nearest;
    double minDistance = double.infinity;
    
    for (final road in roads) {
      for (final roadPoint in road.points) {
        final distance = calculateDistance(point, roadPoint);
        if (distance < minDistance) {
          minDistance = distance;
          nearest = roadPoint;
        }
      }
    }
    
    return nearest;
  }

  /// Generate floor change instruction
  static String _generateFloorChangeInstruction(Floor fromFloor, Floor toFloor, Landmark circulation) {
    final direction = toFloor.level > fromFloor.level ? 'up' : 'down';
    final floorDiff = (toFloor.level - fromFloor.level).abs();
    
    if (circulation.type == 'elevator') {
      return 'Take elevator ${circulation.name} $direction to ${toFloor.name} (${floorDiff} floor${floorDiff != 1 ? 's' : ''})';
    } else {
      return 'Take stairs ${circulation.name} $direction to ${toFloor.name} (${floorDiff} floor${floorDiff != 1 ? 's' : ''})';
    }
  }

  /// Generate detailed navigation instructions
  static String _generateDetailedInstructions(
    List<LatLng> waypoints, 
    List<String> floorChanges, 
    NavigationContext context
  ) {
    final instructions = <String>[];
    
    // Add context
    if (context.type == NavigationType.sameFloor) {
      if (context.startFloor != null) {
        instructions.add('Navigate within ${context.startFloor!.name}');
      } else {
        instructions.add('Navigate outdoors');
      }
    } else {
      instructions.add('Multi-floor navigation route');
    }
    
    // Add distance and time
    final distance = _calculateTotalDistance(waypoints);
    final time = calculateTravelTime(distance);
    instructions.add('Total distance: ${distance.toStringAsFixed(0)}m');
    instructions.add('Estimated time: ${_formatDuration(time)}');
    
    // Add floor changes
    if (floorChanges.isNotEmpty) {
      instructions.add('Floor changes required:');
      instructions.addAll(floorChanges.map((change) => '• $change'));
    }
    
    // Add basic turn-by-turn
    if (waypoints.length > 2) {
      instructions.add('Follow waypoints and signs along the route');
    }
    
    return instructions.join('\n');
  }

  /// Calculate distance between two points using Haversine formula
  static double calculateDistance(LatLng point1, LatLng point2) {
    final lat1Rad = point1.latitude * (pi / 180);
    final lat2Rad = point2.latitude * (pi / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);

    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return _earthRadius * c;
  }

  /// Calculate estimated travel time including floor changes
  static Duration calculateTravelTime(double distanceMeters, [int floorChanges = 0]) {
    final walkingTime = distanceMeters / _walkingSpeed;
    final floorChangeTime = floorChanges * _floorChangeTime;
    final totalSeconds = walkingTime + floorChangeTime;
    return Duration(seconds: totalSeconds.round());
  }

  /// Calculate total distance along waypoints
  static double _calculateTotalDistance(List<LatLng> waypoints) {
    double total = 0.0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      total += calculateDistance(waypoints[i], waypoints[i + 1]);
    }
    return total;
  }

  /// Format duration for display
  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Find the nearest landmark of a specific type with floor awareness
  static Landmark? findNearestLandmark({
    required LatLng userLocation,
    required String landmarkType,
    required RoadSystem roadSystem,
    String? currentFloorId,
    String? currentBuildingId,
    bool searchAllFloors = false,
  }) {
    final allLandmarks = <Landmark>[];
    
    if (currentFloorId != null && !searchAllFloors) {
      // Search within current floor first
      final building = roadSystem.buildings.where((b) => b.id == currentBuildingId).firstOrNull;
      if (building != null) {
        final floor = building.floors.where((f) => f.id == currentFloorId).firstOrNull;
        if (floor != null) {
          allLandmarks.addAll(floor.landmarks.where((l) => l.type == landmarkType));
        }
      }
    } else {
      // Search all landmarks
      allLandmarks.addAll(
        roadSystem.outdoorLandmarks.where((l) => l.type == landmarkType)
      );
      
      for (final building in roadSystem.buildings) {
        for (final floor in building.floors) {
          allLandmarks.addAll(
            floor.landmarks.where((l) => l.type == landmarkType)
          );
        }
      }
    }
    
    if (allLandmarks.isEmpty) return null;
    
    Landmark? nearest;
    double minDistance = double.infinity;
    
    for (final landmark in allLandmarks) {
      double distance = calculateDistance(userLocation, landmark.position);
      
      // Prefer landmarks on the same floor
      if (currentFloorId != null && landmark.floorId == currentFloorId) {
        distance *= 0.3; // Strong preference for same floor
      } else if (currentBuildingId != null && landmark.buildingId == currentBuildingId) {
        distance *= 0.7; // Preference for same building
      }
      
      if (distance < minDistance) {
        minDistance = distance;
        nearest = landmark;
      }
    }
    
    return nearest;
  }

  /// Get turn-by-turn directions with floor context
  static List<NavigationInstruction> getTurnByTurnDirections(
    NavigationRoute route,
  ) {
    final instructions = <NavigationInstruction>[];
    
    for (int i = 0; i < route.waypoints.length - 1; i++) {
      final current = route.waypoints[i];
      final next = route.waypoints[i + 1];
      final distance = calculateDistance(current, next);
      
      instructions.add(NavigationInstruction(
        instruction: _getDirectionInstruction(current, next, i, route.floorTransitions),
        distance: distance,
        position: current,
      ));
    }
    
    instructions.add(NavigationInstruction(
      instruction: 'You have arrived at your destination',
      distance: 0,
      position: route.end,
    ));
    
    return instructions;
  }

  static String _getDirectionInstruction(
    LatLng from, LatLng to, int step, List<FloorTransition> transitions
  ) {
    final distance = calculateDistance(from, to);
    final direction = _getBearing(from, to);
    final cardinalDirection = _getCardinalDirection(direction);
    
    // Check if this step involves a floor transition
    final transition = transitions.where((t) => 
      calculateDistance(t.transitionPoint, from) < 5.0
    ).firstOrNull;
    
    if (transition != null) {
      return transition.instructions;
    }
    
    if (step == 0) {
      return 'Head $cardinalDirection for ${distance.toStringAsFixed(0)}m';
    } else {
      return 'Continue $cardinalDirection for ${distance.toStringAsFixed(0)}m';
    }
  }

  static double _getBearing(LatLng from, LatLng to) {
    final lat1Rad = from.latitude * (pi / 180);
    final lat2Rad = to.latitude * (pi / 180);
    final deltaLngRad = (to.longitude - from.longitude) * (pi / 180);
    
    final y = sin(deltaLngRad) * cos(lat2Rad);
    final x = cos(lat1Rad) * sin(lat2Rad) - 
              sin(lat1Rad) * cos(lat2Rad) * cos(deltaLngRad);
    
    final bearing = atan2(y, x) * (180 / pi);
    return (bearing + 360) % 360;
  }

  static String _getCardinalDirection(double bearing) {
    const directions = [
      'north', 'northeast', 'east', 'southeast',
      'south', 'southwest', 'west', 'northwest'
    ];
    
    final index = ((bearing + 22.5) / 45).floor() % 8;
    return directions[index];
  }

  /// Check if user is off route with floor awareness
  static bool isOffRoute(
    LatLng userLocation,
    NavigationRoute route, {
    double toleranceMeters = 10.0,
    String? currentFloorId,
  }) {
    // Find the closest point on the route
    double minDistance = double.infinity;
    
    for (int i = 0; i < route.waypoints.length - 1; i++) {
      final distance = _distanceToLineSegment(
        userLocation,
        route.waypoints[i],
        route.waypoints[i + 1],
      );
      
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    
    return minDistance > toleranceMeters;
  }

  static double _distanceToLineSegment(LatLng point, LatLng lineStart, LatLng lineEnd) {
    final A = point.latitude - lineStart.latitude;
    final B = point.longitude - lineStart.longitude;
    final C = lineEnd.latitude - lineStart.latitude;
    final D = lineEnd.longitude - lineStart.longitude;
    
    final dot = A * C + B * D;
    final lenSq = C * C + D * D;
    
    if (lenSq == 0) {
      return calculateDistance(point, lineStart);
    }
    
    final param = dot / lenSq;
    
    LatLng closestPoint;
    if (param < 0) {
      closestPoint = lineStart;
    } else if (param > 1) {
      closestPoint = lineEnd;
    } else {
      closestPoint = LatLng(
        lineStart.latitude + param * C,
        lineStart.longitude + param * D,
      );
    }
    
    return calculateDistance(point, closestPoint);
  }
}

/// Navigation context for route calculation
class NavigationContext {
  final NavigationType type;
  final RoadSystem roadSystem;
  final Building? startBuilding;
  final Building? endBuilding;
  final Floor? startFloor;
  final Floor? endFloor;

  NavigationContext({
    required this.type,
    required this.roadSystem,
    this.startBuilding,
    this.endBuilding,
    this.startFloor,
    this.endFloor,
  });
}

/// Types of navigation scenarios
enum NavigationType {
  sameFloor,
  sameBuilding,
  differentBuildings,
  indoorToOutdoor,
  outdoorToIndoor,
  outdoorOnly,
}

/// Enhanced navigation instruction
class NavigationInstruction {
  final String instruction;
  final double distance;
  final LatLng position;
  final String? floorId;
  final String? buildingId;

  NavigationInstruction({
    required this.instruction,
    required this.distance,
    required this.position,
    this.floorId,
    this.buildingId,
  });
}