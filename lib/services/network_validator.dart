import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import 'road_graph_builder.dart';

/// Result of network validation
class ValidationResult {
  final bool isValid;
  final List<ValidationIssue> issues;
  final Map<String, dynamic> statistics;

  ValidationResult({
    required this.isValid,
    required this.issues,
    required this.statistics,
  });

  int get errorCount => issues.where((i) => i.severity == IssueSeverity.error).length;
  int get warningCount => issues.where((i) => i.severity == IssueSeverity.warning).length;
  int get infoCount => issues.where((i) => i.severity == IssueSeverity.info).length;
}

/// Severity of validation issue
enum IssueSeverity {
  error,
  warning,
  info,
}

/// Category of validation issue
enum IssueCategory {
  connectivity,
  navigation,
  dataIntegrity,
  performance,
  accessibility,
}

/// Individual validation issue
class ValidationIssue {
  final String id;
  final IssueSeverity severity;
  final IssueCategory category;
  final String title;
  final String description;
  final LatLng? location;
  final String? relatedId;
  final String? suggestedFix;

  ValidationIssue({
    required this.id,
    required this.severity,
    required this.category,
    required this.title,
    required this.description,
    this.location,
    this.relatedId,
    this.suggestedFix,
  });
}

/// Network validation service
class NetworkValidator {
  final Distance _distance = Distance();

  /// Validate entire road network
  ValidationResult validateNetwork(RoadSystem roadSystem) {
    final issues = <ValidationIssue>[];
    final statistics = <String, dynamic>{};

    // Build graph for validation
    final builder = RoadGraphBuilder();
    final graph = builder.buildGraph(roadSystem);

    // Run all validation checks
    issues.addAll(_validateIntersectionConnectivity(roadSystem, graph));
    issues.addAll(_validateRoadConnections(roadSystem));
    issues.addAll(_validateLandmarkAccessibility(roadSystem, graph));
    issues.addAll(_validateVerticalCirculation(roadSystem));
    issues.addAll(_validateBuildingAccessibility(roadSystem));
    issues.addAll(_validateDataIntegrity(roadSystem));
    issues.addAll(_validateGraphConnectivity(graph));

    // Calculate statistics
    statistics.addAll(_calculateStatistics(roadSystem, graph));

    // Determine if network is valid (no errors)
    final isValid = !issues.any((i) => i.severity == IssueSeverity.error);

    return ValidationResult(
      isValid: isValid,
      issues: issues,
      statistics: statistics,
    );
  }

  /// Validate intersection connectivity
  List<ValidationIssue> _validateIntersectionConnectivity(
    RoadSystem roadSystem,
    RoadGraph graph,
  ) {
    final issues = <ValidationIssue>[];
    var issueCount = 0;

    // Check outdoor intersections
    for (var intersection in roadSystem.outdoorIntersections) {
      final node = graph.nodes[intersection.id];

      if (node == null) {
        issues.add(ValidationIssue(
          id: 'INT_MISSING_${issueCount++}',
          severity: IssueSeverity.error,
          category: IssueCategory.connectivity,
          title: 'Intersection not in graph',
          description: 'Intersection "${intersection.name}" exists but was not added to the navigation graph.',
          location: intersection.position,
          relatedId: intersection.id,
        ));
        continue;
      }

      // Check if intersection has connections
      if (node.edges.isEmpty) {
        issues.add(ValidationIssue(
          id: 'INT_ISOLATED_${issueCount++}',
          severity: IssueSeverity.error,
          category: IssueCategory.connectivity,
          title: 'Isolated intersection',
          description: 'Intersection "${intersection.name}" has no connected roads.',
          location: intersection.position,
          relatedId: intersection.id,
          suggestedFix: 'Connect this intersection to nearby roads or remove it.',
        ));
      } else if (node.edges.length == 1) {
        issues.add(ValidationIssue(
          id: 'INT_DEADEND_${issueCount++}',
          severity: IssueSeverity.warning,
          category: IssueCategory.navigation,
          title: 'Dead-end intersection',
          description: 'Intersection "${intersection.name}" only connects to one road (dead-end).',
          location: intersection.position,
          relatedId: intersection.id,
          suggestedFix: 'Consider connecting to additional roads for better navigation.',
        ));
      }
    }

    // Check indoor intersections
    for (var building in roadSystem.buildings) {
      for (var floor in building.floors) {
        for (var intersection in floor.intersections) {
          final node = graph.nodes[intersection.id];

          if (node == null) {
            issues.add(ValidationIssue(
              id: 'INT_MISSING_${issueCount++}',
              severity: IssueSeverity.error,
              category: IssueCategory.connectivity,
              title: 'Intersection not in graph',
              description: 'Intersection "${intersection.name}" in ${building.name} - ${floor.name} was not added to graph.',
              location: intersection.position,
              relatedId: intersection.id,
            ));
            continue;
          }

          if (node.edges.isEmpty) {
            issues.add(ValidationIssue(
              id: 'INT_ISOLATED_${issueCount++}',
              severity: IssueSeverity.error,
              category: IssueCategory.connectivity,
              title: 'Isolated indoor intersection',
              description: 'Intersection "${intersection.name}" in ${building.name} - ${floor.name} has no connections.',
              location: intersection.position,
              relatedId: intersection.id,
            ));
          }
        }
      }
    }

    return issues;
  }

