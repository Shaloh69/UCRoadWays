import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../providers/location_provider.dart';
import '../providers/road_system_provider.dart';
import '../providers/building_provider.dart';
import '../widgets/map_widget.dart';
import '../widgets/floating_controls.dart';
import '../widgets/bottom_panel.dart';
import '../widgets/floor_switcher.dart';
import '../screens/road_system_manager_screen.dart';
import '../screens/building_manager_screen.dart';
import '../screens/navigation_screen.dart';
import '../screens/floor_management_screen.dart';
import '../screens/road_network_analyze_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final MapController _mapController = MapController();
  final GlobalKey<UCRoadWaysMapState> _mapWidgetKey = GlobalKey<UCRoadWaysMapState>();
  bool _isPanelExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final roadSystemProvider = Provider.of<RoadSystemProvider>(context, listen: false);
    final buildingProvider = Provider.of<BuildingProvider>(context, listen: false);

    try {
      // Load saved road systems
      await roadSystemProvider.loadRoadSystems();
      
      // Start location tracking
      await locationProvider.startLocationTracking();
      
      // Initialize building provider
      buildingProvider.reset();
      
      // Show welcome message if first time
      if (roadSystemProvider.roadSystems.isEmpty) {
        _showWelcomeDialog();
      }
    } catch (e) {
      _showErrorDialog('Initialization Error', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BuildingProvider>(
      builder: (context, buildingProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Consumer2<RoadSystemProvider, BuildingProvider>(
              builder: (context, roadSystemProvider, buildingProvider, child) {
                final currentSystem = roadSystemProvider.currentSystem;
                
                if (buildingProvider.isIndoorMode) {
                  final building = buildingProvider.getSelectedBuilding(currentSystem);
                  final floor = buildingProvider.getSelectedFloor(currentSystem);
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('UCRoadWays', style: TextStyle(fontSize: 16)),
                      if (building != null)
                        Text(
                          '${building.name}${floor != null ? ' - ${floor.name}' : ''}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                        ),
                    ],
                  );
                }
                
                return const Text('UCRoadWays');
              },
            ),
            backgroundColor: buildingProvider.isIndoorMode ? Colors.purple : Colors.blue,
            actions: [
              // Indoor/Outdoor mode indicator
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      buildingProvider.isIndoorMode ? Icons.business : Icons.landscape,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      buildingProvider.isIndoorMode ? 'Indoor' : 'Outdoor',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              IconButton(
                icon: const Icon(Icons.map),
                onPressed: () => _showRoadSystemManager(),
                tooltip: 'Road Systems',
              ),
              IconButton(
                icon: const Icon(Icons.business),
                onPressed: () => _showBuildingManager(),
                tooltip: 'Buildings',
              ),
              
              // NEW: Floor Management
              IconButton(
                icon: const Icon(Icons.layers),
                onPressed: () => _showFloorManager(),
                tooltip: 'Floor Management',
              ),
              
              IconButton(
                icon: const Icon(Icons.navigation),
                onPressed: () => _showNavigation(),
                tooltip: 'Navigation',
              ),
              
              // NEW: Network Analysis
              IconButton(
                icon: const Icon(Icons.analytics),
                onPressed: () => _showNetworkAnalyzer(),
                tooltip: 'Network Analysis',
              ),
              
              PopupMenuButton<String>(
                onSelected: _handleMenuAction,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'export',
                    child: ListTile(
                      leading: Icon(Icons.file_upload),
                      title: Text('Export System'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'import',
                    child: ListTile(
                      leading: Icon(Icons.file_download),
                      title: Text('Import System'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'location_test',
                    child: ListTile(
                      leading: Icon(Icons.location_searching),
                      title: Text('Test Location'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'reset_view',
                    child: ListTile(
                      leading: Icon(Icons.refresh),
                      title: Text('Reset View'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings),
                      title: Text('Settings'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Stack(
            children: [
              // Main map with key for external access
              UCRoadWaysMap(
                key: _mapWidgetKey,
                mapController: _mapController,
              ),
              
              // Floating controls with reference to map widget
              FloatingControls(
                mapController: _mapController,
                mapWidgetKey: _mapWidgetKey,
                onTogglePanel: () {
                  setState(() {
                    _isPanelExpanded = !_isPanelExpanded;
                  });
                },
              ),
              
              // Bottom panel
              BottomPanel(
                isExpanded: _isPanelExpanded,
                onToggle: () {
                  setState(() {
                    _isPanelExpanded = !_isPanelExpanded;
                  });
                },
              ),
              
              // NEW: Floor-specific status overlay
              if (buildingProvider.isIndoorMode)
                Positioned(
                  bottom: _isPanelExpanded ? 450 : 100,
                  right: 90, // Position next to other controls
                  child: FloorSwitcher(
                    onFloorChanged: _onFloorChanged,
                    isCompact: true,
                  ),
                ),
              
              // NEW: Connection status indicator
              Positioned(
                top: MediaQuery.of(context).padding.top + 56, // Below app bar
                left: 0,
                right: 0,
                child: Consumer3<LocationProvider, RoadSystemProvider, BuildingProvider>(
                  builder: (context, locationProvider, roadSystemProvider, buildingProvider, child) {
                    return _buildStatusBar(locationProvider, roadSystemProvider, buildingProvider);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBar(
    LocationProvider locationProvider, 
    RoadSystemProvider roadSystemProvider, 
    BuildingProvider buildingProvider
  ) {
    final hasIssues = locationProvider.error != null || 
                     roadSystemProvider.error != null ||
                     !buildingProvider.isSelectionValid(roadSystemProvider.currentSystem);
    
    if (!hasIssues && locationProvider.isTracking) {
      return const SizedBox.shrink(); // No issues, don't show status bar
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasIssues ? Colors.orange[100] : Colors.green[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasIssues ? Colors.orange : Colors.green,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasIssues ? Icons.warning : Icons.check_circle,
            color: hasIssues ? Colors.orange : Colors.green,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _getStatusMessage(locationProvider, roadSystemProvider, buildingProvider),
              style: TextStyle(
                color: hasIssues ? Colors.orange[800] : Colors.green[800],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (hasIssues)
            TextButton(
              onPressed: () => _handleStatusAction(locationProvider, roadSystemProvider, buildingProvider),
              child: const Text('Fix', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  String _getStatusMessage(
    LocationProvider locationProvider, 
    RoadSystemProvider roadSystemProvider, 
    BuildingProvider buildingProvider
  ) {
    if (locationProvider.error != null) {
      return 'Location services unavailable';
    }
    
    if (roadSystemProvider.error != null) {
      return 'Road system error: ${roadSystemProvider.error}';
    }
    
    if (roadSystemProvider.currentSystem == null) {
      return 'No road system selected';
    }
    
    if (!buildingProvider.isSelectionValid(roadSystemProvider.currentSystem)) {
      return 'Invalid floor selection';
    }
    
    if (!locationProvider.isTracking) {
      return 'Location tracking disabled';
    }
    
    return 'All systems operational';
  }

  void _handleStatusAction(
    LocationProvider locationProvider, 
    RoadSystemProvider roadSystemProvider, 
    BuildingProvider buildingProvider
  ) {
    if (locationProvider.error != null) {
      _testLocationAccess();
    } else if (roadSystemProvider.currentSystem == null) {
      _showRoadSystemManager();
    } else if (!buildingProvider.isSelectionValid(roadSystemProvider.currentSystem)) {
      buildingProvider.reset();
    } else {
      locationProvider.startLocationTracking();
    }
  }

  void _onFloorChanged() {
    // Update map zoom and position when floor changes
    final buildingProvider = Provider.of<BuildingProvider>(context, listen: false);
    final roadSystemProvider = Provider.of<RoadSystemProvider>(context, listen: false);
    
    if (buildingProvider.isIndoorMode) {
      final building = buildingProvider.getSelectedBuilding(roadSystemProvider.currentSystem);
      if (building != null) {
        _mapController.move(building.centerPosition, 21.0);
      }
    } else {
      // Outdoor mode - zoom out to system level
      final system = roadSystemProvider.currentSystem;
      if (system != null) {
        _mapController.move(system.centerPosition, system.zoom);
      }
    }
  }

  void _showRoadSystemManager() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const RoadSystemManagerScreen(),
      ),
    );
  }

  void _showBuildingManager() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BuildingManagerScreen(),
      ),
    );
  }

  void _showFloorManager() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const FloorManagementScreen(),
      ),
    );
  }

  void _showNavigation() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NavigationScreen(),
      ),
    );
  }

  void _showNetworkAnalyzer() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const RoadNetworkAnalyzerScreen(),
      ),
    );
  }

  void _showWelcomeDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.waving_hand, color: Colors.orange),
              SizedBox(width: 8),
              Text('Welcome to UCRoadWays!'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Get started with indoor and outdoor navigation:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('1. Create or import a road system'),
              Text('2. Add buildings and floors'),
              Text('3. Map indoor routes and landmarks'),
              Text('4. Navigate with turn-by-turn directions'),
              SizedBox(height: 12),
              Text(
                'The app works both indoors and outdoors with comprehensive floor-by-floor navigation.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Get Started'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showRoadSystemManager();
              },
              child: const Text('Create System'),
            ),
          ],
        ),
      );
    });
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initializeApp(); // Retry initialization
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _testLocationAccess() async {
    try {
      print('=== TESTING LOCATION ===');
      
      // Test location service
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('Location Service Enabled: $serviceEnabled');
      
      if (!serviceEnabled) {
        _showLocationServiceDialog();
        return;
      }

      // Test permission
      LocationPermission permission = await Geolocator.checkPermission();
      print('Permission Status: $permission');
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print('Permission after request: $permission');
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationPermissionDialog();
        return;
      }

      // Test getting location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      print('SUCCESS: ${position.latitude}, ${position.longitude}');
      print('Accuracy: ${position.accuracy}m');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}\n'
            'Accuracy: ${position.accuracy.toStringAsFixed(1)}m'
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
      
      // Auto-center on location
      _mapController.move(
        LatLng(position.latitude, position.longitude), 
        20.0
      );
      
    } catch (e) {
      print('ERROR: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Location Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text(
          'Please enable location services in your device settings to use navigation features.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'Location permission is permanently denied. Please enable it in app settings to use navigation features.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) async {
    final roadSystemProvider = Provider.of<RoadSystemProvider>(context, listen: false);
    final buildingProvider = Provider.of<BuildingProvider>(context, listen: false);
    
    switch (action) {
      case 'export':
        await _exportCurrentSystem(roadSystemProvider);
        break;
      case 'import':
        await _importSystem(roadSystemProvider);
        break;
      case 'location_test':
        _testLocationAccess();
        break;
      case 'reset_view':
        _resetView(roadSystemProvider, buildingProvider);
        break;
      case 'settings':
        _showSettings();
        break;
    }
  }

  Future<void> _exportCurrentSystem(RoadSystemProvider provider) async {
    if (provider.currentSystem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No road system to export')),
      );
      return;
    }

    try {
      final filePath = await provider.exportCurrentSystem();
      if (filePath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ System exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _importSystem(RoadSystemProvider provider) async {
    try {
      await provider.importRoadSystem();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ System imported successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Import failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resetView(RoadSystemProvider roadSystemProvider, BuildingProvider buildingProvider) {
    // Reset to outdoor mode
    buildingProvider.switchToOutdoorMode();
    
    // Center on system or default location
    final system = roadSystemProvider.currentSystem;
    if (system != null) {
      _mapController.move(system.centerPosition, system.zoom);
    } else {
      _mapController.move(const LatLng(33.9737, -117.3281), 16.0); // UC Riverside
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔄 View reset to outdoor mode'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Location Services'),
              subtitle: const Text('Manage location permissions'),
              onTap: () {
                Navigator.pop(context);
                _testLocationAccess();
              },
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Map Settings'),
              subtitle: const Text('Configure map display options'),
              onTap: () {
                Navigator.pop(context);
                _showMapSettings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.layers),
              title: const Text('Floor Settings'),
              subtitle: const Text('Indoor navigation preferences'),
              onTap: () {
                Navigator.pop(context);
                _showFloorSettings();
              },
            ),
            const ListTile(
              leading: Icon(Icons.info),
              title: Text('About'),
              subtitle: Text('UCRoadWays v1.0.0 - Multi-floor navigation'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showMapSettings() {
    // Implementation for map settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Map settings would be shown here')),
    );
  }

  void _showFloorSettings() {
    // Implementation for floor settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Floor settings would be shown here')),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}