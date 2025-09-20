import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../models/models.dart';
import '../providers/road_system_provider.dart';
import '../providers/building_provider.dart';

class RoadNetworkAnalyzeScreen extends StatefulWidget {
  const RoadNetworkAnalyzeScreen({super.key});

  @override
  State<RoadNetworkAnalyzeScreen> createState() => _RoadNetworkAnalyzeScreenState();
}

class _RoadNetworkAnalyzeScreenState extends State<RoadNetworkAnalyzeScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _analysisResults = {};
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performAnalysis();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _performAnalysis() async {
    final roadSystemProvider = Provider.of<RoadSystemProvider>(context, listen: false);
    final currentSystem = roadSystemProvider.currentSystem;

    if (currentSystem == null) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      // Simulate analysis delay for better UX
      await Future.delayed(const Duration(milliseconds: 500));

      final results = {
        'stats': _analyzeStats(currentSystem),
        'connectivity': _analyzeConnectivity(currentSystem),
        'performance': _analyzePerformance(currentSystem),
        'issues': _identifyIssues(currentSystem),
      };

      if (mounted) {
        setState(() {
          _analysisResults = results;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      debugPrint('Analysis error: $e');
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _performAnalysis,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'Overview'),
            Tab(icon: Icon(Icons.connect_without_contact), text: 'Connectivity'),
            Tab(icon: Icon(Icons.speed), text: 'Performance'),
            Tab(icon: Icon(Icons.warning), text: 'Issues'),
          ],
        ),
      ),
      body: Consumer<RoadSystemProvider>(
        builder: (context, provider, child) {
          final currentSystem = provider.currentSystem;

          if (currentSystem == null) {
            return const Center(
              child: Text('No road system selected'),
            );
          }

          if (_isAnalyzing) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analyzing road network...'),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(currentSystem, provider),
              _buildConnectivityTab(currentSystem),
              _buildPerformanceTab(currentSystem),
              _buildIssuesTab(currentSystem),
            ],
          );
        },
      ),
    );
  }

  Map<String, dynamic> _analyzeStats(RoadSystem system) {
    final allRoads = system.allRoads;
    final allLandmarks = system.allLandmarks;
    final allFloors = system.allFloors;
    
    double totalLength = 0.0;
    for (final road in allRoads) {
      totalLength += _calculateRoadLength(road);
    }

    // Calculate landmark distribution by type
    final landmarkTypes = <String, int>{};
    for (final landmark in allLandmarks) {
      landmarkTypes[landmark.type] = (landmarkTypes[landmark.type] ?? 0) + 1;
    }

    // Calculate building size distribution
    final buildingSizes = <String, int>{};
    for (final building in system.buildings) {
      if (building.floors.length == 1) buildingSizes['small'] = (buildingSizes['small'] ?? 0) + 1;
      else if (building.floors.length <= 3) buildingSizes['medium'] = (buildingSizes['medium'] ?? 0) + 1;
      else buildingSizes['large'] = (buildingSizes['large'] ?? 0) + 1;
    }

    return {
      'totalRoadLength': totalLength,
      'averageRoadLength': allRoads.isNotEmpty ? totalLength / allRoads.length : 0.0,
      'buildings': system.buildings.length,
      'floors': allFloors.length,
      'roads': allRoads.length,
      'landmarks': allLandmarks.length,
      'landmarkTypes': landmarkTypes,
      'buildingSizes': buildingSizes,
      'outdoorRoads': system.outdoorRoads.length,
      'indoorRoads': allRoads.length - system.outdoorRoads.length,
    };
  }

  Map<String, dynamic> _analyzeConnectivity(RoadSystem system) {
    final connectivity = <String, dynamic>{};
    
    // Building connectivity analysis
    connectivity['buildingConnectivity'] = _analyzeBuildingConnectivity(system);
    
    // Floor connectivity analysis  
    connectivity['floorConnectivity'] = _analyzeFloorConnectivity(system);
    
    // Landmark accessibility analysis
    connectivity['landmarkAccessibility'] = _analyzeLandmarkAccessibility(system);
    
    // Network density calculation
    connectivity['networkDensity'] = _calculateNetworkDensity(system);
    
    return connectivity;
  }

  Map<String, dynamic> _analyzePerformance(RoadSystem system) {
    return {
      'averagePathLength': _calculateAveragePathLength(system),
      'navigationEfficiency': _calculateNavigationEfficiency(system),
      'landmarkCoverage': _calculateLandmarkCoverage(system),
      'accessibilityScore': _calculateAccessibilityScore(system),
    };
  }

  List<Map<String, dynamic>> _identifyIssues(RoadSystem system) {
    final issues = <Map<String, dynamic>>[];
    
    // Dead-end roads
    issues.addAll(_findDeadEndRoads(system));
    
    // Isolated landmarks
    issues.addAll(_findIsolatedLandmarks(system));
    
    // Missing vertical circulation
    issues.addAll(_findMissingVerticalCirculation(system));
    
    // Accessibility issues
    issues.addAll(_findAccessibilityIssues(system));
    
    return issues;
  }

  // FIXED IMPLEMENTATION METHODS
  
  double _calculateAveragePathLength(RoadSystem system) {
    final allRoads = system.allRoads;
    if (allRoads.isEmpty) return 0.0;
    
    double totalLength = 0.0;
    int pathCount = 0;
    
    for (final road in allRoads) {
      for (int i = 0; i < road.points.length - 1; i++) {
        totalLength += _calculateDistance(road.points[i], road.points[i + 1]);
        pathCount++;
      }
    }
    
    return pathCount > 0 ? totalLength / pathCount : 0.0;
  }

  double _calculateNavigationEfficiency(RoadSystem system) {
    // Calculate based on direct path vs available path ratios
    final landmarks = system.allLandmarks;
    if (landmarks.length < 2) return 1.0;
    
    double totalEfficiency = 0.0;
    int pairCount = 0;
    
    for (int i = 0; i < landmarks.length; i++) {
      for (int j = i + 1; j < landmarks.length && pairCount < 10; j++) {
        final directDistance = _calculateDistance(landmarks[i].position, landmarks[j].position);
        final pathDistance = _estimatePathDistance(landmarks[i], landmarks[j], system);
        
        if (pathDistance > 0) {
          totalEfficiency += directDistance / pathDistance;
          pairCount++;
        }
      }
    }
    
    return pairCount > 0 ? (totalEfficiency / pairCount).clamp(0.0, 1.0) : 0.5;
  }

  double _calculateLandmarkCoverage(RoadSystem system) {
    final allRoads = system.allRoads;
    final allLandmarks = system.allLandmarks;
    
    if (allRoads.isEmpty || allLandmarks.isEmpty) return 0.0;
    
    int coveredRoadSegments = 0;
    int totalRoadSegments = 0;
    
    for (final road in allRoads) {
      for (int i = 0; i < road.points.length - 1; i++) {
        totalRoadSegments++;
        final segmentMidpoint = LatLng(
          (road.points[i].latitude + road.points[i + 1].latitude) / 2,
          (road.points[i].longitude + road.points[i + 1].longitude) / 2,
        );
        
        // Check if any landmark is within 50 meters of this segment
        final isNearLandmark = allLandmarks.any((landmark) =>
            _calculateDistance(landmark.position, segmentMidpoint) <= 50);
        
        if (isNearLandmark) coveredRoadSegments++;
      }
    }
    
    return totalRoadSegments > 0 ? coveredRoadSegments / totalRoadSegments : 0.0;
  }

  double _calculateAccessibilityScore(RoadSystem system) {
    if (system.buildings.isEmpty) return 1.0;
    
    double totalScore = 0.0;
    
    for (final building in system.buildings) {
      double buildingScore = 0.0;
      
      // Check for elevator
      final hasElevator = building.floors.any((f) => 
          f.landmarks.any((l) => l.type == 'elevator'));
      if (hasElevator || building.floors.length == 1) buildingScore += 0.4;
      
      // Check for accessible entrance
      final hasAccessibleEntrance = building.floors.any((f) => 
          f.landmarks.any((l) => l.type == 'entrance' && (l.properties['accessible'] == true)));
      if (hasAccessibleEntrance) buildingScore += 0.3;
      
      // Check for accessibility features
      final hasAccessibilityLandmarks = building.floors.any((f) => 
          f.landmarks.any((l) => ['ramp', 'accessible_restroom', 'accessible_parking'].contains(l.type)));
      if (hasAccessibilityLandmarks) buildingScore += 0.3;
      
      totalScore += buildingScore;
    }
    
    return totalScore / system.buildings.length;
  }

  List<Map<String, dynamic>> _findDeadEndRoads(RoadSystem system) {
    final issues = <Map<String, dynamic>>[];
    final allRoads = system.allRoads;
    
    for (final road in allRoads) {
      if (road.connectedIntersections.isEmpty) {
        issues.add({
          'type': 'dead_end_road',
          'severity': 'medium',
          'description': 'Road "${road.name}" is not connected to any intersections',
          'road': road,
        });
      }
    }
    
    return issues;
  }

  List<Map<String, dynamic>> _findIsolatedLandmarks(RoadSystem system) {
    final issues = <Map<String, dynamic>>[];
    final allLandmarks = system.allLandmarks;
    final allRoads = system.allRoads;
    
    for (final landmark in allLandmarks) {
      // Check if landmark is near any road (within 30 meters)
      final isNearRoad = allRoads.any((road) =>
          road.points.any((point) => 
              _calculateDistance(landmark.position, point) <= 30));
      
      if (!isNearRoad) {
        issues.add({
          'type': 'isolated_landmark',
          'severity': 'low',
          'description': 'Landmark "${landmark.name}" is not connected to road network',
          'landmark': landmark,
        });
      }
    }
    
    return issues;
  }

  List<Map<String, dynamic>> _findMissingVerticalCirculation(RoadSystem system) {
    final issues = <Map<String, dynamic>>[];
    
    for (final building in system.buildings) {
      if (building.floors.length > 1) {
        final hasVerticalCirculation = building.floors.any((f) => 
            f.landmarks.any((l) => ['elevator', 'stairs', 'escalator'].contains(l.type)));
        
        if (!hasVerticalCirculation) {
          issues.add({
            'type': 'missing_vertical_circulation',
            'severity': 'high',
            'description': 'Building "${building.name}" lacks vertical circulation between floors',
            'building': building,
          });
        }
      }
    }
    
    return issues;
  }

  List<Map<String, dynamic>> _findAccessibilityIssues(RoadSystem system) {
    final issues = <Map<String, dynamic>>[];
    
    for (final building in system.buildings) {
      if (building.floors.length > 1) {
        final hasElevator = building.floors.any((f) => 
            f.landmarks.any((l) => l.type == 'elevator'));
        
        if (!hasElevator) {
          issues.add({
            'type': 'accessibility_issue',
            'severity': 'medium',
            'description': 'Multi-floor building "${building.name}" needs elevator for accessibility',
            'building': building,
          });
        }
      }
      
      // Check for accessible entrances
      final hasAccessibleEntrance = building.floors.any((f) => 
          f.landmarks.any((l) => l.type == 'entrance' && (l.properties['accessible'] == true)));
      
      if (!hasAccessibleEntrance) {
        issues.add({
          'type': 'missing_accessible_entrance',
          'severity': 'medium',
          'description': 'Building "${building.name}" lacks marked accessible entrance',
          'building': building,
        });
      }
    }
    
    return issues;
  }

  // CONNECTIVITY ANALYSIS IMPLEMENTATIONS

  Map<String, dynamic> _analyzeBuildingConnectivity(RoadSystem system) {
    final connectivity = <String, dynamic>{};
    final buildings = system.buildings;
    
    int connectedBuildings = 0;
    int totalConnections = 0;
    
    for (final building in buildings) {
      final nearbyRoads = system.outdoorRoads.where((road) =>
          road.points.any((point) => 
              _calculateDistance(point, building.centerPosition) <= 100)).toList();
      
      if (nearbyRoads.isNotEmpty) {
        connectedBuildings++;
        totalConnections += nearbyRoads.length;
      }
    }
    
    connectivity['connectedBuildings'] = connectedBuildings;
    connectivity['totalBuildings'] = buildings.length;
    connectivity['connectionRatio'] = buildings.isNotEmpty ? connectedBuildings / buildings.length : 0.0;
    connectivity['averageConnections'] = connectedBuildings > 0 ? totalConnections / connectedBuildings : 0.0;
    
    return connectivity;
  }

  Map<String, dynamic> _analyzeFloorConnectivity(RoadSystem system) {
    final connectivity = <String, dynamic>{};
    
    int connectedFloors = 0;
    int totalFloors = 0;
    final isolatedFloors = <Floor>[];
    
    for (final building in system.buildings) {
      for (final floor in building.floors) {
        totalFloors++;
        
        // Check if floor has vertical circulation landmarks
        final hasVerticalCirculation = floor.landmarks.any((l) => 
            ['elevator', 'stairs', 'escalator'].contains(l.type));
        
        // Check if floor is connected via connectedFloors property
        final hasFloorConnections = floor.connectedFloors.isNotEmpty;
        
        if (hasVerticalCirculation || hasFloorConnections || floor.level == 0) {
          connectedFloors++;
        } else {
          isolatedFloors.add(floor);
        }
      }
    }
    
    connectivity['connectedFloors'] = connectedFloors;
    connectivity['totalFloors'] = totalFloors;
    connectivity['isolatedFloors'] = isolatedFloors;
    connectivity['connectivityRatio'] = totalFloors > 0 ? connectedFloors / totalFloors : 1.0;
    
    return connectivity;
  }

  Map<String, dynamic> _analyzeLandmarkAccessibility(RoadSystem system) {
    final accessibility = <String, dynamic>{};
    final allLandmarks = system.allLandmarks;
    
    int accessibleLandmarks = 0;
    final accessibilityByType = <String, Map<String, int>>{};
    
    for (final landmark in allLandmarks) {
      final type = landmark.type;
      accessibilityByType[type] ??= {'total': 0, 'accessible': 0};
      accessibilityByType[type]!['total'] = accessibilityByType[type]!['total']! + 1;
      
      // Consider landmark accessible if:
      // 1. It's on ground floor, OR
      // 2. Building has elevator, OR  
      // 3. It's marked as accessible
      final floor = _getFloorForLandmark(landmark, system);
      final building = _getBuildingForLandmark(landmark, system);
      
      bool isAccessible = false;
      
      if (floor != null && building != null) {
        if (floor.level == 0) {
          isAccessible = true;
        } else {
          final buildingHasElevator = building.floors.any((f) => 
              f.landmarks.any((l) => l.type == 'elevator'));
          isAccessible = buildingHasElevator;
        }
      }
      
      if (landmark.properties['accessible'] == true) {
        isAccessible = true;
      }
      
      if (isAccessible) {
        accessibleLandmarks++;
        accessibilityByType[type]!['accessible'] = accessibilityByType[type]!['accessible']! + 1;
      }
    }
    
    accessibility['accessibleLandmarks'] = accessibleLandmarks;
    accessibility['totalLandmarks'] = allLandmarks.length;
    accessibility['accessibilityRatio'] = allLandmarks.isNotEmpty ? accessibleLandmarks / allLandmarks.length : 1.0;
    accessibility['byType'] = accessibilityByType;
    
    return accessibility;
  }

  double _calculateNetworkDensity(RoadSystem system) {
    final totalElements = system.allRoads.length + system.allLandmarks.length + system.buildings.length;
    
    // Calculate approximate coverage area based on building positions
    if (system.buildings.isEmpty) return 0.0;
    
    double minLat = system.buildings.first.centerPosition.latitude;
    double maxLat = system.buildings.first.centerPosition.latitude;
    double minLng = system.buildings.first.centerPosition.longitude;
    double maxLng = system.buildings.first.centerPosition.longitude;
    
    for (final building in system.buildings) {
      final pos = building.centerPosition;
      minLat = math.min(minLat, pos.latitude);
      maxLat = math.max(maxLat, pos.latitude);
      minLng = math.min(minLng, pos.longitude);
      maxLng = math.max(maxLng, pos.longitude);
    }
    
    // Calculate area in square meters (approximate)
    final latDistance = _calculateDistance(LatLng(minLat, minLng), LatLng(maxLat, minLng));
    final lngDistance = _calculateDistance(LatLng(minLat, minLng), LatLng(minLat, maxLng));
    final area = latDistance * lngDistance;
    
    return area > 0 ? totalElements / area * 10000 : 0.0; // Elements per hectare
  }

  // HELPER METHODS

  double _calculateRoadLength(Road road) {
    if (road.points.length < 2) return 0.0;
    
    double length = 0.0;
    for (int i = 0; i < road.points.length - 1; i++) {
      length += _calculateDistance(road.points[i], road.points[i + 1]);
    }
    return length / 1000; // Convert to kilometers
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // meters
    final double lat1Rad = point1.latitude * math.pi / 180;
    final double lat2Rad = point2.latitude * math.pi / 180;
    final double deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180;
    final double deltaLngRad = (point2.longitude - point1.longitude) * math.pi / 180;

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _estimatePathDistance(Landmark start, Landmark end, RoadSystem system) {
    // Simple estimation based on Manhattan distance with road network
    final directDistance = _calculateDistance(start.position, end.position);
    return directDistance * 1.3; // Assume 30% longer path due to road network
  }

  Floor? _getFloorForLandmark(Landmark landmark, RoadSystem system) {
    for (final building in system.buildings) {
      for (final floor in building.floors) {
        if (floor.landmarks.any((l) => l.id == landmark.id)) {
          return floor;
        }
      }
    }
    return null;
  }

  Building? _getBuildingForLandmark(Landmark landmark, RoadSystem system) {
    for (final building in system.buildings) {
      if (building.floors.any((floor) => 
          floor.landmarks.any((l) => l.id == landmark.id))) {
        return building;
      }
    }
    return null;
  }

  List<String> _getPerformanceRecommendations(Map<String, dynamic> performance) {
    final recommendations = <String>[];
    
    if ((performance['navigationEfficiency'] ?? 0.0) < 0.7) {
      recommendations.add('Consider adding more direct paths between key landmarks');
    }
    
    if ((performance['landmarkCoverage'] ?? 0.0) < 0.6) {
      recommendations.add('Add more landmarks to improve wayfinding coverage');
    }
    
    if ((performance['accessibilityScore'] ?? 0.0) < 0.8) {
      recommendations.add('Improve accessibility by adding elevators and accessible entrances');
    }
    
    if ((performance['averagePathLength'] ?? 0.0) > 100) {
      recommendations.add('Long path segments detected - consider adding intermediate landmarks');
    }
    
    if (recommendations.isEmpty) {
      recommendations.add('Network performance looks good! Continue maintaining current standards.');
    }
    
    return recommendations;
  }

  // UI BUILDER METHODS

  Widget _buildOverviewTab(RoadSystem system, RoadSystemProvider provider) {
    final stats = _analysisResults['stats'] as Map<String, dynamic>? ?? {};
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System overview card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.map, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        system.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Buildings',
                          stats['buildings']?.toString() ?? '0',
                          Icons.business,
                          Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Roads',
                          stats['roads']?.toString() ?? '0',
                          Icons.route,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Landmarks',
                          stats['landmarks']?.toString() ?? '0',
                          Icons.place,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Road network stats
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Road Network',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Length',
                          '${(stats['totalRoadLength'] ?? 0.0).toStringAsFixed(2)} km',
                          Icons.straighten,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Outdoor',
                          stats['outdoorRoads']?.toString() ?? '0',
                          Icons.landscape,
                          Colors.brown,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Indoor',
                          stats['indoorRoads']?.toString() ?? '0',
                          Icons.home,
                          Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Landmark distribution
          if ((stats['landmarkTypes'] as Map<String, int>?)?.isNotEmpty == true) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Landmark Distribution',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...(stats['landmarkTypes'] as Map<String, int>).entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key.replaceAll('_', ' ').toUpperCase()),
                            Text(
                              entry.value.toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectivityTab(RoadSystem system) {
    final connectivity = _analysisResults['connectivity'] as Map<String, dynamic>? ?? {};
    final buildingConn = connectivity['buildingConnectivity'] as Map<String, dynamic>? ?? {};
    final floorConn = connectivity['floorConnectivity'] as Map<String, dynamic>? ?? {};
    final landmarkAcc = connectivity['landmarkAccessibility'] as Map<String, dynamic>? ?? {};
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Building connectivity
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Building Connectivity',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (buildingConn['connectionRatio'] ?? 0.0) as double,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getScoreColor((buildingConn['connectionRatio'] ?? 0.0) as double),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${buildingConn['connectedBuildings'] ?? 0}/${buildingConn['totalBuildings'] ?? 0} buildings connected to road network',
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Floor connectivity
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Floor Connectivity',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (floorConn['connectivityRatio'] ?? 1.0) as double,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getScoreColor((floorConn['connectivityRatio'] ?? 1.0) as double),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${floorConn['connectedFloors'] ?? 0}/${floorConn['totalFloors'] ?? 0} floors accessible',
                  ),
                  if ((floorConn['isolatedFloors'] as List?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Isolated floors: ${(floorConn['isolatedFloors'] as List).length}',
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Landmark accessibility
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Landmark Accessibility',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (landmarkAcc['accessibilityRatio'] ?? 1.0) as double,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getScoreColor((landmarkAcc['accessibilityRatio'] ?? 1.0) as double),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${landmarkAcc['accessibleLandmarks'] ?? 0}/${landmarkAcc['totalLandmarks'] ?? 0} landmarks accessible',
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Network density
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Network Density',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${(connectivity['networkDensity'] ?? 0.0).toStringAsFixed(2)} elements/hectare',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab(RoadSystem system) {
    final performance = _analysisResults['performance'] as Map<String, dynamic>? ?? {};
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Performance metrics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Performance Metrics',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildPerformanceMetric(
                    'Average Path Length',
                    (performance['averagePathLength'] ?? 0.0) / 100, // Normalize for display
                    'Average distance between connected points',
                  ),
                  _buildPerformanceMetric(
                    'Navigation Efficiency',
                    performance['navigationEfficiency'] ?? 0.0,
                    'How efficiently users can navigate between points',
                  ),
                  _buildPerformanceMetric(
                    'Landmark Coverage',
                    performance['landmarkCoverage'] ?? 0.0,
                    'Percentage of areas covered by landmarks',
                  ),
                  _buildPerformanceMetric(
                    'Accessibility Score',
                    performance['accessibilityScore'] ?? 0.0,
                    'Overall accessibility rating',
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Recommendations
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recommendations',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...(_getPerformanceRecommendations(performance)).map(
                    (rec) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb, color: Colors.orange, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(rec)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssuesTab(RoadSystem system) {
    final issues = _analysisResults['issues'] as List<Map<String, dynamic>>? ?? [];
    
    if (issues.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'No Issues Found!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            Text('Your road network looks good'),
          ],
        ),
      );
    }

    // Group issues by severity
    final highPriority = issues.where((i) => i['severity'] == 'high').toList();
    final mediumPriority = issues.where((i) => i['severity'] == 'medium').toList();
    final lowPriority = issues.where((i) => i['severity'] == 'low').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Issues summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Issues Found',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('${issues.length} issues need attention'),
                      ],
                    ),
                  ),
                  Text(
                    '${highPriority.length} High\n${mediumPriority.length} Medium\n${lowPriority.length} Low',
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // High priority issues
          if (highPriority.isNotEmpty) ...[
            _buildIssuesSection('High Priority', highPriority, Colors.red),
            const SizedBox(height: 16),
          ],
          
          // Medium priority issues
          if (mediumPriority.isNotEmpty) ...[
            _buildIssuesSection('Medium Priority', mediumPriority, Colors.orange),
            const SizedBox(height: 16),
          ],
          
          // Low priority issues
          if (lowPriority.isNotEmpty) ...[
            _buildIssuesSection('Low Priority', lowPriority, Colors.yellow[700]!),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetric(String title, double value, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(
                '${(value * 100).toInt()}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getScoreColor(value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(value)),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildIssuesSection(String title, List<Map<String, dynamic>> issues, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.priority_high, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...issues.map((issue) => _buildIssueItem(issue)),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueItem(Map<String, dynamic> issue) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Icon(
          _getIssueIcon(issue['type']),
          color: _getSeverityColor(issue['severity']),
          size: 20,
        ),
        title: Text(issue['description'] ?? 'Unknown issue'),
        trailing: TextButton(
          onPressed: () => _fixIssue(issue),
          child: const Text('Fix'),
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.orange;
    return Colors.red;
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'high': return Colors.red;
      case 'medium': return Colors.orange;
      case 'low': return Colors.yellow[700]!;
      default: return Colors.grey;
    }
  }

  IconData _getIssueIcon(String type) {
    switch (type) {
      case 'dead_end_road': return Icons.block;
      case 'isolated_landmark': return Icons.location_disabled;
      case 'missing_vertical_circulation': return Icons.elevator;
      case 'accessibility_issue': return Icons.accessible;
      case 'missing_accessible_entrance': return Icons.meeting_room;
      default: return Icons.warning;
    }
  }

  void _fixIssue(Map<String, dynamic> issue) {
    // TODO: Implement issue fixing functionality
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fix Issue'),
        content: Text('Fixing: ${issue['description']}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}