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
  bool _isInitialized = false;

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

      // Show loading indicator
      if (mounted) {
        _showLoadingOverlay('Initializing UCRoadWays...');
      }

      // Load saved road systems
      await roadSystemProvider.loadRoadSystems();
      
      // Start location tracking
      await locationProvider.startLocationTracking();
      
      // Initialize building provider
      buildingProvider.reset();
      
      // Hide loading indicator
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // Show welcome message if first time
      if (roadSystemProvider.roadSystems.isEmpty) {
        _showWelcomeDialog();
      } else {
        _showQuickStartTooltips();
      }
      
      setState(() {
        _isInitialized = true;
      });
      
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Hide loading
        _showErrorDialog('Initialization Error', e.toString());
      }
    }
  }

  void _showLoadingOverlay(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer3<LocationProvider, RoadSystemProvider, BuildingProvider>(
        builder: (context, locationProvider, roadSystemProvider, buildingProvider, child) {
          return Stack(
            children: [
              // Main map widget
              UCRoadWaysMap(
                key: _mapWidgetKey,
                mapController: _mapController,
              ),
              
              // Floating controls
              FloatingControls(
                mapController: _mapController,
                mapWidgetKey: _mapWidgetKey,
              ),
              
              // Floor switcher (when in indoor mode)
              if (buildingProvider.isIndoorMode)
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
              
              // Top status bar
              _buildTopStatusBar(roadSystemProvider, buildingProvider, locationProvider),
              
              // Quick actions drawer handle
              _buildQuickActionsHandle(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopStatusBar(
    RoadSystemProvider roadSystemProvider,
    BuildingProvider buildingProvider,
    LocationProvider locationProvider,
  ) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.location_on,
                color: locationProvider.isTracking ? Colors.green : Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  roadSystemProvider.currentSystem?.name ?? 'No System Selected',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (buildingProvider.isIndoorMode) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'INDOOR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: _handleMenuAction,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'systems',
                    child: ListTile(
                      leading: Icon(Icons.map),
                      title: Text('Road Systems'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'buildings',
                    child: ListTile(
                      leading: Icon(Icons.business),
                      title: Text('Buildings'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'navigation',
                    child: ListTile(
                      leading: Icon(Icons.navigation),
                      title: Text('Navigation'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'floors',
                    child: ListTile(
                      leading: Icon(Icons.layers),
                      title: Text('Floor Manager'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'analyzer',
                    child: ListTile(
                      leading: Icon(Icons.analytics),
                      title: Text('Network Analyzer'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsHandle() {
    return Positioned(
      left: 0,
      top: MediaQuery.of(context).size.height * 0.4,
      child: GestureDetector(
        onTap: _showQuickActionsDrawer,
        child: Container(
          height: 60,
          width: 30,
          decoration: const BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(15),
              bottomRight: Radius.circular(15),
            ),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.keyboard_arrow_right, color: Colors.white, size: 16),
              Icon(Icons.menu, color: Colors.white, size: 16),
              Icon(Icons.keyboard_arrow_right, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickActionsDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
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
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.all(16),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _buildQuickActionCard(
                    icon: Icons.map,
                    title: 'Road Systems',
                    subtitle: 'Manage your road networks',
                    color: Colors.blue,
                    onTap: _showRoadSystemManager,
                  ),
                  _buildQuickActionCard(
                    icon: Icons.business,
                    title: 'Buildings',
                    subtitle: 'Add and manage buildings',
                    color: Colors.purple,
                    onTap: _showBuildingManager,
                  ),
                  _buildQuickActionCard(
                    icon: Icons.navigation,
                    title: 'Navigation',
                    subtitle: 'Find your way around',
                    color: Colors.green,
                    onTap: _showNavigation,
                  ),
                  _buildQuickActionCard(
                    icon: Icons.layers,
                    title: 'Floor Manager',
                    subtitle: 'Organize building floors',
                    color: Colors.orange,
                    onTap: _showFloorManager,
                  ),
                  _buildQuickActionCard(
                    icon: Icons.analytics,
                    title: 'Network Analyzer',
                    subtitle: 'Analyze road connections',
                    color: Colors.teal,
                    onTap: _showNetworkAnalyzer,
                  ),
                  _buildQuickActionCard(
                    icon: Icons.help_outline,
                    title: 'Help & Tips',
                    subtitle: 'Learn how to use the app',
                    color: Colors.indigo,
                    onTap: _showHelpDialog,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'systems':
        _showRoadSystemManager();
        break;
      case 'buildings':
        _showBuildingManager();
        break;
      case 'navigation':
        _showNavigation();
        break;
      case 'floors':
        _showFloorManager();
        break;
      case 'analyzer':
        _showNetworkAnalyzer();
        break;
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
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Explore'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showRoadSystemManager();
              },
              child: const Text('Create Road System'),
            ),
          ],
        ),
      );
    });
  }

  void _showQuickStartTooltips() {
    // Show quick tooltips for key features after a delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Tap the + button to add buildings, landmarks, and roads'),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'Got it',
              onPressed: () {},
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
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
          ElevatedButton(
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

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help, color: Colors.blue),
            SizedBox(width: 8),
            Text('How to Use UCRoadWays'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Creating Road Systems:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Tap "Road Systems" to create or manage your navigation networks'),
              SizedBox(height: 12),
              
              Text(
                'Adding Buildings:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Long press on the map or use the + button to add buildings'),
              Text('• Add floors to buildings for multi-level navigation'),
              SizedBox(height: 12),
              
              Text(
                'Creating Roads:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Use the "Record Road" button and walk the path'),
              Text('• Works both indoors and outdoors'),
              SizedBox(height: 12),
              
              Text(
                'Adding Landmarks:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Tap to add important locations like bathrooms, classrooms'),
              Text('• Add elevators and stairs for floor connections'),
              SizedBox(height: 12),
              
              Text(
                'Indoor Mode:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Tap on buildings to enter indoor mode'),
              Text('• Switch between floors using the floor selector'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
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