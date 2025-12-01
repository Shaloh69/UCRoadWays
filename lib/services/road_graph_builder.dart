import 'dart:collection';
import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';

/// Node in the navigation graph
class GraphNode {
  final String id;
  final LatLng position;
  final String? floorId;
  final String? buildingId;
  final String type; // 'intersection', 'landmark', 'road_point'
  final Map<String, GraphEdge> edges; // nodeId -> edge
  final Map<String, dynamic> metadata;

  GraphNode({
    required this.id,
    required this.position,
    this.floorId,
    this.buildingId,
    required this.type,
    Map<String, GraphEdge>? edges,
    Map<String, dynamic>? metadata,
  })  : edges = edges ?? {},
        metadata = metadata ?? {};

  @override
  String toString() => 'GraphNode($id, $type, ${position.latitude}, ${position.longitude})';
}

/// Edge connecting two nodes in the graph
class GraphEdge {
  final String fromNodeId;
  final String toNodeId;
  final double weight; // Distance in meters
  final String? roadId;
  final String? roadType;
  final bool isOneWay;
  final bool isVerticalTransition; // For stairs/elevators
  final String? transitionType; // 'elevator', 'stairs', 'escalator'
  final List<LatLng> waypoints; // Intermediate points along the edge
  final Map<String, dynamic> metadata;

  GraphEdge({
    required this.fromNodeId,
    required this.toNodeId,
    required this.weight,
    this.roadId,
    this.roadType,
    this.isOneWay = false,
    this.isVerticalTransition = false,
    this.transitionType,
    List<LatLng>? waypoints,
    Map<String, dynamic>? metadata,
  })  : waypoints = waypoints ?? [],
        metadata = metadata ?? {};

  @override
  String toString() => 'GraphEdge($fromNodeId -> $toNodeId, ${weight.toStringAsFixed(1)}m)';
}

/// Navigation graph built from road system
class RoadGraph {
  final Map<String, GraphNode> nodes;
  final String roadSystemId;
  final DateTime buildTime;

  RoadGraph({
    required this.nodes,
    required this.roadSystemId,
    DateTime? buildTime,
  }) : buildTime = buildTime ?? DateTime.now();

  /// Get all neighbors of a node
  List<GraphNode> getNeighbors(String nodeId) {
    final node = nodes[nodeId];
    if (node == null) return [];

    return node.edges.values
        .map((edge) => nodes[edge.toNodeId])
        .whereType<GraphNode>()
        .toList();
  }

  /// Get edge between two nodes
  GraphEdge? getEdge(String fromId, String toId) {
    return nodes[fromId]?.edges[toId];
  }

  /// Find nearest node to a position
  GraphNode? findNearestNode(LatLng position, {String? floorId, String? buildingId}) {
    final Distance distance = Distance();
    GraphNode? nearest;
    double minDistance = double.infinity;

    for (var node in nodes.values) {
      // Filter by floor/building if specified
      if (floorId != null && node.floorId != floorId) continue;
      if (buildingId != null && node.buildingId != buildingId) continue;

      final dist = distance.as(LengthUnit.Meter, position, node.position);
      if (dist < minDistance) {
        minDistance = dist;
        nearest = node;
      }
    }

    return nearest;
  }

  /// Get all nodes on a specific floor
  List<GraphNode> getFloorNodes(String floorId) {
    return nodes.values.where((n) => n.floorId == floorId).toList();
  }

  /// Get all nodes in a building
  List<GraphNode> getBuildingNodes(String buildingId) {
    return nodes.values.where((n) => n.buildingId == buildingId).toList();
  }

  /// Get statistics about the graph
  Map<String, dynamic> getStatistics() {
    int totalEdges = nodes.values.fold(0, (sum, node) => sum + node.edges.length);
    int intersectionNodes = nodes.values.where((n) => n.type == 'intersection').length;
    int landmarkNodes = nodes.values.where((n) => n.type == 'landmark').length;
    int roadPointNodes = nodes.values.where((n) => n.type == 'road_point').length;

    return {
      'totalNodes': nodes.length,
      'totalEdges': totalEdges,
      'intersectionNodes': intersectionNodes,
      'landmarkNodes': landmarkNodes,
      'roadPointNodes': roadPointNodes,
    };
  }
}

/// Builds navigation graph from road system
class RoadGraphBuilder {
  final Distance _distance = Distance();

