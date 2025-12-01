import 'dart:collection';
import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'road_graph_builder.dart';

/// Result of A* pathfinding
class PathfindingResult {
  final List<String> nodeIds;
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final double totalDistance;
  final List<LatLng> fullPath; // Complete path including waypoints
  final List<String> instructions;
  final bool success;
  final String? error;

  PathfindingResult({
    required this.nodeIds,
    required this.nodes,
    required this.edges,
    required this.totalDistance,
    required this.fullPath,
    List<String>? instructions,
    this.success = true,
    this.error,
  }) : instructions = instructions ?? [];

  PathfindingResult.failure(String errorMessage)
      : nodeIds = [],
        nodes = [],
        edges = [],
        totalDistance = 0,
        fullPath = [],
        instructions = [],
        success = false,
        error = errorMessage;
}

/// A* node for pathfinding
class _AStarNode implements Comparable<_AStarNode> {
  final String nodeId;
  final double gCost; // Cost from start to this node
  final double hCost; // Heuristic cost from this node to goal
  final String? parentId;

  _AStarNode({
    required this.nodeId,
    required this.gCost,
    required this.hCost,
    this.parentId,
  });

  double get fCost => gCost + hCost;

  @override
  int compareTo(_AStarNode other) => fCost.compareTo(other.fCost);
}

/// A* pathfinding algorithm implementation
class AStarPathfinder {
  final RoadGraph graph;
  final Distance _distance = Distance();

  AStarPathfinder(this.graph);

  /// Find path from start to goal using A* algorithm
  PathfindingResult findPath(
    String startNodeId,
    String goalNodeId, {
    bool preferElevator = true,
    Set<String>? excludedNodes,
  }) {
    final startNode = graph.nodes[startNodeId];
    final goalNode = graph.nodes[goalNodeId];

    if (startNode == null) {
      return PathfindingResult.failure('Start node not found: $startNodeId');
    }

    if (goalNode == null) {
      return PathfindingResult.failure('Goal node not found: $goalNodeId');
    }

    // A* algorithm
    final openSet = PriorityQueue<_AStarNode>();
    final closedSet = <String>{};
    final gScores = <String, double>{};
    final parents = <String, String>{};

    // Initialize start node
    gScores[startNodeId] = 0;
    openSet.add(_AStarNode(
      nodeId: startNodeId,
      gCost: 0,
      hCost: _heuristic(startNode.position, goalNode.position),
    ));

    while (openSet.isNotEmpty) {
      final current = openSet.removeFirst();

      // Goal reached
      if (current.nodeId == goalNodeId) {
        return _reconstructPath(
          startNodeId,
          goalNodeId,
          parents,
          gScores[goalNodeId]!,
        );
      }

      // Skip if already processed
      if (closedSet.contains(current.nodeId)) continue;
      closedSet.add(current.nodeId);

      final currentNode = graph.nodes[current.nodeId]!;

      // Explore neighbors
      for (var edge in currentNode.edges.values) {
        final neighborId = edge.toNodeId;

        // Skip excluded nodes
        if (excludedNodes?.contains(neighborId) ?? false) continue;

        // Skip if already processed
        if (closedSet.contains(neighborId)) continue;

        final neighbor = graph.nodes[neighborId];
        if (neighbor == null) continue;

        // Calculate tentative g score
        var edgeWeight = edge.weight;

        // Apply preferences
        if (edge.isVerticalTransition) {
          if (preferElevator && edge.transitionType != 'elevator') {
            edgeWeight *= 1.5; // Penalize stairs if elevator preferred
          } else if (!preferElevator && edge.transitionType == 'elevator') {
            edgeWeight *= 1.2; // Slight penalty for elevator if not preferred
          }
        }

        final tentativeGScore = gScores[current.nodeId]! + edgeWeight;

        // Check if this path is better
        if (!gScores.containsKey(neighborId) || tentativeGScore < gScores[neighborId]!) {
          gScores[neighborId] = tentativeGScore;
          parents[neighborId] = current.nodeId;

          openSet.add(_AStarNode(
            nodeId: neighborId,
            gCost: tentativeGScore,
            hCost: _heuristic(neighbor.position, goalNode.position),
            parentId: current.nodeId,
          ));
        }
      }
    }

    return PathfindingResult.failure('No path found from $startNodeId to $goalNodeId');
  }

