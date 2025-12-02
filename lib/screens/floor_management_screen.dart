import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../providers/building_provider.dart';
import '../providers/road_system_provider.dart';

class FloorManagementScreen extends StatefulWidget {
  const FloorManagementScreen({super.key});

  @override
  State<FloorManagementScreen> createState() => _FloorManagementScreenState();
}

class _FloorManagementScreenState extends State<FloorManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedBuildingId = '';
  String _searchQuery = '';
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTab = _tabController.index;
      });
    });
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
            Tab(icon: Icon(Icons.layers), text: 'Overview'),
            Tab(icon: Icon(Icons.elevator), text: 'Vertical Access'),
            Tab(icon: Icon(Icons.accessible), text: 'Accessibility'),
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
                    'No Road System Available',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text('Please load or create a road system first'),
                ],
              ),
            );
          }

          return Column(
            children: [
              _buildFilterSection(currentSystem),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddFloorDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterSection(RoadSystem system) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Building filter
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedBuildingId.isEmpty ? null : _selectedBuildingId,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Building',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('All Buildings'),
                    ),
                    ...system.buildings.map((building) {
                      return DropdownMenuItem<String>(
                        value: building.id,
                        child: Text(building.name),
                      );
                    }),
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
      itemCount: filteredBuildings.fold<int>(0, (sum, building) => sum + building.floors.length),
      itemBuilder: (context, index) {
        int currentIndex = 0;
        
        for (final building in filteredBuildings) {
          if (index < currentIndex + building.floors.length) {
            final floorIndex = index - currentIndex;
            final floor = building.floors[floorIndex];
            return _buildFloorCard(floor, building, buildingProvider, roadSystemProvider, system);
          }
          currentIndex += building.floors.length;
        }
        
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildFloorCard(
    Floor floor,
    Building building,
    BuildingProvider buildingProvider,
    RoadSystemProvider roadSystemProvider,
    RoadSystem system,
  ) {
    final isSelected = buildingProvider.selectedFloorId == floor.id &&
                     buildingProvider.selectedBuildingId == building.id;
    
    // Calculate floor statistics
    final floorStats = {
      'landmarks': floor.landmarks.length,
      'roads': floor.roads.length,
      'verticalCirculation': floor.landmarks.where((l) => l.isVerticalCirculation).length,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Colors.purple.shade50 : null,
      child: _buildFloorListTile(floor, building, buildingProvider, roadSystemProvider, system, floorStats, isSelected),
    );
  }

  Widget _buildFloorListTile(
    Floor floor,
    Building building,
    BuildingProvider buildingProvider,
    RoadSystemProvider roadSystemProvider,
    RoadSystem system,
    Map<String, int> floorStats,
    bool isSelected,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getFloorLevelColor(floor.level),
        child: Text(
          _getFloorLevelDisplay(floor.level),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                const Icon(Icons.elevator, size: 12, color: Colors.green),
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
          system,
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
        // First select the building, then navigate to the floor
        buildingProvider.selectBuilding(building.id);
        final success = buildingProvider.navigateToFloor(floor.id, system);
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Selected ${floor.name} in ${building.name}'),
              backgroundColor: Colors.purple,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to navigate to ${floor.name}'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
            leading: const Icon(Icons.business, color: Colors.purple),
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
                  ),
                ),
                title: Text(landmark.name),
                subtitle: Text('${floor.name} (Level ${floor.level})'),
                trailing: IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => _showConnectionDetails(building, floor, landmark),
                ),
                onTap: () {
                  // Navigate to the floor with this landmark
                  buildingProvider.selectBuilding(building.id);
                  buildingProvider.navigateToFloor(floor.id, system);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildAccessibilityTab(RoadSystem system, BuildingProvider buildingProvider) {
    // Collect accessibility issues and features
    final accessibilityIssues = <Map<String, dynamic>>[];
    
    for (final building in system.buildings) {
      final issues = buildingProvider.validateBuilding(building);
      for (final issue in issues) {
        accessibilityIssues.add({
          'type': 'issue',
          'severity': issue.contains('lacks') ? 'high' : 'medium',
          'description': issue,
          'building': building,
        });
      }
    }

    return Column(
      children: [
        // Summary card
        Container(
          margin: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Accessibility Overview',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('${accessibilityIssues.length} issues found'),
                  if (accessibilityIssues.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: 1.0 - (accessibilityIssues.length / (system.buildings.length * 5)),
                      backgroundColor: Colors.red.shade100,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        
        // Issues list
        Expanded(
          child: accessibilityIssues.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 64, color: Colors.green),
                      SizedBox(height: 16),
                      Text(
                        'No Accessibility Issues',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      Text('All buildings meet accessibility standards'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: accessibilityIssues.length,
                  itemBuilder: (context, index) {
                    final issue = accessibilityIssues[index];
                    final building = issue['building'] as Building;
                    final severity = issue['severity'] as String;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
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
    RoadSystem system,
  ) {
    switch (action) {
      case 'select':
        // First select the building, then navigate to the floor
        buildingProvider.selectBuilding(building.id);
        buildingProvider.navigateToFloor(floor.id, system);
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
    final roadSystemProvider = Provider.of<RoadSystemProvider>(context, listen: false);

    if (roadSystemProvider.currentSystem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No road system selected')),
      );
      return;
    }

    // Get all buildings if no specific building is provided
    final buildings = roadSystemProvider.currentSystem!.buildings;

    if (buildings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No buildings available. Create a building first.')),
      );
      return;
    }

    Building? selectedBuilding = building ?? (buildings.isNotEmpty ? buildings.first : null);
    final nameController = TextEditingController();
    final levelController = TextEditingController(text: '0');
    String? errorText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.layers, color: Colors.blue),
              SizedBox(width: 8),
              Text('Add Floor'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create a new floor in a building',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // Building selection
                if (building == null) ...[
                  DropdownButtonFormField<Building>(
                    value: selectedBuilding,
                    decoration: const InputDecoration(
                      labelText: 'Building *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                    items: buildings.map((b) => DropdownMenuItem(
                      value: b,
                      child: Text(b.name),
                    )).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedBuilding = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Floor name
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Floor Name *',
                    hintText: 'e.g., First Floor, Basement',
                    errorText: errorText,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.label),
                  ),
                  onChanged: (value) {
                    if (errorText != null) {
                      setState(() => errorText = null);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Floor level
                TextField(
                  controller: levelController,
                  decoration: const InputDecoration(
                    labelText: 'Floor Level *',
                    hintText: '0 = Ground, >0 = Upper, <0 = Basement',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.layers),
                    helperText: 'e.g., -2, -1, 0, 1, 2, 3',
                  ),
                  keyboardType: TextInputType.numberWithOptions(signed: true),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Level 0 = Ground Floor\nPositive = Upper floors\nNegative = Basements',
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
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final levelText = levelController.text.trim();

                // Validation
                if (name.isEmpty) {
                  setState(() => errorText = 'Floor name is required');
                  return;
                }

                if (name.length < 2) {
                  setState(() => errorText = 'Name must be at least 2 characters');
                  return;
                }

                if (selectedBuilding == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a building')),
                  );
                  return;
                }

                final level = int.tryParse(levelText);
                if (level == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid floor level. Must be a number.')),
                  );
                  return;
                }

                // Check for duplicate level in the same building
                final isDuplicateLevel = selectedBuilding!.floors
                    .any((f) => f.level == level);

                if (isDuplicateLevel) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Floor level $level already exists in this building')),
                  );
                  return;
                }

                // Create new floor
                final newFloor = Floor(
                  id: const Uuid().v4(),
                  name: name,
                  level: level,
                  buildingId: selectedBuilding!.id,
                  roads: [],
                  landmarks: [],
                  connectedFloors: [],
                  centerPosition: selectedBuilding!.centerPosition,
                  properties: {
                    'created': DateTime.now().toIso8601String(),
                  },
                );

                Navigator.pop(context);

                // Add floor using provider method
                try {
                  await roadSystemProvider.addFloorToBuilding(
                    roadSystemProvider.currentSystem!.id,
                    selectedBuilding!.id,
                    newFloor,
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Floor "$name" added successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to add floor: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Add Floor'),
            ),
          ],
        ),
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