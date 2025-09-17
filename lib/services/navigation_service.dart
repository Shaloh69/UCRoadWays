import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';

class NavigationService {
  static const double _walkingSpeed = 1.4; // m/s
  static const double _earthRadius = 6371000; // Earth's radius in meters

  /// Calculate the shortest route between two points in a road system
  static Future<NavigationRoute?> calculateRoute({
    required LatLng start,
    required LatLng end,
    required RoadSystem roadSystem,
    String? startFloorId,
    String? endFloorId,
  }) async {
    try {
      // Simplified pathfinding algorithm
      // In a production app, you'd use A* or Dijkstra's algorithm
      
      final waypoints = <LatLng>[];
      final floorChanges = <String>[];
      
      // If both points are on the same floor/outdoor area
      if (startFloorId == endFloorId) {
        waypoints.addAll([start, end]);
      } else {
        // Multi-floor navigation
        final route = await _calculateMultiFloorRoute(
          start, end, roadSystem, startFloorId, endFloorId
        );
        if (route != null) {
          waypoints.addAll(route.waypoints);
          floorChanges.addAll(route.floorChanges);
        } else {
          // Fallback to direct route
          waypoints.addAll([start, end]);
        }
      }
      
      final totalDistance = _calculateTotalDistance(waypoints);
      final instructions = _generateInstructions(waypoints, floorChanges);
      
      return NavigationRoute(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        start: start,
        end: end,
        waypoints: waypoints,
        totalDistance: totalDistance,
        instructions: instructions,
        floorChanges: floorChanges,
      );
    } catch (e) {
      print('Error calculating route: $e');
      return null;
    }
  }

