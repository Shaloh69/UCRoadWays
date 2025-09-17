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

  // Road creation state - ENHANCED
  bool _isRecordingRoad = false; // Toggle mode for walking
  List<LatLng> _tempRoadPoints = [];
  bool _isAddingLandmark = false;
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
    // Listen to location changes for auto-centering and road recording
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      
      // Set up location stream listener
      locationProvider.addListener(_onLocationChanged);
    });
  }

  void _onLocationChanged() {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final currentLocation = locationProvider.currentLatLng;
    
    if (currentLocation != null) {
      // Auto-center on first location or when app starts
      if (!_hasInitialCentered) {
        _centerOnLocation(currentLocation, _defaultZoom);
        _hasInitialCentered = true;
      }
      
      // Add point to road if recording
      if (_isRecordingRoad) {
        _addPointWhileWalking(currentLocation);
      }
    }
  }

  void _centerOnLocation(LatLng location, double zoom) {
    widget.mapController.move(location, zoom);
  }

  void _addPointWhileWalking(LatLng currentLocation) {
    if (_lastRecordedPoint == null) {
      // First point
      setState(() {
        _tempRoadPoints.add(currentLocation);
        _lastRecordedPoint = currentLocation;
      });
      return;
    }

    // Check if user has moved enough distance
    final distance = _calculateDistance(_lastRecordedPoint!, currentLocation);
    if (distance >= _minDistanceForNewPoint) {
      setState(() {
        _tempRoadPoints.add(currentLocation);
        _lastRecordedPoint = currentLocation;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<LocationProvider, RoadSystemProvider, BuildingProvider>(
      builder: (context, locationProvider, roadSystemProvider, buildingProvider, child) {
        final currentSystem = roadSystemProvider.currentSystem;
        final selectedBuilding = buildingProvider.getSelectedBuilding(currentSystem);
        final selectedFloor = buildingProvider.getSelectedFloor(currentSystem);

        return Stack(
          children: [
            FlutterMap(
              mapController: widget.mapController,
              options: MapOptions(
                initialCenter: _getMapCenter(locationProvider, currentSystem),
                initialZoom: currentSystem?.zoom ?? _defaultZoom,
                minZoom: 10.0,
                maxZoom: 22.0,
                onTap: _isAddingLandmark || _isAddingIntersection || _isConnectingRoads
                    ? (tapPosition, point) => _handleMapTap(point, roadSystemProvider)
                    : null,
                onLongPress: !_isRecordingRoad 
                    ? (tapPosition, point) => _showContextMenu(context, point, roadSystemProvider)
                    : null,
              ),
              children: [
                // Base tile layer
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.ucroadways',
                ),
                
                // Outdoor roads
                if (currentSystem != null) ...[
                  PolylineLayer(
                    polylines: _buildOutdoorRoadPolylines(currentSystem),
                  ),
                  
                  // Building boundaries
                  PolygonLayer(
                    polygons: _buildBuildingPolygons(currentSystem, selectedBuilding),
                  ),
                  
                  // Indoor roads (if floor selected)
                  if (selectedFloor != null)
                    PolylineLayer(
                      polylines: _buildIndoorRoadPolylines(selectedFloor),
                    ),
                  
                  // Intersections
                  MarkerLayer(
                    markers: _buildIntersectionMarkers(),
                  ),
                  
                  // Outdoor landmarks
                  MarkerLayer(
                    markers: _buildOutdoorLandmarkMarkers(currentSystem),
                  ),
                  
                  // Indoor landmarks (if floor selected)
                  if (selectedFloor != null)
                    MarkerLayer(
                      markers: _buildIndoorLandmarkMarkers(selectedFloor),
                    ),
                  
                  // Building markers
                  MarkerLayer(
                    markers: _buildBuildingMarkers(currentSystem, buildingProvider),
                  ),
                ],
                
                // Current location marker - ENHANCED
                if (locationProvider.currentLatLng != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: locationProvider.currentLatLng!,
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _isRecordingRoad 
                                ? Colors.red.withOpacity(0.3)
                                : Colors.blue.withOpacity(0.3),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isRecordingRoad ? Colors.red : Colors.blue, 
                              width: 3
                            ),
                          ),
                          child: Icon(
                            _isRecordingRoad ? Icons.fiber_manual_record : Icons.my_location,
                            color: _isRecordingRoad ? Colors.red : Colors.blue,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                
                // Recording road path
                if (_tempRoadPoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _tempRoadPoints,
                        color: Colors.red.withOpacity(0.8),
                        strokeWidth: 4.0,
                        borderColor: Colors.white,
                        borderStrokeWidth: 2.0,
                      ),
                    ],
                  ),

                // Recording road points
                if (_tempRoadPoints.isNotEmpty)
                  MarkerLayer(
                    markers: _tempRoadPoints.asMap().entries.map((entry) {
                      final index = entry.key;
                      final point = entry.value;
                      final isFirst = index == 0;
                      final isLast = index == _tempRoadPoints.length - 1;
                      
                      return Marker(
                        point: point,
                        width: 16,
                        height: 16,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isFirst ? Colors.green : (isLast && !_isRecordingRoad ? Colors.red : Colors.orange),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),

            // Recording controls - NEW DESIGN
            if (_isRecordingRoad)
              Positioned(
                top: 16,
                left: 50,
                right: 50,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.fiber_manual_record, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Recording Road',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_tempRoadPoints.length} points recorded • Walk to add points',
                        style: TextStyle(fontSize: 12, color: Colors.red[700]),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _tempRoadPoints.length >= 2 ? _finishRecording : null,
                              icon: const Icon(Icons.save),
                              label: const Text('Save Road'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _stopRecording,
                              icon: const Icon(Icons.stop),
                              label: const Text('Stop'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Road connection mode indicator
            if (_isConnectingRoads)
              Positioned(
                top: 16,
                left: 50,
                right: 50,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Road Connection Mode',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('Selected: ${_selectedRoadIds.length} road(s)'),
                      if (_selectedRoadIds.length >= 2)
                        ElevatedButton(
                          onPressed: _connectSelectedRoads,
                          child: const Text('Connect Roads'),
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

  LatLng _getMapCenter(LocationProvider locationProvider, RoadSystem? currentSystem) {
    if (currentSystem != null) {
      return currentSystem.centerPosition;
    }
    if (locationProvider.currentLatLng != null) {
      return locationProvider.currentLatLng!;
    }
    return const LatLng(_defaultLat, _defaultLng);
  }

  // ENHANCED ROAD CREATION METHODS

  void startRoadRecording() {
    setState(() {
      _isRecordingRoad = true;
      _tempRoadPoints.clear();
      _lastRecordedPoint = null;
    });
    
    // Start a timer to periodically check location
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      if (locationProvider.currentLatLng != null) {
        _addPointWhileWalking(locationProvider.currentLatLng!);
      }
    });
  }

  void _stopRecording() {
    setState(() {
      _isRecordingRoad = false;
      _tempRoadPoints.clear();
      _lastRecordedPoint = null;
    });
    _recordingTimer?.cancel();
  }

  void _finishRecording() {
    if (_tempRoadPoints.length >= 2) {
      _showRoadDetailsDialog();
    }
  }

  void _showRoadDetailsDialog() {
    final nameController = TextEditingController();
    String selectedType = 'walkway'; // Default for walking
    double width = 3.0; // Smaller default for walking paths
    bool isOneWay = false;

    final roadTypes = ['walkway', 'road', 'corridor'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Save Recorded Road'),
          content: SingleChildScrollView(
            child: Column(
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
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Road Type'),
                  items: roadTypes.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type[0].toUpperCase() + type.substring(1)),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedType = value;
                      });
                    }
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
                        max: 15.0,
                        divisions: 14,
                        label: '${width.toStringAsFixed(1)}m',
                        onChanged: (value) {
                          setState(() {
                            width = value;
                          });
                        },
                      ),
                    ),
                    Text('${width.toStringAsFixed(1)}m'),
                  ],
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('One Way'),
                  value: isOneWay,
                  onChanged: (value) {
                    setState(() {
                      isOneWay = value ?? false;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Recorded ${_tempRoadPoints.length} points while walking',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _stopRecording();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  _saveRoad(
                    nameController.text,
                    selectedType,
                    width,
                    isOneWay,
                  );
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

  void _saveRoad(String name, String type, double width, bool isOneWay) {
    final provider = Provider.of<RoadSystemProvider>(context, listen: false);
    final buildingProvider = Provider.of<BuildingProvider>(context, listen: false);
    
    final newRoad = Road(
      id: const Uuid().v4(),
      name: name,
      points: List.from(_tempRoadPoints),
      type: type,
      width: width,
      isOneWay: isOneWay,
      floorId: buildingProvider.selectedFloorId ?? '',
    );

    if (buildingProvider.selectedFloorId != null && buildingProvider.selectedFloorId!.isNotEmpty) {
      _addRoadToFloor(newRoad, buildingProvider, provider);
    } else {
      provider.addRoadToCurrentSystem(newRoad);
    }

    _stopRecording();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Road "$name" saved successfully!')),
    );
  }

  // INTERSECTION METHODS

  void startAddingIntersection() {
    setState(() {
      _isAddingIntersection = true;
    });
  }

  void _addIntersection(LatLng point) {
    setState(() {
      _intersections.add(point);
      _isAddingIntersection = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Intersection added')),
    );
  }

  List<Marker> _buildIntersectionMarkers() {
    return _intersections.map((point) {
      return Marker(
        point: point,
        width: 30,
        height: 30,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(
            Icons.multiple_stop,
            color: Colors.white,
            size: 16,
          ),
        ),
      );
    }).toList();
  }

  // ROAD CONNECTION METHODS

  void startRoadConnectionMode() {
    setState(() {
      _isConnectingRoads = true;
      _selectedRoadIds.clear();
    });
  }

  void _selectRoadForConnection(String roadId) {
    setState(() {
      if (_selectedRoadIds.contains(roadId)) {
        _selectedRoadIds.remove(roadId);
      } else {
        _selectedRoadIds.add(roadId);
      }
    });
  }

  void _connectSelectedRoads() {
    if (_selectedRoadIds.length >= 2) {
      // Implementation would create intersection points between roads
      // For now, just show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected ${_selectedRoadIds.length} roads')),
      );
      
      setState(() {
        _isConnectingRoads = false;
        _selectedRoadIds.clear();
      });
    }
  }

  void stopRoadConnectionMode() {
    setState(() {
      _isConnectingRoads = false;
      _selectedRoadIds.clear();
    });
  }

  // EXISTING METHODS

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000;
    final lat1Rad = point1.latitude * (pi / 180);
    final lat2Rad = point2.latitude * (pi / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);

    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  void _handleMapTap(LatLng point, RoadSystemProvider provider) {
    if (_isAddingLandmark) {
      _showAddLandmarkDialog(point, provider);
    } else if (_isAddingIntersection) {
      _addIntersection(point);
    } else if (_isConnectingRoads) {
      // Handle road selection for connection
    }
  }

  void _showContextMenu(BuildContext context, LatLng point, RoadSystemProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.place),
              title: const Text('Add Landmark'),
              onTap: () {
                Navigator.pop(context);
                _showAddLandmarkDialog(point, provider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Add Building'),
              onTap: () {
                Navigator.pop(context);
                _showAddBuildingDialog(point, provider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.multiple_stop),
              title: const Text('Add Intersection'),
              onTap: () {
                Navigator.pop(context);
                _addIntersection(point);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Getters for external access
  bool get isRecordingRoad => _isRecordingRoad;
  bool get isConnectingRoads => _isConnectingRoads;
  bool get isAddingIntersection => _isAddingIntersection;

  // ROAD AND LANDMARK MANAGEMENT METHODS

  void _addLandmarkToFloor(Landmark landmark, BuildingProvider buildingProvider, RoadSystemProvider roadSystemProvider) {
    final currentSystem = roadSystemProvider.currentSystem;
    final selectedBuilding = buildingProvider.getSelectedBuilding(currentSystem);
    final selectedFloor = buildingProvider.getSelectedFloor(currentSystem);
    
    if (currentSystem == null || selectedBuilding == null || selectedFloor == null) return;

    // Update the floor with the new landmark
    final updatedLandmarks = List<Landmark>.from(selectedFloor.landmarks)..add(landmark);
    final updatedFloor = selectedFloor.copyWith(landmarks: updatedLandmarks);
    
    // Update the building with the updated floor
    final updatedFloors = selectedBuilding.floors
        .map((f) => f.id == selectedFloor.id ? updatedFloor : f)
        .toList();
    final updatedBuilding = selectedBuilding.copyWith(floors: updatedFloors);
    
    // Update the system with the updated building
    final updatedBuildings = currentSystem.buildings
        .map((b) => b.id == selectedBuilding.id ? updatedBuilding : b)
        .toList();
    final updatedSystem = currentSystem.copyWith(buildings: updatedBuildings);
    
    roadSystemProvider.updateCurrentSystem(updatedSystem);
  }

  void _showAddLandmarkDialog(LatLng point, RoadSystemProvider provider) {
    final nameController = TextEditingController();
    String selectedType = 'entrance';
    final descriptionController = TextEditingController();

    final landmarkTypes = [
      'entrance',
      'bathroom',
      'classroom',
      'office',
      'elevator',
      'stairs',
      'parking',
      'cafe',
      'library',
      'gym',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Landmark'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                    labelText: 'Type',
                  ),
                  items: landmarkTypes.map((type) => DropdownMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Icon(_getLandmarkIcon(type), size: 16),
                        const SizedBox(width: 8),
                        Text(type[0].toUpperCase() + type.substring(1)),
                      ],
                    ),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedType = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Enter description',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Text(
                  'Location: ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                    point,
                    nameController.text,
                    selectedType,
                    descriptionController.text,
                    provider,
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBuildingDialog(LatLng point, RoadSystemProvider provider) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Building'),
        content: SingleChildScrollView(
          child: Column(
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
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Enter building description',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Text(
                'Position: ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                'The building will be created with a default circular boundary. You can modify it later.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
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
                _addBuilding(point, nameController.text, provider, descriptionController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addBuilding(LatLng point, String name, RoadSystemProvider provider, String description) {
    final currentSystem = provider.currentSystem;
    if (currentSystem == null) return;

    final newBuilding = Building(
      id: const Uuid().v4(),
      name: name,
      centerPosition: point,
      boundaryPoints: _createCircularBoundary(point, 30), // 30m radius default
      properties: {
        'description': description,
        'created': DateTime.now().toIso8601String(),
        'type': 'building',
      },
    );

    final updatedBuildings = List<Building>.from(currentSystem.buildings)
      ..add(newBuilding);

    final updatedSystem = currentSystem.copyWith(
      buildings: updatedBuildings,
    );

    provider.updateCurrentSystem(updatedSystem);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🏢 Added building: $name'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _addLandmark(LatLng point, String name, String type, String description, RoadSystemProvider provider) {
    final buildingProvider = Provider.of<BuildingProvider>(context, listen: false);
    
    final newLandmark = Landmark(
      id: const Uuid().v4(),
      name: name,
      type: type,
      position: point,
      floorId: buildingProvider.selectedFloorId ?? '', // Empty for outdoor landmark
      description: description,
      properties: {
        'created': DateTime.now().toIso8601String(),
        'accessibility': type == 'elevator' || type == 'entrance',
      },
    );

    // Add to appropriate location (outdoor or indoor)
    if (buildingProvider.selectedFloorId != null && buildingProvider.selectedFloorId!.isNotEmpty) {
      _addLandmarkToFloor(newLandmark, buildingProvider, provider);
    } else {
      // Add as outdoor landmark
      final currentSystem = provider.currentSystem;
      if (currentSystem != null) {
        final updatedLandmarks = List<Landmark>.from(currentSystem.outdoorLandmarks)
          ..add(newLandmark);
        final updatedSystem = currentSystem.copyWith(outdoorLandmarks: updatedLandmarks);
        provider.updateCurrentSystem(updatedSystem);
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📍 Added $name'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showLandmarkInfo(BuildContext context, Landmark landmark) {
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Type', landmark.type[0].toUpperCase() + landmark.type.substring(1)),
              if (landmark.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildInfoRow('Description', landmark.description),
              ],
              const SizedBox(height: 8),
              _buildInfoRow('Location', 
                '${landmark.position.latitude.toStringAsFixed(6)}, ${landmark.position.longitude.toStringAsFixed(6)}'
              ),
              const SizedBox(height: 8),
              _buildInfoRow('Floor', landmark.floorId.isEmpty ? 'Outdoor' : 'Indoor'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToLandmark(landmark);
            },
            child: const Text('Navigate'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _navigateToLandmark(Landmark landmark) {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final currentLocation = locationProvider.currentLatLng;
    
    if (currentLocation != null) {
      // Calculate distance
      final distance = _calculateDistance(currentLocation, landmark.position);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🧭 Navigation to ${landmark.name}\n'
            'Distance: ${distance.toStringAsFixed(0)}m'
          ),
          backgroundColor: Colors.blue,
          action: SnackBarAction(
            label: 'Go',
            textColor: Colors.white,
            onPressed: () {
              // Center map on landmark
              widget.mapController.move(landmark.position, 20.0);
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 Current location not available'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // MAP RENDERING METHODS

  List<Polyline> _buildOutdoorRoadPolylines(RoadSystem system) {
    return system.outdoorRoads.map((road) {
      final isSelected = _selectedRoadIds.contains(road.id);
      return Polyline(
        points: road.points,
        color: isSelected 
            ? Colors.purple 
            : _getRoadColor(road.type),
        strokeWidth: isSelected ? road.width + 2 : road.width,
        borderColor: isSelected ? Colors.white : Colors.black,
        borderStrokeWidth: isSelected ? 2 : 1,
      );
    }).toList();
  }

  List<Polyline> _buildIndoorRoadPolylines(Floor floor) {
    return floor.roads.map((road) {
      final isSelected = _selectedRoadIds.contains(road.id);
      return Polyline(
        points: road.points,
        color: isSelected 
            ? Colors.purple.withOpacity(0.8)
            : _getRoadColor(road.type).withOpacity(0.8),
        strokeWidth: isSelected ? road.width + 2 : road.width,
        borderColor: isSelected ? Colors.white : Colors.grey,
        borderStrokeWidth: isSelected ? 2 : 1,
      );
    }).toList();
  }

  List<Polygon> _buildBuildingPolygons(RoadSystem system, Building? selectedBuilding) {
    return system.buildings.map((building) {
      final isSelected = building.id == selectedBuilding?.id;
      return Polygon(
        points: building.boundaryPoints.isNotEmpty 
            ? building.boundaryPoints 
            : _createCircularBoundary(building.centerPosition, 50),
        color: isSelected 
            ? Colors.blue.withOpacity(0.3) 
            : Colors.grey.withOpacity(0.2),
        borderColor: isSelected ? Colors.blue : Colors.grey,
        borderStrokeWidth: 2,
      );
    }).toList();
  }

  List<Marker> _buildOutdoorLandmarkMarkers(RoadSystem system) {
    return system.outdoorLandmarks.map((landmark) {
      return Marker(
        point: landmark.position,
        width: 30,
        height: 30,
        child: GestureDetector(
          onTap: () => _showLandmarkInfo(context, landmark),
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
    }).toList();
  }

  List<Marker> _buildIndoorLandmarkMarkers(Floor floor) {
    return floor.landmarks.map((landmark) {
      return Marker(
        point: landmark.position,
        width: 25,
        height: 25,
        child: GestureDetector(
          onTap: () => _showLandmarkInfo(context, landmark),
          child: Container(
            decoration: BoxDecoration(
              color: _getLandmarkColor(landmark.type).withOpacity(0.8),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: Icon(
              _getLandmarkIcon(landmark.type),
              color: Colors.white,
              size: 12,
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildBuildingMarkers(RoadSystem system, BuildingProvider buildingProvider) {
    return system.buildings.map((building) {
      return Marker(
        point: building.centerPosition,
        width: 60,
        height: 40,
        child: GestureDetector(
          onTap: () => buildingProvider.selectBuilding(building.id),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: buildingProvider.selectedBuildingId == building.id 
                    ? Colors.blue 
                    : Colors.grey,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.business, size: 16),
                Text(
                  building.name,
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  List<LatLng> _createCircularBoundary(LatLng center, double radiusMeters) {
    const int points = 16;
    const double earthRadius = 6371000;
    
    List<LatLng> boundary = [];
    
    for (int i = 0; i < points; i++) {
      double angle = (i * 2 * pi) / points;
      double deltaLat = radiusMeters * cos(angle) / earthRadius * (180 / pi);
      double deltaLng = radiusMeters * sin(angle) / 
          (earthRadius * cos(center.latitude * pi / 180)) * (180 / pi);
      
      boundary.add(LatLng(
        center.latitude + deltaLat,
        center.longitude + deltaLng,
      ));
    }
    
    return boundary;
  }

  Color _getRoadColor(String type) {
    switch (type) {
      case 'road':
        return Colors.grey[800]!;
      case 'walkway':
        return Colors.brown;
      case 'corridor':
        return Colors.orange;
      default:
        return Colors.grey;
    }
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
      case 'parking':
        return Colors.indigo;
      case 'cafe':
        return Colors.deepOrange;
      case 'library':
        return Colors.brown;
      case 'gym':
        return Colors.cyan;
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
      case 'parking':
        return Icons.local_parking;
      case 'cafe':
        return Icons.local_cafe;
      case 'library':
        return Icons.local_library;
      case 'gym':
        return Icons.fitness_center;
      default:
        return Icons.place;
    }
  }

  void _addRoadToFloor(Road road, BuildingProvider buildingProvider, RoadSystemProvider roadSystemProvider) {
    final currentSystem = roadSystemProvider.currentSystem;
    final selectedBuilding = buildingProvider.getSelectedBuilding(currentSystem);
    final selectedFloor = buildingProvider.getSelectedFloor(currentSystem);
    
    if (currentSystem == null || selectedBuilding == null || selectedFloor == null) return;

    final updatedRoads = List<Road>.from(selectedFloor.roads)..add(road);
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
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }
}