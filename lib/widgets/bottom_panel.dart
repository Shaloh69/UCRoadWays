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
          final height = 80 + (300 * _animation.value);
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
              
              // System info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentSystem?.name ?? 'No System Selected',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (selectedBuilding != null)
                          Text(
                            'Building: ${selectedBuilding.name}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
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
        );
      },
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
          length: 3,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Buildings'),
                  Tab(text: 'Roads'),
                  Tab(text: 'Landmarks'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildBuildingsTab(currentSystem, buildingProvider),
                    _buildRoadsTab(currentSystem),
                    _buildLandmarksTab(currentSystem, buildingProvider),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBuildingsTab(RoadSystem system, BuildingProvider buildingProvider) {
    return Column(
      children: [
        // Buildings list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: system.buildings.length,
            itemBuilder: (context, index) {
              final building = system.buildings[index];
              final isSelected = buildingProvider.selectedBuildingId == building.id;
              
              return Card(
                color: isSelected ? Colors.blue[50] : null,
                child: ExpansionTile(
                  leading: Icon(
                    Icons.business,
                    color: isSelected ? Colors.blue : null,
                  ),
                  title: Text(building.name),
                  subtitle: Text('${building.floors.length} floor(s)'),
                  onExpansionChanged: (expanded) {
                    if (expanded) {
                      buildingProvider.selectBuilding(building.id);
                    }
                  },
                  children: building.floors.map((floor) {
                    final isFloorSelected = buildingProvider.selectedFloorId == floor.id;
                    return ListTile(
                      leading: Icon(
                        Icons.layers,
                        color: isFloorSelected ? Colors.blue : Colors.grey,
                      ),
                      title: Text(floor.name),
                      subtitle: Text('Level ${floor.level}'),
                      selected: isFloorSelected,
                      onTap: () {
                        buildingProvider.selectFloor(
                          isFloorSelected ? null : floor.id,
                        );
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

  Widget _buildRoadsTab(RoadSystem system) {
    final allRoads = <Road>[
      ...system.outdoorRoads,
      for (final building in system.buildings)
        for (final floor in building.floors)
          ...floor.roads,
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allRoads.length,
      itemBuilder: (context, index) {
        final road = allRoads[index];
        final isIndoor = road.floorId.isNotEmpty;
        
        return ListTile(
          leading: Icon(
              Icons.route,
              color: isIndoor ? Colors.orange : Colors.grey[700],
            ),
          title: Text(road.name),
          subtitle: Text(
            '${road.type} • ${road.points.length} points • ${road.width.toStringAsFixed(1)}m wide',
          ),
          trailing: isIndoor 
              ? const Icon(Icons.business, size: 16)
              : const Icon(Icons.landscape, size: 16),
          onTap: () {
            // Could center map on road
          },
        );
      },
    );
  }

  Widget _buildLandmarksTab(RoadSystem system, BuildingProvider buildingProvider) {
    final allLandmarks = <Landmark>[
      ...system.outdoorLandmarks,
      for (final building in system.buildings)
        for (final floor in building.floors)
          ...floor.landmarks,
    ];

    // Group landmarks by type
    final landmarksByType = <String, List<Landmark>>{};
    for (final landmark in allLandmarks) {
      landmarksByType.putIfAbsent(landmark.type, () => []).add(landmark);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: landmarksByType.keys.length,
      itemBuilder: (context, index) {
        final type = landmarksByType.keys.elementAt(index);
        final landmarks = landmarksByType[type]!;
        
        return ExpansionTile(
          leading: Icon(_getLandmarkIcon(type)),
          title: Text(_formatLandmarkType(type)),
          subtitle: Text('${landmarks.length} item(s)'),
          children: landmarks.map((landmark) {
            final isIndoor = landmark.floorId.isNotEmpty;
            return ListTile(
              leading: Icon(
                Icons.place,
                color: isIndoor ? Colors.orange : Colors.blue,
                size: 20,
              ),
              title: Text(landmark.name),
              subtitle: landmark.description.isNotEmpty 
                  ? Text(landmark.description)
                  : null,
              trailing: isIndoor 
                  ? const Icon(Icons.business, size: 16)
                  : const Icon(Icons.landscape, size: 16),
              onTap: () {
                // Could center map on landmark
              },
            );
          }).toList(),
        );
      },
    );
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

  String _formatLandmarkType(String type) {
    return type[0].toUpperCase() + type.substring(1) + 's';
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}