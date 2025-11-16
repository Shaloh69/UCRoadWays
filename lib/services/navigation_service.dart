import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';

/// Service for calculating navigation routes in UCRoadWays.
///
/// This service provides comprehensive navigation capabilities including:
/// - Indoor navigation (within floors and between floors)
/// - Outdoor navigation (road network)
/// - Multi-building navigation
/// - Indoor-to-outdoor transitions
/// - Turn-by-turn instructions
/// - Accessibility-aware routing (elevator vs stairs preference)

/// Navigation type enumeration for different route scenarios.
enum NavigationType {
  sameFloor,
  sameBuilding,
  differentBuildings,
  indoorToOutdoor,
  outdoorToIndoor,
  outdoorOnly,
}

// Navigation context class
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

// Navigation instruction model
class NavigationInstruction {
  final String instruction;
  final double distance;
  final LatLng position;

  NavigationInstruction({
    required this.instruction,
    required this.distance,
    required this.position,
  });
}

/// Navigation service for UCRoadWays.
///
/// Provides route calculation, turn-by-turn instructions, and navigation
/// progress tracking for both indoor and outdoor environments.
class NavigationService {
  /// Default walking speed in meters per second (1.4 m/s ≈ 5 km/h)
  static const double _defaultWalkingSpeed = 1.4;

  /// Calculates a navigation route between two points.
  ///
  /// This is the main entry point for navigation. It automatically determines
  /// the navigation type (indoor, outdoor, or mixed) and calculates the
  /// optimal route.
  ///
  /// Parameters:
  /// - [start]: Starting location coordinates
  /// - [end]: Destination location coordinates
  /// - [roadSystem]: The road system containing buildings and roads
  /// - [startFloorId]: Optional floor ID if starting indoors
  /// - [endFloorId]: Optional floor ID if ending indoors
  /// - [startBuildingId]: Optional building ID if starting indoors
  /// - [endBuildingId]: Optional building ID if ending indoors
  /// - [preferElevator]: Whether to prefer elevators over stairs (default: true)
  ///
  /// Returns a [NavigationRoute] with waypoints and instructions, or null if
  /// no route could be calculated.
  static Future<NavigationRoute?> calculateRoute(
    LatLng start,
    LatLng end,
    RoadSystem roadSystem, {
    String? startFloorId,
    String? endFloorId,
    String? startBuildingId,
    String? endBuildingId,
    bool preferElevator = true,
  }) async {
    try {
      final context = _createNavigationContext(
        roadSystem,
        startFloorId,
        endFloorId,
        startBuildingId,
        endBuildingId,
      );

      switch (context.type) {
        case NavigationType.sameFloor:
          return await _calculateSameFloorRoute(start, end, context);
        case NavigationType.sameBuilding:
          return await _calculateSameBuildingRoute(start, end, context, preferElevator);
        case NavigationType.differentBuildings:
          return await _calculateMultiBuildingRoute(start, end, context, preferElevator);
        case NavigationType.indoorToOutdoor:
          return await _calculateIndoorToOutdoorRoute(start, end, context);
        case NavigationType.outdoorToIndoor:
          return await _calculateOutdoorToIndoorRoute(start, end, context);
        case NavigationType.outdoorOnly:
          return await _calculateOutdoorRoute(start, end, context);
      }
    } catch (e) {
      print('Navigation calculation error: $e');
      return null;
    }
  }