  /// Build a complete navigation graph from a road system
  RoadGraph buildGraph(RoadSystem roadSystem) {
    final Map<String, GraphNode> nodes = {};

    // Step 1: Create nodes from intersections
    _addIntersectionNodes(nodes, roadSystem);

    // Step 2: Create nodes from landmarks (POIs)
    _addLandmarkNodes(nodes, roadSystem);

    // Step 3: Create edges from roads
    _addRoadEdges(nodes, roadSystem);

    // Step 4: Add vertical circulation edges (elevators, stairs)
    _addVerticalCirculationEdges(nodes, roadSystem);

    // Step 5: Connect landmarks to nearest road nodes
    _connectLandmarksToRoads(nodes, roadSystem);

    return RoadGraph(
      nodes: nodes,
      roadSystemId: roadSystem.id,
    );
  }

  /// Add intersection nodes to the graph
  void _addIntersectionNodes(Map<String, GraphNode> nodes, RoadSystem roadSystem) {
    // Outdoor intersections
    for (var intersection in roadSystem.outdoorIntersections) {
      nodes[intersection.id] = GraphNode(
        id: intersection.id,
        position: intersection.position,
        floorId: intersection.floorId.isEmpty ? null : intersection.floorId,
        buildingId: null,
        type: 'intersection',
        metadata: {
          'name': intersection.name,
          'intersectionType': intersection.type,
          'properties': intersection.properties,
        },
      );
    }

    // Indoor intersections (in buildings)
    for (var building in roadSystem.buildings) {
      for (var floor in building.floors) {
        for (var intersection in floor.intersections) {
          nodes[intersection.id] = GraphNode(
            id: intersection.id,
            position: intersection.position,
            floorId: intersection.floorId,
            buildingId: building.id,
            type: 'intersection',
            metadata: {
              'name': intersection.name,
              'intersectionType': intersection.type,
              'buildingName': building.name,
              'floorName': floor.name,
              'properties': intersection.properties,
            },
          );
        }
      }
    }
  }

  /// Add landmark nodes to the graph
  void _addLandmarkNodes(Map<String, GraphNode> nodes, RoadSystem roadSystem) {
    // Outdoor landmarks
    for (var landmark in roadSystem.outdoorLandmarks) {
      nodes[landmark.id] = GraphNode(
        id: landmark.id,
        position: landmark.position,
        floorId: landmark.floorId.isEmpty ? null : landmark.floorId,
        buildingId: landmark.buildingId.isEmpty ? null : landmark.buildingId,
        type: 'landmark',
        metadata: {
          'name': landmark.name,
          'landmarkType': landmark.type,
          'description': landmark.description,
          'connectedFloors': landmark.connectedFloors,
          'properties': landmark.properties,
        },
      );
    }

    // Indoor landmarks
    for (var building in roadSystem.buildings) {
      for (var floor in building.floors) {
        for (var landmark in floor.landmarks) {
          nodes[landmark.id] = GraphNode(
            id: landmark.id,
            position: landmark.position,
            floorId: landmark.floorId,
            buildingId: building.id,
            type: 'landmark',
            metadata: {
              'name': landmark.name,
              'landmarkType': landmark.type,
              'description': landmark.description,
              'buildingName': building.name,
              'floorName': floor.name,
              'connectedFloors': landmark.connectedFloors,
              'properties': landmark.properties,
            },
          );
        }
      }
    }
  }

  /// Add edges from roads connecting intersections
  void _addRoadEdges(Map<String, GraphNode> nodes, RoadSystem roadSystem) {
    // Process outdoor roads
    for (var road in roadSystem.outdoorRoads) {
      _processRoad(nodes, road, null, null);
    }

    // Process indoor roads
    for (var building in roadSystem.buildings) {
      for (var floor in building.floors) {
        for (var road in floor.roads) {
          _processRoad(nodes, road, building.id, floor.id);
        }
      }
    }
  }

  /// Process a single road and create edges
  void _processRoad(Map<String, GraphNode> nodes, Road road, String? buildingId, String? floorId) {
    if (road.points.isEmpty) return;

    // If road has connected intersections, create edges between them
    if (road.connectedIntersections.isNotEmpty) {
      _createEdgesFromConnectedIntersections(nodes, road);
    } else {
      // Otherwise, create nodes along the road path
      _createEdgesAlongRoadPath(nodes, road, buildingId, floorId);
    }
  }

