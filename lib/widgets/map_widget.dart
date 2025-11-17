import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' as math;
import 'dart:async';
import '../providers/location_provider.dart';
import '../providers/road_system_provider.dart';
import '../providers/building_provider.dart';
import '../providers/offline_map_provider.dart';
import '../services/offline_tile_provider.dart';
import '../models/models.dart';

class UCRoadWaysMap extends StatefulWidget {
  final MapController mapController;

  const UCRoadWaysMap({
    super.key,
    required this.mapController,
  });

  @override
  State<UCRoadWaysMap> createState() => UCRoadWaysMapState();
}

class UCRoadWaysMapState extends State<UCRoadWaysMap> with WidgetsBindingObserver {
  static const double _defaultLat = 33.9737; // UC Riverside latitude
  static const double _defaultLng = -117.3281; // UC Riverside longitude
  static const double _defaultZoom = 18.0; // Closer zoom for walking

  // Road creation state
  bool _isRecordingRoad = false;
  List<LatLng> _tempRoadPoints = [];
  bool _isAddingLandmark = false;
  bool _isAddingBuilding = false;
  Timer? _recordingTimer;
  LatLng? _lastRecordedPoint;
  static const double _minDistanceForNewPoint = 2.0; // meters
  
  // Auto-center state
  bool _hasInitialCentered = false;
  StreamSubscription<LatLng>? _locationSubscription;
  bool _followUserLocation = true;
  DateTime? _lastManualMove;

  // Offline map support
  late OfflineTileProvider _tileProvider;
  bool _offlineMapInitialized = false;

  // Map state
  double _currentZoom = _defaultZoom;
  LatLng _currentCenter = const LatLng(_defaultLat, _defaultLng);
  bool _isMapReady = false;

  // Error handling
  String? _mapError;
  int _tileLoadErrors = 0;
  static const int _maxTileErrors = 10;