  /// Validate road connections
  List<ValidationIssue> _validateRoadConnections(RoadSystem roadSystem) {
    final issues = <ValidationIssue>[];
    var issueCount = 0;

    // Check outdoor roads
    for (var road in roadSystem.outdoorRoads) {
      if (road.points.isEmpty) {
        issues.add(ValidationIssue(
          id: 'ROAD_EMPTY_${issueCount++}',
          severity: IssueSeverity.error,
          category: IssueCategory.dataIntegrity,
          title: 'Empty road',
          description: 'Road "${road.name}" has no points defined.',
          relatedId: road.id,
        ));
      } else if (road.points.length == 1) {
        issues.add(ValidationIssue(
          id: 'ROAD_SINGLE_${issueCount++}',
          severity: IssueSeverity.warning,
          category: IssueCategory.dataIntegrity,
          title: 'Single-point road',
          description: 'Road "${road.name}" only has one point.',
          location: road.points.first,
          relatedId: road.id,
        ));
      }

      // Check if road connects to intersections
      if (road.connectedIntersections.isEmpty) {
        issues.add(ValidationIssue(
          id: 'ROAD_DISCONNECTED_${issueCount++}',
          severity: IssueSeverity.warning,
          category: IssueCategory.navigation,
          title: 'Unconnected road',
          description: 'Road "${road.name}" is not connected to any intersections.',
          location: road.points.isNotEmpty ? road.points.first : null,
          relatedId: road.id,
          suggestedFix: 'Add intersections at road endpoints or connect to existing intersections.',
        ));
      }

      // Check for very short roads (< 1 meter)
      if (road.points.length >= 2) {
        final length = _calculateRoadLength(road.points);
        if (length < 1.0) {
          issues.add(ValidationIssue(
            id: 'ROAD_TOO_SHORT_${issueCount++}',
            severity: IssueSeverity.info,
            category: IssueCategory.dataIntegrity,
            title: 'Very short road',
            description: 'Road "${road.name}" is very short (${length.toStringAsFixed(2)}m).',
            location: road.points.first,
            relatedId: road.id,
          ));
        }
      }
    }

    // Check indoor roads
    for (var building in roadSystem.buildings) {
      for (var floor in building.floors) {
        for (var road in floor.roads) {
          if (road.points.isEmpty) {
            issues.add(ValidationIssue(
              id: 'ROAD_EMPTY_${issueCount++}',
              severity: IssueSeverity.error,
              category: IssueCategory.dataIntegrity,
              title: 'Empty indoor road',
              description: 'Road "${road.name}" in ${building.name} - ${floor.name} has no points.',
              relatedId: road.id,
            ));
          }

          if (road.connectedIntersections.isEmpty) {
            issues.add(ValidationIssue(
              id: 'ROAD_DISCONNECTED_${issueCount++}',
              severity: IssueSeverity.warning,
              category: IssueCategory.navigation,
              title: 'Unconnected indoor road',
              description: 'Road "${road.name}" in ${building.name} - ${floor.name} is not connected to intersections.',
              location: road.points.isNotEmpty ? road.points.first : null,
              relatedId: road.id,
            ));
          }
        }
      }
    }

    return issues;
  }

