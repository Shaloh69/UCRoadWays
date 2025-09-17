import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../providers/location_provider.dart';
import '../providers/road_system_provider.dart';
import '../widgets/map_widget.dart';
import '../widgets/floating_controls.dart';
import '../widgets/bottom_panel.dart';
import '../screens/road_system_manager_screen.dart';
import '../screens/building_manager_screen.dart';
import '../screens/navigation_screen.dart';

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

    // Load saved road systems
    await roadSystemProvider.loadRoadSystems();
    
    // Start location tracking
    await locationProvider.startLocationTracking();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UCRoadWays'),
        actions: [
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
          IconButton(
            icon: const Icon(Icons.navigation),
            onPressed: () => _showNavigation(),
            tooltip: 'Navigation',
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () => _showLocationDebug(),
            tooltip: 'Location Debug',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.file_upload),
                  title: Text('Export System'),
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.file_download),
                  title: Text('Import System'),
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Settings'),
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
        ],
      ),
    );
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

  void _showNavigation() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NavigationScreen(),
      ),
    );
  }

  void _showLocationDebug() {
    // Quick location test
    _testLocationAccess();
  }

  void _testLocationAccess() async {
    try {
      print('=== TESTING LOCATION ===');
      
      // Test location service
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('Location Service Enabled: $serviceEnabled');
      
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 Please enable location services in device settings'),
            backgroundColor: Colors.orange,
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Location permission denied. Please enable in app settings.'),
            backgroundColor: Colors.red,
          ),
        );
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

  void _handleMenuAction(String action) async {
    final roadSystemProvider = Provider.of<RoadSystemProvider>(context, listen: false);
    
    switch (action) {
      case 'export':
        await _exportCurrentSystem(roadSystemProvider);
        break;
      case 'import':
        await _importSystem(roadSystemProvider);
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
        const SnackBar(content: Text('System imported successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
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
                // Could open location settings
              },
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Map Settings'),
              subtitle: const Text('Configure map display options'),
              onTap: () {
                Navigator.pop(context);
                // Could open map settings
              },
            ),
            const ListTile(
              leading: Icon(Icons.info),
              title: Text('About'),
              subtitle: Text('UCRoadWays v1.0.0'),
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

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}