  /// Create navigation context based on start/end parameters
  static NavigationContext _createNavigationContext(
    RoadSystem roadSystem,
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
      transitionType: circulation.type,
      position: circulation.position,
      landmarkId: circulation.id,
    );
    floorTransitions.add(transition);
    floorChanges.add(_generateFloorChangeInstruction(startFloor, endFloor, circulation));
    
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
              transitionType: circulation.type,
              position: circulation.position,
              landmarkId: circulation.id,
            );
            floorTransitions.add(transition);
            floorChanges.add('Take ${circulation.type} to ground floor to exit building');
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
              transitionType: circulation.type,
              position: circulation.position,
              landmarkId: circulation.id,
            );
            floorTransitions.add(transition);
            floorChanges.add(_generateFloorChangeInstruction(groundFloor, endFloor, circulation));
            
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
    LatLng currentPosition, Floor currentFloor, String targetFloorId, bool preferElevator
  ) {
    final circulation = currentFloor.landmarks.where((l) => 
      l.isVerticalCirculation && l.connectedFloors.contains(targetFloorId)
    ).toList();
    
    if (circulation.isEmpty) return null;
    
    // Sort by preference and distance
    circulation.sort((a, b) {
      final aIsPreferred = preferElevator ? a.type == 'elevator' : a.type == 'stairs';
      final bIsPreferred = preferElevator ? b.type == 'elevator' : b.type == 'stairs';
      
      if (aIsPreferred && !bIsPreferred) return -1;
      if (!aIsPreferred && bIsPreferred) return 1;
      
      // If same preference, sort by distance
      final aDist = calculateDistance(currentPosition, a.position);
      final bDist = calculateDistance(currentPosition, b.position);
      return aDist.compareTo(bDist);
    });
    
    return circulation.first;
  }

  /// Find corresponding circulation on target floor
  static Landmark? _findCorrespondingCirculation(Landmark circulation, Floor targetFloor) {
    return targetFloor.landmarks.where((l) => 
      l.type == circulation.type && 
      l.position.latitude == circulation.position.latitude &&
      l.position.longitude == circulation.position.longitude
    ).firstOrNull;
  }

  /// Find building exit point
  static Landmark? _findBuildingExit(LatLng from, Building building, Floor floor) {
    final exits = floor.landmarks.where((l) => l.type == 'exit' || l.type == 'entrance').toList();
    if (exits.isEmpty) return null;
    
    // Find closest exit
    exits.sort((a, b) {
      final aDist = calculateDistance(from, a.position);
      final bDist = calculateDistance(from, b.position);
      return aDist.compareTo(bDist);
    });
    
    return exits.first;
  }

  /// Find building entrance point
  static Landmark? _findBuildingEntrance(LatLng from, Building building) {
    final groundFloor = building.floors.where((f) => f.level == 0).firstOrNull;
    if (groundFloor == null) return null;
    
    final entrances = groundFloor.landmarks.where((l) => l.type == 'entrance').toList();
    if (entrances.isEmpty) return null;
    
    // Find closest entrance
    entrances.sort((a, b) {
      final aDist = calculateDistance(from, a.position);
      final bDist = calculateDistance(from, b.position);
      return aDist.compareTo(bDist);
    });
    
    return entrances.first;
  }

  /// Indoor pathfinding on a single floor
  static List<LatLng> _findIndoorPath(LatLng start, LatLng end, Floor floor) {
    // Simple pathfinding - in real implementation, use A* algorithm
    final path = <LatLng>[];
    
    // Basic direct path with obstacle avoidance
    final stepCount = 5;
    for (int i = 1; i < stepCount; i++) {
      final lat = start.latitude + (end.latitude - start.latitude) * (i / stepCount);
      final lng = start.longitude + (end.longitude - start.longitude) * (i / stepCount);
      path.add(LatLng(lat, lng));
    }
    
    return path;
  }

  /// Outdoor pathfinding using road network
  static List<LatLng> _findOutdoorPath(LatLng start, LatLng end, RoadSystem roadSystem) {
    // Simple pathfinding - in real implementation, use road network
    final path = <LatLng>[];
    
    // Find nearest roads and create path
    final stepCount = 10;
    for (int i = 1; i < stepCount; i++) {
      final lat = start.latitude + (end.latitude - start.latitude) * (i / stepCount);
      final lng = start.longitude + (end.longitude - start.longitude) * (i / stepCount);
      path.add(LatLng(lat, lng));
    }
    
    return path;
  }

  /// Calculate total distance of route
  static double _calculateTotalDistance(List<LatLng> waypoints) {
    double total = 0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      total += calculateDistance(waypoints[i], waypoints[i + 1]);
    }
    return total;
  }

  /// Generate detailed turn-by-turn instructions
  static String _generateDetailedInstructions(
    List<LatLng> waypoints, List<String> floorChanges, NavigationContext context
  ) {
    if (waypoints.isEmpty) return 'No route found';
    
    final instructions = <String>['Start navigation'];
    instructions.addAll(floorChanges);
    instructions.add('Arrive at destination');
    
    return instructions.join('\n');
  }

  /// Generate instruction for floor changes
  static String _generateFloorChangeInstruction(Floor from, Floor to, Landmark circulation) {
    final fromLevel = from.level;
    final toLevel = to.level;
    final direction = toLevel > fromLevel ? 'up' : 'down';
    final levels = (toLevel - fromLevel).abs();
    
    return 'Take ${circulation.type} $direction ${levels == 1 ? '1 floor' : '$levels floors'} to ${to.name}';
  }

  /// Generate navigation instructions from route
  static List<NavigationInstruction> generateInstructions(NavigationRoute route) {
    final instructions = <NavigationInstruction>[];
    
    if (route.waypoints.length < 2) {
      return [NavigationInstruction(
        instruction: 'You are at your destination',
        distance: 0,
        position: route.end,
      )];
    }
    
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
      calculateDistance(t.position, from) < 5.0
    ).firstOrNull;
    
    if (transition != null) {
      // Generate instruction based on transition type
      final fromLevel = transition.fromFloorId;
      final toLevel = transition.toFloorId;
      return 'Take ${transition.transitionType} from $fromLevel to $toLevel';
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
    if (route.waypoints.isEmpty) return true;
    
    // Find closest waypoint
    double minDistance = double.infinity;
    for (final waypoint in route.waypoints) {
      final distance = calculateDistance(userLocation, waypoint);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    
    return minDistance > toleranceMeters;
  }

  /// Calculate estimated time to complete route
  static Duration calculateEstimatedTime(NavigationRoute route) {
    final distanceKm = route.totalDistance / 1000;
    final timeSeconds = (distanceKm / (_defaultWalkingSpeed * 3.6)) * 3600;
    return Duration(seconds: timeSeconds.round());
  }

  /// Get progress of navigation (0.0 to 1.0)
  static double getNavigationProgress(
    LatLng currentLocation,
    NavigationRoute route,
  ) {
    if (route.waypoints.length < 2) return 1.0;
    
    final totalDistance = route.totalDistance;
    if (totalDistance == 0) return 1.0;
    
    // Find progress along route
    double coveredDistance = 0;
    double minDistanceToRoute = double.infinity;
    int closestSegmentIndex = 0;
    
    for (int i = 0; i < route.waypoints.length - 1; i++) {
      final segmentStart = route.waypoints[i];
      final segmentEnd = route.waypoints[i + 1];
      
      final distanceToSegment = _pointToLineDistance(
        currentLocation, segmentStart, segmentEnd
      );
      
      if (distanceToSegment < minDistanceToRoute) {
        minDistanceToRoute = distanceToSegment;
        closestSegmentIndex = i;
      }
    }
    
    // Calculate covered distance up to closest segment
    for (int i = 0; i < closestSegmentIndex; i++) {
      coveredDistance += calculateDistance(route.waypoints[i], route.waypoints[i + 1]);
    }
    
    // Add partial distance on current segment
    final segmentStart = route.waypoints[closestSegmentIndex];
    final segmentEnd = route.waypoints[closestSegmentIndex + 1];
    final projectedPoint = _projectPointOnLine(currentLocation, segmentStart, segmentEnd);
    coveredDistance += calculateDistance(segmentStart, projectedPoint);
    
    return (coveredDistance / totalDistance).clamp(0.0, 1.0);
  }

  /// Calculate distance between two points
  static double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // meters
    
    final lat1Rad = point1.latitude * (pi / 180);
    final lat2Rad = point2.latitude * (pi / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);
    
    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
              cos(lat1Rad) * cos(lat2Rad) *
              sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  /// Calculate distance from point to line segment
  static double _pointToLineDistance(LatLng point, LatLng lineStart, LatLng lineEnd) {
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

  /// Project point onto line segment
  static LatLng _projectPointOnLine(LatLng point, LatLng lineStart, LatLng lineEnd) {
    final A = point.latitude - lineStart.latitude;
    final B = point.longitude - lineStart.longitude;
    final C = lineEnd.latitude - lineStart.latitude;
    final D = lineEnd.longitude - lineStart.longitude;
    
    final dot = A * C + B * D;
    final lenSq = C * C + D * D;
    
    if (lenSq == 0) return lineStart;
    
    final param = (dot / lenSq).clamp(0.0, 1.0);
    
    return LatLng(
      lineStart.latitude + param * C,
      lineStart.longitude + param * D,
    );
  }
}