import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/road_system_provider.dart';
import '../providers/building_provider.dart';
import '../models/models.dart';

class BottomPanel extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onToggle;

  const BottomPanel({
    super.key,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  State<BottomPanel> createState() => _BottomPanelState();
}

class _BottomPanelState extends State<BottomPanel>
    with TickerProviderStateMixin { // Changed from SingleTickerProviderStateMixin
  late AnimationController _animationController;
  late Animation<double> _animation;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _tabController = TabController(length: 4, vsync: this); // Now properly supported
  }

  @override
  void didUpdateWidget(BottomPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final height = 80 + (350 * _animation.value); // Increased height for more content
          return Container(
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Handle and header
                _buildHeader(),
                
                // Expanded content
                if (widget.isExpanded)
                  Expanded(
                    child: _buildExpandedContent(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return GestureDetector(
      onTap: widget.onToggle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  widget.isExpanded ? 'Road System Details' : 'Tap to expand',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent() {
    return Consumer2<RoadSystemProvider, BuildingProvider>(
      builder: (context, roadSystemProvider, buildingProvider, child) {
        final currentSystem = roadSystemProvider.currentSystem;
        
        if (currentSystem == null) {
          return const Center(
            child: Text('No road system selected'),
          );
        }

        return Column(
          children: [
            // Tab bar
            TabBar(
              controller: _tabController,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Roads'),
                Tab(text: 'Buildings'),
                Tab(text: 'Stats'),
              ],
            ),
            
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(currentSystem, buildingProvider),
                  _buildRoadsTab(currentSystem, buildingProvider),
                  _buildBuildingsTab(currentSystem, buildingProvider),
                  _buildStatsTab(currentSystem, buildingProvider),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOverviewTab(RoadSystem system, BuildingProvider buildingProvider) {
    final selectedBuilding = buildingProvider.getSelectedBuilding(system);
    final selectedFloor = buildingProvider.getSelectedFloor(system);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.map, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'System Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Name: ${system.name}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Center: ${system.centerPosition.latitude.toStringAsFixed(6)}, ${system.centerPosition.longitude.toStringAsFixed(6)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Current mode
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        buildingProvider.isIndoorMode ? Icons.business : Icons.landscape,
                        color: buildingProvider.isIndoorMode ? Colors.purple : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Current Mode: ${buildingProvider.isIndoorMode ? 'Indoor' : 'Outdoor'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (buildingProvider.isIndoorMode && selectedBuilding != null) ...[
                    Text('Building: ${selectedBuilding.name}'),
                    if (selectedFloor != null)
                      Text('Floor: ${buildingProvider.getFloorDisplayName(selectedFloor)}'),
                  ] else
                    const Text('Viewing outdoor roads and buildings'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Quick stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Roads',
                  '${buildingProvider.isIndoorMode ? (selectedFloor?.roads.length ?? 0) : system.outdoorRoads.length}',
                  Icons.route,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Buildings',
                  '${system.buildings.length}',
                  Icons.business,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, [VoidCallback? onTap]) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 20),
                if (onTap != null) Icon(Icons.arrow_forward_ios, size: 12, color: color),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadsTab(RoadSystem system, BuildingProvider buildingProvider) {
    List<Road> roads;
    
    if (buildingProvider.isIndoorMode) {
      final selectedFloor = buildingProvider.getSelectedFloor(system);
      roads = selectedFloor?.roads ?? [];
    } else {
      roads = system.outdoorRoads;
    }

    return Column(
      children: [
        // Header with context
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[50],
          child: Row(
            children: [
              Icon(
                buildingProvider.isIndoorMode ? Icons.business : Icons.landscape,
                color: buildingProvider.isIndoorMode ? Colors.purple : Colors.green,
              ),
              const SizedBox(width: 8),
              Text(
                '${buildingProvider.isIndoorMode ? 'Indoor' : 'Outdoor'} Roads (${roads.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        
        // Roads list
        Expanded(
          child: roads.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.route,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No ${buildingProvider.isIndoorMode ? 'indoor' : 'outdoor'} roads found',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: roads.length,
                  itemBuilder: (context, index) {
                    final road = roads[index];
                    return ListTile(
                      leading: Icon(
                        Icons.route,
                        color: buildingProvider.isIndoorMode ? Colors.purple : Colors.blue,
                      ),
                      title: Text(road.name.isNotEmpty ? road.name : 'Road ${index + 1}'),
                      subtitle: Text('${road.points.length} points'),
                      trailing: Icon(
                        Icons.info_outline,
                        color: Colors.grey[400],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBuildingsTab(RoadSystem system, BuildingProvider buildingProvider) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[50],
          child: Row(
            children: [
              const Icon(Icons.business, color: Colors.purple),
              const SizedBox(width: 8),
              Text(
                'Buildings (${system.buildings.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        
        // Buildings list
        Expanded(
          child: system.buildings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.business,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No buildings found',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: system.buildings.length,
                  itemBuilder: (context, index) {
                    final building = system.buildings[index];
                    final isSelected = buildingProvider.getSelectedBuilding(system)?.id == building.id;
                    
                    return ListTile(
                      leading: Icon(
                        Icons.business,
                        color: isSelected ? Colors.purple : Colors.grey,
                      ),
                      title: Text(
                        building.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text('${building.floors.length} floors'),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Colors.purple)
                          : const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        buildingProvider.switchToIndoorMode(building.id);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatsTab(RoadSystem system, BuildingProvider buildingProvider) {
    final totalRoads = system.outdoorRoads.length + 
        system.buildings.fold<int>(0, (sum, building) => 
            sum + building.floors.fold<int>(0, (floorSum, floor) => 
                floorSum + floor.roads.length));
    
    final totalFloors = system.buildings.fold<int>(0, (sum, building) => 
        sum + building.floors.length);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Overview stats
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'System Statistics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Roads',
                          '$totalRoads',
                          Icons.route,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Buildings',
                          '${system.buildings.length}',
                          Icons.business,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Outdoor Roads',
                          '${system.outdoorRoads.length}',
                          Icons.landscape,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Total Floors',
                          '$totalFloors',
                          Icons.layers,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (buildingProvider.isIndoorMode) ...[
            const SizedBox(height: 16),
            _buildIndoorStats(system, buildingProvider),
          ],
        ],
      ),
    );
  }

  Widget _buildIndoorStats(RoadSystem system, BuildingProvider buildingProvider) {
    final selectedBuilding = buildingProvider.getSelectedBuilding(system);
    
    if (selectedBuilding == null) {
      return const Center(child: Text('No building selected'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Floor selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.layers, color: Colors.purple),
                      const SizedBox(width: 8),
                      const Text(
                        'Floor Navigation',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => buildingProvider.switchToOutdoorMode(),
                        child: const Text('Exit Building'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: selectedBuilding.sortedFloors.length,
                      itemBuilder: (context, index) {
                        final floor = selectedBuilding.sortedFloors[index];
                        final selectedFloor = buildingProvider.getSelectedFloor(system);
                        final isSelected = floor.id == selectedFloor?.id;
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: isSelected,
                            label: Text(buildingProvider.getFloorDisplayName(floor)),
                            onSelected: (selected) {
                              if (selected) {
                                buildingProvider.selectFloor(floor.id);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}