import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/location_provider.dart';
import '../providers/building_provider.dart' as bp;
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
    return Consumer4<LocationProvider, bp.BuildingProvider, RoadSystemProvider, OfflineMapProvider>(
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
                              
                              // Road System Manager
                              _buildRoadSystemManagerButton(),
                              
                              const SizedBox(height: 8),
                              
                              // Building Manager
                              _buildBuildingManagerButton(),
                              
                              const SizedBox(height: 8),
                              
                              // Road Network Analysis
                              _buildNetworkAnalysisButton(),
                              
                              const SizedBox(height: 8),
                              
                              // Center on location
                              _buildCenterLocationButton(locationProvider),
                              
                              const SizedBox(height: 8),
                              
                              // Record road button
                              if (hasSystem)
                                _buildRecordButton(),
                              
                              const SizedBox(height: 8),
                              
                              // Add landmark button (only in indoor mode)
                              if (hasSystem && buildingProvider.isIndoorMode)
                                _buildAddLandmarkButton(),
                              
                              const SizedBox(height: 8),
                              
                              // Add building button (only in outdoor mode)
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

  Widget _buildModeToggleButton(bp.BuildingProvider buildingProvider) {
    return FloatingActionButton.small(
      heroTag: "mode_toggle",
      onPressed: () {
        buildingProvider.toggleIndoorMode();
      },
      backgroundColor: buildingProvider.isIndoorMode 
          ? Colors.purple : Colors.green,
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

  Widget _buildNavigationButton() {
    return FloatingActionButton.small(
      heroTag: "navigation",
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const NavigationScreen(),
          ),
        );
        _toggleControls();
      },
      backgroundColor: Colors.teal,
      child: const Icon(Icons.navigation, size: 20),
    );
  }

  Widget _buildRoadSystemManagerButton() {
    return FloatingActionButton.small(
      heroTag: "road_system_manager",
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const RoadSystemManagerScreen(),
          ),
        );
        _toggleControls();
      },
      backgroundColor: Colors.orange,
      child: const Icon(Icons.account_tree, size: 20),
    );
  }

  Widget _buildBuildingManagerButton() {
    return FloatingActionButton.small(
      heroTag: "building_manager",
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const BuildingManagerScreen(),
          ),
        );
        _toggleControls();
      },
      backgroundColor: Colors.purple,
      child: const Icon(Icons.business_center, size: 20),
    );
  }

  Widget _buildNetworkAnalysisButton() {
    return FloatingActionButton.small(
      heroTag: "network_analysis",
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const RoadNetworkAnalyzeScreen(),
          ),
        );
        _toggleControls();
      },
      backgroundColor: Colors.indigo,
      child: const Icon(Icons.analytics, size: 20),
    );
  }

  Widget _buildCenterLocationButton(LocationProvider locationProvider) {
    return FloatingActionButton.small(
      heroTag: "center_location",
      onPressed: locationProvider.currentLatLng != null ? () {
        widget.mapWidgetKey.currentState?.centerOnCurrentLocation();
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
    widget.mapWidgetKey.currentState?.startRecordingRoad();
    _toggleControls();
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
    });
    widget.mapWidgetKey.currentState?.stopRecordingRoad();
  }

  void _pauseRecording() {
    // Show confirmation that recording is paused
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recording paused - tap stop to finish'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showQuickDownloadDialog(OfflineMapProvider offlineMapProvider, LocationProvider locationProvider) {
    if (locationProvider.currentLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location not available for download'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    double radius = 1.0;
    final TextEditingController nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Download Current Area'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Region Name (optional)',
                  hintText: 'Leave empty for auto-generated name',
                ),
              ),
              const SizedBox(height: 16),
              Text('Download radius: ${radius.toStringAsFixed(1)} km'),
              Slider(
                value: radius,
                min: 0.5,
                max: 5.0,
                divisions: 9,
                onChanged: (value) {
                  setState(() {
                    radius = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Estimated size: ${offlineMapProvider.formatBytes(
                  offlineMapProvider.estimateDownloadSize(
                    LatLng(
                      locationProvider.currentLatLng!.latitude + (radius / 111),
                      locationProvider.currentLatLng!.longitude + (radius / 111),
                    ),
                    LatLng(
                      locationProvider.currentLatLng!.latitude - (radius / 111),
                      locationProvider.currentLatLng!.longitude - (radius / 111),
                    ),
                    12,
                    17,
                  )
                )}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await offlineMapProvider.downloadAroundLocation(
                    locationProvider.currentLatLng!,
                    radius,
                    customName: nameController.text.trim().isNotEmpty 
                        ? nameController.text.trim() 
                        : null,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Download started'),
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
}