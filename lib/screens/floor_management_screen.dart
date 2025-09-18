import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../providers/road_system_provider.dart';
import '../providers/building_provider.dart';
import '../models/models.dart';

class FloorManagementScreen extends StatefulWidget {
  const FloorManagementScreen({super.key});

  @override
  State<FloorManagementScreen> createState() => _FloorManagementScreenState();
}

class _FloorManagementScreenState extends State<FloorManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedBuildingId;
  String? _selectedFloorId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Floor Management'),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _showFloorAnalytics,
            tooltip: 'Floor Analytics',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'add_building',
                child: ListTile(
                  leading: Icon(Icons.add_business),
                  title: Text('Add Building'),
                ),
              ),
              const PopupMenuItem(
                value: 'import_floors',
                child: ListTile(
                  leading: Icon(Icons.file_upload),
                  title: Text('Import Floor Plan'),
                ),
              ),
              const PopupMenuItem(
                value: 'export_floors',
                child: ListTile(
                  leading: Icon(Icons.file_download),
                  title: Text('Export Floor Data'),
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Buildings', icon: Icon(Icons.business)),
            Tab(text: 'Floors', icon: Icon(Icons.layers)),
            Tab(text: 'Connections', icon: Icon(Icons.cable)),
            Tab(text: 'Accessibility', icon: Icon(Icons.accessible)),
          ],
        ),
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
              _buildConnectionsTab(currentSystem, buildingProvider),
              _buildAccessibilityTab(currentSystem, buildingProvider),
            ],
          );
        },
      ),
      floatingActionButton: _buildFloatingActionButton(),
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
            Icon(Icons.business_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            const Text(
              'No Buildings',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add buildings to organize your indoor spaces',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showAddBuildingDialog(roadSystemProvider),
              icon: const Icon(Icons.add_business),
              label: const Text('Add Building'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
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
        final isSelected = building.id == _selectedBuildingId;
        final accessibility = buildingProvider.getBuildingAccessibility(building);

        return Card(
          elevation: isSelected ? 8 : 2,
          margin: const EdgeInsets.only(bottom: 16),
          color: isSelected ? Colors.purple[50] : null,
          child: ExpansionTile(
            leading: Icon(
              Icons.business,
              color: isSelected ? Colors.purple : Colors.grey[600],
              size: 32,
            ),
            title: Text(
              building.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.purple[700] : null,
                fontSize: 18,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildInfoChip('${building.floors.length} floors', Icons.layers, Colors.blue),
                    const SizedBox(width: 8),
                    if (accessibility['hasElevator']!)
                      _buildInfoChip('Elevator', Icons.elevator, Colors.orange),
                    if (accessibility['hasAccessibleEntrance']!)
                      _buildInfoChip('Accessible', Icons.accessible, Colors.green),
                  ],
                ),
                const SizedBox(height: 4),
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
                    leading: Icon(Icons.touch_app, size: 20),
                    title: Text('Select'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit, size: 20),
                    title: Text('Edit'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'add_floor',
                  child: ListTile(
                    leading: Icon(Icons.add, size: 20),
                    title: Text('Add Floor'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'clone',
                  child: ListTile(
                    leading: Icon(Icons.copy, size: 20),
                    title: Text('Clone'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red, size: 20),
                    title: Text('Delete', style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            onExpansionChanged: (expanded) {
              setState(() {
                _selectedBuildingId = expanded ? building.id : null;
                if (!expanded) _selectedFloorId = null;
              });
            },
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Building statistics
                    Row(
                      children: [
                        Expanded(
                          child: _buildBuildingStatCard(
                            'Total Roads',
                            building.floors.fold(0, (sum, floor) => sum + floor.roads.length),
                            Icons.route,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildBuildingStatCard(
                            'Total Landmarks',
                            building.floors.fold(0, (sum, floor) => sum + floor.landmarks.length),
                            Icons.place,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Floors list
                    const Text(
                      'Floors:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    
                    if (building.floors.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.grey),
                            SizedBox(width: 8),
                            Text('No floors added yet'),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: building.sortedFloors.map((floor) {
                          return _buildFloorCard(floor, buildingProvider);
                        }).toList(),
                      ),
                    
                    const SizedBox(height: 16),
                    
                    // Add floor button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddFloorDialog(building, roadSystemProvider),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Floor'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.purple,
                          side: const BorderSide(color: Colors.purple),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
    final allFloors = system.allFloors;
    
    if (allFloors.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.layers_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 24),
            Text(
              'No Floors Available',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            Text(
              'Add buildings and floors to get started',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Group floors by building
    final floorsByBuilding = <String, List<Floor>>{};
    for (final floor in allFloors) {
      final building = system.buildings.where((b) => b.id == floor.buildingId).firstOrNull;
      if (building != null) {
        floorsByBuilding.putIfAbsent(building.name, () => []).add(floor);
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: floorsByBuilding.keys.length,
      itemBuilder: (context, index) {
        final buildingName = floorsByBuilding.keys.elementAt(index);
        final floors = floorsByBuilding[buildingName]!;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            leading: const Icon(Icons.business, color: Colors.purple),
            title: Text(
              buildingName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${floors.length} floor(s)'),
            children: floors.map((floor) {
              final stats = buildingProvider.getFloorStatistics(floor);
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getFloorLevelColor(floor.level),
                  radius: 16,
                  child: Text(
                    _getFloorShortName(floor),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(buildingProvider.getFloorDisplayName(floor)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${stats['roads']} roads • ${stats['landmarks']} landmarks'),
                    if (stats['elevators']! > 0 || stats['stairs']! > 0)
                      Row(
                        children: [
                          if (stats['elevators']! > 0) ...[
                            const Icon(Icons.elevator, size: 12, color: Colors.orange),
                            Text(' ${stats['elevators']}', style: const TextStyle(fontSize: 10)),
                            const SizedBox(width: 8),
                          ],
                          if (stats['stairs']! > 0) ...[
                            const Icon(Icons.stairs, size: 12, color: Colors.teal),
                            Text(' ${stats['stairs']}', style: const TextStyle(fontSize: 10)),
                          ],
                        ],
                      ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) => _handleFloorAction(action, floor, roadSystemProvider),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: ListTile(
                        leading: Icon(Icons.visibility, size: 20),
                        title: Text('View'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit, size: 20),
                        title: Text('Edit'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: ListTile(
                        leading: Icon(Icons.copy, size: 20),
                        title: Text('Duplicate'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red, size: 20),
                        title: Text('Delete', style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  buildingProvider.navigateToFloor(floors.first.buildingId, floor.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Switched to ${floor.name}'),
                      backgroundColor: Colors.purple,
                    ),
                  );
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildConnectionsTab(RoadSystem system, BuildingProvider buildingProvider) {
    final allConnections = <Map<String, dynamic>>[];
    
    // Collect all vertical circulation connections
    for (final building in system.buildings) {
      for (final floor in building.floors) {
        for (final landmark in floor.verticalCirculation) {
          allConnections.add({
            'building': building,
            'floor': floor,
            'landmark': landmark,
            'connections': landmark.connectedFloors.length,
          });
        }
      }
    }

    if (allConnections.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cable, size: 80, color: Colors.grey),
            SizedBox(height: 24),
            Text(
              'No Floor Connections',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            Text(
              'Add elevators and stairs to connect floors',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allConnections.length,
      itemBuilder: (context, index) {
        final connection = allConnections[index];
        final building = connection['building'] as Building;
        final floor = connection['floor'] as Floor;
        final landmark = connection['landmark'] as Landmark;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: landmark.type == 'elevator' ? Colors.orange : Colors.teal,
              child: Icon(
                landmark.type == 'elevator' ? Icons.elevator : Icons.stairs,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(landmark.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${building.name} - ${floor.name}'),
                Text('Connects ${landmark.connectedFloors.length} floors'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${landmark.connectedFloors.length}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
            onTap: () => _showConnectionDetails(building, floor, landmark),
          ),
        );
      },
    );
  }

  Widget _buildAccessibilityTab(RoadSystem system, BuildingProvider buildingProvider) {
    final accessibilityIssues = <Map<String, dynamic>>[];
    
    // Analyze accessibility for each building
    for (final building in system.buildings) {
      final accessibility = buildingProvider.getBuildingAccessibility(building);
      
      if (!accessibility['hasElevator']! && accessibility['multiFloor']!) {
        accessibilityIssues.add({
          'type': 'no_elevator',
          'building': building,
          'severity': 'high',
          'description': 'Multi-floor building without elevator access',
        });
      }
      
      if (!accessibility['hasAccessibleEntrance']!) {
        accessibilityIssues.add({
          'type': 'no_accessible_entrance',
          'building': building,
          'severity': 'medium',
          'description': 'No accessible entrance marked',
        });
      }
      
      // Check for floors without vertical circulation
      for (final floor in building.floors) {
        if (floor.level != 0 && floor.verticalCirculation.isEmpty) {
          accessibilityIssues.add({
            'type': 'isolated_floor',
            'building': building,
            'floor': floor,
            'severity': 'high',
            'description': 'Floor with no vertical circulation access',
          });
        }
      }
    }

    return Column(
      children: [
        // Accessibility overview
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accessibilityIssues.isEmpty ? Colors.green[50] : Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: accessibilityIssues.isEmpty ? Colors.green : Colors.orange,
            ),
          ),
          child: Column(
            children: [
              Icon(
                accessibilityIssues.isEmpty ? Icons.check_circle : Icons.warning,
                color: accessibilityIssues.isEmpty ? Colors.green : Colors.orange,
                size: 48,
              ),
              const SizedBox(height: 8),
              Text(
                accessibilityIssues.isEmpty 
                    ? 'All buildings are accessible' 
                    : '${accessibilityIssues.length} accessibility issue(s) found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: accessibilityIssues.isEmpty ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
        ),
        
        // Issues list
        if (accessibilityIssues.isNotEmpty)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: accessibilityIssues.length,
              itemBuilder: (context, index) {
                final issue = accessibilityIssues[index];
                final building = issue['building'] as Building;
                final severity = issue['severity'] as String;
                final severityColor = severity == 'high' ? Colors.red : Colors.orange;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      _getIssueIcon(issue['type']),
                      color: severityColor,
                    ),
                    title: Text(building.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(issue['description']),
                        if (issue['floor'] != null)
                          Text(
                            'Floor: ${(issue['floor'] as Floor).name}',
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: severityColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        severity.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    onTap: () => _showAccessibilityFix(issue),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    return Consumer2<RoadSystemProvider, BuildingProvider>(
      builder: (context, roadSystemProvider, buildingProvider, child) {
        final selectedBuilding = buildingProvider.getSelectedBuilding(roadSystemProvider.currentSystem);
        
        if (_tabController.index == 0) {
          // Buildings tab
          return FloatingActionButton(
            onPressed: () => _showAddBuildingDialog(roadSystemProvider),
            backgroundColor: Colors.purple,
            tooltip: 'Add Building',
            child: const Icon(Icons.add_business),
          );
        } else if (_tabController.index == 1 && selectedBuilding != null) {
          // Floors tab with building selected
          return FloatingActionButton(
            onPressed: () => _showAddFloorDialog(selectedBuilding, roadSystemProvider),
            backgroundColor: Colors.purple,
            tooltip: 'Add Floor',
            child: const Icon(Icons.layers),
          );
        }
        
        return const SizedBox.shrink();
      },
    );
  }

  // Helper Widgets
  Widget _buildInfoChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingStatCard(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFloorCard(Floor floor, BuildingProvider buildingProvider) {
    final stats = buildingProvider.getFloorStatistics(floor);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getFloorLevelColor(floor.level),
          radius: 12,
          child: Text(
            _getFloorShortName(floor),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          buildingProvider.getFloorDisplayName(floor),
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          '${stats['roads']} roads, ${stats['landmarks']} landmarks',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (stats['elevators']! > 0)
              const Icon(Icons.elevator, size: 12, color: Colors.orange),
            if (stats['stairs']! > 0)
              const Icon(Icons.stairs, size: 12, color: Colors.teal),
          ],
        ),
        dense: true,
        onTap: () {
          setState(() {
            _selectedFloorId = floor.id;
          });
        },
      ),
    );
  }

  // Dialog Methods
  void _showAddBuildingDialog(RoadSystemProvider provider) {
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
                  _addBuilding(nameController.text, LatLng(lat, lng), provider);
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

  void _showAddFloorDialog(Building building, RoadSystemProvider provider) {
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
                _addFloor(building, nameController.text, level, provider);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showConnectionDetails(Building building, Floor floor, Landmark landmark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(landmark.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Building: ${building.name}'),
            Text('Floor: ${floor.name}'),
            Text('Type: ${landmark.type[0].toUpperCase()}${landmark.type.substring(1)}'),
            const SizedBox(height: 16),
            const Text('Connected Floors:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...landmark.connectedFloors.map((floorId) {
              final connectedFloor = building.floors.where((f) => f.id == floorId).firstOrNull;
              return Text('• ${connectedFloor?.name ?? 'Unknown Floor'}');
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Edit connections
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  void _showAccessibilityFix(Map<String, dynamic> issue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accessibility Issue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Issue: ${issue['description']}'),
            const SizedBox(height: 16),
            const Text('Suggested fixes:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...(_getSuggestedFixes(issue['type']) as List<String>).map((fix) => Text('• $fix')),
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

  void _showFloorAnalytics() {
    // Implementation for floor analytics
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Floor analytics would be shown here')),
    );
  }

  // Action Handlers
  void _handleMenuAction(String action) {
    switch (action) {
      case 'add_building':
        final provider = Provider.of<RoadSystemProvider>(context, listen: false);
        _showAddBuildingDialog(provider);
        break;
      case 'import_floors':
        // Implementation for import
        break;
      case 'export_floors':
        // Implementation for export
        break;
    }
  }

  void _handleBuildingAction(String action, Building building, RoadSystemProvider provider) {
    switch (action) {
      case 'select':
        setState(() {
          _selectedBuildingId = building.id;
        });
        break;
      case 'edit':
        // Implementation for editing building
        break;
      case 'add_floor':
        _showAddFloorDialog(building, provider);
        break;
      case 'clone':
        // Implementation for cloning building
        break;
      case 'delete':
        _deleteBuilding(building, provider);
        break;
    }
  }

  void _handleFloorAction(String action, Floor floor, RoadSystemProvider provider) {
    switch (action) {
      case 'view':
        final buildingProvider = Provider.of<BuildingProvider>(context, listen: false);
        buildingProvider.navigateToFloor(floor.buildingId, floor.id);
        break;
      case 'edit':
        // Implementation for editing floor
        break;
      case 'duplicate':
        // Implementation for duplicating floor
        break;
      case 'delete':
        _deleteFloor(floor, provider);
        break;
    }
  }

  // Core Operations
  void _addBuilding(String name, LatLng position, RoadSystemProvider provider) {
    final currentSystem = provider.currentSystem;
    if (currentSystem == null) return;

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
      SnackBar(content: Text('Building "$name" added successfully')),
    );
  }

  void _addFloor(Building building, String name, int level, RoadSystemProvider provider) {
    final currentSystem = provider.currentSystem;
    if (currentSystem == null) return;

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
    provider.updateCurrentSystem(updatedSystem);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Floor "$name" added to ${building.name}')),
    );
  }

  void _deleteBuilding(Building building, RoadSystemProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Building'),
        content: Text('Are you sure you want to delete "${building.name}"? This will delete all floors and their contents.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final currentSystem = provider.currentSystem;
              if (currentSystem != null) {
                final updatedBuildings = currentSystem.buildings
                    .where((b) => b.id != building.id)
                    .toList();
                
                final updatedSystem = currentSystem.copyWith(buildings: updatedBuildings);
                provider.updateCurrentSystem(updatedSystem);
                
                setState(() {
                  if (_selectedBuildingId == building.id) {
                    _selectedBuildingId = null;
                    _selectedFloorId = null;
                  }
                });
              }
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteFloor(Floor floor, RoadSystemProvider provider) {
    // Implementation for deleting floor
  }

  // Helper Methods
  String _getFloorShortName(Floor floor) {
    if (floor.level > 0) {
      return '${floor.level}F';
    } else if (floor.level == 0) {
      return 'GF';
    } else {
      return 'B${-floor.level}';
    }
  }

  Color _getFloorLevelColor(int level) {
    if (level > 0) {
      final intensity = (level / 10).clamp(0.0, 1.0);
      return Color.lerp(Colors.blue[300]!, Colors.blue[900]!, intensity)!;
    } else if (level == 0) {
      return Colors.green;
    } else {
      final intensity = ((-level) / 5).clamp(0.0, 1.0);
      return Color.lerp(Colors.orange[300]!, Colors.red[900]!, intensity)!;
    }
  }

  IconData _getIssueIcon(String type) {
    switch (type) {
      case 'no_elevator':
        return Icons.elevator;
      case 'no_accessible_entrance':
        return Icons.accessible;
      case 'isolated_floor':
        return Icons.layers_clear;
      default:
        return Icons.warning;
    }
  }

  List<String> _getSuggestedFixes(String type) {
    switch (type) {
      case 'no_elevator':
        return ['Add elevator landmarks', 'Mark existing elevators', 'Connect elevator to all floors'];
      case 'no_accessible_entrance':
        return ['Mark accessible entrances', 'Add accessibility properties to entrances'];
      case 'isolated_floor':
        return ['Add stairs or elevator access', 'Connect to vertical circulation', 'Review floor connections'];
      default:
        return ['Review building configuration'];
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}