  /// Create edges between explicitly connected intersections
  void _createEdgesFromConnectedIntersections(Map<String, GraphNode> nodes, Road road) {
    if (road.connectedIntersections.length < 2) return;

    for (int i = 0; i < road.connectedIntersections.length - 1; i++) {
      final fromId = road.connectedIntersections[i];
      final toId = road.connectedIntersections[i + 1];

      final fromNode = nodes[fromId];
      final toNode = nodes[toId];

      if (fromNode == null || toNode == null) continue;

      // Calculate distance
      final distance = _distance.as(
        LengthUnit.Meter,
        fromNode.position,
        toNode.position,
      );

      // Extract waypoints along the road between these intersections
      final waypoints = _extractWaypoints(road.points, fromNode.position, toNode.position);

      // Create edge from -> to
      final edgeForward = GraphEdge(
        fromNodeId: fromId,
        toNodeId: toId,
        weight: distance,
        roadId: road.id,
        roadType: road.type,
        isOneWay: road.isOneWay,
        waypoints: waypoints,
        metadata: {
          'roadName': road.name,
          'width': road.width,
          'properties': road.properties,
        },
      );

      fromNode.edges[toId] = edgeForward;

      // Create reverse edge if not one-way
      if (!road.isOneWay) {
        final edgeBackward = GraphEdge(
          fromNodeId: toId,
          toNodeId: fromId,
          weight: distance,
          roadId: road.id,
          roadType: road.type,
          isOneWay: false,
          waypoints: waypoints.reversed.toList(),
          metadata: {
            'roadName': road.name,
            'width': road.width,
            'properties': road.properties,
          },
        );

        toNode.edges[fromId] = edgeBackward;
      }
    }
  }

  /// Create edges along road path by creating intermediate nodes
  void _createEdgesAlongRoadPath(
    Map<String, GraphNode> nodes,
    Road road,
    String? buildingId,
    String? floorId,
  ) {
    if (road.points.length < 2) return;

    List<String> roadNodeIds = [];

    // Create nodes for each point along the road
    for (int i = 0; i < road.points.length; i++) {
      final nodeId = '${road.id}_point_$i';

      if (!nodes.containsKey(nodeId)) {
        nodes[nodeId] = GraphNode(
          id: nodeId,
          position: road.points[i],
          floorId: floorId,
          buildingId: buildingId,
          type: 'road_point',
          metadata: {
            'roadId': road.id,
            'roadName': road.name,
            'roadType': road.type,
            'pointIndex': i,
          },
        );
      }

      roadNodeIds.add(nodeId);
    }

    // Connect consecutive points
    for (int i = 0; i < roadNodeIds.length - 1; i++) {
      final fromId = roadNodeIds[i];
      final toId = roadNodeIds[i + 1];

      final fromNode = nodes[fromId]!;
      final toNode = nodes[toId]!;

      final distance = _distance.as(
        LengthUnit.Meter,
        fromNode.position,
        toNode.position,
      );

      // Forward edge
      fromNode.edges[toId] = GraphEdge(
        fromNodeId: fromId,
        toNodeId: toId,
        weight: distance,
        roadId: road.id,
        roadType: road.type,
        isOneWay: road.isOneWay,
        metadata: {
          'roadName': road.name,
          'width': road.width,
        },
      );

      // Backward edge if not one-way
      if (!road.isOneWay) {
        toNode.edges[fromId] = GraphEdge(
          fromNodeId: toId,
          toNodeId: fromId,
          weight: distance,
          roadId: road.id,
          roadType: road.type,
          isOneWay: false,
          metadata: {
            'roadName': road.name,
            'width': road.width,
          },
        );
      }
    }
  }

  /// Extract waypoints along a road segment
  List<LatLng> _extractWaypoints(List<LatLng> roadPoints, LatLng start, LatLng end) {
    if (roadPoints.isEmpty) return [];

    List<LatLng> waypoints = [];
    bool collecting = false;

    for (var point in roadPoints) {
      // Check if point is close to start
      if (_distance.as(LengthUnit.Meter, point, start) < 5.0) {
        collecting = true;
      }

      if (collecting) {
        waypoints.add(point);
      }

      // Check if point is close to end
      if (_distance.as(LengthUnit.Meter, point, end) < 5.0) {
        break;
      }
    }

    return waypoints;
  }

