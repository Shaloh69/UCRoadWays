import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import '../providers/road_system_provider.dart';
import '../providers/building_provider.dart';
import '../models/models.dart';

class FloorSwitcher extends StatefulWidget {
  final MapController mapController;
  final bool isPanelExpanded; // FIXED: Added to track panel state
  final double panelHeight; // FIXED: Added to calculate responsive position

  const FloorSwitcher({
    super.key,
    required this.mapController,
    this.isPanelExpanded = false,
    this.panelHeight = 120,
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

        // FIXED: Calculate responsive bottom position based on panel state
        final bottomPosition = widget.panelHeight + 16; // Panel height + 16px margin

        return Positioned(
          left: 16,
          bottom: bottomPosition, // FIXED: Dynamic position based on panel
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              // FIXED: Calculate max height to avoid panel overlap
              final maxHeight = MediaQuery.of(context).size.height - bottomPosition - 100;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Expanded floor list
                  if (_isExpanded) ...[
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: maxHeight * 0.6, // FIXED: Responsive max height
                        maxWidth: 280,
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
    final displayText = selectedFloor != null 
        ? _getAbbreviatedFloorName(selectedFloor.name)
        : 'Select Floor';
    
    final levelDisplay = selectedFloor != null 
        ? _getFloorLevelDisplay(selectedFloor.level)
        : '?';

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(28),
      color: Colors.purple,
      child: InkWell(
        onTap: _toggleExpanded,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Floor level indicator
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    levelDisplay,
                    style: const TextStyle(
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              
              // Floor name
              Flexible( // ENHANCED: Prevent overflow
                child: Text(
                  displayText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              
              // Expand/collapse indicator
              Icon(
                _isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                color: Colors.white,
                size: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedFloorList(
    Building building,
    Floor? selectedFloor,
    BuildingProvider buildingProvider,
  ) {
    // FIXED: Use the correct method that now exists in BuildingProvider
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
                Flexible( // ENHANCED: Prevent text overflow
                  child: Text(
                    building.name,
                    style: TextStyle(
                      color: Colors.purple[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          
          // Floor list
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: Scrollbar( // ENHANCED: Add scrollbar for better UX
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
                        color: isSelected ? Colors.purple : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis, // ENHANCED: Prevent overflow
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Level ${floor.level}',
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
                        // ENHANCED: Show accessibility indicator
                        if (accessibility['isAccessible']!)
                          Icon(Icons.accessible, size: 10, color: Colors.orange[600]),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Selection indicator
              if (isSelected)
                const Icon(Icons.check_circle, color: Colors.purple, size: 16),
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
    if (name.length <= 8) return name; // ENHANCED: Increased limit
    return '${name.substring(0, 7)}...';
  }

  Map<String, bool> _getFloorAccessibility(Floor floor) {
    final hasElevator = floor.landmarks.any((l) => l.type == 'elevator');
    final hasStairs = floor.landmarks.any((l) => l.type == 'stairs');
    final hasRamp = floor.landmarks.any((l) => l.type == 'ramp');
    final hasAccessibleEntrance = floor.landmarks.any((l) => 
        l.type == 'entrance' && l.name.toLowerCase().contains('accessible'));
    
    return {
      'hasElevator': hasElevator,
      'hasStairs': hasStairs,
      'hasRamp': hasRamp, // ENHANCED: Check for ramps too
      'isAccessible': hasElevator || hasRamp || floor.level == 0 || hasAccessibleEntrance,
    };
  }

  int _getElevatorCount(Building building) {
    final elevatorLandmarks = <String>{};
    for (final floor in building.floors) {
      for (final landmark in floor.landmarks) {
        if (landmark.type == 'elevator') {
          elevatorLandmarks.add(landmark.name); // Count unique elevators
        }
      }
    }
    return elevatorLandmarks.length;
  }

  int _getStairCount(Building building) {
    final stairLandmarks = <String>{};
    for (final floor in building.floors) {
      for (final landmark in floor.landmarks) {
        if (landmark.type == 'stairs') {
          stairLandmarks.add(landmark.name); // Count unique staircases
        }
      }
    }
    return stairLandmarks.length;
  }

  void _selectFloor(Floor floor, BuildingProvider buildingProvider) {
    // ENHANCED: Better error handling
    try {
      buildingProvider.selectFloor(floor.id);
      _toggleExpanded(); // Collapse the list
      
      // Center map on floor if it has a center position
      if (floor.centerPosition != null) {
        widget.mapController.move(floor.centerPosition!, 21.0);
      }
      
      // ENHANCED: Better user feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.layers, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Switched to ${floor.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.purple,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      // ENHANCED: Error handling
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Failed to switch floors'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
          ),
        );
      }
    }
  }
}