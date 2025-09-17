import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../providers/road_system_provider.dart';
import '../providers/building_provider.dart';
import '../models/models.dart';

class BuildingManagerScreen extends StatefulWidget {
  const BuildingManagerScreen({super.key});

  @override
  State<BuildingManagerScreen> createState() => _BuildingManagerScreenState();
}

class _BuildingManagerScreenState extends State<BuildingManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Building Manager'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Buildings', icon: Icon(Icons.business)),
            Tab(text: 'Floors', icon: Icon(Icons.layers)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddBuildingDialog(),
            tooltip: 'Add Building',
          ),
        ],
      ),
      body: Consumer2<RoadSystemProvider, BuildingProvider>(
        builder: (context, roadSystemProvider, buildingProvider, child) {
          final currentSystem = roadSystemProvider.currentSystem;
          
          if (currentSystem == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning, size: 64, color: Colors.orange),
                  SizedBox(height: 16),
                  Text(
                    'No Road System Selected',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text('Please select a road system first'),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildBuildingsTab(currentSystem, buildingProvider, roadSystemProvider),
              _buildFloorsTab(currentSystem, buildingProvider, roadSystemProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBuildingsTab(
    RoadSystem system,
    BuildingProvider buildingProvider,
    RoadSystemProvider roadSystemProvider,
  ) {
    if (system.buildings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No Buildings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const Text('Add buildings to organize your indoor spaces'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddBuildingDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Building'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: system.buildings.length,
      itemBuilder: (context, index) {
        final building = system.buildings[index];
        final isSelected = buildingProvider.selectedBuildingId == building.id;

        return Card(
          elevation: isSelected ? 4 : 1,
          margin: const EdgeInsets.only(bottom: 16),
          color: isSelected ? Colors.blue[50] : null,
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.business,
                  color: isSelected ? Colors.blue : Colors.grey[600],
                  size: 32,
                ),
                title: Text(
                  building.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.blue[700] : null,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${building.floors.length} floor(s)'),
                    Text(
                      '${building.centerPosition.latitude.toStringAsFixed(4)}, '
                      '${building.centerPosition.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) => _handleBuildingAction(
                    action,
                    building,
                    roadSystemProvider,
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'select',
                      child: ListTile(
                        leading: Icon(Icons.touch_app),
                        title: Text('Select'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Edit'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'add_floor',
                      child: ListTile(
                        leading: Icon(Icons.add),
                        title: Text('Add Floor'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  buildingProvider.selectBuilding(
                    isSelected ? null : building.id,
                  );
                },
              ),
              if (isSelected && building.floors.isNotEmpty) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Floors:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: building.floors.map((floor) {
                          final isFloorSelected = buildingProvider.selectedFloorId == floor.id;
                          return FilterChip(
                            selected: isFloorSelected,
                            label: Text(floor.name),
                            onSelected: (selected) {
                              buildingProvider.selectFloor(
                                selected ? floor.id : null,
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFloorsTab(
    RoadSystem system,
    BuildingProvider buildingProvider,
    RoadSystemProvider roadSystemProvider,
  ) {
    final selectedBuilding = buildingProvider.getSelectedBuilding(system);
    
    if (selectedBuilding == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.layers_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Building Selected',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            Text('Select a building to manage its floors'),
          ],
        ),
      );
    }

    if (selectedBuilding.floors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.layers_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Floors in ${selectedBuilding.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const Text('Add floors to organize rooms and routes'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddFloorDialog(selectedBuilding),
              icon: const Icon(Icons.add),
              label: const Text('Add Floor'),
            ),
          ],
        ),
      );
    }

    // Sort floors by level
    final sortedFloors = List<Floor>.from(selectedBuilding.floors)
      ..sort((a, b) => b.level.compareTo(a.level));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedFloors.length,
      itemBuilder: (context, index) {
        final floor = sortedFloors[index];
        final isSelected = buildingProvider.selectedFloorId == floor.id;

        return Card(
          elevation: isSelected ? 4 : 1,
          margin: const EdgeInsets.only(bottom: 16),
          color: isSelected ? Colors.blue[50] : null,
          child: ExpansionTile(
            leading: Icon(
              _getFloorIcon(floor.level),
              color: isSelected ? Colors.blue : Colors.grey[600],
            ),
            title: Text(
              floor.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.blue[700] : null,
              ),
            ),
            subtitle: Text('Level ${floor.level}'),
            trailing: PopupMenuButton<String>(
              onSelected: (action) => _handleFloorAction(
                action,
                floor,
                selectedBuilding,
                roadSystemProvider,
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'select',
                  child: ListTile(
                    leading: Icon(Icons.touch_app),
                    title: Text('Select'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Edit'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'add_room',
                  child: ListTile(
                    leading: Icon(Icons.room),
                    title: Text('Add Room'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
            onExpansionChanged: (expanded) {
              if (expanded) {
                buildingProvider.selectFloor(floor.id);
              }
            },
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                         _buildFloorStat('Roads', floor.roads.length, Icons.route, Colors.green),
                        const SizedBox(width: 16),
                        _buildFloorStat('Landmarks', floor.landmarks.length, Icons.place, Colors.orange),
                      ],
                    ),
                    if (floor.landmarks.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Landmarks:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: floor.landmarks.map((landmark) {
                          return Chip(
                            avatar: Icon(
                              _getLandmarkIcon(landmark.type),
                              size: 16,
                              color: Colors.white,
                            ),
                            backgroundColor: _getLandmarkColor(landmark.type),
                            label: Text(
                              landmark.name,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFloorStat(String label, int count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFloorIcon(int level) {
    if (level < 0) return Icons.arrow_downward;
    if (level == 0) return Icons.business;
    return Icons.arrow_upward;
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

  void _showAddBuildingDialog() {
    final nameController = TextEditingController();
    final latController = TextEditingController(text: '33.9737');
    final lngController = TextEditingController(text: '-117.3281');

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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: latController,
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: lngController,
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
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
                final lat = double.tryParse(latController.text);
                final lng = double.tryParse(lngController.text);
                
                if (lat != null && lng != null) {
                  _addBuilding(nameController.text, LatLng(lat, lng));
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddFloorDialog(Building building) {
    final nameController = TextEditingController();
    final levelController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Floor to ${building.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Floor Name',
                hintText: 'e.g., Ground Floor, First Floor',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: levelController,
              decoration: const InputDecoration(
                labelText: 'Floor Level',
                hintText: '0 = Ground, -1 = Basement, 1 = First',
              ),
              keyboardType: TextInputType.number,
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
                final level = int.tryParse(levelController.text) ?? 1;
                _addFloor(building, nameController.text, level);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addBuilding(String name, LatLng position) {
    final roadSystemProvider = Provider.of<RoadSystemProvider>(context, listen: false);
    final currentSystem = roadSystemProvider.currentSystem;
    
    if (currentSystem != null) {
      final newBuilding = Building(
        id: const Uuid().v4(),
        name: name,
        centerPosition: position,
      );
      
      final updatedBuildings = List<Building>.from(currentSystem.buildings)
        ..add(newBuilding);
      
      final updatedSystem = currentSystem.copyWith(buildings: updatedBuildings);
      roadSystemProvider.updateCurrentSystem(updatedSystem);
    }
  }

  void _addFloor(Building building, String name, int level) {
    final roadSystemProvider = Provider.of<RoadSystemProvider>(context, listen: false);
    final currentSystem = roadSystemProvider.currentSystem;
    
    if (currentSystem != null) {
      final newFloor = Floor(
        id: const Uuid().v4(),
        name: name,
        level: level,
        buildingId: building.id,
      );
      
      final updatedFloors = List<Floor>.from(building.floors)..add(newFloor);
      final updatedBuilding = building.copyWith(floors: updatedFloors);
      
      final updatedBuildings = currentSystem.buildings
          .map((b) => b.id == building.id ? updatedBuilding : b)
          .toList();
      
      final updatedSystem = currentSystem.copyWith(buildings: updatedBuildings);
      roadSystemProvider.updateCurrentSystem(updatedSystem);
    }
  }

  void _handleBuildingAction(
    String action,
    Building building,
    RoadSystemProvider roadSystemProvider,
  ) {
    switch (action) {
      case 'select':
        Provider.of<BuildingProvider>(context, listen: false)
            .selectBuilding(building.id);
        break;
      case 'edit':
        // Implementation for editing building
        break;
      case 'add_floor':
        _showAddFloorDialog(building);
        break;
      case 'delete':
        _showDeleteBuildingConfirmation(building, roadSystemProvider);
        break;
    }
  }

  void _handleFloorAction(
    String action,
    Floor floor,
    Building building,
    RoadSystemProvider roadSystemProvider,
  ) {
    switch (action) {
      case 'select':
        Provider.of<BuildingProvider>(context, listen: false)
            .selectFloor(floor.id);
        break;
      case 'edit':
        // Implementation for editing floor
        break;
      case 'add_room':
        // Implementation for adding room/landmark
        break;
      case 'delete':
        _showDeleteFloorConfirmation(floor, building, roadSystemProvider);
        break;
    }
  }

  void _showDeleteBuildingConfirmation(
    Building building,
    RoadSystemProvider roadSystemProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Building'),
        content: Text(
          'Are you sure you want to delete "${building.name}"? '
          'This will also delete all floors and their contents.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _deleteBuilding(building, roadSystemProvider);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteFloorConfirmation(
    Floor floor,
    Building building,
    RoadSystemProvider roadSystemProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Floor'),
        content: Text(
          'Are you sure you want to delete "${floor.name}"? '
          'This will also delete all roads and landmarks on this floor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _deleteFloor(floor, building, roadSystemProvider);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteBuilding(Building building, RoadSystemProvider roadSystemProvider) {
    final currentSystem = roadSystemProvider.currentSystem;
    if (currentSystem != null) {
      final updatedBuildings = currentSystem.buildings
          .where((b) => b.id != building.id)
          .toList();
      
      final updatedSystem = currentSystem.copyWith(buildings: updatedBuildings);
      roadSystemProvider.updateCurrentSystem(updatedSystem);
      
      // Clear selection if this building was selected
      final buildingProvider = Provider.of<BuildingProvider>(context, listen: false);
      if (buildingProvider.selectedBuildingId == building.id) {
        buildingProvider.selectBuilding(null);
      }
    }
  }

  void _deleteFloor(Floor floor, Building building, RoadSystemProvider roadSystemProvider) {
    final currentSystem = roadSystemProvider.currentSystem;
    if (currentSystem != null) {
      final updatedFloors = building.floors
          .where((f) => f.id != floor.id)
          .toList();
      
      final updatedBuilding = building.copyWith(floors: updatedFloors);
      
      final updatedBuildings = currentSystem.buildings
          .map((b) => b.id == building.id ? updatedBuilding : b)
          .toList();
      
      final updatedSystem = currentSystem.copyWith(buildings: updatedBuildings);
      roadSystemProvider.updateCurrentSystem(updatedSystem);
      
      // Clear selection if this floor was selected
      final buildingProvider = Provider.of<BuildingProvider>(context, listen: false);
      if (buildingProvider.selectedFloorId == floor.id) {
        buildingProvider.selectFloor(null);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}