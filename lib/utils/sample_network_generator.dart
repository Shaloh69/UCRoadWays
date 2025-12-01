import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

/// Generates sample road networks for testing and demonstration
class SampleNetworkGenerator {
  final Uuid _uuid = const Uuid();

  /// Generate a complete UC Riverside campus road network
  RoadSystem generateUCRiversideCampus() {
    final systemId = _uuid.v4();

    // UC Riverside approximate center
    final center = LatLng(33.9737, -117.3281);

    // Create outdoor intersections (grid pattern)
    final intersections = <Intersection>[];
    final roads = <Road>[];

    // Create a 4x4 grid of intersections
    final gridSize = 4;
    final spacing = 0.001; // Approximately 111 meters

    final intersectionGrid = <List<Intersection>>[];

    for (int row = 0; row < gridSize; row++) {
      final rowIntersections = <Intersection>[];
      for (int col = 0; col < gridSize; col++) {
        final lat = center.latitude + (row - gridSize / 2) * spacing;
        final lng = center.longitude + (col - gridSize / 2) * spacing;

        final intersection = Intersection(
          id: _uuid.v4(),
          name: 'Intersection ${String.fromCharCode(65 + row)}${col + 1}',
          position: LatLng(lat, lng),
          floorId: '',
          connectedRoadIds: [],
          type: 'simple',
          properties: {},
        );

        rowIntersections.add(intersection);
        intersections.add(intersection);
      }
      intersectionGrid.add(rowIntersections);
    }

    // Create horizontal roads
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize - 1; col++) {
        final from = intersectionGrid[row][col];
        final to = intersectionGrid[row][col + 1];

        final road = Road(
          id: _uuid.v4(),
          name: 'Road ${String.fromCharCode(65 + row)} East-${col + 1}',
          points: [from.position, to.position],
          type: 'road',
          width: 8.0,
          isOneWay: false,
          floorId: '',
          connectedIntersections: [from.id, to.id],
          properties: {},
        );

        roads.add(road);
      }
    }

    // Create vertical roads
    for (int row = 0; row < gridSize - 1; row++) {
      for (int col = 0; col < gridSize; col++) {
        final from = intersectionGrid[row][col];
        final to = intersectionGrid[row + 1][col];

        final road = Road(
          id: _uuid.v4(),
          name: 'Road ${col + 1} South-${String.fromCharCode(65 + row)}',
          points: [from.position, to.position],
          type: 'road',
          width: 8.0,
          isOneWay: false,
          floorId: '',
          connectedIntersections: [from.id, to.id],
          properties: {},
        );

        roads.add(road);
      }
    }

    // Create outdoor landmarks (POIs)
    final landmarks = <Landmark>[
      Landmark(
        id: _uuid.v4(),
        name: 'Student Center',
        type: 'entrance',
        position: LatLng(center.latitude + 0.0005, center.longitude + 0.0005),
        floorId: '',
        description: 'Main student center',
        connectedFloors: [],
        buildingId: '',
        properties: {},
      ),
      Landmark(
        id: _uuid.v4(),
        name: 'Library',
        type: 'entrance',
        position: LatLng(center.latitude - 0.0005, center.longitude + 0.0005),
        floorId: '',
        description: 'Rivera Library',
        connectedFloors: [],
        buildingId: '',
        properties: {},
      ),
      Landmark(
        id: _uuid.v4(),
        name: 'Coffee Shop',
        type: 'restaurant',
        position: LatLng(center.latitude + 0.0008, center.longitude - 0.0003),
        floorId: '',
        description: 'Campus coffee shop',
        connectedFloors: [],
        buildingId: '',
        properties: {},
      ),
      Landmark(
        id: _uuid.v4(),
        name: 'Parking Structure',
        type: 'information',
        position: LatLng(center.latitude - 0.0008, center.longitude - 0.0008),
        floorId: '',
        description: 'Main parking structure',
        connectedFloors: [],
        buildingId: '',
        properties: {},
      ),
    ];

    // Create a sample building with multiple floors
    final building = _generateSampleBuilding(
      'Engineering Building',
      LatLng(center.latitude, center.longitude),
    );

    return RoadSystem(
      id: systemId,
      name: 'UC Riverside Campus',
      buildings: [building],
      outdoorRoads: roads,
      outdoorLandmarks: landmarks,
      outdoorIntersections: intersections,
      centerPosition: center,
      zoom: 16.0,
      properties: {},
    );
  }

  /// Generate a simple test network for debugging
  RoadSystem generateSimpleTestNetwork() {
    final systemId = _uuid.v4();
    final center = LatLng(33.9737, -117.3281);

    // Create 3 intersections in a line
    final int1 = Intersection(
      id: _uuid.v4(),
      name: 'Start Point',
      position: LatLng(center.latitude - 0.001, center.longitude),
      floorId: '',
      connectedRoadIds: [],
      type: 'simple',
      properties: {},
    );

    final int2 = Intersection(
      id: _uuid.v4(),
      name: 'Middle Point',
      position: center,
      floorId: '',
      connectedRoadIds: [],
      type: 'simple',
      properties: {},
    );

    final int3 = Intersection(
      id: _uuid.v4(),
      name: 'End Point',
      position: LatLng(center.latitude + 0.001, center.longitude),
      floorId: '',
      connectedRoadIds: [],
      type: 'simple',
      properties: {},
    );

    // Create roads connecting them
    final road1 = Road(
      id: _uuid.v4(),
      name: 'Main Street South',
      points: [int1.position, int2.position],
      type: 'road',
      width: 10.0,
      isOneWay: false,
      floorId: '',
      connectedIntersections: [int1.id, int2.id],
      properties: {},
    );

    final road2 = Road(
      id: _uuid.v4(),
      name: 'Main Street North',
      points: [int2.position, int3.position],
      type: 'road',
      width: 10.0,
      isOneWay: false,
      floorId: '',
      connectedIntersections: [int2.id, int3.id],
      properties: {},
    );

    // Create landmarks
    final startLandmark = Landmark(
      id: _uuid.v4(),
      name: 'Starting Location',
      type: 'entrance',
      position: int1.position,
      floorId: '',
      description: 'Start here',
      connectedFloors: [],
      buildingId: '',
      properties: {},
    );

    final endLandmark = Landmark(
      id: _uuid.v4(),
      name: 'Destination',
      type: 'office',
      position: int3.position,
      floorId: '',
      description: 'End here',
      connectedFloors: [],
      buildingId: '',
      properties: {},
    );

    return RoadSystem(
      id: systemId,
      name: 'Simple Test Network',
      buildings: [],
      outdoorRoads: [road1, road2],
      outdoorLandmarks: [startLandmark, endLandmark],
      outdoorIntersections: [int1, int2, int3],
      centerPosition: center,
      zoom: 16.0,
      properties: {},
    );
  }

  /// Generate a sample building with properly connected floors
  Building _generateSampleBuilding(String name, LatLng position) {
    final buildingId = _uuid.v4();

    // Create 3 floors
    final floors = <Floor>[];

    for (int level = 0; level < 3; level++) {
      final floorId = _uuid.v4();

      // Create intersections on this floor (4 corners)
      final intersections = <Intersection>[];
      final floorRoads = <Road>[];

      final corner1 = Intersection(
        id: _uuid.v4(),
        name: 'Corner NW',
        position: LatLng(position.latitude + 0.0001, position.longitude - 0.0001),
        floorId: floorId,
        connectedRoadIds: [],
        type: 'simple',
        properties: {},
      );

      final corner2 = Intersection(
        id: _uuid.v4(),
        name: 'Corner NE',
        position: LatLng(position.latitude + 0.0001, position.longitude + 0.0001),
        floorId: floorId,
        connectedRoadIds: [],
        type: 'simple',
        properties: {},
      );

      final corner3 = Intersection(
        id: _uuid.v4(),
        name: 'Corner SW',
        position: LatLng(position.latitude - 0.0001, position.longitude - 0.0001),
        floorId: floorId,
        connectedRoadIds: [],
        type: 'simple',
        properties: {},
      );

      final corner4 = Intersection(
        id: _uuid.v4(),
        name: 'Corner SE',
        position: LatLng(position.latitude - 0.0001, position.longitude + 0.0001),
        floorId: floorId,
        connectedRoadIds: [],
        type: 'simple',
        properties: {},
      );

      intersections.addAll([corner1, corner2, corner3, corner4]);

      // Create roads forming a rectangle
      floorRoads.add(Road(
        id: _uuid.v4(),
        name: 'Corridor North',
        points: [corner1.position, corner2.position],
        type: 'corridor',
        width: 3.0,
        isOneWay: false,
        floorId: floorId,
        connectedIntersections: [corner1.id, corner2.id],
        properties: {},
      ));

      floorRoads.add(Road(
        id: _uuid.v4(),
        name: 'Corridor East',
        points: [corner2.position, corner4.position],
        type: 'corridor',
        width: 3.0,
        isOneWay: false,
        floorId: floorId,
        connectedIntersections: [corner2.id, corner4.id],
        properties: {},
      ));

      floorRoads.add(Road(
        id: _uuid.v4(),
        name: 'Corridor South',
        points: [corner4.position, corner3.position],
        type: 'corridor',
        width: 3.0,
        isOneWay: false,
        floorId: floorId,
        connectedIntersections: [corner4.id, corner3.id],
        properties: {},
      ));

      floorRoads.add(Road(
        id: _uuid.v4(),
        name: 'Corridor West',
        points: [corner3.position, corner1.position],
        type: 'corridor',
        width: 3.0,
        isOneWay: false,
        floorId: floorId,
        connectedIntersections: [corner3.id, corner1.id],
        properties: {},
      ));

      // Create landmarks on this floor
      final landmarks = <Landmark>[];

      if (level == 0) {
        // Ground floor - add entrance
        landmarks.add(Landmark(
          id: _uuid.v4(),
          name: 'Main Entrance',
          type: 'entrance',
          position: LatLng(position.latitude - 0.0001, position.longitude),
          floorId: floorId,
          description: 'Building entrance',
          connectedFloors: [],
          buildingId: buildingId,
          properties: {},
        ));
      }

      // Add some rooms
      landmarks.add(Landmark(
        id: _uuid.v4(),
        name: 'Room ${level}01',
        type: 'classroom',
        position: LatLng(position.latitude + 0.00005, position.longitude - 0.00005),
        floorId: floorId,
        description: 'Classroom',
        connectedFloors: [],
        buildingId: buildingId,
        properties: {},
      ));

      landmarks.add(Landmark(
        id: _uuid.v4(),
        name: 'Room ${level}02',
        type: 'office',
        position: LatLng(position.latitude + 0.00005, position.longitude + 0.00005),
        floorId: floorId,
        description: 'Office',
        connectedFloors: [],
        buildingId: buildingId,
        properties: {},
      ));

      landmarks.add(Landmark(
        id: _uuid.v4(),
        name: 'Restroom',
        type: 'bathroom',
        position: LatLng(position.latitude - 0.00005, position.longitude - 0.00005),
        floorId: floorId,
        description: 'Restroom',
        connectedFloors: [],
        buildingId: buildingId,
        properties: {},
      ));

      // Add elevator (connects all floors)
      final connectedFloorIds = <String>[];
      // We'll update this after all floors are created

      landmarks.add(Landmark(
        id: _uuid.v4(),
        name: 'Elevator',
        type: 'elevator',
        position: position,
        floorId: floorId,
        description: 'Main elevator',
        connectedFloors: connectedFloorIds,
        buildingId: buildingId,
        properties: {},
      ));

      // Add stairs
      landmarks.add(Landmark(
        id: _uuid.v4(),
        name: 'Stairwell',
        type: 'stairs',
        position: LatLng(position.latitude, position.longitude + 0.00008),
        floorId: floorId,
        description: 'Emergency stairs',
        connectedFloors: connectedFloorIds,
        buildingId: buildingId,
        properties: {},
      ));

      final floor = Floor(
        id: floorId,
        name: level == 0 ? 'Ground Floor' : 'Floor $level',
        level: level,
        buildingId: buildingId,
        roads: floorRoads,
        landmarks: landmarks,
        intersections: intersections,
        connectedFloors: [],
        centerPosition: position,
        properties: {},
      );

      floors.add(floor);
    }

    // Update elevator and stairs connections
    final floorIds = floors.map((f) => f.id).toList();
    for (var floor in floors) {
      for (var landmark in floor.landmarks) {
        if (landmark.type == 'elevator' || landmark.type == 'stairs') {
          // Connect to all other floors
          final otherFloors =
              floorIds.where((id) => id != floor.id).toList();
          final updatedLandmark = Landmark(
            id: landmark.id,
            name: landmark.name,
            type: landmark.type,
            position: landmark.position,
            floorId: landmark.floorId,
            description: landmark.description,
            connectedFloors: otherFloors,
            buildingId: landmark.buildingId,
            properties: landmark.properties,
          );

          final landmarkIndex = floor.landmarks.indexOf(landmark);
          floor.landmarks[landmarkIndex] = updatedLandmark;
        }
      }
    }

    return Building(
      id: buildingId,
      name: name,
      centerPosition: position,
      boundaryPoints: [
        LatLng(position.latitude + 0.00015, position.longitude - 0.00015),
        LatLng(position.latitude + 0.00015, position.longitude + 0.00015),
        LatLng(position.latitude - 0.00015, position.longitude + 0.00015),
        LatLng(position.latitude - 0.00015, position.longitude - 0.00015),
      ],
      floors: floors,
      entranceFloorIds: [floors[0].id],
      defaultFloorLevel: 0,
      properties: {},
    );
  }
}
