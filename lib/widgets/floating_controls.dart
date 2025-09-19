import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import '../providers/location_provider.dart';
import '../providers/building_provider.dart';
import '../providers/road_system_provider.dart';
import '../providers/offline_map_provider.dart';
import '../widgets/map_widget.dart';
import '../screens/offline_map_screen.dart';
import '../screens/road_system_manager_screen.dart';
import '../screens/building_manager_screen.dart';
import '../screens/navigation_screen.dart';
import '../screens/road_network_analyze_screen.dart';

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
    return Consumer4<LocationProvider, BuildingProvider, RoadSystemProvider, OfflineMapProvider>(
      builder: (context, locationProvider, buildingProvider, roadSystemProvider, offlineMapProvider, child) {
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
                  
                  // Offline status indicator
                  _buildOfflineStatusButton(offlineMapProvider),
                  const SizedBox(height: 8),
                  
                  // Main menu button
                  FloatingActionButton(
                    heroTag: "main_menu",
                    onPressed: _toggleControls,
                    backgroundColor: _isControlsExpanded ? Colors.red : Colors.blue,
                    child: AnimatedRotation(
                      turns: _isControlsExpanded ? 0.125 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(_isControlsExpanded ? Icons.close : Icons.menu),
                    ),
                  ),
                  
                  // Expanded controls
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _animation.value,
                        alignment: Alignment.topCenter,
                        child: Opacity(
                          opacity: _animation.value,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 8),
                              
                              // Quick download current area
                              if (hasSystem && locationProvider.currentLatLng != null)
                                _buildQuickDownloadButton(offlineMapProvider, locationProvider),
                              
                              const SizedBox(height: 8),
                              
                              // Navigation to other screens
                              _buildNavigationButton(),
                              
                              const SizedBox(height: 8),
                              
                              // Center on location
                              _buildCenterLocationButton(locationProvider),
                              
                              const SizedBox(height: 8),
                              
                              // Record road button
                              if (hasSystem)
                                _buildRecordButton(),
                              
                              const SizedBox(height: 8),
                              
                              // Add landmark button
                              if (hasSystem && buildingProvider.isIndoorMode)
                                _buildAddLandmarkButton(),
                              
                              const SizedBox(height: 8),
                              
                              // Add building button
                              if (hasSystem && !buildingProvider.isIndoorMode)
                                _buildAddBuildingButton(),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // Recording controls (when recording)
            if (_isRecording)
              Positioned(
                right: 16,
                bottom: 200,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton(
                      heroTag: "stop_recording",
                      onPressed: _stopRecording,
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.stop),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: "pause_recording",
                      onPressed: _pauseRecording,
                      backgroundColor: Colors.orange,
                      child: const Icon(Icons.pause),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildModeToggleButton(BuildingProvider buildingProvider) {
    return FloatingActionButton(
      heroTag: "mode_toggle",
      onPressed: () {
        buildingProvider.toggleMode();
      },
      backgroundColor: buildingProvider.isIndoorMode ? Colors.purple : Colors.green,
      child: Icon(
        buildingProvider.isIndoorMode ? Icons.business : Icons.landscape,
      ),
    );
  }

  Widget _buildOfflineStatusButton(OfflineMapProvider offlineMapProvider) {
    return FloatingActionButton.small(
      heroTag: "offline_status",
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const OfflineMapScreen(),
          ),
        );
      },
      backgroundColor: offlineMapProvider.preferOffline 
          ? (offlineMapProvider.isDownloading ? Colors.orange : Colors.green)
          : Colors.grey,
      child: Stack(
        children: [
          Icon(
            offlineMapProvider.preferOffline 
                ? Icons.offline_pin 
                : Icons.cloud,
            size: 20,
          ),
          if (offlineMapProvider.isDownloading)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickDownloadButton(OfflineMapProvider offlineMapProvider, LocationProvider locationProvider) {
    return FloatingActionButton.small(
      heroTag: "quick_download",
      onPressed: offlineMapProvider.isDownloading ? null : () {
        _showQuickDownloadDialog(offlineMapProvider, locationProvider);
      },
      backgroundColor: offlineMapProvider.isDownloading ? Colors.grey : Colors.blue,
      child: Icon(
        offlineMapProvider.isDownloading ? Icons.downloading : Icons.download,
        size: 20,
      ),
    );
  }

  Widget _buildCenterLocationButton(LocationProvider locationProvider) {
    return FloatingActionButton.small(
      heroTag: "center_location",
      onPressed: locationProvider.currentLatLng != null ? () {
        widget.mapController.move(
          locationProvider.currentLatLng!,
          widget.mapController.camera.zoom,
        );
      } : null,
      backgroundColor: locationProvider.currentLatLng != null ? Colors.blue : Colors.grey,
      child: const Icon(Icons.my_location, size: 20),
    );
  }

  Widget _buildRecordButton() {
    return FloatingActionButton.small(
      heroTag: "record_road",
      onPressed: _isRecording ? null : _startRecording,
      backgroundColor: _isRecording ? Colors.grey : Colors.red,
      child: Icon(
        _isRecording ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        size: 20,
      ),
    );
  }

  Widget _buildAddLandmarkButton() {
    return FloatingActionButton.small(
      heroTag: "add_landmark",
      onPressed: () {
        widget.mapWidgetKey.currentState?.startAddingLandmark();
        _toggleControls();
      },
      backgroundColor: Colors.green,
      child: const Icon(Icons.place, size: 20),
    );
  }

  Widget _buildAddBuildingButton() {
    return FloatingActionButton.small(
      heroTag: "add_building",
      onPressed: () {
        widget.mapWidgetKey.currentState?.startAddingBuilding();
        _toggleControls();
      },
      backgroundColor: Colors.purple,
      child: const Icon(Icons.business, size: 20),
    );
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
    });
    widget.mapWidgetKey.currentState?.startRoadRecording();
    _toggleControls();
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
    });
    widget.mapWidgetKey.currentState?.stopRoadRecording();
  }

  void _pauseRecording() {
    // Implement pause functionality if needed
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recording paused'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showQuickDownloadDialog(OfflineMapProvider offlineMapProvider, LocationProvider locationProvider) {
    double radius = 1.0;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Download Current Area'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Download offline maps for the current area'),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Radius: '),
                  Expanded(
                    child: Slider(
                      value: radius,
                      min: 0.5,
                      max: 5.0,
                      divisions: 9,
                      label: '${radius.toStringAsFixed(1)} km',
                      onChanged: (value) {
                        setState(() {
                          radius = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              Text(
                'Estimated size: ${_getEstimatedSize(radius)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                _toggleControls();
                
                try {
                  final regionName = 'Current_Area_${DateTime.now().millisecondsSinceEpoch}';
                  await offlineMapProvider.downloadCurrentView(
                    center: locationProvider.currentLatLng!,
                    zoom: widget.mapController.camera.zoom,
                    regionName: regionName,
                    radiusKm: radius,
                  );
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Downloaded $regionName successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Download failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Download'),
            ),
          ],
        ),
      ),
    );
  }

  String _getEstimatedSize(double radius) {
    // Rough estimation: 1km radius ≈ 2MB at zoom levels 10-18
    final estimatedMB = (radius * radius * 2).round();
    if (estimatedMB < 1) {
      return '< 1 MB';
    } else {
      return '$estimatedMB MB';
    }
  }

  Widget _buildNavigationButton() {
    return FloatingActionButton.small(
      heroTag: "navigation_menu",
      onPressed: () {
        _showNavigationMenu();
      },
      backgroundColor: Colors.purple,
      child: const Icon(Icons.apps, size: 20),
    );
  }

  void _showNavigationMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Navigate to...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Road Systems'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const RoadSystemManagerScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Buildings'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const BuildingManagerScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.navigation),
              title: const Text('Navigation'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const NavigationScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Network Analysis'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const RoadNetworkAnalyzerScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  String _getEstimatedSize(double radius) {
    // Rough estimation: 1km radius ≈ 2MB at zoom levels 10-18
    final estimatedMB = (radius * radius * 2).round();
    if (estimatedMB < 1) {
      return '< 1 MB';
    } else {
      return '$estimatedMB MB';
    }
  }
}
    }