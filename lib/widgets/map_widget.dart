import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import '../providers/road_system_provider.dart';
import '../providers/building_provider.dart';
import '../models/models.dart';
import 'dart:math';

class UCRoadWaysMap extends StatefulWidget {
  final MapController mapController;

  const UCRoadWaysMap({
    super.key,
    required this.mapController,
  });

  @override
  State<UCRoadWaysMap> createState() => _UCRoadWaysMapState();
}

class _UCRoadWaysMapState extends State<UCRoadWaysMap> {
  static const double _defaultLat = 33.9737; // UC Riverside latitude
  static const double _defaultLng = -117.3281; // UC Riverside longitude
  static const double _defaultZoom = 16.0;

  bool _isAddingRoad = false;
  List<LatLng> _tempRoadPoints = [];
  bool _isAddingLandmark = false;

  @override
  Widget build(BuildContext context) {
    return Consumer3<LocationProvider, RoadSystemProvider, BuildingProvider>(
      builder: (context, locationProvider, roadSystemProvider, buildingProvider, child) {
        final currentSystem = roadSystemProvider.currentSystem;
        final selectedBuilding = buildingProvider.getSelectedBuilding(currentSystem);
        final selectedFloor = buildingProvider.getSelectedFloor(currentSystem);

        return FlutterMap(
          mapController: widget.mapController,
          options: MapOptions(
            center: _getMapCenter(locationProvider, currentSystem),
            zoom: currentSystem?.zoom ?? _defaultZoom,
            minZoom: 10.0,
            maxZoom: 20.0,
            onTap: _isAddingRoad || _isAddingLandmark 
                ? (tapPosition, point) => _handleMapTap(point, roadSystemProvider)
                : null,
            onLongPress: (tapPosition, point) => _showContextMenu(context, point, roadSystemProvider),
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
            
            // Current location marker
            if (locationProvider.currentLatLng != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: locationProvider.currentLatLng!,
                    width: 40,
                    height: 40,
                    builder: (context) => Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue, width: 3),
                      ),
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            
            // Temporary road being drawn
            if (_tempRoadPoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _tempRoadPoints,
                    color: Colors.red.withOpacity(0.7),
                    strokeWidth: 3.0,
                    isDotted: true,
                  ),
                ],
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

  List<Polyline> _buildOutdoorRoadPolylines(RoadSystem system) {
    return system.outdoorRoads.map((road) {
      return Polyline(
        points: road.points,
        color: _getRoadColor(road.type),
        strokeWidth: road.width,
        borderColor: Colors.black,
        borderStrokeWidth: 1,
      );
    }).toList();
  }

  List<Polyline> _buildIndoorRoadPolylines(Floor floor) {
    return floor.roads.map((road) {
      return Polyline(
        points: road.points,
        color: _getRoadColor(road.type).withOpacity(0.8),
        strokeWidth: road.width,
        borderColor: Colors.grey,
        borderStrokeWidth: 1,
      );
    }).toList();
  }

  List<Polygon> _buildBuildingPolygons(RoadSystem system, Building? selectedBuilding) {
    return system.buildings.map((building) {
      final isSelected = building.id == selectedBuilding?.id;
      return Polygon(
        points: building.boundaryPoints.isNotEmpty 
            ? building.boundaryPoints 
            : _createCircularBoundary(building.centerPosition, 50), // 50m radius default
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
        builder: (context) => GestureDetector(
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
        builder: (context) => GestureDetector(
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
        builder: (context) => GestureDetector(
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
    const double earthRadius = 6371000; // Earth's radius in meters
    
    List<LatLng> boundary = [];
    
    for (int i = 0; i < points; i++) {
      double angle = (i * 2 * 3.14159) / points;
      double deltaLat = radiusMeters * cos(angle) / earthRadius * (180 / 3.14159);
      double deltaLng = radiusMeters * sin(angle) / 
          (earthRadius * cos(center.latitude * 3.14159 / 180)) * (180 / 3.14159);
      
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
      default:
        return Icons.place;
    }
  }

  void _handleMapTap(LatLng point, RoadSystemProvider provider) {
    if (_isAddingRoad) {
      setState(() {
        _tempRoadPoints.add(point);
      });
    } else if (_isAddingLandmark) {
      _showAddLandmarkDialog(point, provider);
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
              leading: const Icon(Icons.road),
              title: const Text('Start Road'),
              onTap: () {
                Navigator.pop(context);
                _startAddingRoad();
              },
            ),
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
          ],
        ),
      ),
    );
  }

  void _startAddingRoad() {
    setState(() {
      _isAddingRoad = true;
      _tempRoadPoints.clear();
    });
  }

  void _showAddLandmarkDialog(LatLng point, RoadSystemProvider provider) {
    // Implementation for adding landmarks
    // This would show a dialog to input landmark details
  }

  void _showAddBuildingDialog(LatLng point, RoadSystemProvider provider) {
    // Implementation for adding buildings
    // This would show a dialog to input building details
  }

  void _showLandmarkInfo(BuildContext context, Landmark landmark) {
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
}