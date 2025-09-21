import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/building_provider.dart';
import '../providers/road_system_provider.dart';

class BuildingManagerScreen extends StatefulWidget {
  const BuildingManagerScreen({super.key});

  @override
  State<BuildingManagerScreen> createState() => _BuildingManagerScreenState();
}

class _BuildingManagerScreenState extends State<BuildingManagerScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedBuildingFilter = '';
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
        title: const Text('Building Manager'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.business), text: 'Buildings'),
            Tab(icon: Icon(Icons.analytics), text: 'Statistics'),
            Tab(icon: Icon(Icons.map), text: 'Map View'),
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
              _buildSearchAndFilter(currentSystem),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBuildingsTab(currentSystem, buildingProvider, roadSystemProvider),
                    _buildStatisticsTab(currentSystem, buildingProvider),
                    _buildMapViewTab(currentSystem, buildingProvider),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBuildingDialog(),
        child: const Icon(Icons.add),
        tooltip: 'Add Building',
      ),
    );
  }

  Widget _buildSearchAndFilter(RoadSystem system) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search buildings...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
          const SizedBox(height: 12),
          // Filter dropdown
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedBuildingFilter.isEmpty ? null : _selectedBuildingFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Type',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem<String>(value: '', child: Text('All Buildings')),
                    DropdownMenuItem<String>(value: 'academic', child: Text('Academic')),
                    DropdownMenuItem<String>(value: 'residential', child: Text('Residential')),
                    DropdownMenuItem<String>(value: 'administrative', child: Text('Administrative')),
                    DropdownMenuItem<String>(value: 'recreational', child: Text('Recreational')),
                    DropdownMenuItem<String>(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedBuildingFilter = value ?? '';
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingsTab(RoadSystem system, BuildingProvider buildingProvider, RoadSystemProvider roadSystemProvider) {
    final filteredBuildings = _getFilteredBuildings(system);

    if (filteredBuildings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Buildings Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            Text('Add buildings or adjust your search filters'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredBuildings.length,
      itemBuilder: (context, index) {
        final building = filteredBuildings[index];
        return _buildBuildingCard(building, buildingProvider, roadSystemProvider, system);
      },
    );
  }

  Widget _buildBuildingCard(Building building, BuildingProvider buildingProvider, 
      RoadSystemProvider roadSystemProvider, RoadSystem system) {
    final isSelected = buildingProvider.selectedBuildingId == building.id;
    final buildingStats = buildingProvider.getBuildingStatistics(building);
    final accessibility = buildingProvider.getBuildingAccessibility(building);
    final validationIssues = buildingProvider.validateBuilding(building);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 2,
      color: isSelected ? Colors.purple.shade50 : null,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getBuildingTypeColor(building),
          child: Icon(
            _getBuildingTypeIcon(building),
            color: Colors.white,
          ),
        ),
        title: Text(
          building.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.purple : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${building.floors.length} floors • ${buildingStats['totalLandmarks']} landmarks'),
            if (validationIssues.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  children: [
                    Icon(Icons.warning, size: 16, color: Colors.orange),
                    Text(
                      '${validationIssues.length} issue${validationIssues.length != 1 ? 's' : ''}',
                      style: const TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleBuildingAction(action, building, buildingProvider, roadSystemProvider),
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
              value: 'floors',
              child: ListTile(
                leading: Icon(Icons.layers),
                title: Text('Manage Floors'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'statistics',
              child: ListTile(
                leading: Icon(Icons.analytics),
                title: Text('View Statistics'),
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
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Building Statistics
                Row(
                  children: [
                    Expanded(
                      child: _buildStatChip('Floors', '${buildingStats['totalFloors']}', Icons.layers),
                    ),
                    Expanded(
                      child: _buildStatChip('Landmarks', '${buildingStats['totalLandmarks']}', Icons.place),
                    ),
                    Expanded(
                      child: _buildStatChip('Roads', '${buildingStats['totalRoads']}', Icons.route),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Accessibility Information
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.accessible, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Accessibility: ${accessibility['accessibilityScore']}%',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (accessibility['hasElevator'] as bool)
                            Chip(
                              label: const Text('Elevators', style: TextStyle(fontSize: 12)),
                              backgroundColor: Colors.green[100],
                              avatar: const Icon(Icons.elevator, size: 16),
                            ),
                          if (accessibility['hasStairs'] as bool)
                            Chip(
                              label: const Text('Stairs', style: TextStyle(fontSize: 12)),
                              backgroundColor: Colors.blue[100],
                              avatar: const Icon(Icons.stairs, size: 16),
                            ),
                          if (accessibility['hasAccessibleEntrance'] as bool)
                            Chip(
                              label: const Text('Accessible', style: TextStyle(fontSize: 12)),
                              backgroundColor: Colors.orange[100],
                              avatar: const Icon(Icons.accessible, size: 16),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Validation Issues
                if (validationIssues.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning, size: 16, color: Colors.orange),
                            SizedBox(width: 4),
                            Text('Issues:', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ...validationIssues.map((issue) => Padding(
                          padding: const EdgeInsets.only(left: 20, top: 2),
                          child: Text('• $issue', style: const TextStyle(fontSize: 12)),
                        )),
                      ],
                    ),
                  ),
                ],
                
                // Action buttons
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          buildingProvider.selectBuilding(building.id);
                          buildingProvider.autoSelectFloor(building);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.my_location, size: 16),
                        label: const Text('Select Building'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showBuildingDetails(building, buildingProvider),
                        icon: const Icon(Icons.info_outline, size: 16),
                        label: const Text('Details'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: [
          Icon(icon, size: 24, color: Colors.purple),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsTab(RoadSystem system, BuildingProvider buildingProvider) {
    final systemStats = _calculateSystemStatistics(system, buildingProvider);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall System Statistics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'System Overview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildStatRow('Total Buildings', systemStats['totalBuildings']),
                  _buildStatRow('Total Floors', systemStats['totalFloors']),
                  _buildStatRow('Total Landmarks', systemStats['totalLandmarks']),
                  _buildStatRow('Average Floors per Building', systemStats['avgFloorsPerBuilding']),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Accessibility Statistics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Accessibility Analysis',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildStatRow('Buildings with Elevators', systemStats['buildingsWithElevators']),
                  _buildStatRow('Buildings with Accessible Entrances', systemStats['buildingsWithAccessibleEntrances']),
                  _buildStatRow('Average Accessibility Score', '${systemStats['avgAccessibilityScore']}%'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Building Types Distribution
          if (systemStats['buildingTypes'] != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Building Types Distribution',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...(systemStats['buildingTypes'] as Map<String, int>).entries.map(
                      (entry) => _buildStatRow(entry.key.toString().toUpperCase(), entry.value),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapViewTab(RoadSystem system, BuildingProvider buildingProvider) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Map View',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          Text('Interactive building map view coming soon'),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  List<Building> _getFilteredBuildings(RoadSystem system) {
    var buildings = system.buildings;
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      buildings = buildings.where((building) {
        return building.name.toLowerCase().contains(_searchQuery) ||
               building.floors.any((floor) => floor.name.toLowerCase().contains(_searchQuery));
      }).toList();
    }
    
    // Filter by building type
    if (_selectedBuildingFilter.isNotEmpty) {
      buildings = buildings.where((building) {
        final buildingType = building.properties['type']?.toString().toLowerCase() ?? 'other';
        return buildingType == _selectedBuildingFilter;
      }).toList();
    }
    
    return buildings;
  }

  Color _getBuildingTypeColor(Building building) {
    final type = building.properties['type']?.toString().toLowerCase() ?? 'other';
    switch (type) {
      case 'academic':
        return Colors.blue;
      case 'residential':
        return Colors.green;
      case 'administrative':
        return Colors.orange;
      case 'recreational':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getBuildingTypeIcon(Building building) {
    final type = building.properties['type']?.toString().toLowerCase() ?? 'other';
    switch (type) {
      case 'academic':
        return Icons.school;
      case 'residential':
        return Icons.home;
      case 'administrative':
        return Icons.business;
      case 'recreational':
        return Icons.sports;
      default:
        return Icons.business;
    }
  }

  Map<String, dynamic> _calculateSystemStatistics(RoadSystem system, BuildingProvider buildingProvider) {
    final buildings = system.buildings;
    var totalFloors = 0;
    var totalLandmarks = 0;
    var buildingsWithElevators = 0;
    var buildingsWithAccessibleEntrances = 0;
    var totalAccessibilityScore = 0.0;
    final buildingTypes = <String, int>{};

    for (final building in buildings) {
      totalFloors += building.floors.length;
      
      final stats = buildingProvider.getBuildingStatistics(building);
      totalLandmarks += stats['totalLandmarks'] as int;
      
      final accessibility = buildingProvider.getBuildingAccessibility(building);
      if (accessibility['hasElevator'] as bool) buildingsWithElevators++;
      if (accessibility['hasAccessibleEntrance'] as bool) buildingsWithAccessibleEntrances++;
      totalAccessibilityScore += accessibility['accessibilityScore'] as double;
      
      final type = building.properties['type']?.toString().toLowerCase() ?? 'other';
      buildingTypes[type] = (buildingTypes[type] ?? 0) + 1;
    }

    return {
      'totalBuildings': buildings.length,
      'totalFloors': totalFloors,
      'totalLandmarks': totalLandmarks,
      'avgFloorsPerBuilding': buildings.isNotEmpty ? (totalFloors / buildings.length).toStringAsFixed(1) : '0',
      'buildingsWithElevators': buildingsWithElevators,
      'buildingsWithAccessibleEntrances': buildingsWithAccessibleEntrances,
      'avgAccessibilityScore': buildings.isNotEmpty ? (totalAccessibilityScore / buildings.length).toStringAsFixed(1) : '0',
      'buildingTypes': buildingTypes,
    };
  }

  void _handleBuildingAction(String action, Building building, BuildingProvider buildingProvider, RoadSystemProvider roadSystemProvider) {
    switch (action) {
      case 'select':
        buildingProvider.selectBuilding(building.id);
        buildingProvider.autoSelectFloor(building);
        Navigator.pop(context);
        break;
      case 'edit':
        _showEditBuildingDialog(building);
        break;
      case 'floors':
        _showFloorManagementDialog(building, buildingProvider);
        break;
      case 'statistics':
        _showBuildingDetails(building, buildingProvider);
        break;
      case 'delete':
        _showDeleteBuildingDialog(building, roadSystemProvider);
        break;
    }
  }

  void _showAddBuildingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Building'),
        content: const Text('Building creation feature coming soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showEditBuildingDialog(Building building) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${building.name}'),
        content: const Text('Building editing feature coming soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFloorManagementDialog(Building building, BuildingProvider buildingProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manage Floors - ${building.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Building has ${building.floors.length} floors'),
              const SizedBox(height: 12),
              ...building.floors.map((floor) => ListTile(
                leading: CircleAvatar(
                  child: Text(floor.level.toString()),
                ),
                title: Text(floor.name),
                subtitle: Text('${floor.landmarks.length} landmarks'),
                onTap: () {
                  buildingProvider.selectBuilding(building.id);
                  buildingProvider.selectFloor(floor.id);
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              )),
            ],
          ),
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

  void _showBuildingDetails(Building building, BuildingProvider buildingProvider) {
    final stats = buildingProvider.getBuildingStatistics(building);
    final accessibility = buildingProvider.getBuildingAccessibility(building);
    final issues = buildingProvider.validateBuilding(building);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(building.name),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Floors: ${stats['totalFloors']}'),
                Text('Landmarks: ${stats['totalLandmarks']}'),
                Text('Roads: ${stats['totalRoads']}'),
                const SizedBox(height: 12),
                Text('Accessibility Score: ${accessibility['accessibilityScore']}%'),
                if (issues.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Issues:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...issues.map((issue) => Text('• $issue')),
                ],
              ],
            ),
          ),
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

  void _showDeleteBuildingDialog(Building building, RoadSystemProvider roadSystemProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${building.name}'),
        content: const Text(
          'Are you sure you want to delete this building? This action cannot be undone and will remove all floors and landmarks associated with this building.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Delete building implementation would go here
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Building "${building.name}" deleted')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}