  // Performance optimization
  Timer? _debounceTimer;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupLocationListener();
    _initializeOfflineTileProvider();
    _setupMapEventListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    _recordingTimer?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused) {
      // App is going to background, stop intensive operations
      _recordingTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      // App is back in foreground, resume operations
      if (_isRecordingRoad) {
        _startRecordingTimer();
      }
    }
  }

  void _initializeOfflineTileProvider() {
    try {
      final offlineProvider = Provider.of<OfflineMapProvider>(context, listen: false);
      
      _tileProvider = OfflineTileProvider(
        onlineUrlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        preferOffline: offlineProvider.preferOffline,
      );
      
      _offlineMapInitialized = true;
      debugPrint('Offline tile provider initialized');
    } catch (e) {
      debugPrint('Failed to initialize offline tile provider: $e');
      _mapError = 'Failed to initialize offline maps';
      if (mounted) setState(() {});
    }
  }

  void _setupLocationListener() {
    try {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      _locationSubscription = locationProvider.locationStream.listen(
        (position) {
          if (!mounted) return;
          
          // Auto-center on first location
          if (!_hasInitialCentered && _followUserLocation) {
            _centerOnLocation(position, animate: true);
            _hasInitialCentered = true;
          } else if (_followUserLocation && _shouldFollowLocation()) {
            _centerOnLocation(position, animate: false);
          }
        },
        onError: (error) {
          debugPrint('Location stream error in map widget: $error');
        },
      );
    } catch (e) {
      debugPrint('Failed to setup location listener: $e');
    }
  }

  void _setupMapEventListeners() {
    // FIXED: Listen for map move events with correct API
    widget.mapController.mapEventStream.listen((event) {
      if (!mounted) return;
      
      // FIXED: Handle different event types properly
      if (event is MapEventMove) {
        _currentCenter = event.camera.center;
        _currentZoom = event.camera.zoom;
        
        // FIXED: Check for manual movement with correct source constants
        if (event.source == MapEventSource.onDrag ||
            event.source == MapEventSource.doubleTap ||
            event.source == MapEventSource.onMultiFinger) {
          _lastManualMove = DateTime.now();
          _followUserLocation = false;
        }
      }
      
      if (event is MapEventMoveEnd) {
        _currentCenter = event.camera.center;
        _currentZoom = event.camera.zoom;
        _isAnimating = false;
        setState(() {});
      }
      
      if (event is MapEventMoveStart) {
        _isAnimating = true;
      }
    });
  }

  bool _shouldFollowLocation() {
    if (_lastManualMove == null) return true;
    
    // Resume following after 30 seconds of no manual movement
    final timeSinceManualMove = DateTime.now().difference(_lastManualMove!);
    return timeSinceManualMove.inSeconds > 30;
  }

  void _centerOnLocation(LatLng position, {bool animate = false}) {
    if (!mounted || _isAnimating) return;
    
    try {
      if (animate) {
        _isAnimating = true;
        widget.mapController.move(position, _currentZoom);
      } else {
        widget.mapController.move(position, _currentZoom);
      }
    } catch (e) {
      debugPrint('Error centering on location: $e');
    }
  }

  // Public method to enable location following
  void enableLocationFollowing() {
    _followUserLocation = true;
    _lastManualMove = null;
    
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    if (locationProvider.currentLatLng != null) {
      _centerOnLocation(locationProvider.currentLatLng!, animate: true);
    }
  }

  // Public method to center on current location
  void centerOnCurrentLocation() {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    if (locationProvider.currentLatLng != null) {
      enableLocationFollowing();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer4<LocationProvider, RoadSystemProvider, BuildingProvider, OfflineMapProvider>(
      builder: (context, locationProvider, roadSystemProvider, buildingProvider, offlineMapProvider, child) {
        if (_mapError != null) {
          return _buildErrorWidget();
        }

        final currentSystem = roadSystemProvider.currentSystem;
        final currentLocation = locationProvider.currentLatLng;
        final selectedBuilding = buildingProvider.getSelectedBuilding(currentSystem);
        final selectedFloor = buildingProvider.getSelectedFloor(currentSystem);
        
        return Stack(
          children: [
            _buildMap(
              context,
              currentSystem,
              currentLocation,
              selectedBuilding,
              selectedFloor,
              buildingProvider,
              offlineMapProvider,
              locationProvider, // FIXED: Added missing parameter
            ),
            
            // Map controls overlay
            _buildMapControls(locationProvider),
            
            // Recording indicator
            if (_isRecordingRoad) _buildRecordingIndicator(),
            
            // Map status indicators
            _buildStatusIndicators(locationProvider, offlineMapProvider),
          ],
        );
      },
    );
  }

  Widget _buildMap(
    BuildContext context,
    RoadSystem? currentSystem,
    LatLng? currentLocation,
    Building? selectedBuilding,
    Floor? selectedFloor,
    BuildingProvider buildingProvider,
    OfflineMapProvider offlineMapProvider,
    LocationProvider locationProvider, // FIXED: Added missing parameter
  ) {
    return FlutterMap(
      mapController: widget.mapController,
      options: MapOptions(
        initialCenter: _getMapCenter(currentLocation, currentSystem),
        initialZoom: _getMapZoom(currentSystem, buildingProvider),
        minZoom: 10.0,
        maxZoom: 22.0,
        onTap: (tapPosition, point) => _handleMapTap(
          point,
          currentSystem,
          roadSystemProvider: Provider.of<RoadSystemProvider>(context, listen: false),
          buildingProvider: buildingProvider,
        ),
        onLongPress: (tapPosition, point) => _handleMapLongPress(point),
        onMapReady: () {
          _isMapReady = true;
          debugPrint('Map is ready');
        },
        onPositionChanged: (position, hasGesture) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 100), () {
            if (mounted) {
              _currentCenter = position.center!;
              _currentZoom = position.zoom!;
            }
          });
        },
      ),
      children: [
        // Tile layer with error handling
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          tileProvider: _offlineMapInitialized ? _tileProvider : NetworkTileProvider(),
          userAgentPackageName: 'com.example.ucroads',
          maxZoom: 19,
          errorTileCallback: (tile, error, stackTrace) {
            _tileLoadErrors++;
            if (_tileLoadErrors > _maxTileErrors) {
              debugPrint('Too many tile load errors, falling back to online mode');
              if (mounted) {
                setState(() {
                  _mapError = 'Map loading issues detected';
                });
              }
            }
          },
        ),
        
        // FIXED: Building polygons wrapped in PolygonLayer
        if (currentSystem != null) 
          PolygonLayer(
            polygons: _buildBuildingPolygons(currentSystem, selectedBuilding, buildingProvider),
          ),
        
        // FIXED: Road polylines wrapped in PolylineLayer
        if (currentSystem != null) 
          PolylineLayer(
            polylines: _buildRoadPolylines(currentSystem, selectedFloor, buildingProvider),
          ),
        
        // Temporary road being recorded
        if (_tempRoadPoints.isNotEmpty) 
          PolylineLayer(
            polylines: _buildTempRoadPolylines(),
          ),
        
        // Landmark markers
        if (currentSystem != null) 
          MarkerLayer(
            markers: _buildLandmarkMarkers(currentSystem, selectedFloor, buildingProvider),
          ),
        
        // Current location marker
        if (currentLocation != null) 
          _buildCurrentLocationMarker(currentLocation, locationProvider),
        
        // Location history trail
        if (locationProvider.locationHistory.isNotEmpty) 
          _buildLocationTrail(locationProvider),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Map Error',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(_mapError ?? 'Unknown map error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _mapError = null;
                  _tileLoadErrors = 0;
                });
                _initializeOfflineTileProvider();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapControls(LocationProvider locationProvider) {
    return Positioned(
      right: 16,
      bottom: 100,
      child: Column(
        children: [
          // Location button
          FloatingActionButton(
            mini: true,
            heroTag: "location_btn",
            onPressed: locationProvider.hasLocation ? centerOnCurrentLocation : null,
            backgroundColor: _followUserLocation ? Colors.blue : Colors.white,
            child: Icon(
              _followUserLocation ? Icons.my_location : Icons.location_searching,
              color: _followUserLocation ? Colors.white : Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          
          // Zoom in button
          FloatingActionButton(
            mini: true,
            heroTag: "zoom_in_btn",
            onPressed: () {
              final newZoom = (_currentZoom + 1).clamp(10.0, 22.0);
              widget.mapController.move(_currentCenter, newZoom);
            },
            child: const Icon(Icons.zoom_in),
          ),
          const SizedBox(height: 8),
          
          // Zoom out button
          FloatingActionButton(
            mini: true,
            heroTag: "zoom_out_btn",
            onPressed: () {
              final newZoom = (_currentZoom - 1).clamp(10.0, 22.0);
              widget.mapController.move(_currentCenter, newZoom);
            },
            child: const Icon(Icons.zoom_out),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    return Positioned(
      top: 16,
      left: 16,
      child: Card(
        color: Colors.red,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fiber_manual_record, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Recording Road',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Text(
                '${_tempRoadPoints.length} points',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicators(LocationProvider locationProvider, OfflineMapProvider offlineMapProvider) {
    return Positioned(
      top: 16,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // GPS status
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    locationProvider.isTracking ? Icons.gps_fixed : Icons.gps_off,
                    size: 16,
                    color: locationProvider.isTracking ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    locationProvider.isTracking ? 'GPS' : 'NO GPS',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          
          // Offline map status
          if (offlineMapProvider.preferOffline) ...[
            const SizedBox(height: 4),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.offline_pin,
                      size: 16,
                      color: _offlineMapInitialized ? Colors.blue : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'OFFLINE',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          // Download status
          if (offlineMapProvider.isDownloading) ...[
            const SizedBox(height: 4),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Downloading...', style: TextStyle(fontSize: 10)),
                    SizedBox(
                      width: 100,
                      child: LinearProgressIndicator(
                        value: offlineMapProvider.downloadProgress,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  LatLng _getMapCenter(LatLng? currentLocation, RoadSystem? currentSystem) {
    if (currentLocation != null) {
      return currentLocation;
    }
    
    if (currentSystem != null && currentSystem.buildings.isNotEmpty) {
      return currentSystem.buildings.first.centerPosition;
    }
    
    return const LatLng(_defaultLat, _defaultLng);
  }

  double _getMapZoom(RoadSystem? currentSystem, BuildingProvider buildingProvider) {
    if (buildingProvider.isIndoorMode) {
      return 20.0; // Closer zoom for indoor navigation
    }
    
    return currentSystem?.buildings.isNotEmpty == true ? 17.0 : _defaultZoom;
  }

  // FIXED: Return List<Polygon> instead of List<Widget>
  List<Polygon> _buildBuildingPolygons(RoadSystem system, Building? selectedBuilding, BuildingProvider buildingProvider) {
    return system.buildings.map((building) {
      final isSelected = building.id == selectedBuilding?.id;
      final opacity = buildingProvider.isIndoorMode 
          ? (isSelected ? 0.4 : 0.1)
          : (isSelected ? 0.3 : 0.2);
      
      return Polygon(
        points: building.boundaryPoints.isNotEmpty 
            ? building.boundaryPoints
            : _generateDefaultBuildingBoundary(building.centerPosition),
        color: isSelected ? Colors.purple.withOpacity(opacity) : Colors.grey.withOpacity(opacity),
        borderColor: isSelected ? Colors.purple : Colors.grey,
        borderStrokeWidth: isSelected ? 3 : 1,
      );
    }).toList();
  }

  List<LatLng> _generateDefaultBuildingBoundary(LatLng center) {
    const double size = 0.0001; // Small building size
    return [
      LatLng(center.latitude - size, center.longitude - size),
      LatLng(center.latitude - size, center.longitude + size),
      LatLng(center.latitude + size, center.longitude + size),
      LatLng(center.latitude + size, center.longitude - size),
    ];
  }

  List<Polyline> _buildRoadPolylines(RoadSystem system, Floor? selectedFloor, BuildingProvider buildingProvider) {
    final polylines = <Polyline>[];
    
    // Outdoor roads (always visible unless in indoor mode)
    if (!buildingProvider.isIndoorMode) {
      polylines.addAll(system.outdoorRoads.map((road) => Polyline(
        points: road.points,
        color: _getRoadColor(road.type),
        strokeWidth: road.width.clamp(2.0, 8.0),
      )));
    }
    
    // Indoor roads (only for selected floor)
    if (buildingProvider.isIndoorMode && selectedFloor != null) {
      polylines.addAll(selectedFloor.roads.map((road) => Polyline(
        points: road.points,
        color: _getRoadColor(road.type),
        strokeWidth: road.width.clamp(1.0, 6.0),
      )));
    }
    
    return polylines;
  }

  List<Polyline> _buildTempRoadPolylines() {
    if (_tempRoadPoints.length < 2) return [];
    
    return [
      Polyline(
        points: _tempRoadPoints,
        color: Colors.red.withOpacity(0.8),
        strokeWidth: 4.0,
        isDotted: true,
      ),
    ];
  }

  Color _getRoadColor(String type) {
    switch (type) {
      case 'corridor':
        return Colors.purple;
      case 'hallway':
        return Colors.indigo;
      case 'walkway':
        return Colors.blue;
      case 'road':
        return Colors.grey[700]!;
      case 'path':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  List<Marker> _buildLandmarkMarkers(RoadSystem system, Floor? selectedFloor, BuildingProvider buildingProvider) {
    final markers = <Marker>[];
    
    // Outdoor landmarks (always visible unless in indoor mode)
    if (!buildingProvider.isIndoorMode) {
      for (final building in system.buildings) {
        final groundFloor = building.floors.where((f) => f.level == 0).firstOrNull;
        if (groundFloor != null) {
          markers.addAll(groundFloor.landmarks.map((landmark) => _createLandmarkMarker(landmark, false)));
        }
      }
    }
    
    // Indoor landmarks (only for selected floor)
    if (buildingProvider.isIndoorMode && selectedFloor != null) {
      markers.addAll(selectedFloor.landmarks.map((landmark) => _createLandmarkMarker(landmark, true)));
    }
    
    return markers;
  }

  Marker _createLandmarkMarker(Landmark landmark, bool isIndoor) {
    return Marker(
      point: landmark.position,
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () => _showLandmarkDetails(landmark),
        child: Container(
          decoration: BoxDecoration(
            color: _getLandmarkColor(landmark.type),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            _getLandmarkIcon(landmark.type),
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Color _getLandmarkColor(String type) {
    switch (type) {
      case 'entrance':
        return Colors.green;
      case 'elevator':
        return Colors.blue;
      case 'stairs':
        return Colors.orange;
      case 'restroom':
        return Colors.cyan;
      case 'information':
        return Colors.purple;
      case 'emergency_exit':
        return Colors.red;
      case 'parking':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  IconData _getLandmarkIcon(String type) {
    switch (type) {
      case 'entrance':
        return Icons.door_front_door;
      case 'elevator':
        return Icons.elevator;
      case 'stairs':
        return Icons.stairs;
      case 'restroom':
        return Icons.wc;
      case 'information':
        return Icons.info;
      case 'emergency_exit':
        return Icons.exit_to_app; // FIXED: Use valid icon
      case 'parking':
        return Icons.local_parking;
      default:
        return Icons.place;
    }
  }

  Widget _buildCurrentLocationMarker(LatLng currentLocation, LocationProvider locationProvider) {
    return MarkerLayer(
      markers: [
        Marker(
          point: currentLocation,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.my_location,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        
        // Accuracy circle
        if (locationProvider.accuracy > 0 && locationProvider.accuracy < 100)
          Marker(
            point: currentLocation,
            width: locationProvider.accuracy * 2,
            height: locationProvider.accuracy * 2,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(0.1),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLocationTrail(LocationProvider locationProvider) {
    if (locationProvider.locationHistory.length < 2) {
      return const SizedBox.shrink();
    }

    return PolylineLayer(
      polylines: [
        Polyline(
          points: locationProvider.locationHistory,
          color: Colors.blue.withOpacity(0.6),
          strokeWidth: 3.0,
          isDotted: true,
        ),
      ],
    );
  }

  void _handleMapTap(LatLng point, RoadSystem? currentSystem, {
    required RoadSystemProvider roadSystemProvider,
    required BuildingProvider buildingProvider,
  }) {
    if (_isAddingLandmark) {
      _addLandmarkAtPoint(point, currentSystem, roadSystemProvider, buildingProvider);
    } else if (_isAddingBuilding) {
      _addBuildingAtPoint(point, roadSystemProvider);
    }
  }

  void _handleMapLongPress(LatLng point) {
    if (_isRecordingRoad) {
      _stopRecordingRoad();
    } else {
      _showLocationOptions(point);
    }
  }

  void _showLocationOptions(LatLng point) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Location: ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.add_location),
              title: const Text('Add Landmark'),
              onTap: () {
                Navigator.pop(context);
                _addLandmarkAtPoint(
                  point,
                  Provider.of<RoadSystemProvider>(context, listen: false).currentSystem,
                  Provider.of<RoadSystemProvider>(context, listen: false),
                  Provider.of<BuildingProvider>(context, listen: false),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Add Building'),
              onTap: () {
                Navigator.pop(context);
                _addBuildingAtPoint(point, Provider.of<RoadSystemProvider>(context, listen: false));
              },
            ),
            ListTile(
              leading: const Icon(Icons.route),
              title: const Text('Start Recording Road'),
              onTap: () {
                Navigator.pop(context);
                _startRecordingRoad(point);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLandmarkDetails(Landmark landmark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(landmark.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${landmark.type}'),
            if (landmark.description.isNotEmpty)
              Text('Description: ${landmark.description}'),
            Text('Position: ${landmark.position.latitude.toStringAsFixed(6)}, ${landmark.position.longitude.toStringAsFixed(6)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Road recording methods
  void _startRecordingRoad(LatLng startPoint) {
    setState(() {
      _isRecordingRoad = true;
      _tempRoadPoints = [startPoint];
      _lastRecordedPoint = startPoint;
    });
    
    _startRecordingTimer();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recording road... Long press to stop'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _recordLocationForRoad();
    });
  }

  void _recordLocationForRoad() {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final currentLocation = locationProvider.currentLatLng;
    
    if (currentLocation != null && _lastRecordedPoint != null) {
      final distance = _calculateDistance(_lastRecordedPoint!, currentLocation);
      
      if (distance >= _minDistanceForNewPoint) {
        setState(() {
          _tempRoadPoints.add(currentLocation);
          _lastRecordedPoint = currentLocation;
        });
      }
    }
  }

  void _stopRecordingRoad() {
    if (!_isRecordingRoad || _tempRoadPoints.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need at least 2 points to create a road')),
      );
      _cancelRecordingRoad();
      return;
    }

    _recordingTimer?.cancel();
    
    // Show dialog to save the road
    _showSaveRoadDialog();
  }

  void _cancelRecordingRoad() {
    setState(() {
      _isRecordingRoad = false;
      _tempRoadPoints.clear();
      _lastRecordedPoint = null;
    });
    _recordingTimer?.cancel();
  }

  void _showSaveRoadDialog() {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Road'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Road Name',
                hintText: 'Enter road name',
              ),
            ),
            const SizedBox(height: 16),
            Text('Points: ${_tempRoadPoints.length}'),
            Text('Length: ${_calculateRoadLength(_tempRoadPoints).toStringAsFixed(1)}m'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelRecordingRoad();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveRecordedRoad(nameController.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _saveRecordedRoad(String name) {
    final roadSystemProvider = Provider.of<RoadSystemProvider>(context, listen: false);
    final buildingProvider = Provider.of<BuildingProvider>(context, listen: false);
    
    if (name.isEmpty) name = 'Road ${DateTime.now().millisecondsSinceEpoch}';
    
    final road = Road(
      id: const Uuid().v4(),
      name: name,
      points: List.from(_tempRoadPoints),
      type: buildingProvider.isIndoorMode ? 'corridor' : 'path',
      width: 3.0,
      isOneWay: false,
      floorId: buildingProvider.selectedFloorId ?? '', // FIXED: Handle nullable string
      connectedIntersections: [],
      properties: {
        'created': DateTime.now().toIso8601String(),
        'recordedLength': _calculateRoadLength(_tempRoadPoints),
      },
    );
    
    // FIXED: Add road to current system directly
    if (roadSystemProvider.currentSystem != null) {
      if (buildingProvider.isIndoorMode && buildingProvider.selectedFloorId != null) {
        // Add to indoor floor - modify the current system's building floor
        roadSystemProvider.currentSystem!.buildings
          .where((b) => b.floors.any((f) => f.id == buildingProvider.selectedFloorId))
          .first.floors
          .where((f) => f.id == buildingProvider.selectedFloorId)
          .first.roads.add(road);
      } else {
        // Add to outdoor roads
        roadSystemProvider.currentSystem!.outdoorRoads.add(road);
      }
      roadSystemProvider.refresh(); // Notify listeners
    }
    
    _cancelRecordingRoad();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Road "$name" saved successfully')),
    );
  }

  double _calculateRoadLength(List<LatLng> points) {
    if (points.length < 2) return 0.0;
    
    double length = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      length += _calculateDistance(points[i], points[i + 1]);
    }
    return length;
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // meters
    final double lat1Rad = point1.latitude * math.pi / 180;
    final double lat2Rad = point2.latitude * math.pi / 180;
    final double deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180;
    final double deltaLngRad = (point2.longitude - point1.longitude) * math.pi / 180;

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  void _addLandmarkAtPoint(LatLng point, RoadSystem? currentSystem, 
      RoadSystemProvider roadSystemProvider, BuildingProvider buildingProvider) {
    
    if (currentSystem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create or select a road system first')),
      );
      return;
    }

    _showAddLandmarkDialog(point, roadSystemProvider, buildingProvider);
  }

  void _showAddLandmarkDialog(LatLng point, RoadSystemProvider roadSystemProvider, 
      BuildingProvider buildingProvider) {
    
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedType = 'information';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Landmark'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: [
                  'information', 'entrance', 'elevator', 'stairs', 'restroom',
                  'emergency_exit', 'parking', 'office', 'classroom', 'laboratory'
                ].map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type.replaceAll('_', ' ').toUpperCase()),
                )).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedType = value!;
                  });
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
                maxLines: 2,
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
                _saveLandmark(point, nameController.text.trim(), selectedType,
                    descriptionController.text.trim(), roadSystemProvider, buildingProvider);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveLandmark(LatLng point, String name, String type, String description,
      RoadSystemProvider roadSystemProvider, BuildingProvider buildingProvider) {
    
    if (name.isEmpty) name = type.replaceAll('_', ' ').toUpperCase();
    
    final landmark = Landmark(
      id: const Uuid().v4(),
      name: name,
      type: type,
      position: point,
      floorId: buildingProvider.selectedFloorId ?? '', // FIXED: Handle nullable string
      description: description,
      connectedFloors: [],
      buildingId: buildingProvider.selectedBuildingId ?? '', // FIXED: Handle nullable string
      properties: {
        'created': DateTime.now().toIso8601String(),
      },
    );
    
    // FIXED: Add landmark to current system directly
    if (roadSystemProvider.currentSystem != null) {
      if (buildingProvider.isIndoorMode && buildingProvider.selectedFloorId != null) {
        // Add to indoor floor
        roadSystemProvider.currentSystem!.buildings
          .where((b) => b.floors.any((f) => f.id == buildingProvider.selectedFloorId))
          .first.floors
          .where((f) => f.id == buildingProvider.selectedFloorId)
          .first.landmarks.add(landmark);
      } else {
        // Add to outdoor landmarks
        roadSystemProvider.currentSystem!.outdoorLandmarks.add(landmark);
      }
      roadSystemProvider.refresh(); // Notify listeners
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Landmark "$name" added successfully')),
    );
  }

  void _addBuildingAtPoint(LatLng point, RoadSystemProvider roadSystemProvider) {
    _showAddBuildingDialog(point, roadSystemProvider);
  }

  void _showAddBuildingDialog(LatLng point, RoadSystemProvider roadSystemProvider) {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Building'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Building Name',
            hintText: 'Enter building name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveBuilding(point, nameController.text.trim(), roadSystemProvider);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _saveBuilding(LatLng point, String name, RoadSystemProvider roadSystemProvider) {
    if (name.isEmpty) name = 'Building ${DateTime.now().millisecondsSinceEpoch}';
    
    final buildingId = const Uuid().v4();
    final floorId = const Uuid().v4();
    
    // Create ground floor
    final groundFloor = Floor(
      id: floorId,
      name: 'Ground Floor',
      level: 0,
      buildingId: buildingId,
      roads: [],
      landmarks: [],
      connectedFloors: [],
      centerPosition: point,
      properties: {},
    );
    
    // Create building
    final building = Building(
      id: buildingId,
      name: name,
      floors: [groundFloor],
      centerPosition: point,
      boundaryPoints: _generateDefaultBuildingBoundary(point),
      entranceFloorIds: [floorId],
      defaultFloorLevel: 0,
      properties: {
        'created': DateTime.now().toIso8601String(),
      },
    );
    
    // FIXED: Add building to current system directly
    if (roadSystemProvider.currentSystem != null) {
      roadSystemProvider.currentSystem!.buildings.add(building);
      roadSystemProvider.refresh(); // Notify listeners
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Building "$name" added successfully')),
    );
  }

  // FIXED: Public methods for external control (matching what FloatingControls expects)
  void startRecordingRoad() {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    if (locationProvider.currentLatLng != null) {
      _startRecordingRoad(locationProvider.currentLatLng!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPS location not available')),
      );
    }
  }

  void stopRecordingRoad() {
    if (_isRecordingRoad) {
      _stopRecordingRoad();
    }
  }

  // FIXED: Added the missing methods that FloatingControls calls
  void startAddingLandmark() {
    setState(() {
      _isAddingLandmark = true;
      _isAddingBuilding = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tap on the map to add a landmark'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void startAddingBuilding() {
    setState(() {
      _isAddingBuilding = true;
      _isAddingLandmark = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tap on the map to add a building'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Keep the existing toggle methods for backward compatibility
  void toggleAddingLandmark() {
    setState(() {
      _isAddingLandmark = !_isAddingLandmark;
      _isAddingBuilding = false;
    });
  }

  void toggleAddingBuilding() {
    setState(() {
      _isAddingBuilding = !_isAddingBuilding;
      _isAddingLandmark = false;
    });
  }

  // Methods to stop adding modes
  void stopAddingLandmark() {
    setState(() {
      _isAddingLandmark = false;
    });
  }

  void stopAddingBuilding() {
    setState(() {
      _isAddingBuilding = false;
    });
  }

  // Public getters for state
  bool get isRecordingRoad => _isRecordingRoad;
  bool get isAddingLandmark => _isAddingLandmark;
  bool get isAddingBuilding => _isAddingBuilding;
}