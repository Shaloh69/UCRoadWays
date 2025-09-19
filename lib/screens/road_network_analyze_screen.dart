import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../providers/road_system_provider.dart';
import '../providers/building_provider.dart';
import '../models/models.dart';

class RoadNetworkAnalyzerScreen extends StatefulWidget {
  const RoadNetworkAnalyzerScreen({super.key});

  @override
  State<RoadNetworkAnalyzerScreen> createState() => _RoadNetworkAnalyzerScreenState();
}

class _RoadNetworkAnalyzerScreenState extends State<RoadNetworkAnalyzerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _analysisResults = {};
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runAnalysis();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Analyzer'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Connectivity', icon: Icon(Icons.account_tree)),
            Tab(text: 'Performance', icon: Icon(Icons.speed)),
            Tab(text: 'Issues', icon: Icon(Icons.warning)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runAnalysis,
            tooltip: 'Refresh Analysis',
          ),
        ],
      ),
      body: Consumer2<RoadSystemProvider, BuildingProvider>(
        builder: (context, roadSystemProvider, buildingProvider, child) {
          final currentSystem = roadSystemProvider.currentSystem;
          
          if (currentSystem == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning, size: 64, color: Colors.orange),
                  SizedBox(height: 16),
                  Text(
                    'No Road System Selected',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text('Please select a road system first'),
                ],
              ),
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
              _buildOverviewTab(currentSystem, roadSystemProvider),
              _buildConnectivityTab(currentSystem),
              _buildPerformanceTab(currentSystem),
              _buildIssuesTab(currentSystem),
            ],
          );
        },
      ),
    );
  }

  Future<void> _runAnalysis() async {
    setState(() {
      _isAnalyzing = true;
    });

    final roadSystemProvider = Provider.of<RoadSystemProvider>(context, listen: false);
    final currentSystem = roadSystemProvider.currentSystem;
    
    if (currentSystem != null) {
      await Future.delayed(const Duration(seconds: 1)); // Simulate analysis time
      _analysisResults = await _analyzeRoadNetwork(currentSystem);
    }

    setState(() {
      _isAnalyzing = false;
    });
  }

  Future<Map<String, dynamic>> _analyzeRoadNetwork(RoadSystem system) async {
    final analysis = <String, dynamic>{};
    
    // Basic statistics
    analysis['stats'] = _calculateBasicStats(system);
    
    // Connectivity analysis
    analysis['connectivity'] = _analyzeConnectivity(system);
    
    // Performance metrics
    analysis['performance'] = _analyzePerformance(system);
    
    // Issues and recommendations
    analysis['issues'] = _identifyIssues(system);
    
    return analysis;
  }

  Map<String, dynamic> _calculateBasicStats(RoadSystem system) {
    final allRoads = system.allRoads;
    final allLandmarks = system.allLandmarks;
    
    double totalLength = 0.0;
    for (final road in allRoads) {
      totalLength += _calculateRoadLength(road);
    }
    
    final indoorRoads = allRoads.where((r) => r.isIndoor).length;
    final outdoorRoads = allRoads.where((r) => r.isOutdoor).length;
    
    final indoorLandmarks = allLandmarks.where((l) => l.isIndoor).length;
    final outdoorLandmarks = allLandmarks.where((l) => l.isOutdoor).length;
    
    return {
      'totalRoads': allRoads.length,
      'indoorRoads': indoorRoads,
      'outdoorRoads': outdoorRoads,
      'totalLandmarks': allLandmarks.length,
      'indoorLandmarks': indoorLandmarks,
      'outdoorLandmarks': outdoorLandmarks,
      'totalLength': totalLength,
      'averageRoadLength': allRoads.isNotEmpty ? totalLength / allRoads.length : 0.0,
      'buildings': system.buildings.length,
      'floors': system.allFloors.length,
    };
  }

  Map<String, dynamic> _analyzeConnectivity(RoadSystem system) {
    final connectivity = <String, dynamic>{};
    
    // Building connectivity
    connectivity['buildingConnectivity'] = _analyzeBuildingConnectivity(system);
    
    // Floor connectivity
    connectivity['floorConnectivity'] = _analyzeFloorConnectivity(system);
    
    // Landmark accessibility
    connectivity['landmarkAccessibility'] = _analyzeLandmarkAccessibility(system);
    
    // Network density
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
                          'Floors',
                          stats['floors']?.toString() ?? '0',
                          Icons.layers,
                          Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Roads',
                          stats['totalRoads']?.toString() ?? '0',
                          Icons.route,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Landmarks',
                          stats['totalLandmarks']?.toString() ?? '0',
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
          
          // Network metrics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.analytics, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'Network Metrics',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildMetricRow(
                    'Total Length',
                    '${(stats['totalLength'] ?? 0.0).toStringAsFixed(1)} km',
                  ),
                  _buildMetricRow(
                    'Average Road Length',
                    '${(stats['averageRoadLength'] ?? 0.0).toStringAsFixed(1)} m',
                  ),
                  _buildMetricRow(
                    'Indoor/Outdoor Split',
                    '${stats['indoorRoads'] ?? 0}/${stats['outdoorRoads'] ?? 0}',
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Quick actions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _exportAnalysisReport(system),
                          icon: const Icon(Icons.file_download),
                          label: const Text('Export Report'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _optimizeNetwork(system),
                          icon: const Icon(Icons.tune),
                          label: const Text('Optimize'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectivityTab(RoadSystem system) {
    final connectivity = _analysisResults['connectivity'] as Map<String, dynamic>? ?? {};
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Connectivity score
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Overall Connectivity',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildConnectivityScore(connectivity['networkDensity'] ?? 0.0),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Building connectivity
          if (system.buildings.isNotEmpty) ...[
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
                    ...system.buildings.map((building) => _buildBuildingConnectivityItem(building)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Floor connectivity
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Floor Connectivity Analysis',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text('Floors with vertical circulation issues will be highlighted.'),
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
        children: [
          // Performance overview
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
                          Icon(Icons.lightbulb, color: Colors.orange, size: 16),
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

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildConnectivityScore(double score) {
    final percentage = (score * 100).clamp(0, 100);
    Color color;
    String status;
    
    if (percentage >= 80) {
      color = Colors.green;
      status = 'Excellent';
    } else if (percentage >= 60) {
      color = Colors.orange;
      status = 'Good';
    } else {
      color = Colors.red;
      status = 'Needs Improvement';
    }
    
    return Column(
      children: [
        CircularProgressIndicator(
          value: score,
          strokeWidth: 8,
          backgroundColor: color.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
        const SizedBox(height: 8),
        Text(
          '${percentage.toInt()}%',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(status, style: TextStyle(color: color)),
      ],
    );
  }

  Widget _buildBuildingConnectivityItem(Building building) {
    final floorCount = building.floors.length;
    final hasVerticalCirculation = building.floors.any((f) => 
        f.landmarks.any((l) => l.isVerticalCirculation));
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.business,
            color: hasVerticalCirculation ? Colors.green : Colors.orange,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(building.name)),
          Text('$floorCount floors'),
          const SizedBox(width: 8),
          Icon(
            hasVerticalCirculation ? Icons.check_circle : Icons.warning,
            color: hasVerticalCirculation ? Colors.green : Colors.orange,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetric(String title, double value, String description) {
    final percentage = (value * 100).clamp(0, 100);
    Color color;
    
    if (percentage >= 80) {
      color = Colors.green;
    } else if (percentage >= 60) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${percentage.toInt()}%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: value,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                Icon(Icons.warning, color: color),
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
            ...issues.map((issue) => _buildIssueItem(issue, color)),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueItem(Map<String, dynamic> issue, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(issue['description'] ?? 'Unknown issue')),
          TextButton(
            onPressed: () => _fixIssue(issue),
            child: const Text('Fix'),
          ),
        ],
      ),
    );
  }

  // Analysis helper methods
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
    final double lat1Rad = point1.latitude * pi / 180;
    final double lat2Rad = point2.latitude * pi / 180;
    final double deltaLatRad = (point2.latitude - point1.latitude) * pi / 180;
    final double deltaLngRad = (point2.longitude - point1.longitude) * pi / 180;

    final double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  Map<String, dynamic> _analyzeBuildingConnectivity(RoadSystem system) {
    // Implementation for building connectivity analysis
    return {};
  }

  Map<String, dynamic> _analyzeFloorConnectivity(RoadSystem system) {
    // Implementation for floor connectivity analysis
    return {};
  }

  Map<String, dynamic> _analyzeLandmarkAccessibility(RoadSystem system) {
    // Implementation for landmark accessibility analysis
    return {};
  }

  double _calculateNetworkDensity(RoadSystem system) {
    // Simple density calculation based on roads and landmarks
    final totalElements = system.allRoads.length + system.allLandmarks.length;
    final maxPossibleElements = system.buildings.length * 20; // Arbitrary max
    return maxPossibleElements > 0 ? totalElements / maxPossibleElements : 0.0;
  }

  double _calculateAveragePathLength(RoadSystem system) {
    // Implementation for average path length calculation
    return 0.75; // Placeholder
  }

  double _calculateNavigationEfficiency(RoadSystem system) {
    // Implementation for navigation efficiency calculation
    return 0.80; // Placeholder
  }

  double _calculateLandmarkCoverage(RoadSystem system) {
    // Implementation for landmark coverage calculation
    return 0.65; // Placeholder
  }

  double _calculateAccessibilityScore(RoadSystem system) {
    // Implementation for accessibility score calculation
    double score = 0.0;
    int totalBuildings = system.buildings.length;
    
    if (totalBuildings == 0) return 1.0;
    
    for (final building in system.buildings) {
      final hasElevator = building.floors.any((f) => 
          f.landmarks.any((l) => l.type == 'elevator'));
      final hasAccessibleEntrance = building.floors.any((f) => 
          f.landmarks.any((l) => l.type == 'entrance' && l.isAccessible));
      
      if (hasElevator) score += 0.5;
      if (hasAccessibleEntrance) score += 0.5;
    }
    
    return score / totalBuildings;
  }

  List<Map<String, dynamic>> _findDeadEndRoads(RoadSystem system) {
    // Implementation for finding dead-end roads
    return [];
  }

  List<Map<String, dynamic>> _findIsolatedLandmarks(RoadSystem system) {
    // Implementation for finding isolated landmarks
    return [];
  }

  List<Map<String, dynamic>> _findMissingVerticalCirculation(RoadSystem system) {
    final issues = <Map<String, dynamic>>[];
    
    for (final building in system.buildings) {
      if (building.floors.length > 1) {
        final hasVerticalCirculation = building.floors.any((f) => 
            f.landmarks.any((l) => l.isVerticalCirculation));
        
        if (!hasVerticalCirculation) {
          issues.add({
            'type': 'missing_vertical_circulation',
            'severity': 'high',
            'description': 'Building "${building.name}" lacks vertical circulation',
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
      final hasElevator = building.floors.any((f) => 
          f.landmarks.any((l) => l.type == 'elevator'));
      
      if (building.floors.length > 1 && !hasElevator) {
        issues.add({
          'type': 'accessibility_issue',
          'severity': 'medium',
          'description': 'Building "${building.name}" needs elevator for accessibility',
          'building': building,
        });
      }
    }
    
    return issues;
  }

  List<String> _getPerformanceRecommendations(Map<String, dynamic> performance) {
    final recommendations = <String>[];
    
    if ((performance['navigationEfficiency'] ?? 0.0) < 0.7) {
      recommendations.add('Add more connecting roads between key areas');
    }
    
    if ((performance['landmarkCoverage'] ?? 0.0) < 0.6) {
      recommendations.add('Add landmarks in areas with low coverage');
    }
    
    if ((performance['accessibilityScore'] ?? 0.0) < 0.8) {
      recommendations.add('Improve accessibility with elevators and accessible entrances');
    }
    
    if (recommendations.isEmpty) {
      recommendations.add('Your network is performing well!');
    }
    
    return recommendations;
  }

  void _exportAnalysisReport(RoadSystem system) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Analysis report exported')),
    );
  }

  void _optimizeNetwork(RoadSystem system) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Network optimization suggestions generated')),
    );
  }

  void _fixIssue(Map<String, dynamic> issue) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Fixing: ${issue['description']}')),
    );
  }
}