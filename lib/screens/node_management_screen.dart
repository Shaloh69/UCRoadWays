import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../providers/road_system_provider.dart';
import '../services/road_graph_builder.dart';

/// Screen for managing intersections/nodes in the road network
class NodeManagementScreen extends StatefulWidget {
  final RoadSystem roadSystem;

  const NodeManagementScreen({
    Key? key,
    required this.roadSystem,
  }) : super(key: key);

  @override
  State<NodeManagementScreen> createState() => _NodeManagementScreenState();
}

class _NodeManagementScreenState extends State<NodeManagementScreen> {
  final MapController _mapController = MapController();
  final Uuid _uuid = const Uuid();

  bool _createMode = false;
  bool _connectMode = false;
  bool _showGraph = false;
  String? _selectedFloorId;
  String? _selectedBuildingId;
  Intersection? _selectedIntersection;
  Intersection? _connectFromIntersection;
  RoadGraph? _roadGraph;

  @override
  void initState() {
    super.initState();
    _buildGraph();
  }

  void _buildGraph() {
    final builder = RoadGraphBuilder();
    setState(() {
      _roadGraph = builder.buildGraph(widget.roadSystem);
    });
  }

  List<Intersection> _getIntersections() {
    if (_selectedBuildingId != null && _selectedFloorId != null) {
      // Indoor intersections
      final building = widget.roadSystem.buildings
          .firstWhere((b) => b.id == _selectedBuildingId);
      final floor = building.floors.firstWhere((f) => f.id == _selectedFloorId);
      return floor.intersections;
    } else {
      // Outdoor intersections
      return widget.roadSystem.outdoorIntersections;
    }
  }

  List<Road> _getRoads() {
    if (_selectedBuildingId != null && _selectedFloorId != null) {
      // Indoor roads
      final building = widget.roadSystem.buildings
          .firstWhere((b) => b.id == _selectedBuildingId);
      final floor = building.floors.firstWhere((f) => f.id == _selectedFloorId);
      return floor.roads;
    } else {
      // Outdoor roads
      return widget.roadSystem.outdoorRoads;
    }
  }

  void _handleMapTap(LatLng position) {
    if (_createMode) {
      _createIntersection(position);
    } else if (_connectMode && _selectedIntersection != null) {
      // Find nearest intersection to connect to
      final intersections = _getIntersections();
      Intersection? nearest;
      double minDist = double.infinity;

      for (var intersection in intersections) {
        if (intersection.id == _selectedIntersection!.id) continue;
        final dist = const Distance().as(
          LengthUnit.Meter,
          position,
          intersection.position,
        );
        if (dist < minDist) {
          minDist = dist;
          nearest = intersection;
        }
      }

      if (nearest != null && minDist < 50) {
        _connectIntersections(_selectedIntersection!, nearest);
      }
    } else {
      // Select intersection
      final intersections = _getIntersections();
      Intersection? nearest;
      double minDist = double.infinity;

      for (var intersection in intersections) {
        final dist = const Distance().as(
          LengthUnit.Meter,
          position,
          intersection.position,
        );
        if (dist < minDist) {
          minDist = dist;
          nearest = intersection;
        }
      }

      if (nearest != null && minDist < 20) {
        setState(() {
          _selectedIntersection = nearest;
        });
      }
    }
  }

