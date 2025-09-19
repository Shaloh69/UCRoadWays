import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  String _selectedBuildingId = '';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        title: const Text('Floor Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Vertical Access', icon: Icon(Icons.elevator)),
            Tab(text: 'Accessibility', icon: Icon(Icons.accessible)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddFloorDialog,
            tooltip: 'Add Floor',
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

          return Column(
            children: [
              // Building selector and search
              _buildHeaderControls(currentSystem),
              
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(currentSystem, buildingProvider, roadSystemProvider),
                    _buildVerticalAccessTab(currentSystem, buildingProvider),
                    _buildAccessibilityTab(currentSystem, buildingProvider),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderControls(RoadSystem system) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          // Building selector
          Row(
            children: [
              const Icon(Icons.business, color: Colors.purple),
              const SizedBox(width: 8),
              const Text(
                'Building:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedBuildingId.isEmpty ? null : _selectedBuildingId,
                  hint: const Text('Select a building'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('All Buildings'),
                    ),
                    ...system.buildings.map((building) => DropdownMenuItem<String>(
                      value: building.id,
                      child: Text(building.name),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedBuildingId = value ?? '';
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Search bar
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search floors, landmarks, or features...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(
    RoadSystem system,
    BuildingProvider buildingProvider,
    RoadSystemProvider roadSystemProvider,
  ) {
    final filteredBuildings = _getFilteredBuildings(system);
    
    if (filteredBuildings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.layers_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No Floors Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const Text('Add buildings and floors to get started'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/buildings'),
              icon: const Icon(Icons.add),
              label: const Text('Add Building'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredBuildings.length,
      itemBuilder: (context, index) {
        final building = filteredBuildings[index];
        return _buildBuildingCard(building, buildingProvider, roadSystemProvider);
      },
    );
  }

  Widget _buildBuildingCard(
    Building building,
    BuildingProvider buildingProvider,
    RoadSystemProvider roadSystemProvider,
  ) {
    final sortedFloors = building.sortedFloors;
    final buildingStats = buildingProvider.getBuildingStatistics(building);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: Icon(Icons.business, color: Colors.purple),
        title: Text(
          building.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${building.floors.length} floors • ${buildingStats['totalLandmarks']} landmarks',
        ),
        children: [
          // Building stats summary
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildStatChip('Floors', building.floors.length.toString(), Icons.layers, Colors.blue),
                _buildStatChip('Roads', buildingStats['totalRoads'].toString(), Icons.route, Colors.green),
                _buildStatChip('Landmarks', buildingStats['totalLandmarks'].toString(), Icons.place, Colors.orange),
              ],
            ),
          ),
          
          // Floor list
          ...sortedFloors.map((floor) => _buildFloorListTile(
            floor,
            building,
            buildingProvider,
            roadSystemProvider,
          )),
          
          // Add floor button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showAddFloorDialog(building),
                icon: const Icon(Icons.add),
                label: const Text('Add Floor'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloorListTile(
    Floor floor,
    Building building,
    BuildingProvider buildingProvider,
    RoadSystemProvider roadSystemProvider,
  ) {
    final floorStats = buildingProvider.getFloorStatistics(floor);
    final isSelected = buildingProvider.selectedFloorId == floor.id;
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isSelected ? Colors.purple : _getFloorLevelColor(floor.level),
        child: Text(
          _getFloorLevelDisplay(floor.level),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
      title: Text(
        floor.name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.purple : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Level ${floor.level} • ${building.name}'),
          Row(
            children: [
              Text('${floorStats['landmarks']} landmarks'),
              const SizedBox(width: 8),
              Text('${floorStats['roads']} roads'),
              if (floorStats['verticalCirculation']! > 0) ...[
                const SizedBox(width: 8),
                Icon(Icons.elevator, size: 12, color: Colors.green),
                Text('${floorStats['verticalCirculation']}'),
              ],
            ],
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
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: Icon(Icons.edit),
              title: Text('Edit'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuItem(
            value: 'manage',
            child: ListTile(
              leading: Icon(Icons.settings),
              title: Text('Manage'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete', style: TextStyle(color: Colors.red)),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      onTap: () {
        buildingProvider.navigateToFloor(building.id, floor.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selected ${floor.name} in ${building.name}'),
            backgroundColor: Colors.purple,
          ),
        );
      },
    );
  }

  Widget _buildVerticalAccessTab(RoadSystem system, BuildingProvider buildingProvider) {
    final verticalElements = <Map<String, dynamic>>[];
    
    // Collect all vertical circulation elements
    for (final building in system.buildings) {
      for (final floor in building.floors) {
        for (final landmark in floor.verticalCirculation) {
          verticalElements.add({
            'landmark': landmark,
            'floor': floor,
            'building': building,
          });
        }
      }
    }

    if (verticalElements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.elevator_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No Vertical Access Points',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const Text('Add elevators and stairs to connect floors'),
          ],
        ),
      );
    }

    // Group by building
    final groupedElements = <String, List<Map<String, dynamic>>>{};
    for (final element in verticalElements) {
      final building = element['building'] as Building;
      groupedElements.putIfAbsent(building.id, () => []).add(element);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedElements.length,
      itemBuilder: (context, index) {
        final buildingId = groupedElements.keys.elementAt(index);
        final elements = groupedElements[buildingId]!;
        final building = elements.first['building'] as Building;
        
        return Card(
          child: ExpansionTile(
            leading: Icon(Icons.business, color: Colors.purple),
            title: Text(building.name),
            subtitle: Text('${elements.length} vertical access points'),
            children: elements.map((element) {
              final landmark = element['landmark'] as Landmark;
              final floor = element['floor'] as Floor;
              final isVerticalCirculation = landmark.type == 'elevator' || landmark.type == 'stairs';
              
              return ListTile(
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
              );
            }).toList(),
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
          child: Row(
            children: [
              Icon(
                accessibilityIssues.isEmpty ? Icons.check_circle : Icons.warning,
                color: accessibilityIssues.isEmpty ? Colors.green : Colors.orange,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      accessibilityIssues.isEmpty 
                          ? 'Accessibility: Good'
                          : 'Accessibility Issues Found',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: accessibilityIssues.isEmpty ? Colors.green[800] : Colors.orange[800],
                      ),
                    ),
                    Text(
                      accessibilityIssues.isEmpty
                          ? 'All buildings have good accessibility features'
                          : '${accessibilityIssues.length} issues need attention',
                      style: TextStyle(
                        color: accessibilityIssues.isEmpty ? Colors.green[700] : Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Issues list
        Expanded(
          child: accessibilityIssues.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.accessible, size: 64, color: Colors.green),
                      SizedBox(height: 16),
                      Text(
                        'Great Accessibility!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text('All buildings have good accessibility features'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: accessibilityIssues.length,
                  itemBuilder: (context, index) {
                    final issue = accessibilityIssues[index];
                    final severity = issue['severity'] as String;
                    final building = issue['building'] as Building;
                    
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: severity == 'high' ? Colors.red : Colors.orange,
                          child: Icon(
                            severity == 'high' ? Icons.error : Icons.warning,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(issue['description']),
                        subtitle: Text('Building: ${building.name}'),
                        trailing: TextButton(
                          onPressed: () => _showAccessibilityDetails(issue),
                          child: const Text('Fix'),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<Building> _getFilteredBuildings(RoadSystem system) {
    var buildings = system.buildings;
    
    // Filter by selected building
    if (_selectedBuildingId.isNotEmpty) {
      buildings = buildings.where((b) => b.id == _selectedBuildingId).toList();
    }
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      buildings = buildings.where((building) {
        // Search in building name
        if (building.name.toLowerCase().contains(_searchQuery)) return true;
        
        // Search in floor names and landmarks
        for (final floor in building.floors) {
          if (floor.name.toLowerCase().contains(_searchQuery)) return true;
          for (final landmark in floor.landmarks) {
            if (landmark.name.toLowerCase().contains(_searchQuery) ||
                landmark.type.toLowerCase().contains(_searchQuery)) {
              return true;
            }
          }
        }
        return false;
      }).toList();
    }
    
    return buildings;
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
        buildingProvider.navigateToFloor(building.id, floor.id);
        Navigator.pop(context);
        break;
      case 'edit':
        _showEditFloorDialog(floor, building);
        break;
      case 'manage':
        _showFloorManagementDialog(floor, building);
        break;
      case 'delete':
        _showDeleteFloorDialog(floor, building, roadSystemProvider);
        break;
    }
  }

  void _showAddFloorDialog([Building? building]) {
    // Implementation for adding floor
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Floor${building != null ? ' to ${building.name}' : ''}'),
        content: const Text('Floor creation dialog implementation'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditFloorDialog(Floor floor, Building building) {
    // Implementation for editing floor
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${floor.name}'),
        content: const Text('Floor editing dialog implementation'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showFloorManagementDialog(Floor floor, Building building) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manage ${floor.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.place),
              title: const Text('Manage Landmarks'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to landmark management
              },
            ),
            ListTile(
              leading: const Icon(Icons.route),
              title: const Text('Manage Roads'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to road management
              },
            ),
            ListTile(
              leading: const Icon(Icons.elevator),
              title: const Text('Vertical Circulation'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to vertical circulation
              },
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

  void _showDeleteFloorDialog(
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
              // Delete floor implementation
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Floor "${floor.name}" deleted')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showConnectionDetails(Building building, Floor floor, Landmark landmark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${landmark.name} Connections'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${landmark.type.toUpperCase()}'),
            Text('Current Floor: ${floor.name}'),
            const SizedBox(height: 8),
            if (landmark.connectedFloors.isNotEmpty) ...[
              const Text('Connected Floors:'),
              ...landmark.connectedFloors.map((floorId) {
                final connectedFloor = building.floors
                    .where((f) => f.id == floorId)
                    .firstOrNull;
                return Text('• ${connectedFloor?.name ?? 'Unknown Floor'}');
              }),
            ] else ...[
              const Text('No floor connections configured'),
            ],
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
            child: const Text('Edit Connections'),
          ),
        ],
      ),
    );
  }

  void _showAccessibilityDetails(Map<String, dynamic> issue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accessibility Issue'),
        content: Text(issue['description']),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to fix the issue
            },
            child: const Text('Fix Now'),
          ),
        ],
      ),
    );
  }

  String _getFloorLevelDisplay(int level) {
    if (level > 0) return level.toString();
    if (level == 0) return 'G';
    return 'B${-level}';
  }

  Color _getFloorLevelColor(int level) {
    if (level > 0) return Colors.blue;
    if (level == 0) return Colors.green;
    return Colors.brown;
  }
}

// Note: IterableExtension is defined in models.dart