  /// Find path from a position to another position
  PathfindingResult findPathFromPositions(
    LatLng startPos,
    LatLng goalPos, {
    String? startFloorId,
    String? goalFloorId,
    String? startBuildingId,
    String? goalBuildingId,
    bool preferElevator = true,
  }) {
    // Find nearest nodes to start and goal positions
    final startNode = graph.findNearestNode(
      startPos,
      floorId: startFloorId,
      buildingId: startBuildingId,
    );

    final goalNode = graph.findNearestNode(
      goalPos,
      floorId: goalFloorId,
      buildingId: goalBuildingId,
    );

    if (startNode == null) {
      return PathfindingResult.failure('No node found near start position');
    }

    if (goalNode == null) {
      return PathfindingResult.failure('No node found near goal position');
    }

    // Add distance from actual positions to nearest nodes
    final startOffset = _distance.as(LengthUnit.Meter, startPos, startNode.position);
    final goalOffset = _distance.as(LengthUnit.Meter, goalPos, goalNode.position);

    // Find path between nodes
    final result = findPath(
      startNode.id,
      goalNode.id,
      preferElevator: preferElevator,
    );

    if (!result.success) return result;

    // Add start and goal positions to the path
    final fullPath = <LatLng>[
      startPos,
      ...result.fullPath,
      goalPos,
    ];

    return PathfindingResult(
      nodeIds: result.nodeIds,
      nodes: result.nodes,
      edges: result.edges,
      totalDistance: result.totalDistance + startOffset + goalOffset,
      fullPath: fullPath,
      instructions: result.instructions,
      success: true,
    );
  }

  /// Heuristic function (straight-line distance)
  double _heuristic(LatLng from, LatLng to) {
    return _distance.as(LengthUnit.Meter, from, to);
  }

  /// Reconstruct path from parent map
  PathfindingResult _reconstructPath(
    String startId,
    String goalId,
    Map<String, String> parents,
    double totalDistance,
  ) {
    final nodeIds = <String>[];
    final nodes = <GraphNode>[];
    final edges = <GraphEdge>[];
    final fullPath = <LatLng>[];

    // Build path from goal to start
    String? currentId = goalId;
    while (currentId != null) {
      nodeIds.insert(0, currentId);
      final node = graph.nodes[currentId]!;
      nodes.insert(0, node);

      currentId = parents[currentId];
    }

    // Build edges and full path with waypoints
    for (int i = 0; i < nodeIds.length - 1; i++) {
      final fromId = nodeIds[i];
      final toId = nodeIds[i + 1];

      final edge = graph.getEdge(fromId, toId);
      if (edge != null) {
        edges.add(edge);

        // Add start position
        fullPath.add(nodes[i].position);

        // Add waypoints if available
        if (edge.waypoints.isNotEmpty) {
          fullPath.addAll(edge.waypoints);
        }
      }
    }

    // Add final position
    if (nodes.isNotEmpty) {
      fullPath.add(nodes.last.position);
    }

    // Generate instructions
    final instructions = _generateInstructions(nodes, edges);

    return PathfindingResult(
      nodeIds: nodeIds,
      nodes: nodes,
      edges: edges,
      totalDistance: totalDistance,
      fullPath: fullPath,
      instructions: instructions,
      success: true,
    );
  }

