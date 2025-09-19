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
    with TickerProviderStateMixin { // Changed from SingleTickerProviderStateMixin
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
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
                  provider.selectFloor(floor.id); // Fixed: use floor.id instead of floor
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
                  ),
                  child: Center(
                    child: Text(
                      _getFloorLevelText(floor.level),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.purple : Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                // Floor name
                Text(
                  floor.name.length > 8 
                      ? '${floor.name.substring(0, 8)}...'
                      : floor.name,
                  style: TextStyle(
                    fontSize: 8,
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullSwitcher(Building building, Floor? selectedFloor, BuildingProvider provider) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.business, color: Colors.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    building.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    provider.switchToOutdoorMode();
                    widget.onFloorChanged?.call();
                  },
                  child: const Text('Exit Building'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Floor grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1.2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: building.sortedFloors.length,
              itemBuilder: (context, index) {
                final floor = building.sortedFloors[index];
                final isSelected = floor.id == selectedFloor?.id;
                final canAccess = provider.canAccessFloor(null, floor.id);
                
                return _buildFullFloorCard(floor, isSelected, canAccess, provider);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullFloorCard(Floor floor, bool isSelected, bool canAccess, BuildingProvider provider) {
    final levelColor = _getFloorLevelColor(floor.level);
    
    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Colors.purple : Colors.white,
      child: InkWell(
        onTap: canAccess 
            ? () {
                provider.selectFloor(floor.id); // Fixed: use floor.id instead of floor
                widget.onFloorChanged?.call();
              }
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Floor level
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : levelColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getFloorLevelText(floor.level),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.purple : Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Floor name
              Text(
                floor.name,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // Stats
              if (floor.roads.isNotEmpty || floor.landmarks.isNotEmpty)
                Text(
                  '${floor.roads.length}r ${floor.landmarks.length}l',
                  style: TextStyle(
                    fontSize: 8,
                    color: isSelected ? Colors.white70 : Colors.grey[600],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getFloorLevelColor(int level) {
    if (level > 0) {
      return Colors.blue; // Above ground
    } else if (level == 0) {
      return Colors.green; // Ground floor
    } else {
      return Colors.orange; // Below ground
    }
  }

  String _getFloorLevelText(int level) {
    if (level > 0) {
      return '${level}F';
    } else if (level == 0) {
      return 'GF';
    } else {
      return 'B${-level}';
    }
  }

  IconData _getFloorIcon(int level) {
    if (level > 0) {
      return Icons.keyboard_arrow_up;
    } else if (level == 0) {
      return Icons.home;
    } else {
      return Icons.keyboard_arrow_down;
    }
  }
}