  void _createIntersection(LatLng position) {
    final provider = Provider.of<RoadSystemProvider>(context, listen: false);

    final intersection = Intersection(
      id: _uuid.v4(),
      name: 'Intersection ${_getIntersections().length + 1}',
      position: position,
      floorId: _selectedFloorId ?? '',
      connectedRoadIds: [],
      type: 'simple',
      properties: {},
    );

    if (_selectedBuildingId != null && _selectedFloorId != null) {
      provider.addIntersectionToFloor(
        widget.roadSystem.id,
        _selectedBuildingId!,
        _selectedFloorId!,
        intersection,
      );
    } else {
      provider.addOutdoorIntersection(widget.roadSystem.id, intersection);
    }

    _buildGraph();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Intersection created: ${intersection.name}')),
    );
  }

  void _connectIntersections(Intersection from, Intersection to) {
    final provider = Provider.of<RoadSystemProvider>(context, listen: false);

    // Create a road connecting the two intersections
    final road = Road(
      id: _uuid.v4(),
      name: 'Road ${_getRoads().length + 1}',
      points: [from.position, to.position],
      type: 'road',
      width: 5.0,
      isOneWay: false,
      floorId: _selectedFloorId ?? '',
      connectedIntersections: [from.id, to.id],
      properties: {},
    );

    if (_selectedBuildingId != null && _selectedFloorId != null) {
      provider.addRoadToFloor(
        widget.roadSystem.id,
        _selectedBuildingId!,
        _selectedFloorId!,
        road,
      );
    } else {
      provider.addOutdoorRoad(widget.roadSystem.id, road);
    }

    _buildGraph();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Intersections connected')),
    );
  }

  void _deleteIntersection(Intersection intersection) {
    final provider = Provider.of<RoadSystemProvider>(context, listen: false);

    if (_selectedBuildingId != null && _selectedFloorId != null) {
      provider.removeIntersectionFromFloor(
        widget.roadSystem.id,
        _selectedBuildingId!,
        _selectedFloorId!,
        intersection.id,
      );
    } else {
      provider.removeOutdoorIntersection(widget.roadSystem.id, intersection.id);
    }

    setState(() {
      _selectedIntersection = null;
    });

    _buildGraph();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Intersection deleted')),
    );
  }

  void _editIntersection(Intersection intersection) {
    showDialog(
      context: context,
      builder: (context) => _EditIntersectionDialog(
        intersection: intersection,
        onSave: (updatedIntersection) {
          final provider =
              Provider.of<RoadSystemProvider>(context, listen: false);

          if (_selectedBuildingId != null && _selectedFloorId != null) {
            provider.updateIntersectionInFloor(
              widget.roadSystem.id,
              _selectedBuildingId!,
              _selectedFloorId!,
              updatedIntersection,
            );
          } else {
            provider.updateOutdoorIntersection(
              widget.roadSystem.id,
              updatedIntersection,
            );
          }

          setState(() {
            _selectedIntersection = updatedIntersection;
          });

          _buildGraph();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final intersections = _getIntersections();
    final roads = _getRoads();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Node Management'),
        actions: [
          IconButton(
            icon: Icon(_showGraph ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() {
                _showGraph = !_showGraph;
              });
            },
            tooltip: 'Toggle Graph View',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showGraphStats,
            tooltip: 'Graph Statistics',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildToolbar(),
          if (_selectedIntersection != null) _buildIntersectionInfo(),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.roadSystem.centerPosition,
                initialZoom: widget.roadSystem.zoom,
                onTap: (_, position) => _handleMapTap(position),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.ucroadways',
                ),
                // Draw roads
                PolylineLayer(
                  polylines: roads.map((road) {
                    return Polyline(
                      points: road.points,
                      color: Colors.blue.withOpacity(0.5),
                      strokeWidth: 4.0,
                    );
                  }).toList(),
                ),
                // Draw graph edges if enabled
                if (_showGraph && _roadGraph != null)
                  PolylineLayer(
                    polylines: _buildGraphEdges(),
                  ),
                // Draw intersections
                MarkerLayer(
                  markers: intersections.map((intersection) {
                    final isSelected =
                        _selectedIntersection?.id == intersection.id;
                    return Marker(
                      point: intersection.position,
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedIntersection = intersection;
                          });
                        },
                        child: Icon(
                          Icons.circle,
                          color: isSelected ? Colors.red : Colors.orange,
                          size: isSelected ? 24 : 16,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActions(),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.grey[200],
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<String?>(
              value: _selectedBuildingId,
              hint: const Text('Select Building'),
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: null, child: Text('Outdoor')),
                ...widget.roadSystem.buildings.map((building) {
                  return DropdownMenuItem(
                    value: building.id,
                    child: Text(building.name),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedBuildingId = value;
                  _selectedFloorId = null;
                  _selectedIntersection = null;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          if (_selectedBuildingId != null)
            Expanded(
              child: DropdownButton<String?>(
                value: _selectedFloorId,
                hint: const Text('Select Floor'),
                isExpanded: true,
                items: widget.roadSystem.buildings
                    .firstWhere((b) => b.id == _selectedBuildingId)
                    .floors
                    .map((floor) {
                  return DropdownMenuItem(
                    value: floor.id,
                    child: Text(floor.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedFloorId = value;
                    _selectedIntersection = null;
                  });
                },
              ),
            ),
          const SizedBox(width: 8),
          Text('${intersections.length} nodes'),
        ],
      ),
    );
  }

  Widget _buildIntersectionInfo() {
    final intersection = _selectedIntersection!;
    final connectedRoads = _getRoads()
        .where((r) => r.connectedIntersections.contains(intersection.id))
        .length;

    return Container(
      padding: const EdgeInsets.all(12.0),
      color: Colors.blue[50],
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  intersection.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Type: ${intersection.type}'),
                Text('Connected roads: $connectedRoads'),
                Text(
                  'Position: ${intersection.position.latitude.toStringAsFixed(6)}, ${intersection.position.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editIntersection(intersection),
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteIntersection(intersection),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'create',
          onPressed: () {
            setState(() {
              _createMode = !_createMode;
              _connectMode = false;
            });
          },
          backgroundColor: _createMode ? Colors.green : null,
          child: const Icon(Icons.add_location),
          tooltip: 'Create Intersection',
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          heroTag: 'connect',
          onPressed: _selectedIntersection != null
              ? () {
                  setState(() {
                    _connectMode = !_connectMode;
                    _createMode = false;
                    if (_connectMode) {
                      _connectFromIntersection = _selectedIntersection;
                    }
                  });
                }
              : null,
          backgroundColor: _connectMode ? Colors.blue : null,
          child: const Icon(Icons.link),
          tooltip: 'Connect Intersections',
        ),
      ],
    );
  }

  List<Polyline> _buildGraphEdges() {
    if (_roadGraph == null) return [];

    final polylines = <Polyline>[];
    final floorId = _selectedFloorId;

    for (var node in _roadGraph!.nodes.values) {
      // Filter by floor if selected
      if (floorId != null && node.floorId != floorId) continue;
      if (floorId == null && node.floorId != null) continue;

      for (var edge in node.edges.values) {
        final toNode = _roadGraph!.nodes[edge.toNodeId];
        if (toNode == null) continue;

        polylines.add(Polyline(
          points: [node.position, toNode.position],
          color: edge.isVerticalTransition
              ? Colors.purple.withOpacity(0.6)
              : Colors.green.withOpacity(0.4),
          strokeWidth: 2.0,
          isDotted: edge.isOneWay,
        ));
      }
    }

    return polylines;
  }

  void _showGraphStats() {
    if (_roadGraph == null) {
      _buildGraph();
    }

    final stats = _roadGraph!.getStatistics();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Graph Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Nodes: ${stats['totalNodes']}'),
            Text('Total Edges: ${stats['totalEdges']}'),
            Text('Intersection Nodes: ${stats['intersectionNodes']}'),
            Text('Landmark Nodes: ${stats['landmarkNodes']}'),
            Text('Road Point Nodes: ${stats['roadPointNodes']}'),
            const SizedBox(height: 16),
            const Text(
              'Average Connections per Node:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              ((stats['totalEdges'] as int) /
                      (stats['totalNodes'] as int).toDouble())
                  .toStringAsFixed(2),
            ),
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

class _EditIntersectionDialog extends StatefulWidget {
  final Intersection intersection;
  final Function(Intersection) onSave;

  const _EditIntersectionDialog({
    required this.intersection,
    required this.onSave,
  });

  @override
  State<_EditIntersectionDialog> createState() =>
      _EditIntersectionDialogState();
}

class _EditIntersectionDialogState extends State<_EditIntersectionDialog> {
  late TextEditingController _nameController;
  late String _type;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.intersection.name);
    _type = widget.intersection.type;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Intersection'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'simple', child: Text('Simple')),
              DropdownMenuItem(value: 'traffic_light', child: Text('Traffic Light')),
              DropdownMenuItem(value: 'roundabout', child: Text('Roundabout')),
              DropdownMenuItem(value: 'crossing', child: Text('Crossing')),
            ],
            onChanged: (value) {
              setState(() {
                _type = value!;
              });
            },
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
            final updated = Intersection(
              id: widget.intersection.id,
              name: _nameController.text,
              position: widget.intersection.position,
              floorId: widget.intersection.floorId,
              connectedRoadIds: widget.intersection.connectedRoadIds,
              type: _type,
              properties: widget.intersection.properties,
            );
            widget.onSave(updated);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