  /// Validate landmark accessibility
  List<ValidationIssue> _validateLandmarkAccessibility(
    RoadSystem roadSystem,
    RoadGraph graph,
  ) {
    final issues = <ValidationIssue>[];
    var issueCount = 0;

    // Check outdoor landmarks
    for (var landmark in roadSystem.outdoorLandmarks) {
      // Skip vertical circulation landmarks
      if (landmark.type == 'elevator' ||
          landmark.type == 'stairs' ||
          landmark.type == 'escalator') {
        continue;
      }

      final node = graph.nodes[landmark.id];

      if (node == null) {
        issues.add(ValidationIssue(
          id: 'LANDMARK_MISSING_${issueCount++}',
          severity: IssueSeverity.error,
          category: IssueCategory.accessibility,
          title: 'Landmark not in graph',
          description: 'Landmark "${landmark.name}" was not added to the navigation graph.',
          location: landmark.position,
          relatedId: landmark.id,
        ));
        continue;
      }

      if (node.edges.isEmpty) {
        issues.add(ValidationIssue(
          id: 'LANDMARK_ISOLATED_${issueCount++}',
          severity: IssueSeverity.error,
          category: IssueCategory.accessibility,
          title: 'Inaccessible landmark',
          description: 'Landmark "${landmark.name}" is not connected to the road network.',
          location: landmark.position,
          relatedId: landmark.id,
          suggestedFix: 'Move landmark closer to a road or add a connecting path.',
        ));
      }
    }

    // Check indoor landmarks
    for (var building in roadSystem.buildings) {
      for (var floor in building.floors) {
        for (var landmark in floor.landmarks) {
          if (landmark.type == 'elevator' ||
              landmark.type == 'stairs' ||
              landmark.type == 'escalator') {
            continue;
          }

          final node = graph.nodes[landmark.id];

          if (node == null) {
            issues.add(ValidationIssue(
              id: 'LANDMARK_MISSING_${issueCount++}',
              severity: IssueSeverity.error,
              category: IssueCategory.accessibility,
              title: 'Indoor landmark not in graph',
              description: 'Landmark "${landmark.name}" in ${building.name} - ${floor.name} not in graph.',
              location: landmark.position,
              relatedId: landmark.id,
            ));
            continue;
          }

          if (node.edges.isEmpty) {
            issues.add(ValidationIssue(
              id: 'LANDMARK_ISOLATED_${issueCount++}',
              severity: IssueSeverity.error,
              category: IssueCategory.accessibility,
              title: 'Inaccessible indoor landmark',
              description: 'Landmark "${landmark.name}" in ${building.name} - ${floor.name} is not accessible.',
              location: landmark.position,
              relatedId: landmark.id,
            ));
          }
        }
      }
    }

    return issues;
  }

  /// Validate vertical circulation (elevators, stairs)
  List<ValidationIssue> _validateVerticalCirculation(RoadSystem roadSystem) {
    final issues = <ValidationIssue>[];
    var issueCount = 0;

    for (var building in roadSystem.buildings) {
      if (building.floors.length <= 1) continue;

      // Check if there's vertical circulation
      bool hasVerticalCirculation = false;

      for (var floor in building.floors) {
        for (var landmark in floor.landmarks) {
          if (landmark.type == 'elevator' ||
              landmark.type == 'stairs' ||
              landmark.type == 'escalator') {
            hasVerticalCirculation = true;

            // Check if it connects to other floors
            if (landmark.connectedFloors.isEmpty) {
              issues.add(ValidationIssue(
                id: 'CIRC_DISCONNECTED_${issueCount++}',
                severity: IssueSeverity.error,
                category: IssueCategory.accessibility,
                title: 'Disconnected vertical circulation',
                description: '${landmark.type} "${landmark.name}" in ${building.name} - ${floor.name} is not connected to any floors.',
                location: landmark.position,
                relatedId: landmark.id,
                suggestedFix: 'Add connected floors to this vertical circulation element.',
              ));
            } else if (landmark.connectedFloors.length == 1) {
              issues.add(ValidationIssue(
                id: 'CIRC_SINGLE_${issueCount++}',
                severity: IssueSeverity.warning,
                category: IssueCategory.accessibility,
                title: 'Single-floor circulation',
                description: '${landmark.type} "${landmark.name}" only connects to one other floor.',
                location: landmark.position,
                relatedId: landmark.id,
              ));
            }
          }
        }
      }

      if (!hasVerticalCirculation) {
        issues.add(ValidationIssue(
          id: 'BUILDING_NO_CIRC_${issueCount++}',
          severity: IssueSeverity.error,
          category: IssueCategory.accessibility,
          title: 'No vertical circulation',
          description: 'Building "${building.name}" has multiple floors but no elevators or stairs.',
          location: building.centerPosition,
          relatedId: building.id,
          suggestedFix: 'Add elevators and/or stairs to enable floor transitions.',
        ));
      }
    }

    return issues;
  }

