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
    with SingleTickerProviderStateMixin {
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
    _tabController = TabController(length: 4, vsync: this); // Added one more tab
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
    return Consumer2<RoadSystemProvider, BuildingProvider>(
      builder: (context, roadSystemProvider, buildingProvider, child) {
        final currentSystem = roadSystemProvider.currentSystem;
        final selectedBuilding = buildingProvider.getSelectedBuilding(currentSystem);
        final selectedFloor = buildingProvider.getSelectedFloor(currentSystem);
        
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              
              // System info with enhanced context
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // System name
                        Text(
                          currentSystem?.name ?? 'No System Selected',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        // Context-aware subtitle
                        if (buildingProvider.isOutdoorMode)
                          Row(
                            children: [
                              const Icon(Icons.landscape, size: 16, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                'Outdoor View • ${currentSystem?.buildings.length ?? 0} buildings',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          )
                        else if (buildingProvider.isIndoorMode && selectedBuilding != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.business, size: 16, color: Colors.purple),
                                  const SizedBox(width: 4),
                                  Text(
                                    selectedBuilding.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              if (selectedFloor != null)
                                Row(
                                  children: [
                                    const Icon(Icons.layers, size: 14, color: Colors.purple),
                                    const SizedBox(width: 4),
                                    Text(
                                      buildingProvider.getFloorDisplayName(selectedFloor),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.purple,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildFloorStats(selectedFloor),
                                  ],
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  
                  // Quick action buttons
                  Row(
                    children: [
                      // Indoor/Outdoor toggle
                      IconButton(
                        icon: Icon(
                          buildingProvider.isIndoorMode ? Icons.landscape : Icons.business,
                          color: buildingProvider.isIndoorMode ? Colors.green : Colors.purple,
                        ),
                        onPressed: () => _toggleViewMode(buildingProvider, roadSystemProvider),
                        tooltip: buildingProvider.isIndoorMode ? 'Switch to Outdoor' : 'Enter Building',
                      ),
                      
                      // Expand/collapse button
                      IconButton(
                        icon: Icon(
                          widget.isExpanded 
                              ? Icons.keyboard_arrow_down 
                              : Icons.keyboard_arrow_up,
                        ),
                        onPressed: widget.onToggle,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFloorStats(Floor floor) {
    final stats = Provider.of<BuildingProvider>(context, listen: false).getFloorStatistics(floor);
    
    return Row(
      children: [
        _buildMiniStat(stats['roads']!, Icons.route, Colors.blue),
        const SizedBox(width: 4),
        _buildMiniStat(stats['landmarks']!, Icons.place, Colors.orange),
        if (stats['elevators']! > 0) ...[
          const SizedBox(width: 4),
          _buildMiniStat(stats['elevators']!, Icons.elevator, Colors.green),
        ],
      ],
    );
  }

  Widget _buildMiniStat(int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
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

        return DefaultTabController(
          length: 4,
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: [
                  Tab(
                    icon: Icon(buildingProvider.isIndoorMode ? Icons.business : Icons.landscape),
                    text: buildingProvider.isIndoorMode ? 'Current Floor' : 'Overview',
                  ),
                  const Tab(icon: Icon(Icons.route), text: 'Roads'),
                  const Tab(icon: Icon(Icons.place), text: 'Landmarks'),
                  const Tab(icon: Icon(Icons.analytics), text: 'Statistics'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildContextTab(currentSystem, buildingProvider),
                    _buildRoadsTab(currentSystem, buildingProvider),
                    _buildLandmarksTab(currentSystem, buildingProvider),
                    _buildStatisticsTab(currentSystem, buildingProvider),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContextTab(RoadSystem system, BuildingProvider buildingProvider) {
    if (buildingProvider.isOutdoorMode) {
      return _buildOutdoorOverviewTab(system, buildingProvider);
    } else {
      return _buildIndoorFloorTab(system, buildingProvider);
    }
  }

  Widget _buildOutdoorOverviewTab(RoadSystem system, BuildingProvider buildingProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System overview cards
          Row(
            children: [
              Expanded(
                child: _buildOverviewCard(
                  'Buildings',
                  system.buildings.length.toString(),
                  Icons.business,
                  Colors.purple,
                  () => _showBuildingsList(system, buildingProvider),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildOverviewCard(
                  'Outdoor Roads',
                  system.outdoorRoads.length.toString(),
                  Icons.route,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildOverviewCard(
                  'Landmarks',
                  system.outdoorLandmarks.length.toString(),
                  Icons.place,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildOverviewCard(
                  'Total Floors',
                  system.allFloors.length.toString(),
                  Icons.layers,
                  Colors.green,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Buildings list
          if (system.buildings.isNotEmpty) ...[
            const Text(
              'Buildings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...system.buildings.take(3).map((building) => Card(
              child: ListTile(
                leading: const Icon(Icons.business, color: Colors.purple),
                title: Text(building.name),
                subtitle: Text('${building.floors.length} floor(s)'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  buildingProvider.switchToIndoorMode(building.id);
                  widget.onToggle(); // Close panel
                },
              ),
            )),
            if (system.buildings.length > 3)
              TextButton(
                onPressed: () => _showBuildingsList(system, buildingProvider),
                child: Text('View all ${system.buildings.length} buildings'),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildIndoorFloorTab(RoadSystem system, BuildingProvider buildingProvider) {
    final selectedBuilding = buildingProvider.getSelectedBuilding(system);
    final selectedFloor = buildingProvider.getSelectedFloor(system);
    
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
                            backgroundColor: Colors.grey[100],
                            selectedColor: Colors.purple[100],
                            checkmarkColor: Colors.purple,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Current floor details
          if (selectedFloor != null) ...[
            Text(
              'Current Floor: ${selectedFloor.name}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            // Floor statistics
            Row(
              children: [
                Expanded(
                  child: _buildFloorStatCard(
                    'Roads',
                    selectedFloor.roads.length,
                    Icons.route,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFloorStatCard(
                    'Landmarks',
                    selectedFloor.landmarks.length,
                    Icons.place,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Vertical circulation
            if (selectedFloor.verticalCirculation.isNotEmpty) ...[
              const Text(
                'Vertical Circulation',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: selectedFloor.verticalCirculation.map((landmark) {
                  return Chip(
                    avatar: Icon(
                      landmark.type == 'elevator' ? Icons.elevator : Icons.stairs,
                      size: 16,
                      color: Colors.white,
                    ),
                    backgroundColor: landmark.type == 'elevator' ? Colors.orange : Colors.teal,
                    label: Text(
                      landmark.name,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            
            // Connected floors
            if (selectedFloor.connectedFloors.isNotEmpty) ...[
              const Text(
                'Connected Floors',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: selectedFloor.connectedFloors.map((floorId) {
                  final connectedFloor = selectedBuilding.floors
                      .where((f) => f.id == floorId)
                      .firstOrNull;
                  if (connectedFloor == null) return const SizedBox.shrink();
                  
                  return ActionChip(
                    label: Text(buildingProvider.getFloorDisplayName(connectedFloor)),
                    onPressed: () {
                      buildingProvider.selectFloor(connectedFloor.id);
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildFloorStatCard(String label, int count, IconData icon, Color color) {
    return Container(
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
    );
  }

  Widget _buildOverviewCard(String label, String value, IconData icon, Color color, [VoidCallback? onTap]) {
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
                        'No ${buildingProvider.isIndoorMode ? 'indoor' : 'outdoor'} roads',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: roads.length,
                  itemBuilder: (context, index) {
                    final road = roads[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          Icons.route,
                          color: _getRoadTypeColor(road.type),
                        ),
                        title: Text(road.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${road.type} • ${road.points.length} points • ${road.width.toStringAsFixed(1)}m wide'),
                            if (road.isOneWay)
                              const Row(
                                children: [
                                  Icon(Icons.arrow_forward, size: 12),
                                  SizedBox(width: 4),
                                  Text('One way', style: TextStyle(fontSize: 10)),
                                ],
                              ),
                          ],
                        ),
                        trailing: buildingProvider.isIndoorMode 
                            ? const Icon(Icons.business, size: 16)
                            : const Icon(Icons.landscape, size: 16),
                        onTap: () {
                          // Could center map on road
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLandmarksTab(RoadSystem system, BuildingProvider buildingProvider) {
    List<Landmark> landmarks;
    
    if (buildingProvider.isIndoorMode) {
      final selectedFloor = buildingProvider.getSelectedFloor(system);
      landmarks = selectedFloor?.landmarks ?? [];
    } else {
      landmarks = system.outdoorLandmarks;
    }

    // Group landmarks by type
    final landmarksByType = <String, List<Landmark>>{};
    for (final landmark in landmarks) {
      landmarksByType.putIfAbsent(landmark.type, () => []).add(landmark);
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
                '${buildingProvider.isIndoorMode ? 'Indoor' : 'Outdoor'} Landmarks (${landmarks.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        
        // Landmarks list
        Expanded(
          child: landmarksByType.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.place,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No ${buildingProvider.isIndoorMode ? 'indoor' : 'outdoor'} landmarks',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: landmarksByType.keys.length,
                  itemBuilder: (context, index) {
                    final type = landmarksByType.keys.elementAt(index);
                    final typeLandmarks = landmarksByType[type]!;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        leading: Icon(_getLandmarkIcon(type)),
                        title: Text(_formatLandmarkType(type)),
                        subtitle: Text('${typeLandmarks.length} item(s)'),
                        children: typeLandmarks.map((landmark) {
                          return ListTile(
                            leading: Icon(
                              Icons.place,
                              color: _getLandmarkColor(landmark.type),
                              size: 20,
                            ),
                            title: Text(landmark.name),
                            subtitle: landmark.description.isNotEmpty 
                                ? Text(landmark.description)
                                : null,
                            trailing: landmark.isVerticalCirculation
                                ? const Icon(Icons.stairs, size: 16, color: Colors.orange)
                                : null,
                            onTap: () {
                              // Could center map on landmark
                            },
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatisticsTab(RoadSystem system, BuildingProvider buildingProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Context-specific statistics
          if (buildingProvider.isIndoorMode) 
            _buildIndoorStatistics(system, buildingProvider)
          else
            _buildOutdoorStatistics(system),
          
          const SizedBox(height: 24),
          
          // Overall system statistics
          const Text(
            'System Overview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Total Buildings', system.buildings.length, Icons.business),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard('Total Floors', system.allFloors.length, Icons.layers),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Total Roads', system.allRoads.length, Icons.route),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard('Total Landmarks', system.allLandmarks.length, Icons.place),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIndoorStatistics(RoadSystem system, BuildingProvider buildingProvider) {
    final selectedBuilding = buildingProvider.getSelectedBuilding(system);
    final selectedFloor = buildingProvider.getSelectedFloor(system);
    
    if (selectedBuilding == null) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${selectedBuilding.name} Statistics',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        
        if (selectedFloor != null) ...[
          Text(
            'Current Floor: ${selectedFloor.name}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Roads', selectedFloor.roads.length, Icons.route),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard('Landmarks', selectedFloor.landmarks.length, Icons.place),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Elevators', selectedFloor.landmarks.where((l) => l.type == 'elevator').length, Icons.elevator),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard('Stairs', selectedFloor.landmarks.where((l) => l.type == 'stairs').length, Icons.stairs),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildOutdoorStatistics(RoadSystem system) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Outdoor Statistics',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: _buildStatCard('Outdoor Roads', system.outdoorRoads.length, Icons.route),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard('Outdoor Landmarks', system.outdoorLandmarks.length, Icons.place),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildStatCard('Intersections', system.outdoorIntersections.length, Icons.multiple_stop),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard('Buildings', system.buildings.length, Icons.business),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey[600], size: 24),
          const SizedBox(height: 4),
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _toggleViewMode(BuildingProvider buildingProvider, RoadSystemProvider roadSystemProvider) {
    if (buildingProvider.isIndoorMode) {
      buildingProvider.switchToOutdoorMode();
    } else {
      // Show buildings selection if available
      final system = roadSystemProvider.currentSystem;
      if (system != null && system.buildings.isNotEmpty) {
        _showBuildingsList(system, buildingProvider);
      }
    }
  }

  void _showBuildingsList(RoadSystem system, BuildingProvider buildingProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Building'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: system.buildings.length,
            itemBuilder: (context, index) {
              final building = system.buildings[index];
              final accessibility = buildingProvider.getBuildingAccessibility(building);
              
              return ListTile(
                leading: Icon(
                  Icons.business,
                  color: accessibility['hasElevator']! ? Colors.orange : Colors.grey,
                ),
                title: Text(building.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${building.floors.length} floor(s)'),
                    Row(
                      children: [
                        if (accessibility['hasElevator']!)
                          const Icon(Icons.elevator, size: 12, color: Colors.orange),
                        if (accessibility['hasAccessibleEntrance']!)
                          const Icon(Icons.accessible, size: 12, color: Colors.green),
                        if (accessibility['multiFloor']!)
                          const Icon(Icons.layers, size: 12, color: Colors.blue),
                      ],
                    ),
                  ],
                ),
                onTap: () {
                  buildingProvider.switchToIndoorMode(building.id);
                  Navigator.pop(context);
                  widget.onToggle(); // Close panel
                },
              );
            },
          ),
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

  Color _getRoadTypeColor(String type) {
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

  String _formatLandmarkType(String type) {
    return type[0].toUpperCase() + type.substring(1) + 's';
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}