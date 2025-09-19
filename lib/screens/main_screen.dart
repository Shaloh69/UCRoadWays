import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../providers/location_provider.dart';
import '../providers/road_system_provider.dart';
import '../providers/building_provider.dart';
import '../providers/offline_map_provider.dart';
import '../widgets/map_widget.dart';
import '../widgets/floating_controls.dart';
import '../widgets/bottom_panel.dart';
import '../widgets/floor_switcher.dart';
import '../screens/offline_map_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final MapController _mapController = MapController();
  final GlobalKey<UCRoadWaysMapState> _mapWidgetKey = GlobalKey<UCRoadWaysMapState>();
  bool _isPanelExpanded = false;
  bool _isInitialized = false;
  bool _showNetworkStatus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    if (_isInitialized) return;
    
    try {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      final roadSystemProvider = Provider.of<RoadSystemProvider>(context, listen: false);
      final buildingProvider = Provider.of<BuildingProvider>(context, listen: false);
      final offlineMapProvider = Provider.of<OfflineMapProvider>(context, listen: false);

      // Show loading indicator
      if (mounted) {
        _showLoadingOverlay('Initializing UCRoadWays...');
      }

      // Initialize offline map service first
      await offlineMapProvider.initialize();

      // Load saved road systems
      await roadSystemProvider.loadRoadSystems();

      // Start location tracking (LocationProvider initializes automatically)
      await locationProvider.startLocationTracking();
      
      // Check location permissions
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      // Start location tracking
      await locationProvider.startLocationTracking();

      _isInitialized = true;
      
      if (mounted) {
        _hideLoadingOverlay();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('UCRoadWays initialized successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error initializing app: $e');
      if (mounted) {
        _hideLoadingOverlay();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Initialization error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  OverlayEntry? _loadingOverlay;

  void _showLoadingOverlay(String message) {
    _loadingOverlay = OverlayEntry(
      builder: (context) => Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    Overlay.of(context).insert(_loadingOverlay!);
  }

  void _hideLoadingOverlay() {
    _loadingOverlay?.remove();
    _loadingOverlay = null;
  }

  @override
  void dispose() {
    _hideLoadingOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer4<LocationProvider, RoadSystemProvider, BuildingProvider, OfflineMapProvider>(
        builder: (context, locationProvider, roadSystemProvider, buildingProvider, offlineMapProvider, child) {
          return Stack(
            children: [
              // Main map
              UCRoadWaysMap(
                key: _mapWidgetKey,
                mapController: _mapController,
              ),
              
              // Floating controls
              FloatingControls(
                mapController: _mapController,
                mapWidgetKey: _mapWidgetKey,
              ),
              
              // Floor switcher (indoor mode only)
              FloorSwitcher(
                mapController: _mapController,
              ),
              
              // Bottom panel
              BottomPanel(
                isExpanded: _isPanelExpanded,
                onToggleExpanded: () {
                  setState(() {
                    _isPanelExpanded = !_isPanelExpanded;
                  });
                },
              ),
              
              // Offline map status and controls
              Positioned(
                top: 50,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Network status indicator
                    if (_showNetworkStatus)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                offlineMapProvider.preferOffline 
                                    ? Icons.wifi_off 
                                    : Icons.wifi,
                                size: 16,
                                color: offlineMapProvider.preferOffline 
                                    ? Colors.orange 
                                    : Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                offlineMapProvider.preferOffline 
                                    ? 'Offline' 
                                    : 'Online',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 8),
                    
                    // Offline maps button
                    FloatingActionButton.small(
                      heroTag: "offline_maps",
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const OfflineMapScreen(),
                          ),
                        );
                      },
                      backgroundColor: offlineMapProvider.preferOffline 
                          ? Colors.orange 
                          : Colors.blue,
                      child: Icon(
                        offlineMapProvider.preferOffline 
                            ? Icons.offline_pin 
                            : Icons.map,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Network status toggle
                    FloatingActionButton.small(
                      heroTag: "network_toggle",
                      onPressed: () {
                        setState(() {
                          _showNetworkStatus = !_showNetworkStatus;
                        });
                      },
                      backgroundColor: _showNetworkStatus 
                          ? Colors.green 
                          : Colors.grey,
                      child: Icon(
                        _showNetworkStatus 
                            ? Icons.network_check 
                            : Icons.network_cell,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Download progress overlay
              if (offlineMapProvider.isDownloading)
                Positioned(
                  top: 120,
                  left: 16,
                  right: 80,
                  child: Card(
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Downloading ${offlineMapProvider.currentRegionName}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Cancel Download'),
                                      content: const Text('Are you sure you want to cancel the download?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(),
                                          child: const Text('No'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            offlineMapProvider.cancelDownload();
                                            Navigator.of(context).pop();
                                          },
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                          child: const Text('Cancel'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.close, size: 18),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: offlineMapProvider.downloadProgress,
                            backgroundColor: Colors.grey[300],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${offlineMapProvider.currentTileCount}/${offlineMapProvider.totalTileCount} tiles',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                '${(offlineMapProvider.downloadProgress * 100).toStringAsFixed(1)}%',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              
              // Current location indicator
              Positioned(
                bottom: 200,
                left: 16,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              locationProvider.isTracking 
                                  ? Icons.gps_fixed 
                                  : Icons.gps_off,
                              size: 16,
                              color: locationProvider.isTracking 
                                  ? Colors.green 
                                  : Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              locationProvider.isTracking 
                                  ? 'GPS Active' 
                                  : 'GPS Inactive',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        if (locationProvider.currentLatLng != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Lat: ${locationProvider.currentLatLng!.latitude.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 10),
                          ),
                          Text(
                            'Lng: ${locationProvider.currentLatLng!.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}