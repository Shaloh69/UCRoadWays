import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../providers/road_system_provider.dart';
import '../providers/building_provider.dart';
import '../providers/location_provider.dart';
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                    color: isSelected ? Colors.blue : null,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${building.floors.length} floors'),
                    Text(
                      'Lat: ${building.centerPosition.latitude.toStringAsFixed(6)}, '
                      'Lng: ${building.centerPosition.longitude.toStringAsFixed(6)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) => _handleBuildingAction(
                    action,
                    building,
                    roadSystemProvider,
                    buildingProvider,
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'select',
                      child: ListTile(
                        leading: Icon(Icons.my_location),
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
                      value: 'manage_boundary',
                      child: ListTile(
                        leading: Icon(Icons.border_outer),
                        title: Text('Set Boundary'),
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
                onTap: () => buildingProvider.selectBuilding(building.id),
              ),
              if (building.floors.isNotEmpty) ...[
                const Divider(height: 1),
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Floors:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: building.sortedFloors.map((floor) {
                          final isFloorSelected = buildingProvider.selectedFloorId == floor.id;
                          return GestureDetector(
                            onTap: () => buildingProvider.selectFloor(floor.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isFloorSelected ? Colors.blue : Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isFloorSelected ? Colors.blue : Colors.grey[400]!,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getFloorIcon(floor.level),
                                    size: 12,
                                    color: isFloorSelected ? Colors.white : Colors.grey[700],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    buildingProvider.getFloorDisplayName(floor),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isFloorSelected ? Colors.white : Colors.grey[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
    final allFloors = <Map<String, dynamic>>[];
    
    for (final building in system.buildings) {
      for (final floor in building.floors) {
        allFloors.add({
          'floor': floor,
          'building': building,
        });
      }
    }

    allFloors.sort((a, b) {
      final floorA = a['floor'] as Floor;
      final floorB = a['floor'] as Floor;
      final comparison = (a['building'] as Building).name.compareTo((b['building'] as Building).name);
      if (comparison != 0) return comparison;
      return floorB.level.compareTo(floorA.level);
    });

    if (allFloors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.layers_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No Floors',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const Text('Add buildings and floors to organize your spaces'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allFloors.length,
      itemBuilder: (context, index) {
        final item = allFloors[index];
        final floor = item['floor'] as Floor;
        final building = item['building'] as Building;
        final isSelected = buildingProvider.selectedFloorId == floor.id;

        return Card(
          elevation: isSelected ? 4 : 1,
          color: isSelected ? Colors.green[50] : null,
          child: ListTile(
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getFloorIcon(floor.level),
                  color: isSelected ? Colors.green : Colors.grey[600],
                ),
                Text(
                  '${floor.level > 0 ? '+' : ''}${floor.level}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? Colors.green : Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            title: Text(
              floor.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.green : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Building: ${building.name}'),
                Text('${floor.roads.length} roads, ${floor.landmarks.length} landmarks'),
                if (floor.verticalCirculation.isNotEmpty)
                  Text(
                    'Vertical access: ${floor.verticalCirculation.map((l) => l.type).join(', ')}',
                    style: TextStyle(color: Colors.blue[700], fontSize: 12),
                  ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (action) => _handleFloorAction(
                action,
                floor,
                building,
                roadSystemProvider,
                buildingProvider,
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'select',
                  child: ListTile(
                    leading: Icon(Icons.my_location),
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
                  value: 'add_landmark',
                  child: ListTile(
                    leading: Icon(Icons.place_outlined),
                    title: Text('Add Landmark'),
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
              buildingProvider.selectBuilding(building.id);
              buildingProvider.selectFloor(floor.id);
            },
          ),
        );
      },
    );
  }

  void _showAddBuildingDialog() {
    final nameController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    
    // Pre-fill with current location if available
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    if (locationProvider.currentLatLng != null) {
      latController.text = locationProvider.currentLatLng!.latitude.toStringAsFixed(6);
      lngController.text = locationProvider.currentLatLng!.longitude.toStringAsFixed(6);
    } else {
      // Default to UC Riverside
      latController.text = '33.9737';
      lngController.text = '-117.3281';
    }

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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      if (locationProvider.currentLatLng != null) {
                        latController.text = locationProvider.currentLatLng!.latitude.toStringAsFixed(6);
                        lngController.text = locationProvider.currentLatLng!.longitude.toStringAsFixed(6);
                      }
                    },
                    icon: const Icon(Icons.my_location),
                    label: const Text('Use Current'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      latController.text = '33.9737';
                      lngController.text = '-117.3281';
                    },
                    icon: const Icon(Icons.location_city),
                    label: const Text('UCR Default'),
                  ),
                ],
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
              if (nameController.text.isNotEmpty &&
                  latController.text.isNotEmpty &&
                  lngController.text.isNotEmpty) {
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
    final levelController = TextEditingController(text: '0');

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
                final level = int.tryParse(levelController.text) ?? 0;
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Building "$name" added successfully'),
          backgroundColor: Colors.green,
        ),
      );
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
        centerPosition: building.centerPosition,
      );
      
      final updatedFloors = List<Floor>.from(building.floors)..add(newFloor);
      final updatedBuilding = building.copyWith(floors: updatedFloors);
      
      final updatedBuildings = currentSystem.buildings
          .map((b) => b.id == building.id ? updatedBuilding : b)
          .toList();
      
      final updatedSystem = currentSystem.copyWith(buildings: updatedBuildings);
      roadSystemProvider.updateCurrentSystem(updatedSystem);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Floor "$name" added to ${building.name}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _handleBuildingAction(
    String action,
    Building building,
    RoadSystemProvider roadSystemProvider,
    BuildingProvider buildingProvider,
  ) {
    switch (action) {
      case 'select':
        buildingProvider.selectBuilding(building.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selected ${building.name}')),
        );
        break;
      case 'edit':
        _showEditBuildingDialog(building);
        break;
      case 'add_floor':
        _showAddFloorDialog(building);
        break;
      case 'manage_boundary':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Boundary management - Navigate to map to set boundary')),
        );
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
    BuildingProvider buildingProvider,
  ) {
    switch (action) {
      case 'select':
        buildingProvider.selectBuilding(building.id);
        buildingProvider.selectFloor(floor.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selected ${floor.name} in ${building.name}')),
        );
        break;
      case 'edit':
        _showEditFloorDialog(floor, building);
        break;
      case 'add_landmark':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Navigate to map to add landmarks to this floor')),
        );
        break;
      case 'delete':
        _showDeleteFloorConfirmation(floor, building, roadSystemProvider);
        break;
    }
  }

  void _showEditBuildingDialog(Building building) {
    final nameController = TextEditingController(text: building.name);
    final latController = TextEditingController(
      text: building.centerPosition.latitude.toStringAsFixed(6),
    );
    final lngController = TextEditingController(
      text: building.centerPosition.longitude.toStringAsFixed(6),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Building'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Building Name'),
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
                  _updateBuilding(building, nameController.text, LatLng(lat, lng));
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditFloorDialog(Floor floor, Building building) {
    final nameController = TextEditingController(text: floor.name);
    final levelController = TextEditingController(text: floor.level.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Floor in ${building.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Floor Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: levelController,
              decoration: const InputDecoration(labelText: 'Floor Level'),
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
                final level = int.tryParse(levelController.text) ?? floor.level;
                _updateFloor(floor, building, nameController.text, level);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _updateBuilding(Building building, String name, LatLng position) {
    final roadSystemProvider = Provider.of<RoadSystemProvider>(context, listen: false);
    final currentSystem = roadSystemProvider.currentSystem;
    
    if (currentSystem != null) {
      final updatedBuilding = building.copyWith(
        name: name,
        centerPosition: position,
      );
      
      final updatedBuildings = currentSystem.buildings
          .map((b) => b.id == building.id ? updatedBuilding : b)
          .toList();
      
      final updatedSystem = currentSystem.copyWith(buildings: updatedBuildings);
      roadSystemProvider.updateCurrentSystem(updatedSystem);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Building "$name" updated')),
      );
    }
  }

  void _updateFloor(Floor floor, Building building, String name, int level) {
    final roadSystemProvider = Provider.of<RoadSystemProvider>(context, listen: false);
    final currentSystem = roadSystemProvider.currentSystem;
    
    if (currentSystem != null) {
      final updatedFloor = floor.copyWith(name: name, level: level);
      
      final updatedFloors = building.floors
          .map((f) => f.id == floor.id ? updatedFloor : f)
          .toList();
      
      final updatedBuilding = building.copyWith(floors: updatedFloors);
      
      final updatedBuildings = currentSystem.buildings
          .map((b) => b.id == building.id ? updatedBuilding : b)
          .toList();
      
      final updatedSystem = currentSystem.copyWith(buildings: updatedBuildings);
      roadSystemProvider.updateCurrentSystem(updatedSystem);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Floor "$name" updated')),
      );
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
      
      // Clear selection if deleted building was selected
      final buildingProvider = Provider.of<BuildingProvider>(context, listen: false);
      if (buildingProvider.selectedBuildingId == building.id) {
        buildingProvider.reset();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Building "${building.name}" deleted'),
          backgroundColor: Colors.red,
        ),
      );
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
      
      // Clear selection if deleted floor was selected
      final buildingProvider = Provider.of<BuildingProvider>(context, listen: false);
      if (buildingProvider.selectedFloorId == floor.id) {
        buildingProvider.selectFloor('');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Floor "${floor.name}" deleted'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  IconData _getFloorIcon(int level) {
    if (level < 0) return Icons.arrow_downward;
    if (level == 0) return Icons.business;
    return Icons.arrow_upward;
  }
}