  /// Validate building accessibility (entrances/exits)
  List<ValidationIssue> _validateBuildingAccessibility(RoadSystem roadSystem) {
    final issues = <ValidationIssue>[];
    var issueCount = 0;

    for (var building in roadSystem.buildings) {
      final groundFloor = building.floors.where((f) => f.level == 0).firstOrNull;

      if (groundFloor == null) {
        issues.add(ValidationIssue(
          id: 'BUILDING_NO_GROUND_${issueCount++}',
          severity: IssueSeverity.warning,
          category: IssueCategory.accessibility,
          title: 'No ground floor',
          description: 'Building "${building.name}" has no ground floor (level 0).',
          location: building.centerPosition,
          relatedId: building.id,
        ));
        continue;
      }

      // Check for entrances/exits
      final entrances = groundFloor.landmarks
          .where((l) => l.type == 'entrance' || l.type == 'exit')
          .toList();

      if (entrances.isEmpty) {
        issues.add(ValidationIssue(
          id: 'BUILDING_NO_ENTRANCE_${issueCount++}',
          severity: IssueSeverity.error,
          category: IssueCategory.accessibility,
          title: 'No building entrances',
          description: 'Building "${building.name}" has no marked entrances or exits.',
          location: building.centerPosition,
          relatedId: building.id,
          suggestedFix: 'Add entrance/exit landmarks on the ground floor.',
        ));
      } else if (entrances.length == 1) {
        issues.add(ValidationIssue(
          id: 'BUILDING_SINGLE_ENTRANCE_${issueCount++}',
          severity: IssueSeverity.info,
          category: IssueCategory.accessibility,
          title: 'Single entrance',
          description: 'Building "${building.name}" only has one entrance/exit.',
          location: entrances.first.position,
          relatedId: building.id,
        ));
      }
    }

    return issues;
  }

  /// Validate data integrity
  List<ValidationIssue> _validateDataIntegrity(RoadSystem roadSystem) {
    final issues = <ValidationIssue>[];
    var issueCount = 0;

    // Check for duplicate IDs
    final allIds = <String>{};

    // Buildings
    for (var building in roadSystem.buildings) {
      if (!allIds.add(building.id)) {
        issues.add(ValidationIssue(
          id: 'DATA_DUP_ID_${issueCount++}',
          severity: IssueSeverity.error,
          category: IssueCategory.dataIntegrity,
          title: 'Duplicate building ID',
          description: 'Duplicate ID found: ${building.id}',
          relatedId: building.id,
        ));
      }

      // Floors
      for (var floor in building.floors) {
        if (!allIds.add(floor.id)) {
          issues.add(ValidationIssue(
            id: 'DATA_DUP_ID_${issueCount++}',
            severity: IssueSeverity.error,
            category: IssueCategory.dataIntegrity,
            title: 'Duplicate floor ID',
            description: 'Duplicate ID found: ${floor.id}',
            relatedId: floor.id,
          ));
        }
      }
    }

    // Check for empty system
    if (roadSystem.buildings.isEmpty &&
        roadSystem.outdoorRoads.isEmpty &&
        roadSystem.outdoorIntersections.isEmpty) {
      issues.add(ValidationIssue(
        id: 'DATA_EMPTY_${issueCount++}',
        severity: IssueSeverity.warning,
        category: IssueCategory.dataIntegrity,
        title: 'Empty road system',
        description: 'The road system contains no buildings, roads, or intersections.',
      ));
    }

    return issues;
  }

