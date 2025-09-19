import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import '../providers/location_provider.dart';
import '../providers/building_provider.dart';
import '../providers/road_system_provider.dart';
import '../widgets/map_widget.dart';

class FloatingControls extends StatefulWidget {
  final MapController mapController;
  final GlobalKey<UCRoadWaysMapState> mapWidgetKey;

  const FloatingControls({
    super.key,
    required this.mapController,
    required this.mapWidgetKey,
  });

  @override
  State<FloatingControls> createState() => _FloatingControlsState();
}

class _FloatingControlsState extends State<FloatingControls>
    with TickerProviderStateMixin {
  bool _isRecording = false;
  bool _isControlsExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _isControlsExpanded = !_isControlsExpanded;
    });
    
    if (_isControlsExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<LocationProvider, BuildingProvider, RoadSystemProvider>(
      builder: (context, locationProvider, buildingProvider, roadSystemProvider, child) {
        final currentSystem = roadSystemProvider.currentSystem;
        final hasSystem = currentSystem != null;
        
        return Stack(
          children: [
            // Main controls panel
            Positioned(
              right: 16,
              top: 100,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mode toggle button
                  if (hasSystem) ...[
                    _buildModeToggleButton(buildingProvider),
                    const SizedBox(height: 8),
                  ],
                  
                  // Main menu button
                  FloatingActionButton(
                    heroTag: "main_menu",
                    onPressed: _toggleControls,
                    backgroundColor: _isControlsExpanded ? Colors.red : Colors.blue,
                    child: AnimatedRotation(
                      turns: _isControlsExpanded ? 0.125 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(_isControlsExpanded ? Icons.close : Icons.add),
                    ),
                  ),
                  
                  // Expanded controls
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _animation.value,
                        child: Opacity(
                          opacity: _animation.value,
                          child: _isControlsExpanded ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 12),
                              ..._buildExpandedControls(buildingProvider, hasSystem),
                            ],
                          ) : const SizedBox.shrink(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // Location controls
            Positioned(
              right: 16,
              bottom: 200,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLocationButton(locationProvider),
                  const SizedBox(height: 8),
                  _buildZoomControls(),
                ],
              ),
            ),
            
            // Recording controls (when recording)
            if (_isRecording)
              Positioned(
                bottom: 120,
                left: 16,
                right: 16,
                child: _buildRecordingControls(),
              ),
            
            // Quick action for indoor mode
            if (buildingProvider.isIndoorMode)
              Positioned(
                left: 16,
                top: 100,
                child: _buildIndoorControls(buildingProvider, roadSystemProvider),
              ),
          ],
        );
      },
    );
  }

  Widget _buildModeToggleButton(BuildingProvider buildingProvider) {
    return Container(
      decoration: BoxDecoration(
        color: buildingProvider.isIndoorMode ? Colors.purple : Colors.green,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: () {
            buildingProvider.toggleMode();
            _showModeChangeSnackBar(buildingProvider.isIndoorMode);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  buildingProvider.isIndoorMode ? Icons.business : Icons.map,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  buildingProvider.isIndoorMode ? 'INDOOR' : 'OUTDOOR',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildExpandedControls(BuildingProvider buildingProvider, bool hasSystem) {
    if (!hasSystem) {
      return [
        _buildControlButton(
          icon: Icons.warning,
          label: 'No System',
          color: Colors.orange,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please create or select a road system first')),
            );
          },
        ),
      ];
    }

    return [
      // Road recording controls
      _buildControlButton(
        icon: _isRecording ? Icons.stop : Icons.route,
        label: _isRecording ? 'Stop Recording' : 'Record Road',
        color: _isRecording ? Colors.red : Colors.blue,
        onPressed: _toggleRoadRecording,
      ),
      const SizedBox(height: 8),
      
      // Building controls
      _buildControlButton(
        icon: Icons.business,
        label: 'Add Building',
        color: Colors.purple,
        onPressed: () {
          widget.mapWidgetKey.currentState?.startBuildingMode();
          _toggleControls();
        },
      ),
      const SizedBox(height: 8),
      
      // Landmark controls
      _buildControlButton(
        icon: Icons.place,
        label: buildingProvider.isIndoorMode ? 'Add Indoor Landmark' : 'Add Outdoor Landmark',
        color: Colors.green,
        onPressed: () {
          widget.mapWidgetKey.currentState?.startLandmarkMode();
          _toggleControls();
        },
      ),
      const SizedBox(height: 8),
      
      // Navigation controls
      _buildControlButton(
        icon: Icons.navigation,
        label: 'Start Navigation',
        color: Colors.orange,
        onPressed: () {
          Navigator.pushNamed(context, '/navigation');
          _toggleControls();
        },
      ),
    ];
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onPressed,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationButton(LocationProvider locationProvider) {
    final isTracking = locationProvider.isTracking;
    final hasLocation = locationProvider.currentLatLng != null;
    
    return FloatingActionButton(
      heroTag: "location",
      onPressed: () async {
        if (hasLocation) {
          widget.mapController.move(locationProvider.currentLatLng!, 20.0);
        } else {
          await locationProvider.getCurrentLocation();
          if (locationProvider.currentLatLng != null) {
            widget.mapController.move(locationProvider.currentLatLng!, 20.0);
          }
        }
      },
      backgroundColor: isTracking ? Colors.blue : Colors.grey,
      child: Icon(
        hasLocation ? Icons.my_location : Icons.location_searching,
        color: Colors.white,
      ),
    );
  }

  Widget _buildZoomControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: "zoom_in",
          mini: true,
          onPressed: () {
            final currentZoom = widget.mapController.camera.zoom;
            widget.mapController.move(
              widget.mapController.camera.center,
              (currentZoom + 1).clamp(10.0, 22.0),
            );
          },
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          child: const Icon(Icons.add),
        ),
        const SizedBox(height: 4),
        FloatingActionButton(
          heroTag: "zoom_out",
          mini: true,
          onPressed: () {
            final currentZoom = widget.mapController.camera.zoom;
            widget.mapController.move(
              widget.mapController.camera.center,
              (currentZoom - 1).clamp(10.0, 22.0),
            );
          },
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          child: const Icon(Icons.remove),
        ),
      ],
    );
  }

  Widget _buildRecordingControls() {
    return Card(
      color: Colors.red,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.fiber_manual_record, color: Colors.white),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Recording Road Path...',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                widget.mapWidgetKey.currentState?.finishRoadRecording();
                setState(() {
                  _isRecording = false;
                });
              },
              child: const Text(
                'FINISH',
                style: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                widget.mapWidgetKey.currentState?.stopRoadRecording();
                setState(() {
                  _isRecording = false;
                });
              },
              child: const Text(
                'CANCEL',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndoorControls(BuildingProvider buildingProvider, RoadSystemProvider roadSystemProvider) {
    final building = buildingProvider.getSelectedBuilding(roadSystemProvider.currentSystem);
    final floor = buildingProvider.getSelectedFloor(roadSystemProvider.currentSystem);
    
    return Card(
      color: Colors.purple[100],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.business, color: Colors.purple[800], size: 20),
                const SizedBox(width: 6),
                Text(
                  'INDOOR MODE',
                  style: TextStyle(
                    color: Colors.purple[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (building != null) ...[
              const SizedBox(height: 4),
              Text(
                building.name,
                style: TextStyle(
                  color: Colors.purple[900],
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (floor != null)
                Text(
                  buildingProvider.getFloorDisplayName(floor),
                  style: TextStyle(
                    color: Colors.purple[700],
                    fontSize: 12,
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSmallButton(
                  icon: Icons.layers,
                  tooltip: 'Switch Floor',
                  onPressed: () => _showFloorSelector(buildingProvider, roadSystemProvider),
                ),
                const SizedBox(width: 4),
                _buildSmallButton(
                  icon: Icons.exit_to_app,
                  tooltip: 'Exit to Outdoor',
                  onPressed: () {
                    buildingProvider.goOutdoor();
                    _showModeChangeSnackBar(false);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.purple[200],
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 16, color: Colors.purple[800]),
          ),
        ),
      ),
    );
  }

  void _toggleRoadRecording() {
    setState(() {
      _isRecording = !_isRecording;
    });
    
    if (_isRecording) {
      widget.mapWidgetKey.currentState?.startRoadRecording();
      _toggleControls(); // Close the menu
    } else {
      widget.mapWidgetKey.currentState?.stopRoadRecording();
    }
  }

  void _showModeChangeSnackBar(bool isIndoor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isIndoor ? Icons.business : Icons.map,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text('Switched to ${isIndoor ? 'Indoor' : 'Outdoor'} mode'),
          ],
        ),
        backgroundColor: isIndoor ? Colors.purple : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showFloorSelector(BuildingProvider buildingProvider, RoadSystemProvider roadSystemProvider) {
    final building = buildingProvider.getSelectedBuilding(roadSystemProvider.currentSystem);
    if (building == null || building.floors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No floors available in this building')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.layers, color: Colors.purple[800]),
                const SizedBox(width: 8),
                Text(
                  'Select Floor - ${building.name}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...buildingProvider.getSortedFloorsForBuilding(building).map(
              (floor) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: buildingProvider.selectedFloorId == floor.id 
                      ? Colors.purple 
                      : Colors.grey[300],
                  child: Text(
                    floor.level.toString(),
                    style: TextStyle(
                      color: buildingProvider.selectedFloorId == floor.id 
                          ? Colors.white 
                          : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(buildingProvider.getFloorDisplayName(floor)),
                subtitle: Text('${floor.roads.length} roads, ${floor.landmarks.length} landmarks'),
                trailing: buildingProvider.selectedFloorId == floor.id 
                    ? const Icon(Icons.check_circle, color: Colors.purple)
                    : null,
                onTap: () {
                  buildingProvider.selectFloor(floor.id);
                  Navigator.pop(context);
                  
                  // Center map on floor
                  if (floor.centerPosition != null) {
                    widget.mapController.move(floor.centerPosition!, 21.0);
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Switched to ${floor.name}'),
                      backgroundColor: Colors.purple,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}