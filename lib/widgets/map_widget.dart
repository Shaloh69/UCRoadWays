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

  // Road creation state - ENHANCED for floor support
  bool _isRecordingRoad = false;
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

  // NEW: Floor-specific state
  String? _currentEditingFloorId;
  bool _showFloorTransitions = true;
  Map<String, bool> _floorVisibility = {}; // Track which floors are visible

  @override
  void initState() {
    super.initState();
    _setupLocationListener();
  }

  void _setupLocationListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      locationProvider.addListener(_onLocationChanged);
    });
  }

  void _onLocationChanged() {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final currentLocation = locationProvider.currentLatLng;
    
    if (currentLocation != null) {
      if (!_hasInitialCentered) {
        _centerOnLocation(currentLocation, _defaultZoom);
        _hasInitialCentered = true;
      }
      
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
      setState(() {
        _tempRoadPoints.add(currentLocation);
        _lastRecordedPoint = currentLocation;
      });
      return;
    }

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

        // Update editing context based on current selection
        _currentEditingFloorId = buildingProvider.isIndoorMode ? selectedFloor?.id : null;

        return Stack(
          children: [
            FlutterMap(
              mapController: widget.mapController,
              options: MapOptions(
                initialCenter: _getMapCenter(locationProvider, currentSystem, selectedBuilding),
                initialZoom: _getMapZoom(currentSystem, buildingProvider),
                minZoom: 10.0,
                maxZoom: 24.0, // Higher max zoom for indoor details
                onTap: _isAddingLandmark || _isAddingIntersection || _isConnectingRoads
                    ? (tapPosition, point) => _handleMapTap(point, roadSystemProvider, buildingProvider)
                    : null,
                onLongPress: !_isRecordingRoad 
                    ? (tapPosition, point) => _showContextMenu(context, point, roadSystemProvider, buildingProvider)
                    : null,
              ),
              children: [
                // Base tile layer
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.ucroadways',
                ),
                
                if (currentSystem != null) ...[
                  // CONDITIONAL RENDERING based on indoor/outdoor mode
                  if (buildingProvider.isOutdoorMode) ...[
                    // Outdoor view - show all outdoor elements
                    PolylineLayer(
                      polylines: _buildOutdoorRoadPolylines(currentSystem),
                    ),
                    MarkerLayer(
                      markers: _buildOutdoorLandmarkMarkers(currentSystem),
                    ),
                    MarkerLayer(
                      markers: _buildIntersectionMarkers(currentSystem.outdoorIntersections),
                    ),
                  ] else ...[
                    // Indoor view - show selected floor content
                    if (selectedFloor != null) ...[
                      PolylineLayer(
                        polylines: _buildIndoorRoadPolylines(selectedFloor),
                      ),
                      MarkerLayer(
                        markers: _buildIndoorLandmarkMarkers(selectedFloor),
                      ),
                      // Show indoor intersections for this floor
                      MarkerLayer(
                        markers: _buildIntersectionMarkers(
                          currentSystem.outdoorIntersections.where((i) => i.floorId == selectedFloor.id).toList()
                        ),
                      ),
                    ],
                  ],
                  
                  // Building boundaries (always show)
                  PolygonLayer(
                    polygons: _buildBuildingPolygons(currentSystem, selectedBuilding, buildingProvider),
                  ),
                  
                  // Building markers (always show for navigation)
                  MarkerLayer(
                    markers: _buildBuildingMarkers(currentSystem, buildingProvider),
                  ),
                  
                  // NEW: Floor transition markers (elevators/stairs)
                  if (buildingProvider.isIndoorMode && selectedFloor != null && _showFloorTransitions)
                    MarkerLayer(
                      markers: _buildFloorTransitionMarkers(selectedFloor, selectedBuilding!),
                    ),
                ],
                
                // Current location marker - ENHANCED with indoor/outdoor indication
                if (locationProvider.currentLatLng != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: locationProvider.currentLatLng!,
                        width: 60,
                        height: 60,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _isRecordingRoad 
                                ? Colors.red.withOpacity(0.3)
                                : buildingProvider.isIndoorMode
                                    ? Colors.purple.withOpacity(0.3)
                                    : Colors.blue.withOpacity(0.3),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isRecordingRoad 
                                  ? Colors.red 
                                  : buildingProvider.isIndoorMode
                                      ? Colors.purple
                                      : Colors.blue, 
                              width: 3
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isRecordingRoad 
                                    ? Icons.fiber_manual_record 
                                    : buildingProvider.isIndoorMode
                                        ? Icons.business
                                        : Icons.my_location,
                                color: _isRecordingRoad 
                                    ? Colors.red 
                                    : buildingProvider.isIndoorMode
                                        ? Colors.purple
                                        : Colors.blue,
                                size: 20,
                              ),
                              if (buildingProvider.isIndoorMode && selectedFloor != null)
                                Text(
                                  'L${selectedFloor.level}',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                
                // Recording road path - ENHANCED for floor context
                if (_tempRoadPoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _tempRoadPoints,
                        color: buildingProvider.isIndoorMode 
                            ? Colors.purple.withOpacity(0.8)
                            : Colors.red.withOpacity(0.8),
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
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),

            // ENHANCED: Context-aware recording controls
            if (_isRecordingRoad)
              Positioned(
                top: 16,
                left: 50,
                right: 50,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: buildingProvider.isIndoorMode ? Colors.purple[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: buildingProvider.isIndoorMode ? Colors.purple : Colors.red, 
                      width: 2
                    ),
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
                          Icon(
                            Icons.fiber_manual_record, 
                            color: buildingProvider.isIndoorMode ? Colors.purple : Colors.red, 
                            size: 20
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Recording ${buildingProvider.isIndoorMode ? 'Indoor' : 'Outdoor'} Road',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: buildingProvider.isIndoorMode ? Colors.purple : Colors.red,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        buildingProvider.getCurrentContextDescription(currentSystem),
                        style: TextStyle(
                          fontSize: 12, 
                          color: buildingProvider.isIndoorMode ? Colors.purple[700] : Colors.red[700]
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_tempRoadPoints.length} points recorded • Walk to add points',
                        style: TextStyle(
                          fontSize: 12, 
                          color: buildingProvider.isIndoorMode ? Colors.purple[700] : Colors.red[700]
                        ),
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
                                foregroundColor: buildingProvider.isIndoorMode ? Colors.purple : Colors.red,
                                side: BorderSide(
                                  color: buildingProvider.isIndoorMode ? Colors.purple : Colors.red
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // NEW: Floor context indicator
            if (buildingProvider.isIndoorMode && selectedFloor != null)
              Positioned(
                top: 80,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.purple, width: 2),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '🏢 ${selectedBuilding?.name ?? 'Building'}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        buildingProvider.getFloorDisplayName(selectedFloor),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Road connection mode indicator (updated for floor context)
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
                      Text(
                        'Road Connection Mode - ${buildingProvider.getCurrentContextDescription(currentSystem)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
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

  // ENHANCED: Context-aware map center
  LatLng _getMapCenter(LocationProvider locationProvider, RoadSystem? currentSystem, Building? selectedBuilding) {
    // If indoor mode and building selected, center on building
    if (selectedBuilding != null) {
      return selectedBuilding.centerPosition;
    }
    
    if (currentSystem != null) {
      return currentSystem.centerPosition;
    }
    
    if (locationProvider.currentLatLng != null) {
      return locationProvider.currentLatLng!;
    }
    
    return const LatLng(_defaultLat, _defaultLng);
  }

  // ENHANCED: Context-aware zoom level
  double _getMapZoom(RoadSystem? currentSystem, BuildingProvider buildingProvider) {
    if (buildingProvider.isIndoorMode) {
      return 21.0; // Higher zoom for indoor details
    }
    return currentSystem?.zoom ?? _defaultZoom;
  }

  // ENHANCED ROAD CREATION METHODS

  void startRoadRecording() {
    setState(() {
      _isRecordingRoad = true;
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
    final buildingProvider = Provider.of<BuildingProvider>(context, listen: false);
    final nameController = TextEditingController();
    
    // Default values based on context
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: buildingProvider.isIndoorMode ? Colors.purple[50] : Colors.blue[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Creating road in: ${buildingProvider.getCurrentContextDescription(null)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
                
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
                        max: buildingProvider.isIndoorMode ? 10.0 : 15.0,
                        divisions: buildingProvider.isIndoorMode ? 9 : 14,
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
      floorId: _currentEditingFloorId ?? '', // Use current editing context
      properties: {
        'created': DateTime.now().toIso8601String(),
        'createdBy': 'walking_recording',
        'indoor': buildingProvider.isIndoorMode,
      },
    );

    if (buildingProvider.isIndoorMode && _currentEditingFloorId != null) {
      _addRoadToFloor(newRoad, buildingProvider, provider);
    } else {
      provider.addRoadToCurrentSystem(newRoad);
    }

    _stopRecording();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🛤️ Road "$name" saved to ${buildingProvider.getCurrentContextDescription(null)}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // NEW: Floor transition markers
  List<Marker> _buildFloorTransitionMarkers(Floor floor, Building building) {
    return floor.verticalCirculation.map((landmark) {
      return Marker(
        point: landmark.position,
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showFloorTransitionDialog(landmark, building),
          child: Container(
            decoration: BoxDecoration(
              color: landmark.type == 'elevator' ? Colors.orange : Colors.teal,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  landmark.type == 'elevator' ? Icons.elevator : Icons.stairs,
                  color: Colors.white,
                  size: 16,
                ),
                Text(
                  '${landmark.connectedFloors.length}F',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  void _showFloorTransitionDialog(Landmark landmark, Building building) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              landmark.type == 'elevator' ? Icons.elevator : Icons.stairs,
              color: landmark.type == 'elevator' ? Colors.orange : Colors.teal,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(landmark.name)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${landmark.type[0].toUpperCase()}${landmark.type.substring(1)}'),
            const SizedBox(height: 8),
            const Text('Connected Floors:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...landmark.connectedFloors.map((floorId) {
              final floor = building.floors.where((f) => f.id == floorId).firstOrNull;
              return Text('• ${floor?.name ?? 'Unknown Floor'}');
            }),
            if (landmark.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Notes: ${landmark.description}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (landmark.connectedFloors.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showFloorSelectionDialog(landmark, building);
              },
              child: const Text('Go to Floor'),
            ),
        ],
      ),
    );
  }

  void _showFloorSelectionDialog(Landmark landmark, Building building) {
    final buildingProvider = Provider.of<BuildingProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Floor - ${landmark.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: landmark.connectedFloors.map((floorId) {
            final floor = building.floors.where((f) => f.id == floorId).firstOrNull;
            if (floor == null) return const SizedBox.shrink();
            
            return ListTile(
              leading: Icon(_getFloorIcon(floor.level)),
              title: Text(buildingProvider.getFloorDisplayName(floor)),
              onTap: () {
                buildingProvider.navigateToFloor(building.id, floor.id);
                Navigator.pop(context);
                
                // Center map on the landmark position on the new floor
                widget.mapController.move(landmark.position, 21.0);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('📍 Switched to ${floor.name}'),
                    backgroundColor: Colors.purple,
                  ),
                );
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  IconData _getFloorIcon(int level) {
    if (level < 0) return Icons.arrow_downward;
    if (level == 0) return Icons.business;
    return Icons.arrow_upward;
  }

  // ENHANCED BUILDING POLYGON RENDERING
  List<Polygon> _buildBuildingPolygons(RoadSystem system, Building? selectedBuilding, BuildingProvider buildingProvider) {
    return system.buildings.map((building) {
      final isSelected = building.id == selectedBuilding?.id;
      final opacity = buildingProvider.isIndoorMode 
          ? (isSelected ? 0.4 : 0.1)
          : (isSelected ? 0.3 : 0.2);
      
      return Polygon(
        points: building.boundaryPoints.isNotEmpty 
            ? building.boundaryPoints 
            : _createCircularBoundary(building.centerPosition, 50),
        color: isSelected 
            ? (buildingProvider.isIndoorMode ? Colors.purple : Colors.blue).withOpacity(opacity)
            : Colors.grey.withOpacity(opacity),
        borderColor: isSelected 
            ? (buildingProvider.isIndoorMode ? Colors.purple : Colors.blue)
            : Colors.grey,
        borderStrokeWidth: isSelected ? 3 : 1,
      );
    }).toList();
  }

  // ENHANCED ROAD POLYLINES for floor context
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
            ? Colors.purple
            : _getRoadColor(road.type).withOpacity(0.9),
        strokeWidth: isSelected ? road.width + 2 : road.width,
        borderColor: isSelected ? Colors.white : Colors.grey,
        borderStrokeWidth: isSelected ? 2 : 1,
      );
    }).toList();
  }

  // ENHANCED LANDMARK MARKERS
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
      final isVerticalCirculation = landmark.isVerticalCirculation;
      
      return Marker(
        point: landmark.position,
        width: isVerticalCirculation ? 35 : 25,
        height: isVerticalCirculation ? 35 : 25,
        child: GestureDetector(
          onTap: () => _showLandmarkInfo(context, landmark),
          child: Container(
            decoration: BoxDecoration(
              color: _getLandmarkColor(landmark.type).withOpacity(0.9),
              shape: BoxShape.circle,
              border: Border.all(
                color: isVerticalCirculation ? Colors.yellow : Colors.white, 
                width: isVerticalCirculation ? 3 : 2
              ),
              boxShadow: isVerticalCirculation ? [
                BoxShadow(
                  color: Colors.yellow.withOpacity(0.5),
                  blurRadius: 8,
                ),
              ] : null,
            ),
            child: Icon(
              _getLandmarkIcon(landmark.type),
              color: Colors.white,
              size: isVerticalCirculation ? 18 : 12,
            ),
          ),
        ),
      );
    }).toList();
  }

  // ENHANCED BUILDING MARKERS with floor indication
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
                    color: isSelected ? Colors.purple : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  void _handleBuildingTap(Building building, BuildingProvider buildingProvider) {
    if (buildingProvider.selectedBuildingId == building.id) {
      // If already selected, show floor selection
      _showFloorQuickSelect(building, buildingProvider);
    } else {
      // Select building and enter indoor mode
      buildingProvider.switchToIndoorMode(building.id);
      widget.mapController.move(building.centerPosition, 21.0);
    }
  }

  void _showFloorQuickSelect(Building building, BuildingProvider buildingProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${building.name} - Select Floor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Outdoor option
            ListTile(
              leading: const Icon(Icons.landscape),
              title: const Text('Outdoor View'),
              selected: buildingProvider.isOutdoorMode,
              onTap: () {
                buildingProvider.switchToOutdoorMode();
                Navigator.pop(context);
              },
            ),
            const Divider(),
            // Floor options
            ...building.sortedFloors.map((floor) {
              final isSelected = floor.id == buildingProvider.selectedFloorId;
              return ListTile(
                leading: Icon(_getFloorIcon(floor.level)),
                title: Text(buildingProvider.getFloorDisplayName(floor)),
                subtitle: Text('${floor.roads.length} roads, ${floor.landmarks.length} landmarks'),
                selected: isSelected,
                onTap: () {
                  buildingProvider.navigateToFloor(building.id, floor.id);
                  Navigator.pop(context);
                },
              );
            }),
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

  // Implement other required methods...
  
  void _handleMapTap(LatLng point, RoadSystemProvider provider, BuildingProvider buildingProvider) {
    if (_isAddingLandmark) {
      _showAddLandmarkDialog(point, provider, buildingProvider);
    } else if (_isAddingIntersection) {
      _addIntersection(point);
    } else if (_isConnectingRoads) {
      // Handle road selection for connection
    }
  }

  void _showContextMenu(BuildContext context, LatLng point, RoadSystemProvider provider, BuildingProvider buildingProvider) {
    final isIndoor = buildingProvider.isIndoorMode;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${isIndoor ? 'Indoor' : 'Outdoor'} Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isIndoor)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Adding to: ${buildingProvider.getCurrentContextDescription(null)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.place),
              title: const Text('Add Landmark'),
              onTap: () {
                Navigator.pop(context);
                _showAddLandmarkDialog(point, provider, buildingProvider);
              },
            ),
            if (!isIndoor) ...[
              ListTile(
                leading: const Icon(Icons.business),
                title: const Text('Add Building'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddBuildingDialog(point, provider);
                },
              ),
            ],
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

  // Add other missing methods like _showAddLandmarkDialog, _calculateDistance, etc.
  // These would be similar to the original implementation but with floor context awareness
  
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

  void startAddingIntersection() {
    setState(() {
      _isAddingIntersection = true;
    });
  }

  void startRoadConnectionMode() {
    setState(() {
      _isConnectingRoads = true;
      _selectedRoadIds.clear();
    });
  }

  void stopRoadConnectionMode() {
    setState(() {
      _isConnectingRoads = false;
      _selectedRoadIds.clear();
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

  void _connectSelectedRoads() {
    if (_selectedRoadIds.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected ${_selectedRoadIds.length} roads')),
      );
      
      setState(() {
        _isConnectingRoads = false;
        _selectedRoadIds.clear();
      });
    }
  }

  List<Marker> _buildIntersectionMarkers(List<Intersection> intersections) {
    return intersections.map((intersection) {
      return Marker(
        point: intersection.position,
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

  // Getters for external access
  bool get isRecordingRoad => _isRecordingRoad;
  bool get isConnectingRoads => _isConnectingRoads;
  bool get isAddingIntersection => _isAddingIntersection;

  // Implement helper methods for colors, icons, etc.
  Color _getRoadColor(String type) {
    switch (type) {
      case 'road':
        return Colors.grey[800]!;
      case 'walkway':
        return Colors.brown;
      case 'corridor':
        return Colors.orange;
      case 'hallway':
        return Colors.purple[300]!;
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

  // Add placeholder implementations for missing methods
  void _showAddLandmarkDialog(LatLng point, RoadSystemProvider provider, BuildingProvider buildingProvider) {
    // Implementation similar to original but with floor context
  }

  void _showAddBuildingDialog(LatLng point, RoadSystemProvider provider) {
    // Implementation similar to original
  }

  void _showLandmarkInfo(BuildContext context, Landmark landmark) {
    // Implementation similar to original
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