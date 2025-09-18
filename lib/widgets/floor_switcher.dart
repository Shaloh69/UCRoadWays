import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/building_provider.dart';
import '../providers/road_system_provider.dart';
import '../models/models.dart';

class FloorSwitcher extends StatefulWidget {
  final VoidCallback? onFloorChanged;
  final bool isCompact;

  const FloorSwitcher({
    super.key,
    this.onFloorChanged,
    this.isCompact = false,
  });

  @override
  State<FloorSwitcher> createState() => _FloorSwitcherState();
}

class _FloorSwitcherState extends State<FloorSwitcher>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<BuildingProvider, RoadSystemProvider>(
      builder: (context, buildingProvider, roadSystemProvider, child) {
        final currentSystem = roadSystemProvider.currentSystem;
        final selectedBuilding = buildingProvider.getSelectedBuilding(currentSystem);
        final selectedFloor = buildingProvider.getSelectedFloor(currentSystem);

        // Don't show if not in indoor mode
        if (!buildingProvider.isIndoorMode || selectedBuilding == null) {
          return const SizedBox.shrink();
        }

        if (widget.isCompact) {
          return _buildCompactSwitcher(selectedBuilding, selectedFloor, buildingProvider);
        } else {
          return _buildFullSwitcher(selectedBuilding, selectedFloor, buildingProvider);
        }
      },
    );
  }

  Widget _buildCompactSwitcher(Building building, Floor? selectedFloor, BuildingProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purple, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Building indicator
          Icon(Icons.business, color: Colors.purple, size: 16),
          const SizedBox(width: 4),
          
          // Floor navigation buttons
          IconButton(
            onPressed: () => _changeFloor(building, provider, true),
            icon: const Icon(Icons.keyboard_arrow_up, size: 16),
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            padding: EdgeInsets.zero,
            tooltip: 'Go Up',
          ),
          
          // Current floor display
          GestureDetector(
            onTap: () => _showFloorSelectionDialog(building, provider),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                selectedFloor != null 
                    ? _getFloorShortName(selectedFloor)
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          IconButton(
            onPressed: () => _changeFloor(building, provider, false),
            icon: const Icon(Icons.keyboard_arrow_down, size: 16),
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            padding: EdgeInsets.zero,
            tooltip: 'Go Down',
          ),
        ],
      ),
    );
  }

  Widget _buildFullSwitcher(Building building, Floor? selectedFloor, BuildingProvider provider) {
    return Container(
      width: 80,
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.purple,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.business, color: Colors.white, size: 20),
                Text(
                  building.name.length > 8 
                      ? '${building.name.substring(0, 8)}...'
                      : building.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          // Floor list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: building.sortedFloors.length,
              itemBuilder: (context, index) {
                final floor = building.sortedFloors[index];
                final isSelected = floor.id == selectedFloor?.id;
                final canAccess = provider.canAccessFloor(null, floor.id);
                
                return _buildFloorButton(floor, isSelected, canAccess, provider);
              },
            ),
          ),
          
          // Outdoor mode button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(4),
            child: OutlinedButton(
              onPressed: () {
                provider.switchToOutdoorMode();
                widget.onFloorChanged?.call();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                side: const BorderSide(color: Colors.grey),
              ),
              child: const Column(
                children: [
                  Icon(Icons.landscape, size: 16, color: Colors.grey),
                  Text(
                    'Outdoor',
                    style: TextStyle(fontSize: 8, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorButton(Floor floor, bool isSelected, bool canAccess, BuildingProvider provider) {
    final levelColor = _getFloorLevelColor(floor.level);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Material(
        color: isSelected ? Colors.purple : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: canAccess 
              ? () {
                  provider.selectFloor(floor.id);
                  widget.onFloorChanged?.call();
                }
              : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              children: [
                // Floor level indicator
                Container(
                  width: 32,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : levelColor,
                    borderRadius: BorderRadius.circular(4),
                    border: !isSelected ? Border.all(color: Colors.grey) : null,
                  ),
                  child: Center(
                    child: Text(
                      _getFloorShortName(floor),
                      style: TextStyle(
                        color: isSelected ? Colors.purple : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                
                // Floor stats
                if (isSelected) ...[
                  Text(
                    '${floor.roads.length}R',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                    ),
                  ),
                  Text(
                    '${floor.landmarks.length}L',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                    ),
                  ),
                ],
                
                // Accessibility indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (floor.landmarks.any((l) => l.type == 'elevator'))
                      Icon(
                        Icons.elevator,
                        size: 8,
                        color: isSelected ? Colors.white : Colors.orange,
                      ),
                    if (floor.landmarks.any((l) => l.type == 'stairs'))
                      Icon(
                        Icons.stairs,
                        size: 8,
                        color: isSelected ? Colors.white : Colors.teal,
                      ),
                  ],
                ),
                
                // Connection indicator
                if (!canAccess)
                  const Icon(
                    Icons.lock,
                    size: 10,
                    color: Colors.red,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _changeFloor(Building building, BuildingProvider provider, bool goUp) {
    final currentFloor = provider.getSelectedFloor(null);
    if (currentFloor == null) return;
    
    final targetLevel = goUp ? currentFloor.level + 1 : currentFloor.level - 1;
    final targetFloor = building.floors.where((f) => f.level == targetLevel).firstOrNull;
    
    if (targetFloor != null) {
      // Check if accessible via vertical circulation
      final canAccess = provider.canAccessFloor(null, targetFloor.id);
      
      if (canAccess) {
        provider.selectFloor(targetFloor.id);
        widget.onFloorChanged?.call();
        
        // Show transition animation/feedback
        _showFloorTransitionFeedback(currentFloor, targetFloor, goUp);
      } else {
        _showAccessibilityDialog(currentFloor, targetFloor, provider);
      }
    } else {
      // No floor in that direction
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No floor ${goUp ? 'above' : 'below'} current level'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showFloorSelectionDialog(Building building, BuildingProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${building.name} - Select Floor'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: building.sortedFloors.length + 1, // +1 for outdoor option
            itemBuilder: (context, index) {
              if (index == 0) {
                // Outdoor option
                return ListTile(
                  leading: const Icon(Icons.landscape, color: Colors.green),
                  title: const Text('Outdoor View'),
                  subtitle: const Text('Exit to outdoor navigation'),
                  onTap: () {
                    provider.switchToOutdoorMode();
                    widget.onFloorChanged?.call();
                    Navigator.pop(context);
                  },
                );
              }
              
              final floor = building.sortedFloors[index - 1];
              final isSelected = floor.id == provider.selectedFloorId;
              final canAccess = provider.canAccessFloor(null, floor.id);
              final stats = provider.getFloorStatistics(floor);
              
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
                title: Text(
                  provider.getFloorDisplayName(floor),
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.purple : null,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${stats['roads']} roads • ${stats['landmarks']} landmarks'),
                    Row(
                      children: [
                        if (stats['elevators']! > 0) ...[
                          const Icon(Icons.elevator, size: 12, color: Colors.orange),
                          Text('${stats['elevators']}', style: const TextStyle(fontSize: 10)),
                          const SizedBox(width: 8),
                        ],
                        if (stats['stairs']! > 0) ...[
                          const Icon(Icons.stairs, size: 12, color: Colors.teal),
                          Text('${stats['stairs']}', style: const TextStyle(fontSize: 10)),
                        ],
                      ],
                    ),
                  ],
                ),
                trailing: !canAccess 
                    ? const Icon(Icons.lock, color: Colors.red, size: 16)
                    : isSelected 
                        ? const Icon(Icons.check_circle, color: Colors.purple)
                        : null,
                selected: isSelected,
                enabled: canAccess,
                onTap: canAccess ? () {
                  provider.selectFloor(floor.id);
                  widget.onFloorChanged?.call();
                  Navigator.pop(context);
                } : () {
                  _showAccessibilityInfo(floor);
                },
              );
            },
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

  void _showFloorTransitionFeedback(Floor fromFloor, Floor toFloor, bool goUp) {
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              goUp ? Icons.arrow_upward : Icons.arrow_downward,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text('Moved to ${toFloor.name}'),
          ],
        ),
        backgroundColor: Colors.purple,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAccessibilityDialog(Floor fromFloor, Floor toFloor, BuildingProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Floor Not Accessible'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cannot access ${toFloor.name} from ${fromFloor.name}.'),
            const SizedBox(height: 16),
            const Text('Possible reasons:', style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('• No elevator or stairs connecting these floors'),
            const Text('• Vertical circulation is not mapped'),
            const Text('• Access restrictions'),
            const SizedBox(height: 16),
            const Text(
              'Try navigating through other floors or use the floor selector to see all available floors.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showFloorSelectionDialog(provider.getSelectedBuilding(null)!, provider);
            },
            child: const Text('View All Floors'),
          ),
        ],
      ),
    );
  }

  void _showAccessibilityInfo(Floor floor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${floor.name} - Access Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This floor is not directly accessible from your current location.'),
            const SizedBox(height: 16),
            Text('Vertical circulation on ${floor.name}:'),
            ...floor.verticalCirculation.map((landmark) => 
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Row(
                  children: [
                    Icon(
                      landmark.type == 'elevator' ? Icons.elevator : Icons.stairs,
                      size: 16,
                      color: landmark.type == 'elevator' ? Colors.orange : Colors.teal,
                    ),
                    const SizedBox(width: 8),
                    Text(landmark.name),
                  ],
                ),
              ),
            ),
            if (floor.verticalCirculation.isEmpty)
              const Padding(
                padding: EdgeInsets.only(left: 16, top: 4),
                child: Text('No elevators or stairs mapped on this floor'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

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
      // Upper floors - blue gradient
      final intensity = (level / 10).clamp(0.0, 1.0);
      return Color.lerp(Colors.blue[300]!, Colors.blue[900]!, intensity)!;
    } else if (level == 0) {
      // Ground floor - green
      return Colors.green;
    } else {
      // Basement floors - orange/red gradient
      final intensity = ((-level) / 5).clamp(0.0, 1.0);
      return Color.lerp(Colors.orange[300]!, Colors.red[900]!, intensity)!;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}