import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import '../providers/road_system_provider.dart';
import '../providers/building_provider.dart';
import '../models/models.dart';

class FloorSwitcher extends StatefulWidget {
  final MapController mapController;

  const FloorSwitcher({
    super.key,
    required this.mapController,
  });

  @override
  State<FloorSwitcher> createState() => _FloorSwitcherState();
}

class _FloorSwitcherState extends State<FloorSwitcher>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
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
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    
    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<RoadSystemProvider, BuildingProvider>(
      builder: (context, roadSystemProvider, buildingProvider, child) {
        final currentSystem = roadSystemProvider.currentSystem;
        final selectedBuilding = buildingProvider.getSelectedBuilding(currentSystem);
        final selectedFloor = buildingProvider.getSelectedFloor(currentSystem);
        
        // Only show if in indoor mode and building is selected
        if (!buildingProvider.isIndoorMode || selectedBuilding == null) {
          return const SizedBox.shrink();
        }

        return Positioned(
          left: 16,
          bottom: 180,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Expanded floor list
                  if (_isExpanded) ...[
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: _buildExpandedFloorList(selectedBuilding, selectedFloor, buildingProvider),
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  // Current floor button
                  _buildCurrentFloorButton(selectedBuilding, selectedFloor, buildingProvider),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCurrentFloorButton(
    Building building,
    Floor? selectedFloor,
    BuildingProvider buildingProvider,
  ) {
    return GestureDetector(
      onTap: building.floors.length > 1 ? _toggleExpanded : null,
      child: Container(
        width: 60,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.purple,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Floor level indicator
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Text(
                  _getFloorLevelDisplay(selectedFloor?.level ?? 0),
                  style: const TextStyle(
                    color: Colors.purple,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            
            // Floor name (abbreviated)
            Text(
              _getAbbreviatedFloorName(selectedFloor?.name ?? 'Floor'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            // Expansion indicator
            if (building.floors.length > 1) ...[
              const SizedBox(height: 2),
              Icon(
                _isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                color: Colors.white,
                size: 12,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedFloorList(
    Building building,
    Floor? selectedFloor,
    BuildingProvider buildingProvider,
  ) {
    final sortedFloors = buildingProvider.getSortedFloorsForBuilding(building);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.business, color: Colors.purple[700], size: 16),
                const SizedBox(width: 6),
                Text(
                  building.name,
                  style: TextStyle(
                    color: Colors.purple[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Floor list
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: Column(
                children: sortedFloors.map((floor) {
                  final isSelected = selectedFloor?.id == floor.id;
                  final accessibility = _getFloorAccessibility(floor);
                  
                  return _buildFloorListItem(
                    floor,
                    isSelected,
                    accessibility,
                    buildingProvider,
                  );
                }).toList(),
              ),
            ),
          ),
          
          // Footer with building stats
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBuildingStat(Icons.layers, '${building.floors.length}'),
                const SizedBox(width: 12),
                _buildBuildingStat(Icons.elevator, _getElevatorCount(building).toString()),
                const SizedBox(width: 12),
                _buildBuildingStat(Icons.stairs, _getStairCount(building).toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorListItem(
    Floor floor,
    bool isSelected,
    Map<String, bool> accessibility,
    BuildingProvider buildingProvider,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectFloor(floor, buildingProvider),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.purple[100] : null,
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Floor level circle
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.purple : Colors.grey[300],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    _getFloorLevelDisplay(floor.level),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              
              // Floor info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      floor.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isSelected ? Colors.purple[700] : Colors.black,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${floor.landmarks.length} landmarks',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (accessibility['hasElevator']!)
                          Icon(Icons.elevator, size: 10, color: Colors.green[600]),
                        if (accessibility['hasStairs']!)
                          Icon(Icons.stairs, size: 10, color: Colors.blue[600]),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Selection indicator
              if (isSelected)
                Icon(Icons.check_circle, color: Colors.purple, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBuildingStat(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey[600]),
        const SizedBox(width: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  String _getFloorLevelDisplay(int level) {
    if (level > 0) return level.toString();
    if (level == 0) return 'G';
    return 'B${-level}';
  }

  String _getAbbreviatedFloorName(String name) {
    if (name.length <= 6) return name;
    return '${name.substring(0, 5)}...';
  }

  Map<String, bool> _getFloorAccessibility(Floor floor) {
    final hasElevator = floor.landmarks.any((l) => l.type == 'elevator');
    final hasStairs = floor.landmarks.any((l) => l.type == 'stairs');
    
    return {
      'hasElevator': hasElevator,
      'hasStairs': hasStairs,
      'isAccessible': hasElevator || floor.level == 0,
    };
  }

  int _getElevatorCount(Building building) {
    return building.floors
        .expand((f) => f.landmarks)
        .where((l) => l.type == 'elevator')
        .length;
  }

  int _getStairCount(Building building) {
    return building.floors
        .expand((f) => f.landmarks)
        .where((l) => l.type == 'stairs')
        .length;
  }

  void _selectFloor(Floor floor, BuildingProvider buildingProvider) {
    buildingProvider.selectFloor(floor.id);
    _toggleExpanded(); // Collapse the list
    
    // Center map on floor if it has a center position
    if (floor.centerPosition != null) {
      widget.mapController.move(floor.centerPosition!, 21.0);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.layers, color: Colors.white),
            const SizedBox(width: 8),
            Text('Switched to ${floor.name}'),
          ],
        ),
        backgroundColor: Colors.purple,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}