  /// Generate turn-by-turn instructions
  List<String> _generateInstructions(List<GraphNode> nodes, List<GraphEdge> edges) {
    final instructions = <String>[];

    if (nodes.isEmpty) return instructions;

    instructions.add('Start at ${_getNodeName(nodes.first)}');

    for (int i = 0; i < edges.length; i++) {
      final edge = edges[i];
      final toNode = nodes[i + 1];

      if (edge.isVerticalTransition) {
        // Vertical transition instruction
        final fromFloor = edge.metadata['fromFloor'] ?? 'floor';
        final toFloor = edge.metadata['toFloor'] ?? 'floor';
        final building = edge.metadata['buildingName'] ?? '';

        instructions.add(
          'Take ${edge.transitionType ?? 'transition'} from $fromFloor to $toFloor${building.isNotEmpty ? ' in $building' : ''}',
        );
      } else {
        // Regular movement instruction
        final roadName = edge.metadata['roadName'] ?? edge.roadType ?? 'path';
        final distance = edge.weight.toStringAsFixed(0);

        if (i == 0) {
          instructions.add('Follow $roadName for ${distance}m');
        } else {
          // Determine turn direction
          final direction = _getTurnDirection(
            i > 0 ? nodes[i - 1].position : nodes[i].position,
            nodes[i].position,
            toNode.position,
          );

          if (direction != 'straight') {
            instructions.add('Turn $direction onto $roadName');
          }
          instructions.add('Continue for ${distance}m');
        }
      }
    }

    instructions.add('Arrive at ${_getNodeName(nodes.last)}');

    return instructions;
  }

  /// Get readable node name
  String _getNodeName(GraphNode node) {
    if (node.metadata.containsKey('name')) {
      return node.metadata['name'];
    }

    if (node.type == 'intersection') {
      return 'intersection';
    }

    if (node.type == 'landmark') {
      return 'destination';
    }

    return 'waypoint';
  }

  /// Calculate turn direction
  String _getTurnDirection(LatLng from, LatLng via, LatLng to) {
    // Calculate bearings
    final bearing1 = _calculateBearing(from, via);
    final bearing2 = _calculateBearing(via, to);

    // Calculate turn angle
    var angle = bearing2 - bearing1;
    if (angle > 180) angle -= 360;
    if (angle < -180) angle += 360;

    // Classify turn
    if (angle.abs() < 30) return 'straight';
    if (angle > 0) {
      return angle > 120 ? 'sharp right' : 'right';
    } else {
      return angle < -120 ? 'sharp left' : 'left';
    }
  }

  /// Calculate bearing between two points
  double _calculateBearing(LatLng from, LatLng to) {
    final lat1 = from.latitudeInRad;
    final lon1 = from.longitudeInRad;
    final lat2 = to.latitudeInRad;
    final lon2 = to.longitudeInRad;

    final dLon = lon2 - lon1;

    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

    final bearing = atan2(y, x);
    return (bearing * 180 / pi + 360) % 360;
  }
}

/// Priority queue implementation for A*
class PriorityQueue<T extends Comparable> {
  final _heap = <T>[];

  bool get isNotEmpty => _heap.isNotEmpty;
  bool get isEmpty => _heap.isEmpty;
  int get length => _heap.length;

  void add(T value) {
    _heap.add(value);
    _bubbleUp(_heap.length - 1);
  }

  T removeFirst() {
    if (_heap.isEmpty) throw StateError('No element');

    final result = _heap[0];
    final last = _heap.removeLast();

    if (_heap.isNotEmpty) {
      _heap[0] = last;
      _bubbleDown(0);
    }

    return result;
  }

  void _bubbleUp(int index) {
    while (index > 0) {
      final parent = (index - 1) ~/ 2;
      if (_heap[index].compareTo(_heap[parent]) >= 0) break;

      _swap(index, parent);
      index = parent;
    }
  }

  void _bubbleDown(int index) {
    while (true) {
      var smallest = index;
      final left = 2 * index + 1;
      final right = 2 * index + 2;

      if (left < _heap.length && _heap[left].compareTo(_heap[smallest]) < 0) {
        smallest = left;
      }

      if (right < _heap.length && _heap[right].compareTo(_heap[smallest]) < 0) {
        smallest = right;
      }

      if (smallest == index) break;

      _swap(index, smallest);
      index = smallest;
    }
  }

  void _swap(int i, int j) {
    final temp = _heap[i];
    _heap[i] = _heap[j];
    _heap[j] = temp;
  }

  void clear() => _heap.clear();
}
