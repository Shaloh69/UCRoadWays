import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
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

class UCRoadWaysMapState extends State<UCRoadWaysMap> {
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

  // Offline map support
  late OfflineTileProvider _tileProvider;

  @override
  void initState() {
    super.initState();
    _setupLocationListener();
    _initializeOfflineTileProvider();
  }

  void _initializeOfflineTileProvider() {
    _tileProvider = OfflineTileProvider(
      onlineUrlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      preferOffline: true,
    );
  }

  void _setupLocationListener() {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    _locationSubscription = locationProvider.locationStream.listen((position) {
      if (!_hasInitialCentered && mounted) {
        widget.mapController.move(position, _defaultZoom);
        _hasInitialCentered = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer4<LocationProvider, RoadSystemProvider, BuildingProvider, OfflineMapProvider>(
      builder: (context, locationProvider, roadSystemProvider, buildingProvider, offlineMapProvider, child) {
        final currentSystem = roadSystemProvider.currentSystem;
        final currentLocation = locationProvider.currentLatLng;
        final selectedBuilding = buildingProvider.getSelectedBuilding(currentSystem);
        final selectedFloor = buildingProvider.getSelectedFloor(currentSystem);
        
        return Stack(
          children: [
            FlutterMap(
              mapController: widget.mapController,
              options: MapOptions(
                initialCenter: _getMapCenter(currentLocation, currentSystem),
                initialZoom: _getMapZoom(currentSystem, buildingProvider),
                minZoom: 10.0,
                maxZoom: 22.0,
                onTap: (tapPosition, point) => _handleMapTap(point, buildingProvider, roadSystemProvider),
                onLongPress: (tapPosition, point) => _handleMapLongPress(point, buildingProvider, roadSystemProvider),
              ),
              children: [
                // Offline-first tile layer
                TileLayer(
                  tileProvider: _tileProvider,
                  userAgentPackageName: 'com.ucroadways.app',
                  tileSize: 256,
                  maxZoom: 22,
                ),
                
                // Building polygons (only show if not in indoor mode or if selected building)
                if (currentSystem != null) ...[
                  PolygonLayer(
                    polygons: _buildBuildingPolygons(currentSystem, selectedBuilding, buildingProvider),
                  ),
                  
                  // Roads layer
                  PolylineLayer(
                    polylines: _buildRoadPolylines(currentSystem, selectedFloor, buildingProvider),
                  ),
                  
                  // Landmarks layer
                  MarkerLayer(
                    markers: [
                      ..._buildLandmarkMarkers(currentSystem, selectedFloor, buildingProvider),
                      ..._buildBuildingMarkers(currentSystem, buildingProvider),
                    ],
                  ),
                  
                  // Current location marker
                  if (currentLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: currentLocation,
                          width: 20,
                          height: 20,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  
                  // Temporary road being recorded
                  if (_isRecordingRoad && _tempRoadPoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _tempRoadPoints,
                          color: Colors.red.withOpacity(0.7),
                          strokeWidth: 4.0,
                          isDotted: true,
                        ),
                      ],
                    ),
                ],
              ],
            ),
            
            // Download progress indicator
            if (offlineMapProvider.isDownloading)
              Positioned(
                top: 50,
                left: 16,
                right: 16,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
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
                            TextButton(
                              onPressed: offlineMapProvider.cancelDownload,
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: offlineMapProvider.downloadProgress,
                          backgroundColor: Colors.grey[300],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${offlineMapProvider.currentTileCount}/${offlineMapProvider.totalTileCount} tiles (${(offlineMapProvider.downloadProgress * 100).toStringAsFixed(1)}%)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            
            // Recording/Adding indicators
            if (_isRecordingRoad || _isAddingLandmark || _isAddingBuilding)
              Positioned(
                bottom: 100,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: _isRecordingRoad ? Colors.red : _isAddingLandmark ? Colors.green : Colors.purple,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isRecordingRoad ? Icons.radio_button_checked : 
                        _isAddingLandmark ? Icons.place : Icons.business,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isRecordingRoad 
                            ? 'Recording road... (${_tempRoadPoints.length} points)'
                            : _isAddingLandmark 
                                ? 'Tap to add landmark'
                                : 'Tap to add building',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (_isRecordingRoad)
                        TextButton(
                          onPressed: stopRoadRecording,
                          child: const Text('Stop', style: TextStyle(color: Colors.white)),
                        ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isRecordingRoad = false;
                            _isAddingLandmark = false;
                            _isAddingBuilding = false;
                            _tempRoadPoints.clear();
                          });
                        },
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  // MAP INTERACTION HANDLERS

  void _handleMapTap(LatLng point, BuildingProvider buildingProvider, RoadSystemProvider roadSystemProvider) {
    if (_isAddingBuilding) {
      _showBuildingDialog(point, roadSystemProvider);
    } else if (_isAddingLandmark) {
      _showLandmarkDialog(point, buildingProvider, roadSystemProvider);
    }
  }

  void _handleMapLongPress(LatLng point, BuildingProvider buildingProvider, RoadSystemProvider roadSystemProvider) {
    if (_isRecordingRoad) {
      _addPointWhileWalking(point);
    }
  }

  // ROAD RECORDING METHODS

  void startRoadRecording() {
    setState(() {
      _isRecordingRoad = true;
      _tempRoadPoints.clear();
      _lastRecordedPoint = null;
    });

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      final currentLocation = locationProvider.currentLatLng;
      
      if (currentLocation != null) {
        _addPointWhileWalking(currentLocation);
      }
    });
  }

  void stopRoadRecording() {
    if (_tempRoadPoints.length >= 2) {
      _showRoadSaveDialog();
    } else {
      setState(() {
        _isRecordingRoad = false;
        _tempRoadPoints.clear();
      });
      _recordingTimer?.cancel();
    }
  }

  void _addPointWhileWalking(LatLng point) {
    if (_lastRecordedPoint != null) {
      final distance = _calculateDistance(_lastRecordedPoint!, point);
      if (distance < _minDistanceForNewPoint) {
        return; // Too close to last point
      }
    }
    
    setState(() {
      _tempRoadPoints.add(point);
      _lastRecordedPoint = point;
    });
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // meters
    
    final lat1Rad = point1.latitude * (pi / 180);
    final lat2Rad = point2.latitude * (pi / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);
    
    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
              cos(lat1Rad) * cos(lat2Rad) *
              sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  void _saveRoad(String name, String type, double width, bool isOneWay) {
    if (_tempRoadPoints.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Road must have at least 2 points'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final roadSystemProvider = Provider.of<RoadSystemProvider>(context, listen: false);
    final buildingProvider = Provider.of<BuildingProvider>(context, listen: false);
    final currentSystem = roadSystemProvider.currentSystem;
    
    if (currentSystem == null) return;

    final newRoad = Road(
      id: const Uuid().v4(),
      name: name,
      points: List<LatLng>.from(_tempRoadPoints),
      type: type,
      width: width,
      isOneWay: isOneWay,
      floorId: buildingProvider.isIndoorMode ? (buildingProvider.selectedFloorId ?? '') : '',
    );

    if (buildingProvider.isIndoorMode) {
      // Add to specific floor
      final selectedBuilding = buildingProvider.getSelectedBuilding(currentSystem);
      final selectedFloor = buildingProvider.getSelectedFloor(currentSystem);
      
      if (selectedBuilding != null && selectedFloor != null) {
        final updatedRoads = List<Road>.from(selectedFloor.roads)..add(newRoad);
        final updatedFloor = selectedFloor.copyWith(roads: updatedRoads, buildingId: '');
        
        final updatedFloors = selectedBuilding.floors
            .map((f) => f.id == selectedFloor.id ? updatedFloor : f)
            .toList();
        final updatedBuilding = selectedBuilding.copyWith(floors: updatedFloors);
        
        final updatedBuildings = currentSystem.buildings
            .map((b) => b.id == selectedBuilding.id ? updatedBuilding : b)
            .toList();
        final updatedSystem = currentSystem.copyWith(buildings: updatedBuildings);
        
        roadSystemProvider.updateCurrentSystem(updatedSystem);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Indoor road "$name" added to ${selectedFloor.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // Add to outdoor roads
      final updatedRoads = List<Road>.from(currentSystem.outdoorRoads)..add(newRoad);
      final updatedSystem = currentSystem.copyWith(outdoorRoads: updatedRoads);
      
      roadSystemProvider.updateCurrentSystem(updatedSystem);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Outdoor road "$name" added'),
          backgroundColor: Colors.green,
        ),
      );
    }

    setState(() {
      _isRecordingRoad = false;
      _tempRoadPoints.clear();
    });
    _recordingTimer?.cancel();
  }

  // MAP RENDERING METHODS

  LatLng _getMapCenter(LatLng? currentLocation, RoadSystem? currentSystem) {
    if (currentLocation != null) {
      return currentLocation;
    }
    if (currentSystem != null) {
      return currentSystem.centerPosition;
    }
    return const LatLng(_defaultLat, _defaultLng);
  }

  double _getMapZoom(RoadSystem? currentSystem, BuildingProvider buildingProvider) {
    if (buildingProvider.isIndoorMode) {
      return 21.0; // Higher zoom for indoor details
    }
    return currentSystem?.zoom ?? _defaultZoom;
  }

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
        for (final floor in building.floors) {
          if (floor.level == 0) { // Ground floor landmarks visible outdoors
            markers.addAll(floor.landmarks.map((landmark) => _createLandmarkMarker(landmark)));
          }
        }
      }
    }
    
    // Indoor landmarks (only for selected floor)
    if (buildingProvider.isIndoorMode && selectedFloor != null) {
      markers.addAll(selectedFloor.landmarks.map((landmark) => _createLandmarkMarker(landmark)));
    }
    
    return markers;
  }

  List<Marker> _buildBuildingMarkers(RoadSystem system, BuildingProvider buildingProvider) {
    if (buildingProvider.isIndoorMode) return [];
    
    return system.buildings.map((building) => Marker(
      point: building.centerPosition,
      width: 60,
      height: 40,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Center(
          child: Text(
            building.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    )).toList();
  }

  Marker _createLandmarkMarker(Landmark landmark) {
    return Marker(
      point: landmark.position,
      width: 30,
      height: 30,
      child: GestureDetector(
        onTap: () => _showLandmarkInfo(landmark),
        child: Container(
          decoration: BoxDecoration(
            color: _getLandmarkColor(landmark.type),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(
            _getLandmarkIcon(landmark.type),
            color: Colors.white,
            size: 16,
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
      case 'office':
        return Colors.purple;
      case 'classroom':
        return Colors.indigo;
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
      case 'office':
        return Icons.business_center;
      case 'classroom':
        return Icons.school;
      default:
        return Icons.place;
    }
  }

  // ADDING CONTROLS

  void startAddingLandmark() {
    setState(() {
      _isAddingLandmark = true;
      _isAddingBuilding = false;
    });
  }

  void startAddingBuilding() {
    setState(() {
      _isAddingBuilding = true;
      _isAddingLandmark = false;
    });
  }

  // DIALOG METHODS

  void _showRoadSaveDialog() {
    String name = '';
    String type = 'corridor';
    double width = 3.0;
    bool isOneWay = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Save Road'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Road Name'),
                onChanged: (value) => name = value,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Road Type'),
                value: type,
                items: const [
                  DropdownMenuItem(value: 'corridor', child: Text('Corridor')),
                  DropdownMenuItem(value: 'hallway', child: Text('Hallway')),
                  DropdownMenuItem(value: 'walkway', child: Text('Walkway')),
                  DropdownMenuItem(value: 'road', child: Text('Road')),
                  DropdownMenuItem(value: 'path', child: Text('Path')),
                ],
                onChanged: (value) => setState(() => type = value!),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Width: '),
                  Expanded(
                    child: Slider(
                      value: width,
                      min: 1.0,
                      max: 10.0,
                      divisions: 18,
                      label: '${width.toStringAsFixed(1)}m',
                      onChanged: (value) => setState(() => width = value),
                    ),
                  ),
                ],
              ),
              CheckboxListTile(
                title: const Text('One Way'),
                value: isOneWay,
                onChanged: (value) => setState(() => isOneWay = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                this.setState(() {
                  _isRecordingRoad = false;
                  _tempRoadPoints.clear();
                });
                _recordingTimer?.cancel();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: name.isNotEmpty ? () {
                Navigator.of(context).pop();
                _saveRoad(name, type, width, isOneWay);
              } : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLandmarkDialog(LatLng point, BuildingProvider buildingProvider, RoadSystemProvider roadSystemProvider) {
    String name = '';
    String type = 'office';
    String description = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Landmark'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Landmark Name'),
              onChanged: (value) => name = value,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Landmark Type'),
              value: type,
              items: const [
                DropdownMenuItem(value: 'entrance', child: Text('Entrance')),
                DropdownMenuItem(value: 'elevator', child: Text('Elevator')),
                DropdownMenuItem(value: 'stairs', child: Text('Stairs')),
                DropdownMenuItem(value: 'restroom', child: Text('Restroom')),
                DropdownMenuItem(value: 'office', child: Text('Office')),
                DropdownMenuItem(value: 'classroom', child: Text('Classroom')),
              ],
              onChanged: (value) => type = value!,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              onChanged: (value) => description = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _isAddingLandmark = false);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: name.isNotEmpty ? () {
              Navigator.of(context).pop();
              _saveLandmark(point, name, type, description, buildingProvider, roadSystemProvider);
            } : null,
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showBuildingDialog(LatLng point, RoadSystemProvider roadSystemProvider) {
    String name = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Building'),
        content: TextField(
          decoration: const InputDecoration(labelText: 'Building Name'),
          onChanged: (value) => name = value,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _isAddingBuilding = false);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: name.isNotEmpty ? () {
              Navigator.of(context).pop();
              _saveBuilding(point, name, roadSystemProvider);
            } : null,
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showLandmarkInfo(Landmark landmark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(landmark.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${landmark.type}'),
            if (landmark.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Description: ${landmark.description}'),
            ],
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

  // SAVE METHODS

  void _saveLandmark(LatLng point, String name, String type, String description, 
                     BuildingProvider buildingProvider, RoadSystemProvider roadSystemProvider) {
    final currentSystem = roadSystemProvider.currentSystem;
    if (currentSystem == null) return;

    final newLandmark = Landmark(
      id: const Uuid().v4(),
      name: name,
      type: type,
      position: point,
      floorId: buildingProvider.isIndoorMode ? (buildingProvider.selectedFloorId ?? '') : '',
      description: description,
      buildingId: buildingProvider.isIndoorMode ? (buildingProvider.selectedBuildingId ?? '') : '',
    );

    if (buildingProvider.isIndoorMode) {
      // Add to specific floor
      final selectedBuilding = buildingProvider.getSelectedBuilding(currentSystem);
      final selectedFloor = buildingProvider.getSelectedFloor(currentSystem);
      
      if (selectedBuilding != null && selectedFloor != null) {
        final updatedLandmarks = List<Landmark>.from(selectedFloor.landmarks)..add(newLandmark);
        final updatedFloor = selectedFloor.copyWith(landmarks: updatedLandmarks, buildingId: '');
        
        final updatedFloors = selectedBuilding.floors
            .map((f) => f.id == selectedFloor.id ? updatedFloor : f)
            .toList();
        final updatedBuilding = selectedBuilding.copyWith(floors: updatedFloors);
        
        final updatedBuildings = currentSystem.buildings
            .map((b) => b.id == selectedBuilding.id ? updatedBuilding : b)
            .toList();
        final updatedSystem = currentSystem.copyWith(buildings: updatedBuildings);
        
        roadSystemProvider.updateCurrentSystem(updatedSystem);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Landmark "$name" added to ${selectedFloor.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // Add to ground floor of nearest building or create new building
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a building and floor to add landmarks'),
          backgroundColor: Colors.orange,
        ),
      );
    }

    setState(() => _isAddingLandmark = false);
  }

  void _saveBuilding(LatLng point, String name, RoadSystemProvider roadSystemProvider) {
    final currentSystem = roadSystemProvider.currentSystem;
    if (currentSystem == null) return;

    final newBuilding = Building(
      id: const Uuid().v4(),
      name: name,
      centerPosition: point,
      floors: [
        Floor(
          id: const Uuid().v4(),
          name: 'Ground Floor',
          level: 0,
          buildingId: '', // Will be set after building creation
        ),
      ],
    );

    // Update floor building IDs
    final updatedFloors = newBuilding.floors.map((floor) => 
        floor.copyWith(buildingId: newBuilding.id)).toList();
    final finalBuilding = newBuilding.copyWith(floors: updatedFloors);

    final updatedBuildings = List<Building>.from(currentSystem.buildings)..add(finalBuilding);
    final updatedSystem = currentSystem.copyWith(buildings: updatedBuildings);
    
    roadSystemProvider.updateCurrentSystem(updatedSystem);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Building "$name" added'),
        backgroundColor: Colors.green,
      ),
    );

    setState(() => _isAddingBuilding = false);
  }
}