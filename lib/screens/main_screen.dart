import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:math' as math;
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

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final GlobalKey<UCRoadWaysMapState> _mapWidgetKey = GlobalKey<UCRoadWaysMapState>();
  
  // UI State
  bool _isPanelExpanded = false;
  bool _showNetworkStatus = false;
  
  // Initialization State
  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _initializationError;
  double _initializationProgress = 0.0;
  String _initializationStatus = 'Starting...';
  
  // Auto-retry
  Timer? _retryTimer;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  
  // App lifecycle
  bool _isAppActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    _isAppActive = state == AppLifecycleState.resumed;
    
    if (state == AppLifecycleState.paused) {
      // App going to background - save state if needed
      _saveAppState();
    } else if (state == AppLifecycleState.resumed) {
      // App coming back to foreground - refresh if needed
      _refreshAppState();
    }
  }

  Future<void> _saveAppState() async {
    try {
      final roadSystemProvider = Provider.of<RoadSystemProvider>(context, listen: false);
      await roadSystemProvider.saveRoadSystems();
      debugPrint('App state saved');
    } catch (e) {
      debugPrint('Failed to save app state: $e');
    }
  }

  Future<void> _refreshAppState() async {
    if (!_isInitialized) return;
    
    try {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      
      // Restart location tracking if it was stopped
      if (!locationProvider.isTracking && locationProvider.hasPermission) {
        await locationProvider.startLocationTracking();
      }
      
      debugPrint('App state refreshed');
    } catch (e) {
      debugPrint('Failed to refresh app state: $e');
    }
  }

  Future<void> _initializeApp() async {
    if (_isInitialized || _isInitializing) return;
    
    setState(() {
      _isInitializing = true;
      _initializationError = null;
      _initializationProgress = 0.0;
      _initializationStatus = 'Initializing UCRoadWays...';
    });

    try {
      // Show loading overlay
      _showLoadingOverlay();
      
      // Get providers
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      final roadSystemProvider = Provider.of<RoadSystemProvider>(context, listen: false);
      final buildingProvider = Provider.of<BuildingProvider>(context, listen: false);
      final offlineMapProvider = Provider.of<OfflineMapProvider>(context, listen: false);

      // Step 1: Initialize offline map service (critical for map functionality)
      _updateInitializationProgress(0.1, 'Initializing offline maps...');
      await offlineMapProvider.initialize();
      
      // Step 2: Load saved road systems
      _updateInitializationProgress(0.3, 'Loading road systems...');
      await roadSystemProvider.loadRoadSystems();
      
      // Step 3: Initialize location services
      _updateInitializationProgress(0.5, 'Setting up GPS...');
      await _initializeLocationServices(locationProvider);
      
      // Step 4: Load app preferences and settings
      _updateInitializationProgress(0.7, 'Loading preferences...');
      await _loadAppPreferences();
      
      // Step 5: Perform health checks
      _updateInitializationProgress(0.8, 'Running system checks...');
      await _performHealthChecks();
      
      // Step 6: Final setup
      _updateInitializationProgress(0.9, 'Finalizing setup...');
      await _finalizeInitialization();
      
      // Complete
      _updateInitializationProgress(1.0, 'Ready!');
      
      // Small delay to show completion
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
        _isInitialized = true;
        _isInitializing = false;
        _retryCount = 0;
      });
      
      _hideLoadingOverlay();
      
      // Show welcome message for first-time users
      _checkAndShowWelcome();
      
      debugPrint('UCRoadWays initialization completed successfully');
      
    } catch (e, stackTrace) {
      debugPrint('Initialization failed: $e');
      debugPrint('Stack trace: $stackTrace');
      
      setState(() {
        _initializationError = e.toString();
        _isInitializing = false;
      });
      
      _hideLoadingOverlay();
      _handleInitializationError(e);
    }
  }

  void _updateInitializationProgress(double progress, String status) {
    if (mounted) {
      setState(() {
        _initializationProgress = progress;
        _initializationStatus = status;
      });
    }
    debugPrint('Initialization: ${(progress * 100).toInt()}% - $status');
  }

  Future<void> _initializeLocationServices(LocationProvider locationProvider) async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        // Don't fail initialization, just warn
        return;
      }
      
      // Start location tracking
      await locationProvider.startLocationTracking();
      
    } catch (e) {
      debugPrint('Location initialization failed: $e');
      // Don't fail app initialization for location issues
    }
  }

  Future<void> _loadAppPreferences() async {
    try {
      // Load app preferences, themes, etc.
      // In a real implementation, load from SharedPreferences
      await Future.delayed(const Duration(milliseconds: 200)); // Simulate loading
    } catch (e) {
      debugPrint('Failed to load preferences: $e');
      // Don't fail initialization for preferences
    }
  }

  Future<void> _performHealthChecks() async {
    try {
      // Check critical app components
      final offlineMapProvider = Provider.of<OfflineMapProvider>(context, listen: false);
      
      if (!offlineMapProvider.isInitialized) {
        throw Exception('Offline map service failed to initialize');
      }
      
      // Add more health checks as needed
      await Future.delayed(const Duration(milliseconds: 100));
      
    } catch (e) {
      debugPrint('Health check failed: $e');
      rethrow; // Health check failures should stop initialization
    }
  }

  Future<void> _finalizeInitialization() async {
    try {
      // Final setup tasks
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      debugPrint('Finalization failed: $e');
    }
  }

  void _handleInitializationError(dynamic error) {
    String errorMessage = 'An unexpected error occurred during initialization.';
    String? actionAdvice;
    
    if (error.toString().contains('location')) {
      errorMessage = 'Location services initialization failed.';
      actionAdvice = 'Please enable location services and restart the app.';
    } else if (error.toString().contains('offline')) {
      errorMessage = 'Offline map system failed to initialize.';
      actionAdvice = 'Check your storage permissions and available space.';
    } else if (error.toString().contains('permission')) {
      errorMessage = 'Required permissions were not granted.';
      actionAdvice = 'Please grant necessary permissions in app settings.';
    }
    
    _showErrorDialog(errorMessage, actionAdvice);
  }

  void _showErrorDialog(String message, String? advice) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Initialization Error'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (advice != null) ...[
              const SizedBox(height: 12),
              Text(
                advice,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_retryCount < _maxRetries)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _retryInitialization();
              },
              child: const Text('Retry'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _continueWithLimitedFunctionality();
            },
            child: const Text('Continue Anyway'),
          ),
          TextButton(
            onPressed: () => _openAppSettings(),
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  void _retryInitialization() {
    _retryCount++;
    debugPrint('Retrying initialization (attempt $_retryCount/$_maxRetries)');
    
    // Add exponential backoff
    final delay = Duration(seconds: math.min(_retryCount * 2, 10));
    
    _retryTimer = Timer(delay, () {
      _initializeApp();
    });
  }

  void _continueWithLimitedFunctionality() {
    setState(() {
      _isInitialized = true;
      _isInitializing = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Running with limited functionality. Some features may not work properly.'),
        duration: Duration(seconds: 5),
      ),
    );
  }

  void _openAppSettings() async {
    try {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      await locationProvider.openAppSettings();
    } catch (e) {
      debugPrint('Failed to open app settings: $e');
    }
  }

  void _checkAndShowWelcome() {
    final roadSystemProvider = Provider.of<RoadSystemProvider>(context, listen: false);
    
    // Show welcome if no road systems exist
    if (roadSystemProvider.roadSystems.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showWelcomeDialog();
      });
    }
  }

  void _showWelcomeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Welcome to UCRoadWays!'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('UCRoadWays helps you navigate indoor and outdoor spaces with precision.'),
            SizedBox(height: 12),
            Text('Key Features:'),
            Text('• GPS tracking and navigation'),
            Text('• Indoor mapping and wayfinding'),
            Text('• Offline map support'),
            Text('• Custom road system creation'),
            SizedBox(height: 12),
            Text('Get started by creating your first road system or exploring the existing ones.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Get Started'),
          ),
        ],
      ),
    );
  }

  void _showLoadingOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  _initializationStatus,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: _initializationProgress),
                const SizedBox(height: 8),
                Text(
                  '${(_initializationProgress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _hideLoadingOverlay() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized && !_isInitializing) {
      return _buildErrorState();
    }
    
    if (_isInitializing) {
      return _buildInitializingState();
    }

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
              
              // FIXED: Floating controls with proper integration
              FloatingControls(
                mapController: _mapController,
                mapWidgetKey: _mapWidgetKey,
              ),
              
              // Floor switcher (when in indoor mode)
              if (buildingProvider.isIndoorMode && buildingProvider.getSelectedBuilding(roadSystemProvider.currentSystem) != null)
                FloorSwitcher(
                  mapController: _mapController,
                ),
              
              // Bottom panel
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: BottomPanel(
                  isExpanded: _isPanelExpanded,
                  onToggleExpanded: () => setState(() => _isPanelExpanded = !_isPanelExpanded),
                ),
              ),
              
              // Network status indicator
              if (_showNetworkStatus)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  child: _buildNetworkStatusIndicator(offlineMapProvider),
                ),
              
              // Download progress indicator
              if (offlineMapProvider.isDownloading)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  child: _buildDownloadIndicator(offlineMapProvider),
                ),
              
              // GPS status indicator
              Positioned(
                bottom: 200,
                left: 16,
                child: _buildGPSStatusIndicator(locationProvider),
              ),
              
              // Error banner
              if (_initializationError != null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  child: _buildErrorBanner(),
                ),
            ],
          );
        },
      ),
      drawer: _buildAppDrawer(),
    );
  }

  Widget _buildInitializingState() {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo or icon
            Icon(
              Icons.map,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            
            // App name
            Text(
              'UCRoadWays',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),
            
            // Loading indicator
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            
            // Status text
            Text(
              _initializationStatus,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Progress bar
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(value: _initializationProgress),
            ),
            const SizedBox(height: 8),
            
            // Progress percentage
            Text(
              '${(_initializationProgress * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 24),
              
              Text(
                'Failed to Start',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                _initializationError ?? 'Unknown error occurred',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_retryCount < _maxRetries) ...[
                    ElevatedButton(
                      onPressed: () => _retryInitialization(),
                      child: const Text('Retry'),
                    ),
                    const SizedBox(width: 16),
                  ],
                  OutlinedButton(
                    onPressed: () => _continueWithLimitedFunctionality(),
                    child: const Text('Continue Anyway'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkStatusIndicator(OfflineMapProvider offlineMapProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              offlineMapProvider.preferOffline ? Icons.cloud_off : Icons.cloud,
              size: 20,
              color: offlineMapProvider.preferOffline ? Colors.blue : Colors.green,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                offlineMapProvider.preferOffline ? 'Offline Mode' : 'Online Mode',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => setState(() => _showNetworkStatus = false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadIndicator(OfflineMapProvider offlineMapProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.download, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Downloading ${offlineMapProvider.currentRegionName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: offlineMapProvider.downloadProgress),
            const SizedBox(height: 4),
            Text(
              '${offlineMapProvider.currentTileCount}/${offlineMapProvider.totalTileCount} tiles (${(offlineMapProvider.downloadProgress * 100).toStringAsFixed(1)}%)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGPSStatusIndicator(LocationProvider locationProvider) {
    return Card(
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
                  locationProvider.isTracking ? Icons.gps_fixed : Icons.gps_off,
                  size: 16,
                  color: locationProvider.isTracking ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  locationProvider.isTracking ? 'GPS Active' : 'GPS Inactive',
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
              if (locationProvider.accuracy > 0)
                Text(
                  'Acc: ±${locationProvider.accuracy.toStringAsFixed(1)}m',
                  style: const TextStyle(fontSize: 10),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.warning,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'App started with limited functionality',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              onPressed: () => setState(() => _initializationError = null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppDrawer() {
    return Drawer(
      child: Consumer<RoadSystemProvider>(
        builder: (context, roadSystemProvider, child) {
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UCRoadWays',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Indoor & Outdoor Navigation',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (roadSystemProvider.currentSystem != null)
                      Text(
                        'Active: ${roadSystemProvider.currentSystem!.name}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                  ],
                ),
              ),
              
              ListTile(
                leading: const Icon(Icons.map),
                title: const Text('Road Systems'),
                onTap: () => _navigateToRoadSystems(),
              ),
              
              ListTile(
                leading: const Icon(Icons.business),
                title: const Text('Buildings'),
                onTap: () => _navigateToBuildings(),
              ),
              
              ListTile(
                leading: const Icon(Icons.navigation),
                title: const Text('Navigation'),
                onTap: () => _navigateToNavigation(),
              ),
              
              ListTile(
                leading: const Icon(Icons.offline_pin),
                title: const Text('Offline Maps'),
                onTap: () => _navigateToOfflineMap(),
              ),
              
              ListTile(
                leading: const Icon(Icons.analytics),
                title: const Text('Network Analysis'),
                onTap: () => _navigateToAnalysis(),
              ),
              
              const Divider(),
              
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () => _navigateToSettings(),
              ),
              
              ListTile(
                leading: const Icon(Icons.help),
                title: const Text('Help & Tutorial'),
                onTap: () => _navigateToHelp(),
              ),
              
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('About'),
                onTap: () => _navigateToAbout(),
              ),
            ],
          );
        },
      ),
    );
  }

  void _navigateToRoadSystems() {
    Navigator.pop(context);
    // Navigate to road systems screen
  }

  void _navigateToBuildings() {
    Navigator.pop(context);
    // Navigate to buildings screen
  }

  void _navigateToNavigation() {
    Navigator.pop(context);
    // Navigate to navigation screen
  }

  void _navigateToOfflineMap() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OfflineMapScreen()),
    );
  }

  void _navigateToAnalysis() {
    Navigator.pop(context);
    // Navigate to analysis screen
  }

  void _navigateToSettings() {
    Navigator.pop(context);
    // Navigate to settings screen
  }

  void _navigateToHelp() {
    Navigator.pop(context);
    // Navigate to help screen
  }

  void _navigateToAbout() {
    Navigator.pop(context);
    // Navigate to about screen
  }
}