  /// Find the nearest landmark of a specific type
  static Landmark? findNearestLandmark({
    required LatLng userLocation,
    required String landmarkType,
    required RoadSystem roadSystem,
    String? currentFloorId,
  }) {
    final allLandmarks = <Landmark>[];
    
    // Add outdoor landmarks
    allLandmarks.addAll(
      roadSystem.outdoorLandmarks.where((l) => l.type == landmarkType)
    );
    
    // Add indoor landmarks
    for (final building in roadSystem.buildings) {
      for (final floor in building.floors) {
        allLandmarks.addAll(
          floor.landmarks.where((l) => l.type == landmarkType)
        );
      }
    }
    
    if (allLandmarks.isEmpty) return null;
    
    Landmark? nearest;
    double minDistance = double.infinity;
    
    for (final landmark in allLandmarks) {
      double distance = calculateDistance(userLocation, landmark.position);
      
      // Prefer landmarks on the same floor
      if (currentFloorId != null && landmark.floorId == currentFloorId) {
        distance *= 0.5; // Preference factor
      }
      
      if (distance < minDistance) {
        minDistance = distance;
        nearest = landmark;
      }
    }
    
    return nearest;
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

  /// Calculate estimated travel time
  static Duration calculateTravelTime(double distanceMeters) {
    final timeSeconds = distanceMeters / _walkingSpeed;
    return Duration(seconds: timeSeconds.round());
  }

  /// Get turn-by-turn directions
  static List<NavigationInstruction> getTurnByTurnDirections(
    NavigationRoute route,
  ) {
    final instructions = <NavigationInstruction>[];
    
    for (int i = 0; i < route.waypoints.length - 1; i++) {
      final current = route.waypoints[i];
      final next = route.waypoints[i + 1];
      final distance = calculateDistance(current, next);
      
      instructions.add(NavigationInstruction(
        instruction: _getDirectionInstruction(current, next, i),
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

  /// Check if user is off route
  static bool isOffRoute(
    LatLng userLocation,
    NavigationRoute route, {
    double toleranceMeters = 10.0,
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

  static Future<NavigationRoute?> _calculateMultiFloorRoute(
    LatLng start,
    LatLng end,
    RoadSystem roadSystem,
    String? startFloorId,
    String? endFloorId,
  ) async {
    // Simplified multi-floor routing
    final waypoints = <LatLng>[start];
    final floorChanges = <String>[];
    
    // Find nearest vertical circulation (elevator/stairs) on start floor
    final startBuilding = _findBuildingForFloor(roadSystem, startFloorId);
    final endBuilding = _findBuildingForFloor(roadSystem, endFloorId);
    
    if (startBuilding != null && endBuilding != null) {
      // Same building - find elevator/stairs
      if (startBuilding.id == endBuilding.id) {
        final circulation = _findNearestVerticalCirculation(
          start, startBuilding, startFloorId!
        );
        
        if (circulation != null) {
          waypoints.add(circulation.position);
          floorChanges.add('Take ${circulation.type} to floor $endFloorId');
          
          // Add path from circulation to destination on end floor
          final endCirculation = _findCorrespondingCirculation(
            circulation, endBuilding, endFloorId!
          );
          
          if (endCirculation != null) {
            waypoints.add(endCirculation.position);
          }
        }
      } else {
        // Different buildings - route through exits and entrances
        // This would be more complex in a real implementation
        floorChanges.add('Exit building and walk to destination building');
      }
    }
    
    waypoints.add(end);
    
    return NavigationRoute(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      start: start,
      end: end,
      waypoints: waypoints,
      totalDistance: _calculateTotalDistance(waypoints),
      instructions: _generateInstructions(waypoints, floorChanges),
      floorChanges: floorChanges,
    );
  }

  static Building? _findBuildingForFloor(RoadSystem roadSystem, String? floorId) {
    if (floorId == null) return null;
    
    for (final building in roadSystem.buildings) {
      for (final floor in building.floors) {
        if (floor.id == floorId) {
          return building;
        }
      }
    }
    return null;
  }

  static Landmark? _findNearestVerticalCirculation(
    LatLng userPosition,
    Building building,
    String floorId,
  ) {
    // Find the floor first
    Floor? targetFloor;
    for (final floor in building.floors) {
      if (floor.id == floorId) {
        targetFloor = floor;
        break;
      }
    }
    
    if (targetFloor == null) return null;
    
    final circulation = targetFloor.landmarks.where(
      (l) => l.type == 'elevator' || l.type == 'stairs'
    );
    
    if (circulation.isEmpty) return null;
    
    Landmark? nearest;
    double minDistance = double.infinity;
    
    for (final landmark in circulation) {
      final distance = calculateDistance(userPosition, landmark.position);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = landmark;
      }
    }
    
    return nearest;
  }

  static Landmark? _findCorrespondingCirculation(
    Landmark circulation,
    Building building,
    String floorId,
  ) {
    // Find the target floor
    Floor? targetFloor;
    for (final floor in building.floors) {
      if (floor.id == floorId) {
        targetFloor = floor;
        break;
      }
    }
    
    if (targetFloor == null) return null;
    
    // Find circulation of the same type with similar name or position
    final sameTypeCirculation = targetFloor.landmarks.where(
      (l) => l.type == circulation.type
    );
    
    if (sameTypeCirculation.isEmpty) return null;
    
    // Try to find one with similar name first
    final firstWord = circulation.name.split(' ').first;
    for (final landmark in sameTypeCirculation) {
      if (landmark.name.contains(firstWord)) {
        return landmark;
      }
    }
    
    // Fall back to first circulation of same type
    return sameTypeCirculation.first;
  }

  static double _calculateTotalDistance(List<LatLng> waypoints) {
    double total = 0.0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      total += calculateDistance(waypoints[i], waypoints[i + 1]);
    }
    return total;
  }

  static String _generateInstructions(
    List<LatLng> waypoints,
    List<String> floorChanges,
  ) {
    final instructions = <String>[];
    
    if (waypoints.length >= 2) {
      final distance = calculateDistance(waypoints.first, waypoints.last);
      instructions.add(
        'Head towards your destination (${distance.toStringAsFixed(0)}m total)'
      );
    }
    
    if (floorChanges.isNotEmpty) {
      instructions.addAll(floorChanges);
    }
    
    instructions.add('Continue straight until you reach your destination');
    
    return instructions.join('. ');
  }

  static String _getDirectionInstruction(LatLng from, LatLng to, int step) {
    final distance = calculateDistance(from, to);
    final direction = _getBearing(from, to);
    final cardinalDirection = _getCardinalDirection(direction);
    
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

  static double _distanceToLineSegment(LatLng point, LatLng lineStart, LatLng lineEnd) {
    // Simplified distance calculation to line segment
    // This is a basic implementation - a more accurate one would use
    // great circle calculations
    
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