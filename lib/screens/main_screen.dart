import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import '../providers/road_system_provider.dart';
import '../providers/building_provider.dart';
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
          // Main map
          UCRoadWaysMap(
            mapController: _mapController,
          ),
          
          // Floating controls
          FloatingControls(
            mapController: _mapController,
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
          SnackBar(content: Text('System exported to: $filePath')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
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
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.location_on),
              title: Text('Location Services'),
              subtitle: Text('Manage location permissions'),
            ),
            ListTile(
              leading: Icon(Icons.map),
              title: Text('Map Settings'),
              subtitle: Text('Configure map display options'),
            ),
            ListTile(
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