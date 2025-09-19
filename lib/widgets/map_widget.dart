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

  // Intersection and connection state
  bool _isAddingIntersection = false;
  bool _isConnectingRoads = false;
  List<String> _selectedRoadIds = [];
  List<LatLng> _intersections = [];

  @override
  void initState() {
    super.initState();
    _setupLocationListener();
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
    return Consumer3<LocationProvider, RoadSystemProvider, BuildingProvider>(
      builder: (context, locationProvider, roadSystemProvider, buildingProvider, child) {
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
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.ucroadways.app',
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
                          color: Colors.red,
                          strokeWidth: 4.0,
                          pattern: const StrokePattern.dashed(),
                        ),
                      ],
                    ),
                ],
              ],
            ),
            
            // Recording indicator
            if (_isRecordingRoad)
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: Card(
                  color: Colors.red,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.fiber_manual_record, color: Colors.white),
                        const SizedBox(width: 8),
                        const Text(
                          'Recording Road...',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          '${_tempRoadPoints.length} points',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            
            // Mode indicators
            if (_isAddingLandmark || _isAddingBuilding)
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: Card(
                  color: _isAddingLandmark ? Colors.green : Colors.purple,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          _isAddingLandmark ? Icons.place : Icons.business,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isAddingLandmark ? 'Tap to add landmark' : 'Tap to add building',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => setState(() {
                            _isAddingLandmark = false;
                            _isAddingBuilding = false;
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            
            // Floor context indicator
            if (buildingProvider.isIndoorMode && selectedBuilding != null && selectedFloor != null)
              Positioned(
                bottom: 100,
                left: 20,
                child: Card(
                  color: Colors.purple[100],
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Indoor Mode',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[800],
                          ),
                        ),
                        Text(
                          selectedBuilding.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[900],
                          ),
                        ),
                        Text(
                          buildingProvider.getFloorDisplayName(selectedFloor),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.purple[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // BUILDING CREATION AND MANAGEMENT

  void startBuildingMode() {
    setState(() {
      _isAddingBuilding = true;
      _isAddingLandmark = false;
      _isRecordingRoad = false;
    });
  }

  void startLandmarkMode() {
    setState(() {
      _isAddingLandmark = true;
      _isAddingBuilding = false;
      _isRecordingRoad = false;
    });
  }

  void startRoadRecording() {
    setState(() {
      _isRecordingRoad = true;
      _isAddingLandmark = false;
      _isAddingBuilding = false;
      _tempRoadPoints.clear();
      _lastRecordedPoint = null;
    });
    
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      if (locationProvider.currentLatLng != null) {
        _addPointWhileWalking(locationProvider.currentLatLng!);
      }
    });
  }

  void stopRoadRecording() {
    setState(() {
      _isRecordingRoad = false;
      _tempRoadPoints.clear();
      _lastRecordedPoint = null;
    });
    _recordingTimer?.cancel();
  }

  void finishRoadRecording() {
    if (_tempRoadPoints.length >= 2) {
      _showRoadDetailsDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need at least 2 points to create a road')),
      );
    }
  }

  void _addPointWhileWalking(LatLng point) {
    if (_lastRecordedPoint == null || 
        _calculateDistance(_lastRecordedPoint!, point) >= _minDistanceForNewPoint) {
      setState(() {
        _tempRoadPoints.add(point);
        _lastRecordedPoint = point;
      });
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // meters
    final double lat1Rad = point1.latitude * pi / 180;
    final double lat2Rad = point2.latitude * pi / 180;
    final double deltaLatRad = (point2.latitude - point1.latitude) * pi / 180;
    final double deltaLngRad = (point2.longitude - point1.longitude) * pi / 180;

    final double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  void _handleMapTap(LatLng point, BuildingProvider buildingProvider, RoadSystemProvider roadSystemProvider) {
    if (_isAddingBuilding) {
      _showAddBuildingDialog(point, roadSystemProvider);
    } else if (_isAddingLandmark) {
      _showAddLandmarkDialog(point, buildingProvider, roadSystemProvider);
    }
  }

  void _handleMapLongPress(LatLng point, BuildingProvider buildingProvider, RoadSystemProvider roadSystemProvider) {
    _showContextMenu(point, buildingProvider, roadSystemProvider);
  }

  void _showContextMenu(LatLng point, BuildingProvider buildingProvider, RoadSystemProvider roadSystemProvider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add at Location',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.business, color: Colors.purple),
              title: const Text('Add Building'),
              subtitle: const Text('Create a new building structure'),
              onTap: () {
                Navigator.pop(context);
                _showAddBuildingDialog(point, roadSystemProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.place, color: Colors.green),
              title: const Text('Add Landmark'),
              subtitle: buildingProvider.isIndoorMode 
                  ? Text('Add to current floor: ${buildingProvider.getSelectedFloor(roadSystemProvider.currentSystem)?.name ?? 'Unknown'}')
                  : const Text('Add outdoor landmark'),
              onTap: () {
                Navigator.pop(context);
                _showAddLandmarkDialog(point, buildingProvider, roadSystemProvider);
              },
            ),
            if (_isRecordingRoad) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.route, color: Colors.red),
                title: const Text('Add Road Point'),
                subtitle: Text('${_tempRoadPoints.length} points recorded'),
                onTap: () {
                  Navigator.pop(context);
                  _addPointWhileWalking(point);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddBuildingDialog(LatLng point, RoadSystemProvider provider) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Building'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Building Name',
                hintText: 'Enter building name',
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'Location',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
                  ),
                  Text('Lat: ${point.latitude.toStringAsFixed(6)}'),
                  Text('Lng: ${point.longitude.toStringAsFixed(6)}'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                _addBuilding(nameController.text, point, provider);
                Navigator.pop(context);
                setState(() {
                  _isAddingBuilding = false;
                });
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddLandmarkDialog(LatLng point, BuildingProvider buildingProvider, RoadSystemProvider roadSystemProvider) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedType = 'entrance';
    
    final landmarkTypes = [
      'entrance', 'bathroom', 'classroom', 'office', 'elevator', 'stairs',
      'restaurant', 'library', 'parking', 'exit', 'information', 'shop'
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(buildingProvider.isIndoorMode ? 'Add Indoor Landmark' : 'Add Outdoor Landmark'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Context info
                if (buildingProvider.isIndoorMode) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Adding to: ${buildingProvider.getSelectedBuilding(roadSystemProvider.currentSystem)?.name ?? 'Unknown Building'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Floor: ${buildingProvider.getSelectedFloor(roadSystemProvider.currentSystem)?.name ?? 'Unknown Floor'}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Landmark Name',
                    hintText: 'Enter landmark name',
                  ),
                ),
                const SizedBox(height: 16),
                
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Landmark Type',
                  ),
                  items: landmarkTypes.map((type) => DropdownMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Icon(_getLandmarkIcon(type), size: 20),
                        const SizedBox(width: 8),
                        Text(type.toUpperCase()),
                      ],
                    ),
                  )).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Add notes or description',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Location',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
                      ),
                      Text('Lat: ${point.latitude.toStringAsFixed(6)}'),
                      Text('Lng: ${point.longitude.toStringAsFixed(6)}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  _addLandmark(
                    nameController.text,
                    selectedType,
                    point,
                    descriptionController.text,
                    buildingProvider,
                    roadSystemProvider,
                  );
                  Navigator.pop(context);
                  setState(() {
                    _isAddingLandmark = false;
                  });
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoadDetailsDialog() {
    final buildingProvider = Provider.of<BuildingProvider>(context, listen: false);
    final nameController = TextEditingController();
    
    String selectedType = buildingProvider.isIndoorMode ? 'corridor' : 'walkway';
    double width = buildingProvider.isIndoorMode ? 2.0 : 3.0;
    bool isOneWay = false;

    final roadTypes = buildingProvider.isIndoorMode 
        ? ['corridor', 'walkway', 'hallway']
        : ['walkway', 'road', 'path'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Save ${buildingProvider.isIndoorMode ? 'Indoor' : 'Outdoor'} Road'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Context info
                if (buildingProvider.isIndoorMode) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Adding to: ${buildingProvider.getSelectedBuilding(Provider.of<RoadSystemProvider>(context, listen: false).currentSystem)?.name ?? 'Unknown Building'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Floor: ${buildingProvider.getSelectedFloor(Provider.of<RoadSystemProvider>(context, listen: false).currentSystem)?.name ?? 'Unknown Floor'}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Road Name',
                    hintText: 'Enter road name',
                  ),
                ),
                const SizedBox(height: 16),
                
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Road Type'),
                  items: roadTypes.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.toUpperCase()),
                  )).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedType = value!;
                    });
                  },
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
                        onChanged: (value) {
                          setState(() {
                            width = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                
                CheckboxListTile(
                  title: const Text('One-way road'),
                  value: isOneWay,
                  onChanged: (value) {
                    setState(() {
                      isOneWay = value!;
                    });
                  },
                ),
                
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Road recorded with ${_tempRoadPoints.length} points',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                stopRoadRecording();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  _saveRoad(nameController.text, selectedType, width, isOneWay);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _addBuilding(String name, LatLng position, RoadSystemProvider provider) {
    final currentSystem = provider.currentSystem;
    
    if (currentSystem != null) {
      final newBuilding = Building(
        id: const Uuid().v4(),
        name: name,
        centerPosition: position,
      );
      
      final updatedBuildings = List<Building>.from(currentSystem.buildings)
        ..add(newBuilding);
      
      final updatedSystem = currentSystem.copyWith(buildings: updatedBuildings);
      provider.updateCurrentSystem(updatedSystem);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Building "$name" added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _addLandmark(
    String name,
    String type,
    LatLng position,
    String description,
    BuildingProvider buildingProvider,
    RoadSystemProvider roadSystemProvider,
  ) {
    final currentSystem = roadSystemProvider.currentSystem;
    if (currentSystem == null) return;

    final newLandmark = Landmark(
      id: const Uuid().v4(),
      name: name,
      type: type,
      position: position,
      description: description,
      floorId: buildingProvider.isIndoorMode ? (buildingProvider.selectedFloorId ?? '') : '',
      buildingId: buildingProvider.isIndoorMode ? (buildingProvider.selectedBuildingId ?? '') : '',
    );

    if (buildingProvider.isIndoorMode) {
      // Add to specific floor
      final selectedBuilding = buildingProvider.getSelectedBuilding(currentSystem);
      final selectedFloor = buildingProvider.getSelectedFloor(currentSystem);
      
      if (selectedBuilding != null && selectedFloor != null) {
        final updatedLandmarks = List<Landmark>.from(selectedFloor.landmarks)..add(newLandmark);
        final updatedFloor = selectedFloor.copyWith(landmarks: updatedLandmarks);
        
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
            content: Text('Indoor landmark "$name" added to ${selectedFloor.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // Add to outdoor landmarks
      final updatedLandmarks = List<Landmark>.from(currentSystem.outdoorLandmarks)..add(newLandmark);
      final updatedSystem = currentSystem.copyWith(outdoorLandmarks: updatedLandmarks);
      
      roadSystemProvider.updateCurrentSystem(updatedSystem);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Outdoor landmark "$name" added'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _saveRoad(String name, String type, double width, bool isOneWay) {
    final buildingProvider = Provider.of<BuildingProvider>(context, listen: false);
    final roadSystemProvider = Provider.of<RoadSystemProvider>(context, listen: false);
    final currentSystem = roadSystemProvider.currentSystem;
    
    if (currentSystem == null || _tempRoadPoints.length < 2) return;

    final newRoad = Road(
      id: const Uuid().v4(),
      name: name,
      points: List.from(_tempRoadPoints),
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
        final updatedFloor = selectedFloor.copyWith(roads: updatedRoads);
        
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

    stopRoadRecording();
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
      markers.addAll(system.outdoorLandmarks.map((landmark) => Marker(
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
      )));
    }
    
    // Indoor landmarks (only for selected floor)
    if (buildingProvider.isIndoorMode && selectedFloor != null) {
      markers.addAll(selectedFloor.landmarks.map((landmark) => Marker(
        point: landmark.position,
        width: 25,
        height: 25,
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
              size: 12,
            ),
          ),
        ),
      )));
    }
    
    return markers;
  }

  List<Marker> _buildBuildingMarkers(RoadSystem system, BuildingProvider buildingProvider) {
    return system.buildings.map((building) {
      final isSelected = building.id == buildingProvider.selectedBuildingId;
      
      return Marker(
        point: building.centerPosition,
        width: 80,
        height: 50,
        child: GestureDetector(
          onTap: () => _handleBuildingTap(building, buildingProvider),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? Colors.purple : Colors.grey,
                width: isSelected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.business, 
                      size: 14, 
                      color: isSelected ? Colors.purple : Colors.grey[700]
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${building.floors.length}F',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.purple : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                Text(
                  building.name,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.purple : Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  void _handleBuildingTap(Building building, BuildingProvider buildingProvider) {
    buildingProvider.selectBuilding(building.id);
    
    if (building.floors.isNotEmpty) {
      // Auto-select the default floor or first floor
      final defaultFloor = building.defaultFloor ?? building.floors.first;
      buildingProvider.selectFloor(defaultFloor.id);
      buildingProvider.setIndoorMode(true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Entered ${building.name} - ${defaultFloor.name}'),
          backgroundColor: Colors.purple,
        ),
      );
    }
  }

  void _showLandmarkInfo(Landmark landmark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getLandmarkIcon(landmark.type),
              color: _getLandmarkColor(landmark.type),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(landmark.name)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${landmark.type.toUpperCase()}'),
            if (landmark.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Description: ${landmark.description}'),
            ],
            if (landmark.isVerticalCirculation && landmark.connectedFloors.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Connected Floors: ${landmark.connectedFloors.length}'),
            ],
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

  Color _getLandmarkColor(String type) {
    switch (type) {
      case 'bathroom':
        return Colors.blue;
      case 'classroom':
        return Colors.green;
      case 'office':
        return Colors.purple;
      case 'entrance':
        return Colors.red;
      case 'elevator':
        return Colors.orange;
      case 'stairs':
        return Colors.teal;
      case 'restaurant':
        return Colors.pink;
      case 'library':
        return Colors.indigo;
      case 'parking':
        return Colors.grey;
      case 'exit':
        return Colors.red[800]!;
      case 'information':
        return Colors.cyan;
      case 'shop':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  IconData _getLandmarkIcon(String type) {
    switch (type) {
      case 'bathroom':
        return Icons.wc;
      case 'classroom':
        return Icons.school;
      case 'office':
        return Icons.work;
      case 'entrance':
        return Icons.door_front_door;
      case 'elevator':
        return Icons.elevator;
      case 'stairs':
        return Icons.stairs;
      case 'restaurant':
        return Icons.restaurant;
      case 'library':
        return Icons.local_library;
      case 'parking':
        return Icons.local_parking;
      case 'exit':
        return Icons.exit_to_app;
      case 'information':
        return Icons.info;
      case 'shop':
        return Icons.shopping_cart;
      default:
        return Icons.place;
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }
}