  /// Add vertical circulation edges (elevators, stairs, escalators)
  void _addVerticalCirculationEdges(Map<String, GraphNode> nodes, RoadSystem roadSystem) {
    for (var building in roadSystem.buildings) {
      // Find all vertical circulation landmarks
      Map<String, List<Landmark>> verticalCirculation = {};

      for (var floor in building.floors) {
        for (var landmark in floor.landmarks) {
          if (landmark.type == 'elevator' ||
              landmark.type == 'stairs' ||
              landmark.type == 'escalator') {

            final key = '${landmark.name}_${landmark.type}';
            verticalCirculation.putIfAbsent(key, () => []);
            verticalCirculation[key]!.add(landmark);
          }
        }
      }

      // Create edges between floors for each vertical circulation group
      for (var group in verticalCirculation.values) {
        if (group.length < 2) continue;

        // Sort by floor level
        group.sort((a, b) {
          final floorA = building.floors.firstWhere((f) => f.id == a.floorId);
          final floorB = building.floors.firstWhere((f) => f.id == b.floorId);
          return floorA.level.compareTo(floorB.level);
        });

        // Connect consecutive floors
        for (int i = 0; i < group.length - 1; i++) {
          final fromLandmark = group[i];
          final toLandmark = group[i + 1];

          final fromNode = nodes[fromLandmark.id];
          final toNode = nodes[toLandmark.id];

          if (fromNode == null || toNode == null) continue;

          // Calculate distance (vertical distance + small horizontal offset)
          final floorFrom = building.floors.firstWhere((f) => f.id == fromLandmark.floorId);
          final floorTo = building.floors.firstWhere((f) => f.id == toLandmark.floorId);

          // Estimate vertical distance (assume 4 meters per floor level)
          final verticalDistance = (floorTo.level - floorFrom.level).abs() * 4.0;

          // Add time penalty for stairs vs elevator
          double timePenalty = fromLandmark.type == 'stairs' ? 2.0 : 1.0;
          final weight = verticalDistance * timePenalty;

          // Bidirectional edges for vertical circulation
          fromNode.edges[toLandmark.id] = GraphEdge(
            fromNodeId: fromLandmark.id,
            toNodeId: toLandmark.id,
            weight: weight,
            isVerticalTransition: true,
            transitionType: fromLandmark.type,
            metadata: {
              'fromFloor': floorFrom.name,
              'toFloor': floorTo.name,
              'buildingName': building.name,
            },
          );

          toNode.edges[fromLandmark.id] = GraphEdge(
            fromNodeId: toLandmark.id,
            toNodeId: fromLandmark.id,
            weight: weight,
            isVerticalTransition: true,
            transitionType: fromLandmark.type,
            metadata: {
              'fromFloor': floorTo.name,
              'toFloor': floorFrom.name,
              'buildingName': building.name,
            },
          );
        }
      }
    }
  }

  /// Connect landmarks to nearest road nodes
  void _connectLandmarksToRoads(Map<String, GraphNode> nodes, RoadSystem roadSystem) {
    final landmarkNodes = nodes.values.where((n) => n.type == 'landmark').toList();

    for (var landmarkNode in landmarkNodes) {
      // Skip vertical circulation landmarks (already connected)
      final landmarkType = landmarkNode.metadata['landmarkType'] as String?;
      if (landmarkType == 'elevator' || landmarkType == 'stairs' || landmarkType == 'escalator') {
        continue;
      }

      // Find nearest road nodes (intersections or road points)
      final nearestNodes = _findNearestRoadNodes(
        nodes,
        landmarkNode.position,
        floorId: landmarkNode.floorId,
        buildingId: landmarkNode.buildingId,
        maxDistance: 50.0, // Within 50 meters
        limit: 3, // Connect to 3 nearest nodes
      );

      // Create bidirectional edges
      for (var nearNode in nearestNodes) {
        final distance = _distance.as(
          LengthUnit.Meter,
          landmarkNode.position,
          nearNode.position,
        );

        landmarkNode.edges[nearNode.id] = GraphEdge(
          fromNodeId: landmarkNode.id,
          toNodeId: nearNode.id,
          weight: distance,
          metadata: {'connectionType': 'landmark_to_road'},
        );

        nearNode.edges[landmarkNode.id] = GraphEdge(
          fromNodeId: nearNode.id,
          toNodeId: landmarkNode.id,
          weight: distance,
          metadata: {'connectionType': 'road_to_landmark'},
        );
      }
    }
  }

  /// Find nearest road nodes to a position
  List<GraphNode> _findNearestRoadNodes(
    Map<String, GraphNode> nodes,
    LatLng position, {
    String? floorId,
    String? buildingId,
    double maxDistance = 100.0,
    int limit = 3,
  }) {
    final candidates = nodes.values.where((n) {
      // Filter by floor/building
      if (floorId != null && n.floorId != floorId) return false;
      if (buildingId != null && n.buildingId != buildingId) return false;

      // Only road nodes (intersections and road points)
      return n.type == 'intersection' || n.type == 'road_point';
    }).toList();

    // Sort by distance
    candidates.sort((a, b) {
      final distA = _distance.as(LengthUnit.Meter, position, a.position);
      final distB = _distance.as(LengthUnit.Meter, position, b.position);
      return distA.compareTo(distB);
    });

    // Filter by max distance and limit
    return candidates
        .where((n) => _distance.as(LengthUnit.Meter, position, n.position) <= maxDistance)
        .take(limit)
        .toList();
  }
}
