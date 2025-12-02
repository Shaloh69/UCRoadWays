import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import '../providers/location_provider.dart';
import '../providers/building_provider.dart' as bp;
import '../providers/road_system_provider.dart';
import '../providers/offline_map_provider.dart';
import '../widgets/map_widget.dart';
import '../screens/offline_map_screen.dart';
import '../screens/road_system_manager_screen.dart';
import '../screens/building_manager_screen.dart'; // FIXED: Now imports the correct screen class
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
        final hasSystem = roadSystemProvider.currentSystem != null;
        
        return Stack(
          children: [
            // Main floating action button
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                heroTag: "main_fab",
                onPressed: _toggleControls,
                backgroundColor: Colors.blue,
                child: AnimatedRotation(
                  turns: _isControlsExpanded ? 0.125 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: const Icon(Icons.add),
                ),
              ),
            ),
            
            // Expanded controls - FIXED: Add max height constraint
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                // FIXED: Calculate safe max height to avoid overflow
                final screenHeight = MediaQuery.of(context).size.height;
                final maxHeight = screenHeight - 200; // Leave space for FAB and other UI

                return Positioned(
                  right: 16,
                  bottom: 80,
                  child: Transform.scale(
                    scale: _animation.value,
                    child: Opacity(
                      opacity: _animation.value,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: maxHeight, // FIXED: Prevent overflow
                        ),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                          // Mode toggle (indoor/outdoor)
                          _buildModeToggleButton(buildingProvider),
                          
                          const SizedBox(height: 8),
                          
                          // Offline status and download
                          _buildOfflineStatusButton(offlineMapProvider),
                          
                          const SizedBox(height: 8),
                          
                          // Quick download
                          _buildQuickDownloadButton(offlineMapProvider, locationProvider),
                          
                          const SizedBox(height: 8),
                          
                          // Navigation
                          _buildNavigationButton(),
                          
                          const SizedBox(height: 8),
                          
                          // Road System Manager
                          _buildRoadSystemManagerButton(),
                          
                          const SizedBox(height: 8),
                          
                          // Building Manager - FIXED: Now uses the correct class
                          _buildBuildingManagerButton(),
                          
                          const SizedBox(height: 8),
                          
                          // Road Network Analysis
                          _buildNetworkAnalysisButton(),
                          
                          const SizedBox(height: 8),
                          
                          // Center on location
                          _buildCenterLocationButton(locationProvider),
                          
                          const SizedBox(height: 8),
                          
                          // Record road button (only if system exists)
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
                      ),
                    ),
                  ),
                );
              },
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
        
        // Show feedback to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              buildingProvider.isIndoorMode 
                  ? 'Switched to Indoor Mode' 
                  : 'Switched to Outdoor Mode'
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
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
                : Icons.cloud_off,
          ),
          if (offlineMapProvider.isDownloading)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
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
      onPressed: offlineMapProvider.isDownloading 
          ? null 
          : () => _showQuickDownloadDialog(offlineMapProvider, locationProvider),
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

  // FIXED: Now correctly references the BuildingManagerScreen class
  Widget _buildBuildingManagerButton() {
    return FloatingActionButton.small(
      heroTag: "building_manager",
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const BuildingManagerScreen(), // FIXED: Correct class name
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Centered on current location'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tap on the map to add a landmark'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      backgroundColor: Colors.amber,
      child: const Icon(Icons.place, size: 20),
    );
  }

  Widget _buildAddBuildingButton() {
    return FloatingActionButton.small(
      heroTag: "add_building",
      onPressed: () {
        widget.mapWidgetKey.currentState?.startAddingBuilding();
        _toggleControls();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tap on the map to add a building'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      backgroundColor: Colors.deepPurple,
      child: const Icon(Icons.business, size: 20),
    );
  }

  // Recording control methods
  void _startRecording() {
    setState(() {
      _isRecording = true;
    });
    
    widget.mapWidgetKey.currentState?.startRecordingRoad();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Started recording road. Move around to trace the path.'),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
    });
    
    widget.mapWidgetKey.currentState?.stopRecordingRoad();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stopped recording road.'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _pauseRecording() {
    // Pause recording implementation would go here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recording paused.'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showQuickDownloadDialog(OfflineMapProvider offlineMapProvider, LocationProvider locationProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quick Download'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Download offline maps for your current area?'),
            const SizedBox(height: 16),
            if (locationProvider.currentLatLng != null)
              Text(
                'Location: ${locationProvider.currentLatLng!.latitude.toStringAsFixed(4)}, '
                '${locationProvider.currentLatLng!.longitude.toStringAsFixed(4)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (locationProvider.currentLatLng != null) {
                // Start download implementation would go here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Starting offline map download...'),
                    duration: Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }
}