  /// Validate graph connectivity
  List<ValidationIssue> _validateGraphConnectivity(RoadGraph graph) {
    final issues = <ValidationIssue>[];
    var issueCount = 0;

    // Find connected components
    final components = _findConnectedComponents(graph);

    if (components.length > 1) {
      issues.add(ValidationIssue(
        id: 'GRAPH_DISCONNECTED_${issueCount++}',
        severity: IssueSeverity.error,
        category: IssueCategory.connectivity,
        title: 'Disconnected network',
        description: 'The road network has ${components.length} disconnected components. Some destinations may be unreachable.',
        suggestedFix: 'Add roads to connect all parts of the network.',
      ));

      // Report size of each component
      for (int i = 0; i < components.length; i++) {
        final size = components[i].length;
        issues.add(ValidationIssue(
          id: 'GRAPH_COMPONENT_${issueCount++}',
          severity: IssueSeverity.info,
          category: IssueCategory.connectivity,
          title: 'Network component ${i + 1}',
          description: 'Component ${i + 1} contains $size nodes.',
        ));
      }
    }

    return issues;
  }

  /// Find connected components using DFS
  List<List<String>> _findConnectedComponents(RoadGraph graph) {
    final visited = <String>{};
    final components = <List<String>>[];

    for (var nodeId in graph.nodes.keys) {
      if (!visited.contains(nodeId)) {
        final component = <String>[];
        _dfs(graph, nodeId, visited, component);
        components.add(component);
      }
    }

    return components;
  }

  /// Depth-first search
  void _dfs(
    RoadGraph graph,
    String nodeId,
    Set<String> visited,
    List<String> component,
  ) {
    visited.add(nodeId);
    component.add(nodeId);

    final node = graph.nodes[nodeId];
    if (node == null) return;

    for (var edge in node.edges.values) {
      if (!visited.contains(edge.toNodeId)) {
        _dfs(graph, edge.toNodeId, visited, component);
      }
    }
  }

  /// Calculate road length
  double _calculateRoadLength(List<LatLng> points) {
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += _distance.as(LengthUnit.Meter, points[i], points[i + 1]);
    }
    return total;
  }

  /// Calculate statistics
  Map<String, dynamic> _calculateStatistics(
    RoadSystem roadSystem,
    RoadGraph graph,
  ) {
    final stats = graph.getStatistics();

    // Calculate total road length
    double totalOutdoorRoadLength = 0;
    for (var road in roadSystem.outdoorRoads) {
      totalOutdoorRoadLength += _calculateRoadLength(road.points);
    }

    double totalIndoorRoadLength = 0;
    for (var building in roadSystem.buildings) {
      for (var floor in building.floors) {
        for (var road in floor.roads) {
          totalIndoorRoadLength += _calculateRoadLength(road.points);
        }
      }
    }

    // Count vertical circulation
    int totalElevators = 0;
    int totalStairs = 0;
    int totalEscalators = 0;

    for (var building in roadSystem.buildings) {
      for (var floor in building.floors) {
        for (var landmark in floor.landmarks) {
          if (landmark.type == 'elevator') totalElevators++;
          if (landmark.type == 'stairs') totalStairs++;
          if (landmark.type == 'escalator') totalEscalators++;
        }
      }
    }

    return {
      ...stats,
      'totalOutdoorRoadLength': totalOutdoorRoadLength.toStringAsFixed(2),
      'totalIndoorRoadLength': totalIndoorRoadLength.toStringAsFixed(2),
      'totalRoadLength':
          (totalOutdoorRoadLength + totalIndoorRoadLength).toStringAsFixed(2),
      'elevators': totalElevators,
      'stairs': totalStairs,
      'escalators': totalEscalators,
      'buildings': roadSystem.buildings.length,
    };
  }
}
