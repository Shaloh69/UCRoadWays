import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';
import '../providers/road_system_provider.dart';
import '../providers/building_provider.dart';
import '../providers/location_provider.dart';
import '../models/models.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  
  LatLng? _fromLocation;
  LatLng? _toLocation;
  Landmark? _fromLandmark;
  Landmark? _toLandmark;
  NavigationRoute? _currentRoute;
  bool _isNavigating = false;
  bool _useCurrentLocation = true;
  
  List<Map<String, dynamic>> _searchResults = [];
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeCurrentLocation();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  Future<void> _initializeCurrentLocation() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    if (locationProvider.currentLatLng != null) {
      setState(() {
        _fromLocation = locationProvider.currentLatLng;
        _fromController.text = 'Current Location';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Route Planner', icon: Icon(Icons.directions)),
            Tab(text: 'Active Route', icon: Icon(Icons.navigation)),
            Tab(text: 'History', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: Consumer3<RoadSystemProvider, BuildingProvider, LocationProvider>(
        builder: (context, roadSystemProvider, buildingProvider, locationProvider, child) {
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

          return TabBarView(
            controller: _tabController,
            children: [
              _buildRoutePlannerTab(currentSystem, buildingProvider, locationProvider),
              _buildActiveRouteTab(currentSystem, locationProvider),
              _buildHistoryTab(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRoutePlannerTab(
    RoadSystem system,
    BuildingProvider buildingProvider,
    LocationProvider locationProvider,
  ) {
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
                  const Row(
                    children: [
                      Icon(Icons.route, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Plan Your Route',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // From location
                  _buildLocationInput(
                    controller: _fromController,
                    label: 'From',
                    icon: Icons.my_location,
                    color: Colors.green,
                    onTap: () => _showLocationPicker(context, true, system, buildingProvider),
                    onToggleCurrentLocation: () {
                      setState(() {
                        _useCurrentLocation = !_useCurrentLocation;
                        if (_useCurrentLocation && locationProvider.currentLatLng != null) {
                          _fromLocation = locationProvider.currentLatLng;
                          _fromController.text = 'Current Location';
                          _fromLandmark = null;
                        }
                      });
                    },
                    useCurrentLocation: _useCurrentLocation,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Swap button
                  Center(
                    child: IconButton(
                      onPressed: _swapLocations,
                      icon: const Icon(Icons.swap_vert),
                      tooltip: 'Swap locations',
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // To location
                  _buildLocationInput(
                    controller: _toController,
                    label: 'To',
                    icon: Icons.place,
                    color: Colors.red,
                    onTap: () => _showLocationPicker(context, false, system, buildingProvider),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Route options
                  _buildRouteOptions(),
                  
                  const SizedBox(height: 16),
                  
                  // Plan route button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _canPlanRoute() ? () => _planRoute(system) : null,
                      icon: const Icon(Icons.directions),
                      label: const Text('Plan Route'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Route results
          if (_currentRoute != null) ...[
            _buildRouteResultCard(_currentRoute!, system),
            const SizedBox(height: 16),
          ],
          
          // Quick destinations
          _buildQuickDestinations(system, buildingProvider),
        ],
      ),
    );
  }

  Widget _buildActiveRouteTab(RoadSystem system, LocationProvider locationProvider) {
    if (!_isNavigating || _currentRoute == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.navigation_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No Active Navigation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const Text('Plan a route to start navigation'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(0),
              icon: const Icon(Icons.route),
              label: const Text('Plan Route'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Navigation status
          _buildNavigationStatusCard(locationProvider),
          
          const SizedBox(height: 16),
          
          // Turn-by-turn directions
          _buildDirectionsCard(_currentRoute!),
          
          const SizedBox(height: 16),
          
          // Route progress
          _buildRouteProgressCard(_currentRoute!, locationProvider),
          
          const SizedBox(height: 16),
          
          // Navigation controls
          _buildNavigationControls(),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Navigation History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          Text('Your recent routes will appear here'),
        ],
      ),
    );
  }

  Widget _buildLocationInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    VoidCallback? onToggleCurrentLocation,
    bool useCurrentLocation = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (onToggleCurrentLocation != null) ...[
              const Spacer(),
              Switch(
                value: useCurrentLocation,
                onChanged: (_) => onToggleCurrentLocation(),
                activeColor: Colors.blue,
              ),
              const Text('Current', style: TextStyle(fontSize: 12)),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: true,
          onTap: onTap,
          decoration: InputDecoration(
            hintText: 'Select $label location',
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.search),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildRouteOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Route Options',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('Accessible'),
              selected: true,
              onSelected: (selected) {
                // Handle accessible route option
              },
            ),
            FilterChip(
              label: const Text('Shortest'),
              selected: false,
              onSelected: (selected) {
                // Handle shortest route option
              },
            ),
            FilterChip(
              label: const Text('Avoid Stairs'),
              selected: false,
              onSelected: (selected) {
                // Handle avoid stairs option
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRouteResultCard(NavigationRoute route, RoadSystem system) {
    return Card(
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
                  'Route Found',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${(route.totalDistance / 1000).toStringAsFixed(1)} km',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Route summary
            Row(
              children: [
                _buildRouteStat('Distance', '${route.totalDistance.toInt()} m', Icons.straighten),
                _buildRouteStat('Steps', '${route.waypoints.length}', Icons.directions_walk),
                _buildRouteStat('Floors', '${route.floorChanges.length}', Icons.layers),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Floor transitions
            if (route.floorTransitions.isNotEmpty) ...[
              const Text(
                'Floor Changes:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...route.floorTransitions.map((transition) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      transition.transitionType == 'elevator' ? Icons.elevator : Icons.stairs,
                      size: 16,
                      color: transition.transitionType == 'elevator' ? Colors.orange : Colors.teal,
                    ),
                    const SizedBox(width: 8),
                    Text('Use ${transition.transitionType}'),
                  ],
                ),
              )),
              const SizedBox(height: 16),
            ],
            
            // Start navigation button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _startNavigation(route),
                icon: const Icon(Icons.navigation),
                label: const Text('Start Navigation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteStat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDestinations(RoadSystem system, BuildingProvider buildingProvider) {
    final popularLandmarks = _getPopularLandmarks(system);
    
    if (popularLandmarks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.star, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Quick Destinations',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: popularLandmarks.map((landmark) => ActionChip(
                avatar: Icon(
                  _getLandmarkIcon(landmark.type),
                  size: 16,
                  color: Colors.blue,
                ),
                label: Text(landmark.name),
                onPressed: () => _selectDestination(landmark),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationStatusCard(LocationProvider locationProvider) {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.navigation, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Navigating to Destination',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text('GPS Accuracy: ${locationProvider.accuracyStatus}'),
                ],
              ),
            ),
            Text(
              '${locationProvider.speed.toStringAsFixed(1)} m/s',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionsCard(NavigationRoute route) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.directions, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Turn-by-Turn Directions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.arrow_forward, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Continue straight for 50 meters',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Then: Turn right at the next intersection',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteProgressCard(NavigationRoute route, LocationProvider locationProvider) {
    final progress = 0.3; // Calculate actual progress
    final remainingDistance = route.totalDistance * (1 - progress);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timeline, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Route Progress',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(progress * 100).toInt()}% Complete'),
                Text('${remainingDistance.toInt()}m remaining'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pauseNavigation,
                icon: const Icon(Icons.pause),
                label: const Text('Pause'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _stopNavigation,
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationPicker(
    BuildContext context,
    bool isFrom,
    RoadSystem system,
    BuildingProvider buildingProvider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Select ${isFrom ? 'From' : 'To'} Location',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search locations...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (query) => _searchLocations(query, system),
              ),
            ),
            Expanded(
              child: _buildLocationSearchResults(system, buildingProvider, isFrom),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSearchResults(
    RoadSystem system,
    BuildingProvider buildingProvider,
    bool isFrom,
  ) {
    final allLandmarks = system.allLandmarks;
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allLandmarks.length,
      itemBuilder: (context, index) {
        final landmark = allLandmarks[index];
        final building = system.buildings
            .where((b) => b.id == landmark.buildingId)
            .firstOrNull;
        final floor = building?.floors
            .where((f) => f.id == landmark.floorId)
            .firstOrNull;
        
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _getLandmarkColor(landmark.type),
            child: Icon(
              _getLandmarkIcon(landmark.type),
              color: Colors.white,
              size: 20,
            ),
          ),
          title: Text(landmark.name),
          subtitle: Text(
            landmark.isIndoor 
                ? '${building?.name ?? 'Unknown Building'} - ${floor?.name ?? 'Unknown Floor'}'
                : 'Outdoor',
          ),
          onTap: () {
            _selectLocation(landmark, isFrom);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _searchLocations(String query, RoadSystem system) {
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query.toLowerCase();
    });

    // Search in landmarks
    final results = <Map<String, dynamic>>[];
    for (final landmark in system.allLandmarks) {
      if (landmark.name.toLowerCase().contains(_searchQuery) ||
          landmark.type.toLowerCase().contains(_searchQuery)) {
        results.add({
          'type': 'landmark',
          'item': landmark,
          'title': landmark.name,
          'subtitle': landmark.type,
        });
      }
    }

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _selectLocation(Landmark landmark, bool isFrom) {
    setState(() {
      if (isFrom) {
        _fromLocation = landmark.position;
        _fromLandmark = landmark;
        _fromController.text = landmark.name;
        _useCurrentLocation = false;
      } else {
        _toLocation = landmark.position;
        _toLandmark = landmark;
        _toController.text = landmark.name;
      }
    });
  }

  void _selectDestination(Landmark landmark) {
    setState(() {
      _toLocation = landmark.position;
      _toLandmark = landmark;
      _toController.text = landmark.name;
    });
  }

  void _swapLocations() {
    setState(() {
      final tempLocation = _fromLocation;
      final tempLandmark = _fromLandmark;
      final tempText = _fromController.text;
      
      _fromLocation = _toLocation;
      _fromLandmark = _toLandmark;
      _fromController.text = _toController.text;
      
      _toLocation = tempLocation;
      _toLandmark = tempLandmark;
      _toController.text = tempText;
      
      _useCurrentLocation = false;
    });
  }

  bool _canPlanRoute() {
    return _fromLocation != null && _toLocation != null;
  }

  void _planRoute(RoadSystem system) {
    if (!_canPlanRoute()) return;

    // Calculate floor transitions if needed
    final floorTransitions = <FloorTransition>[];
    
    // Check if route involves floor changes
    if (_fromLandmark != null && _toLandmark != null &&
        _fromLandmark!.floorId != _toLandmark!.floorId &&
        _fromLandmark!.buildingId == _toLandmark!.buildingId &&
        _fromLandmark!.buildingId.isNotEmpty) {
      
      // Find vertical circulation between floors
      final building = system.buildings.where((b) => b.id == _fromLandmark!.buildingId).firstOrNull;
      if (building != null) {
        // Find elevator or stairs that connects the floors
        for (final floor in building.floors) {
          for (final landmark in floor.landmarks) {
            if (landmark.isVerticalCirculation &&
                landmark.connectedFloors.contains(_fromLandmark!.floorId) &&
                landmark.connectedFloors.contains(_toLandmark!.floorId)) {
              
              floorTransitions.add(FloorTransition(
                fromFloorId: _fromLandmark!.floorId,
                toFloorId: _toLandmark!.floorId,
                transitionType: landmark.type,
                position: landmark.position,
                landmarkId: landmark.id,
              ));
              break;
            }
          }
        }
      }
    }

    // Simple route calculation (in a real app, this would be more complex)
    final route = NavigationRoute(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      start: _fromLocation!,
      end: _toLocation!,
      waypoints: [_fromLocation!, _toLocation!],
      totalDistance: _calculateDistance(_fromLocation!, _toLocation!),
      instructions: 'Navigate from ${_fromController.text} to ${_toController.text}',
      floorChanges: floorTransitions.map((t) => '${t.fromFloorId}-${t.toFloorId}').toList(),
      floorTransitions: floorTransitions,
    );

    setState(() {
      _currentRoute = route;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Route calculated successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _startNavigation(NavigationRoute route) {
    setState(() {
      _isNavigating = true;
    });
    
    _tabController.animateTo(1);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Navigation started'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _pauseNavigation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigation paused')),
    );
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
      _currentRoute = null;
    });
    
    _tabController.animateTo(0);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigation stopped')),
    );
  }

  List<Landmark> _getPopularLandmarks(RoadSystem system) {
    final landmarks = system.allLandmarks;
    
    // Return landmarks of common types
    return landmarks.where((l) => [
      'bathroom',
      'entrance',
      'elevator',
      'information',
      'restaurant',
    ].contains(l.type)).take(6).toList();
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
      case 'restaurant':
        return Icons.restaurant;
      case 'information':
        return Icons.info;
      default:
        return Icons.place;
    }
  }
}

// Note: IterableExtension is defined in models.dart