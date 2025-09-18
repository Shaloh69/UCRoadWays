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
  String? _startFloorId;
  String? _endFloorId;
  String? _startBuildingId;
  String? _endBuildingId;
  
  NavigationRoute? _currentRoute;
  bool _isCalculatingRoute = false;
  bool _preferElevator = true; // For accessibility
  
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // Added accessibility tab
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation'),
        backgroundColor: Colors.blue,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Route', icon: Icon(Icons.directions)),
            Tab(text: 'Search', icon: Icon(Icons.search)),
            Tab(text: 'Multi-Floor', icon: Icon(Icons.layers)),
            Tab(text: 'History', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRouteTab(),
          _buildSearchTab(),
          _buildMultiFloorTab(),
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
              // Enhanced Route input section
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
                      
                      // Start point with floor context
                      _buildLocationInput(
                        controller: _startController,
                        label: 'Starting point',
                        icon: Icons.my_location,
                        iconColor: Colors.green,
                        isStart: true,
                        currentFloorId: _startFloorId,
                        currentBuildingId: _startBuildingId,
                        buildingProvider: buildingProvider,
                        roadSystemProvider: roadSystemProvider,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // End point with floor context
                      _buildLocationInput(
                        controller: _endController,
                        label: 'Destination',
                        icon: Icons.location_on,
                        iconColor: Colors.red,
                        isStart: false,
                        currentFloorId: _endFloorId,
                        currentBuildingId: _endBuildingId,
                        buildingProvider: buildingProvider,
                        roadSystemProvider: roadSystemProvider,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Navigation preferences
                      Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('Prefer Elevator'),
                              subtitle: const Text('For accessibility'),
                              value: _preferElevator,
                              onChanged: (value) {
                                setState(() {
                                  _preferElevator = value ?? true;
                                });
                              },
                              contentPadding: EdgeInsets.zero,
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Enhanced route details
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
                        
                        // Route statistics
                        Row(
                          children: [
                            Expanded(
                              child: _buildRouteStatCard(
                                'Distance',
                                '${_currentRoute!.totalDistance.toStringAsFixed(0)}m',
                                Icons.straighten,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildRouteStatCard(
                                'Est. Time',
                                _getEstimatedTime(_currentRoute!.totalDistance, _currentRoute!.floorTransitions.length),
                                Icons.access_time,
                                Colors.green,
                              ),
                            ),
                          ],
                        ),
                        
                        if (_currentRoute!.floorTransitions.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildRouteStatCard(
                                  'Floor Changes',
                                  _currentRoute!.floorTransitions.length.toString(),
                                  Icons.layers,
                                  Colors.purple,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildRouteStatCard(
                                  'Buildings',
                                  _getUniqueBuildingsCount().toString(),
                                  Icons.business,
                                  Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ],
                        
                        // Floor transitions detail
                        if (_currentRoute!.floorTransitions.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Floor Changes:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Column(
                            children: _currentRoute!.floorTransitions.map((transition) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.purple[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.purple[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      transition.transitionType == 'elevator' 
                                          ? Icons.elevator 
                                          : Icons.stairs,
                                      color: Colors.purple,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        transition.instructions,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        
                        if (_currentRoute!.instructions.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Instructions:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Text(
                              _currentRoute!.instructions,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
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
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              // Quick destinations with floor awareness
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
                      _buildQuickDestinations(currentSystem, buildingProvider),
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

  Widget _buildLocationInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color iconColor,
    required bool isStart,
    required String? currentFloorId,
    required String? currentBuildingId,
    required BuildingProvider buildingProvider,
    required RoadSystemProvider roadSystemProvider,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: label,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.gps_fixed),
                        onPressed: () => _useCurrentLocation(isStart, buildingProvider, roadSystemProvider),
                        tooltip: 'Use current location',
                      ),
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => _showLandmarkPicker(isStart, roadSystemProvider),
                        tooltip: 'Search landmarks',
                      ),
                      IconButton(
                        icon: const Icon(Icons.place),
                        onPressed: () => _selectFromMap(isStart),
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
        
        // Floor context indicator
        if (currentFloorId != null && currentBuildingId != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple[200]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.business, size: 12, color: Colors.purple),
                const SizedBox(width: 4),
                Text(
                  _getLocationContext(currentBuildingId, currentFloorId, roadSystemProvider),
                  style: const TextStyle(fontSize: 10, color: Colors.purple),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRouteStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return Consumer2<RoadSystemProvider, BuildingProvider>(
      builder: (context, roadSystemProvider, buildingProvider, child) {
        final currentSystem = roadSystemProvider.currentSystem;
        
        if (currentSystem == null) {
          return const Center(
            child: Text('No road system selected'),
          );
        }

        // Collect all landmarks with floor context
        final allLandmarks = <Map<String, dynamic>>[];
        
        // Outdoor landmarks
        for (final landmark in currentSystem.outdoorLandmarks) {
          allLandmarks.add({
            'landmark': landmark,
            'context': 'Outdoor',
            'building': null,
            'floor': null,
          });
        }
        
        // Indoor landmarks
        for (final building in currentSystem.buildings) {
          for (final floor in building.floors) {
            for (final landmark in floor.landmarks) {
              allLandmarks.add({
                'landmark': landmark,
                'context': 'Indoor',
                'building': building,
                'floor': floor,
              });
            }
          }
        }

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
            
            // Filter chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: true,
                      onSelected: (selected) {},
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Outdoor'),
                      selected: false,
                      onSelected: (selected) {},
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Indoor'),
                      selected: false,
                      onSelected: (selected) {},
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Current Floor'),
                      selected: false,
                      onSelected: (selected) {},
                    ),
                  ],
                ),
              ),
            ),
            
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: allLandmarks.length,
                itemBuilder: (context, index) {
                  final item = allLandmarks[index];
                  final landmark = item['landmark'] as Landmark;
                  final context = item['context'] as String;
                  final building = item['building'] as Building?;
                  final floor = item['floor'] as Floor?;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        _getLandmarkIcon(landmark.type),
                        color: _getLandmarkColor(landmark.type),
                      ),
                      title: Text(landmark.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(landmark.type),
                          Text(
                            context == 'Indoor' && building != null && floor != null
                                ? '${building.name} - ${floor.name}'
                                : context,
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                      trailing: Icon(
                        context == 'Indoor' ? Icons.business : Icons.landscape,
                        size: 16,
                        color: context == 'Indoor' ? Colors.purple : Colors.green,
                      ),
                      onTap: () => _selectDestination(landmark, building?.id, floor?.id),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMultiFloorTab() {
    return Consumer2<RoadSystemProvider, BuildingProvider>(
      builder: (context, roadSystemProvider, buildingProvider, child) {
        final currentSystem = roadSystemProvider.currentSystem;
        
        if (currentSystem == null || currentSystem.buildings.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.layers, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No Multi-Floor Buildings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text('Add buildings with multiple floors to enable multi-floor navigation'),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Multi-floor navigation overview
              Card(
                color: Colors.purple[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.layers, color: Colors.purple),
                          SizedBox(width: 8),
                          Text(
                            'Multi-Floor Navigation',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Navigate between floors using elevators and stairs. The app automatically finds the best route including floor changes.',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMultiFloorStat(
                              'Buildings',
                              currentSystem.buildings.length,
                              Icons.business,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMultiFloorStat(
                              'Total Floors',
                              currentSystem.allFloors.length,
                              Icons.layers,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMultiFloorStat(
                              'Elevators',
                              _getTotalElevators(currentSystem),
                              Icons.elevator,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Buildings with floor navigation
              ...currentSystem.buildings.map((building) {
                final accessibility = buildingProvider.getBuildingAccessibility(building);
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ExpansionTile(
                    leading: Icon(
                      Icons.business,
                      color: accessibility['hasElevator']! ? Colors.purple : Colors.grey,
                    ),
                    title: Text(building.name),
                    subtitle: Text(
                      '${building.floors.length} floors • '
                      '${accessibility['hasElevator']! ? 'Elevator available' : 'Stairs only'}'
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Floor list
                            const Text(
                              'Floors:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: building.sortedFloors.map((floor) {
                                return ActionChip(
                                  avatar: CircleAvatar(
                                    backgroundColor: _getFloorLevelColor(floor.level),
                                    radius: 10,
                                    child: Text(
                                      _getFloorShortName(floor),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  label: Text(floor.name),
                                  onPressed: () {
                                    buildingProvider.navigateToFloor(building.id, floor.id);
                                    _tabController.animateTo(0); // Switch to route tab
                                  },
                                );
                              }).toList(),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Vertical circulation
                            if (building.allVerticalCirculation.isNotEmpty) ...[
                              const Text(
                                'Vertical Circulation:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              ...building.allVerticalCirculation.map((circulation) {
                                return ListTile(
                                  leading: Icon(
                                    circulation.type == 'elevator' ? Icons.elevator : Icons.stairs,
                                    color: circulation.type == 'elevator' ? Colors.orange : Colors.teal,
                                  ),
                                  title: Text(circulation.name),
                                  subtitle: Text(
                                    'Connects ${circulation.connectedFloors.length} floors',
                                  ),
                                  dense: true,
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMultiFloorStat(String label, int value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.purple, size: 20),
          const SizedBox(height: 4),
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.purple),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    // This would show navigation history
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Navigation History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text('Recent routes will appear here'),
        ],
      ),
    );
  }

  Widget _buildQuickDestinations(RoadSystem system, BuildingProvider buildingProvider) {
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
          onPressed: () => _findNearestLandmark(dest['type'] as String, buildingProvider),
        );
      }).toList(),
    );
  }

  // Core functionality methods
  bool _canCalculateRoute() {
    return _startPoint != null && _endPoint != null;
  }

  void _useCurrentLocation(bool isStart, BuildingProvider buildingProvider, RoadSystemProvider roadSystemProvider) {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final currentLocation = locationProvider.currentLatLng;
    
    if (currentLocation != null) {
      setState(() {
        if (isStart) {
          _startPoint = currentLocation;
          _startDescription = 'Current Location';
          _startController.text = 'Current Location';
          
          // Set floor context if in indoor mode
          if (buildingProvider.isIndoorMode) {
            _startFloorId = buildingProvider.selectedFloorId;
            _startBuildingId = buildingProvider.selectedBuildingId;
          } else {
            _startFloorId = null;
            _startBuildingId = null;
          }
        } else {
          _endPoint = currentLocation;
          _endDescription = 'Current Location';
          _endController.text = 'Current Location';
          
          if (buildingProvider.isIndoorMode) {
            _endFloorId = buildingProvider.selectedFloorId;
            _endBuildingId = buildingProvider.selectedBuildingId;
          } else {
            _endFloorId = null;
            _endBuildingId = null;
          }
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location not available')),
      );
    }
  }

  void _selectFromMap(bool isStart) {
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

  void _showLandmarkPicker(bool isStart, RoadSystemProvider roadSystemProvider) {
    final currentSystem = roadSystemProvider.currentSystem;
    if (currentSystem == null) return;

    // Navigate to search tab
    _tabController.animateTo(1);
  }

  void _selectDestination(Landmark landmark, String? buildingId, String? floorId) {
    setState(() {
      _endPoint = landmark.position;
      _endDescription = landmark.name;
      _endController.text = landmark.name;
      _endFloorId = floorId;
      _endBuildingId = buildingId;
    });
    _tabController.animateTo(0); // Switch to route tab
  }

  void _findNearestLandmark(String type, BuildingProvider buildingProvider) {
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

    final nearestLandmark = NavigationService.findNearestLandmark(
      userLocation: currentLocation,
      landmarkType: type,
      roadSystem: currentSystem,
      currentFloorId: buildingProvider.selectedFloorId,
      currentBuildingId: buildingProvider.selectedBuildingId,
    );

    if (nearestLandmark != null) {
      setState(() {
        _startPoint = currentLocation;
        _startDescription = 'Current Location';
        _startController.text = 'Current Location';
        _startFloorId = buildingProvider.selectedFloorId;
        _startBuildingId = buildingProvider.selectedBuildingId;
        
        _endPoint = nearestLandmark.position;
        _endDescription = nearestLandmark.name;
        _endController.text = nearestLandmark.name;
        _endFloorId = nearestLandmark.floorId.isEmpty ? null : nearestLandmark.floorId;
        _endBuildingId = nearestLandmark.buildingId.isEmpty ? null : nearestLandmark.buildingId;
      });
      _tabController.animateTo(0); // Switch to route tab
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No ${type}s found nearby')),
      );
    }
  }

  Future<void> _calculateRoute() async {
    if (!_canCalculateRoute()) return;

    setState(() {
      _isCalculatingRoute = true;
    });

    try {
      final roadSystemProvider = Provider.of<RoadSystemProvider>(context, listen: false);
      final currentSystem = roadSystemProvider.currentSystem!;
      
      final route = await NavigationService.calculateRoute(
        start: _startPoint!,
        end: _endPoint!,
        roadSystem: currentSystem,
        startFloorId: _startFloorId,
        endFloorId: _endFloorId,
        startBuildingId: _startBuildingId,
        endBuildingId: _endBuildingId,
        preferElevator: _preferElevator,
      );

      setState(() {
        _currentRoute = route;
        _isCalculatingRoute = false;
      });
      
      if (route == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not calculate route'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isCalculatingRoute = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to calculate route: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getEstimatedTime(double distanceMeters, int floorChanges) {
    final travelTime = NavigationService.calculateTravelTime(distanceMeters, floorChanges);
    
    final minutes = travelTime.inMinutes;
    final seconds = travelTime.inSeconds % 60;
    
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  int _getUniqueBuildingsCount() {
    if (_currentRoute == null) return 0;
    
    final buildingIds = <String>{};
    if (_startBuildingId != null) buildingIds.add(_startBuildingId!);
    if (_endBuildingId != null) buildingIds.add(_endBuildingId!);
    
    for (final transition in _currentRoute!.floorTransitions) {
      buildingIds.add(transition.buildingId);
    }
    
    return buildingIds.length;
  }

  String _getLocationContext(String? buildingId, String? floorId, RoadSystemProvider roadSystemProvider) {
    if (buildingId == null || floorId == null) return 'Outdoor';
    
    final system = roadSystemProvider.currentSystem;
    if (system == null) return 'Unknown';
    
    final building = system.buildings.where((b) => b.id == buildingId).firstOrNull;
    if (building == null) return 'Unknown Building';
    
    final floor = building.floors.where((f) => f.id == floorId).firstOrNull;
    if (floor == null) return building.name;
    
    return '${building.name} - ${floor.name}';
  }

  int _getTotalElevators(RoadSystem system) {
    int count = 0;
    for (final building in system.buildings) {
      for (final floor in building.floors) {
        count += floor.landmarks.where((l) => l.type == 'elevator').length;
      }
    }
    return count;
  }

  void _shareRoute() {
    if (_currentRoute != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route sharing would be implemented here')),
      );
    }
  }

  void _startNavigation() {
    if (_currentRoute != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start Navigation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Turn-by-turn navigation will start.'),
              if (_currentRoute!.floorTransitions.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('This route includes floor changes:'),
                ...(_currentRoute!.floorTransitions.take(3).map((t) => 
                  Text('• ${t.instructions}', style: const TextStyle(fontSize: 12))
                )),
                if (_currentRoute!.floorTransitions.length > 3)
                  Text('• And ${_currentRoute!.floorTransitions.length - 3} more...', 
                       style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Start navigation implementation
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🧭 Navigation started'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Start'),
            ),
          ],
        ),
      );
    }
  }

  // Helper methods for UI
  Color _getLandmarkColor(String type) {
    switch (type) {
      case 'bathroom': return Colors.blue;
      case 'classroom': return Colors.green;
      case 'office': return Colors.purple;
      case 'entrance': return Colors.red;
      case 'elevator': return Colors.orange;
      case 'stairs': return Colors.teal;
      default: return Colors.grey;
    }
  }

  IconData _getLandmarkIcon(String type) {
    switch (type) {
      case 'bathroom': return Icons.wc;
      case 'classroom': return Icons.school;
      case 'office': return Icons.work;
      case 'entrance': return Icons.door_front_door;
      case 'elevator': return Icons.elevator;
      case 'stairs': return Icons.stairs;
      default: return Icons.place;
    }
  }

  String _getFloorShortName(Floor floor) {
    if (floor.level > 0) {
      return '${floor.level}F';
    } else if (floor.level == 0) {
      return 'GF';
    } else {
      return 'B${-floor.level}';
    }
  }

  Color _getFloorLevelColor(int level) {
    if (level > 0) {
      final intensity = (level / 10).clamp(0.0, 1.0);
      return Color.lerp(Colors.blue[300]!, Colors.blue[900]!, intensity)!;
    } else if (level == 0) {
      return Colors.green;
    } else {
      final intensity = ((-level) / 5).clamp(0.0, 1.0);
      return Color.lerp(Colors.orange[300]!, Colors.red[900]!, intensity)!;
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