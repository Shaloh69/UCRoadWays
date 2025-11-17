import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
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
  
  // Loading overlay
  OverlayEntry? _loadingOverlay;
  
  // Initialization lock to prevent race conditions
  bool _initializationLock = false;

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
    _hideLoadingOverlay();
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

  void _showLoadingOverlay() {
    _hideLoadingOverlay(); // Ensure no duplicate overlays
    
    _loadingOverlay = OverlayEntry(
      builder: (context) => Container(
        color: Colors.black54,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_initializationStatus),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 200,
                    child: LinearProgressIndicator(value: _initializationProgress),
                  ),
                ],
              ),
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

  Future<void> _initializeApp() async {
    // Prevent concurrent initializations
    if (_initializationLock || _isInitialized) return;
    
    _initializationLock = true;
    
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
    } finally {
      _initializationLock = false;
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
    
    // Cleanup before retry
    _hideLoadingOverlay();
    _retryTimer?.cancel();
    
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

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return _buildInitializingState();
    }
    
    if (!_isInitialized && _initializationError != null) {
      return _buildErrorState();
    }
    
    return Consumer4<LocationProvider, RoadSystemProvider, BuildingProvider, OfflineMapProvider>(
      builder: (context, locationProvider, roadSystemProvider, buildingProvider, offlineMapProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('UCRoadWays'),
            centerTitle: true,
            actions: [
              // Network status indicator
              IconButton(
                icon: Icon(
                  offlineMapProvider.preferOffline ? Icons.cloud_off : Icons.cloud_queue,
                  color: offlineMapProvider.preferOffline ? Colors.orange : Colors.blue,
                ),
                onPressed: () => setState(() => _showNetworkStatus = !_showNetworkStatus),
              ),
              
              // Settings
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => _openAppSettings(),
              ),
            ],
          ),
          body: Stack(
            children: [
              // Main map widget
              UCRoadWaysMap(
                key: _mapWidgetKey,
                mapController: _mapController,
              ),
              
              // Floor switcher (if in building mode)
              if (buildingProvider.isIndoorMode &&
                  buildingProvider.getSelectedBuilding(roadSystemProvider.currentSystem) != null)
                FloorSwitcher(mapController: _mapController),
              
              // Floating action buttons
              FloatingControls(
                mapController: _mapController,
                mapWidgetKey: _mapWidgetKey,
              ),
              
              // Bottom panel
              BottomPanel(
                isExpanded: _isPanelExpanded,
                onToggleExpanded: () => setState(() => _isPanelExpanded = !_isPanelExpanded),
              ),
              
              // Network status overlay
              if (_showNetworkStatus)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 70,
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
          ),
          drawer: _buildAppDrawer(),
        );
      },
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
              offlineMapProvider.preferOffline ? Icons.offline_bolt : Icons.wifi,
              color: offlineMapProvider.preferOffline ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    offlineMapProvider.preferOffline ? 'Offline Mode' : 'Online Mode',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    offlineMapProvider.preferOffline
                        ? 'Using cached maps'
                        : 'Downloading maps on demand',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            Switch(
              value: offlineMapProvider.preferOffline,
              onChanged: (value) => offlineMapProvider.setPreferOffline(value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadIndicator(OfflineMapProvider offlineMapProvider) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const CircularProgressIndicator(strokeWidth: 2),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Downloading Map Tiles',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${offlineMapProvider.downloadProgress.toStringAsFixed(0)}% complete',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => offlineMapProvider.cancelDownload(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: offlineMapProvider.downloadProgress / 100),
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
                        'Current: ${roadSystemProvider.currentSystem!.name}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
                        ),
                      ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.map),
                title: const Text('Offline Maps'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const OfflineMapScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('About'),
                onTap: () {
                  Navigator.pop(context);
                  showAboutDialog(
                    context: context,
                    applicationName: 'UCRoadWays',
                    applicationVersion: '1.0.0',
                    applicationLegalese: '© 2024 UCRoadWays. All rights reserved.',
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Clear All Data', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmClearData();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmClearData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text('This will delete all road systems and reset the app. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final provider = Provider.of<RoadSystemProvider>(context, listen: false);
              await provider.clearAllData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All data cleared')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}