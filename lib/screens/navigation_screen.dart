import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../providers/location_provider.dart';
import '../providers/road_system_provider.dart';
import '../providers/building_provider.dart';
import '../models/models.dart';
import '../services/navigation_service.dart';
import 'dart:math';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  LatLng? _startPoint;
  LatLng? _endPoint;
  String? _startDescription;
  String? _endDescription;
  NavigationRoute? _currentRoute;
  bool _isCalculatingRoute = false;
  
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Route', icon: Icon(Icons.directions)),
            Tab(text: 'Search', icon: Icon(Icons.search)),
            Tab(text: 'History', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRouteTab(),
          _buildSearchTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildRouteTab() {
    return Consumer3<LocationProvider, RoadSystemProvider, BuildingProvider>(
      builder: (context, locationProvider, roadSystemProvider, buildingProvider, child) {
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
                Text('Please select a road system to use navigation'),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Route input section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Plan Your Route',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      
                      // Start point
                      Row(
                        children: [
                          const Icon(Icons.my_location, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _startController,
                              decoration: InputDecoration(
                                hintText: 'Starting point',
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.gps_fixed),
                                      onPressed: () => _useCurrentLocation(true),
                                      tooltip: 'Use current location',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.place),
                                      onPressed: () => _selectFromMap(true),
                                      tooltip: 'Select on map',
                                    ),
                                  ],
                                ),
                              ),
                              readOnly: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // End point
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _endController,
                              decoration: InputDecoration(
                                hintText: 'Destination',
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.search),
                                      onPressed: () => _showLandmarkPicker(false),
                                      tooltip: 'Search landmarks',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.place),
                                      onPressed: () => _selectFromMap(false),
                                      tooltip: 'Select on map',
                                    ),
                                  ],
                                ),
                              ),
                              readOnly: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Calculate route button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _canCalculateRoute() && !_isCalculatingRoute
                              ? _calculateRoute
                              : null,
                          icon: _isCalculatingRoute
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.directions),
                          label: Text(_isCalculatingRoute ? 'Calculating...' : 'Calculate Route'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Route details
              if (_currentRoute != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.route, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Text(
                              'Route Details',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _currentRoute = null;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        Row(
                          children: [
                            Icon(Icons.straighten, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              'Distance: ${_currentRoute!.totalDistance.toStringAsFixed(0)}m',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        Row(
                          children: [
                            Icon(Icons.access_time, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              'Est. time: ${_getEstimatedTime(_currentRoute!.totalDistance)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        
                        if (_currentRoute!.floorChanges.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.layers, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Text(
                                'Floor changes: ${_currentRoute!.floorChanges.length}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ],
                        
                        if (_currentRoute!.instructions.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Instructions:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(_currentRoute!.instructions),
                        ],
                        
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _shareRoute,
                                icon: const Icon(Icons.share),
                                label: const Text('Share'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _startNavigation,
                                icon: const Icon(Icons.navigation),
                                label: const Text('Start'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              // Quick destinations
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick Destinations',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildQuickDestinations(currentSystem),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchTab() {
    return Consumer<RoadSystemProvider>(
      builder: (context, provider, child) {
        final currentSystem = provider.currentSystem;
        
        if (currentSystem == null) {
          return const Center(
            child: Text('No road system selected'),
          );
        }

        // Collect all landmarks
        final allLandmarks = <Landmark>[
          ...currentSystem.outdoorLandmarks,
          for (final building in currentSystem.buildings)
            for (final floor in building.floors)
              ...floor.landmarks,
        ];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search for places...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  // Implement search functionality
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: allLandmarks.length,
                itemBuilder: (context, index) {
                  final landmark = allLandmarks[index];
                  final isIndoor = landmark.floorId.isNotEmpty;
                  
                  return ListTile(
                    leading: Icon(
                      _getLandmarkIcon(landmark.type),
                      color: _getLandmarkColor(landmark.type),
                    ),
                    title: Text(landmark.name),
                    subtitle: Text(landmark.type),
                    trailing: isIndoor 
                        ? const Icon(Icons.business, size: 16)
                        : const Icon(Icons.landscape, size: 16),
                    onTap: () => _selectDestination(landmark),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    // This would show navigation history
    return const Center(
      child: Text(
        'Navigation History',
        style: TextStyle(fontSize: 18),
      ),
    );
  }

  Widget _buildQuickDestinations(RoadSystem system) {
    final quickDestinations = [
      {'name': 'Nearest Bathroom', 'type': 'bathroom', 'icon': Icons.wc},
      {'name': 'Main Entrance', 'type': 'entrance', 'icon': Icons.door_front_door},
      {'name': 'Elevator', 'type': 'elevator', 'icon': Icons.elevator},
      {'name': 'Stairs', 'type': 'stairs', 'icon': Icons.stairs},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: quickDestinations.map((dest) {
        return ActionChip(
          avatar: Icon(dest['icon'] as IconData, size: 16),
          label: Text(dest['name'] as String),
          onPressed: () => _findNearestLandmark(dest['type'] as String),
        );
      }).toList(),
    );
  }

  bool _canCalculateRoute() {
    return _startPoint != null && _endPoint != null;
  }

  void _useCurrentLocation(bool isStart) {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final currentLocation = locationProvider.currentLatLng;
    
    if (currentLocation != null) {
      setState(() {
        if (isStart) {
          _startPoint = currentLocation;
          _startDescription = 'Current Location';
          _startController.text = 'Current Location';
        } else {
          _endPoint = currentLocation;
          _endDescription = 'Current Location';
          _endController.text = 'Current Location';
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location not available')),
      );
    }
  }

  void _selectFromMap(bool isStart) {
    // This would open a map picker
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select ${isStart ? 'Start' : 'End'} Point'),
        content: const Text('Map point selection would be implemented here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showLandmarkPicker(bool isStart) {
    final provider = Provider.of<RoadSystemProvider>(context, listen: false);
    final currentSystem = provider.currentSystem;
    
    if (currentSystem == null) return;

    // Collect all landmarks
    final allLandmarks = <Landmark>[
      ...currentSystem.outdoorLandmarks,
      for (final building in currentSystem.buildings)
        for (final floor in building.floors)
          ...floor.landmarks,
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select ${isStart ? 'Start' : 'Destination'}'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: allLandmarks.length,
            itemBuilder: (context, index) {
              final landmark = allLandmarks[index];
              return ListTile(
                leading: Icon(
                  _getLandmarkIcon(landmark.type),
                  color: _getLandmarkColor(landmark.type),
                ),
                title: Text(landmark.name),
                subtitle: Text(landmark.type),
                onTap: () {
                  setState(() {
                    if (isStart) {
                      _startPoint = landmark.position;
                      _startDescription = landmark.name;
                      _startController.text = landmark.name;
                    } else {
                      _endPoint = landmark.position;
                      _endDescription = landmark.name;
                      _endController.text = landmark.name;
                    }
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _selectDestination(Landmark landmark) {
    setState(() {
      _endPoint = landmark.position;
      _endDescription = landmark.name;
      _endController.text = landmark.name;
    });
    _tabController.animateTo(0); // Switch to route tab
  }

  void _findNearestLandmark(String type) {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final roadSystemProvider = Provider.of<RoadSystemProvider>(context, listen: false);
    
    final currentLocation = locationProvider.currentLatLng;
    final currentSystem = roadSystemProvider.currentSystem;
    
    if (currentLocation == null || currentSystem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location or system not available')),
      );
      return;
    }

    // Find nearest landmark of specified type
    final allLandmarks = <Landmark>[
      ...currentSystem.outdoorLandmarks.where((l) => l.type == type),
      for (final building in currentSystem.buildings)
        for (final floor in building.floors)
          ...floor.landmarks.where((l) => l.type == type),
    ];

    if (allLandmarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No ${type}s found')),
      );
      return;
    }

    // Find closest one (simplified distance calculation)
    Landmark? nearest;
    double minDistance = double.infinity;
    
    for (final landmark in allLandmarks) {
      final distance = _calculateDistance(currentLocation, landmark.position);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = landmark;
      }
    }

    if (nearest != null) {
      setState(() {
        _startPoint = currentLocation;
        _startDescription = 'Current Location';
        _startController.text = 'Current Location';
        _endPoint = nearest!.position;
        _endDescription = nearest.name;
        _endController.text = nearest.name;
      });
      _tabController.animateTo(0); // Switch to route tab
    }
  }

  Future<void> _calculateRoute() async {
    if (!_canCalculateRoute()) return;

    setState(() {
      _isCalculatingRoute = true;
    });

    try {
      // Simulate route calculation
      await Future.delayed(const Duration(seconds: 2));
      
      final distance = _calculateDistance(_startPoint!, _endPoint!);
      final waypoints = [_startPoint!, _endPoint!]; // Simplified
      
      final route = NavigationRoute(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        start: _startPoint!,
        end: _endPoint!,
        waypoints: waypoints,
        totalDistance: distance,
        instructions: 'Head towards your destination. Turn right at the intersection.',
      );

      setState(() {
        _currentRoute = route;
        _isCalculatingRoute = false;
      });
    } catch (e) {
      setState(() {
        _isCalculatingRoute = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to calculate route: $e')),
      );
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    // Simplified distance calculation (Haversine formula would be more accurate)
    const double earthRadius = 6371000; // Earth's radius in meters
    final lat1Rad = point1.latitude * (3.14159 / 180);
    final lat2Rad = point2.latitude * (3.14159 / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (3.14159 / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (3.14159 / 180);

    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  String _getEstimatedTime(double distanceMeters) {
    const double walkingSpeedMps = 1.4; // 1.4 m/s average walking speed
    final timeSeconds = distanceMeters / walkingSpeedMps;
    
    if (timeSeconds < 60) {
      return '${timeSeconds.round()} seconds';
    } else {
      final minutes = (timeSeconds / 60).round();
      return '$minutes minute${minutes != 1 ? 's' : ''}';
    }
  }

  void _shareRoute() {
    if (_currentRoute != null) {
      // Implementation for sharing route
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route sharing would be implemented here')),
      );
    }
  }

  void _startNavigation() {
    if (_currentRoute != null) {
      // Implementation for starting turn-by-turn navigation
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start Navigation'),
          content: const Text('Turn-by-turn navigation would start here'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Start navigation
              },
              child: const Text('Start'),
            ),
          ],
        ),
      );
    }
  }

  Color _getLandmarkColor(String type) {
    switch (type) {
      case 'bathroom':
        return Colors.blue;
      case 'classroom':
        return Colors.green;
      case 'office':
        return Colors.purple;
      case 'entrance':
        return Colors.red;
      case 'elevator':
        return Colors.orange;
      case 'stairs':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getLandmarkIcon(String type) {
    switch (type) {
      case 'bathroom':
        return Icons.wc;
      case 'classroom':
        return Icons.school;
      case 'office':
        return Icons.work;
      case 'entrance':
        return Icons.door_front_door;
      case 'elevator':
        return Icons.elevator;
      case 'stairs':
        return Icons.stairs;
      default:
        return Icons.place;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }
}