import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import '../providers/road_system_provider.dart';
import '../providers/building_provider.dart';
import '../widgets/map_widget.dart';
import '../widgets/floor_switcher.dart';

class FloatingControls extends StatefulWidget {
  final MapController mapController;
  final VoidCallback onTogglePanel;
  final GlobalKey<UCRoadWaysMapState>? mapWidgetKey;

  const FloatingControls({
    super.key,
    required this.mapController,
    required this.onTogglePanel,
    this.mapWidgetKey,
  });

  @override
  State<FloatingControls> createState() => _FloatingControlsState();
}

class _FloatingControlsState extends State<FloatingControls> {
  bool _isEditMode = false;
  EditingTool _currentTool = EditingTool.none;
  bool _showFloorSwitcher = true;

  @override
  Widget build(BuildContext context) {
    return Consumer3<LocationProvider, RoadSystemProvider, BuildingProvider>(
      builder: (context, locationProvider, roadSystemProvider, buildingProvider, child) {
        return Stack(
          children: [
            // Top-right controls
            Positioned(
              top: 16,
              right: 16,
              child: Column(
                children: [
                  _buildControlButton(
                    icon: Icons.my_location,
                    onPressed: _centerOnLocation,
                    tooltip: 'Center on Location',
                  ),
                  const SizedBox(height: 8),
                  _buildControlButton(
                    icon: Icons.zoom_in,
                    onPressed: _zoomIn,
                    tooltip: 'Zoom In',
                  ),
                  const SizedBox(height: 8),
                  _buildControlButton(
                    icon: Icons.zoom_out,
                    onPressed: _zoomOut,
                    tooltip: 'Zoom Out',
                  ),
                  const SizedBox(height: 8),
                  
                  // NEW: Indoor/Outdoor mode toggle
                  _buildControlButton(
                    icon: buildingProvider.isIndoorMode ? Icons.business : Icons.landscape,
                    onPressed: () => _toggleIndoorOutdoorMode(buildingProvider, roadSystemProvider),
                    tooltip: buildingProvider.isIndoorMode ? 'Switch to Outdoor' : 'Enter Building',
                    backgroundColor: buildingProvider.isIndoorMode ? Colors.purple : Colors.green,
                  ),
                  const SizedBox(height: 8),
                  
                  _buildControlButton(
                    icon: _isEditMode ? Icons.edit_off : Icons.edit,
                    onPressed: _toggleEditMode,
                    tooltip: _isEditMode ? 'Exit Edit Mode' : 'Enter Edit Mode',
                    backgroundColor: _isEditMode ? Colors.orange : null,
                  ),
                ],
              ),
            ),

            // NEW: Floor switcher (left side, visible in indoor mode)
            if (buildingProvider.isIndoorMode && _showFloorSwitcher)
              Positioned(
                top: 100,
                left: 16,
                child: FloorSwitcher(
                  onFloorChanged: _onFloorChanged,
                  isCompact: false,
                ),
              ),

            // Bottom-right editing tools (ENHANCED for floor context)
            if (_isEditMode)
              Positioned(
                bottom: 100,
                right: 16,
                child: Column(
                  children: [
                    // Context indicator
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: buildingProvider.isIndoorMode ? Colors.purple[50] : Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: buildingProvider.isIndoorMode ? Colors.purple : Colors.blue,
                        ),
                      ),
                      child: Text(
                        'Editing: ${buildingProvider.getCurrentContextDescription(roadSystemProvider.currentSystem)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: buildingProvider.isIndoorMode ? Colors.purple : Colors.blue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Road Recording Toggle - ENHANCED
                    _buildEditingToolButton(
                      icon: _isRoadRecording() ? Icons.stop_circle : Icons.directions_walk,
                      tool: EditingTool.roadRecord,
                      tooltip: _isRoadRecording() ? 'Stop Recording' : 'Start Walking Record',
                      backgroundColor: _isRoadRecording() ? Colors.red : null,
                      badge: buildingProvider.isIndoorMode ? 'IN' : 'OUT',
                    ),
                    const SizedBox(height: 8),
                    
                    // Intersection Tool
                    _buildEditingToolButton(
                      icon: Icons.multiple_stop,
                      tool: EditingTool.intersection,
                      tooltip: 'Add Intersection',
                    ),
                    const SizedBox(height: 8),
                    
                    // Road Connection Tool
                    _buildEditingToolButton(
                      icon: Icons.call_merge,
                      tool: EditingTool.connect,
                      tooltip: 'Connect Roads',
                    ),
                    const SizedBox(height: 8),
                    
                    // Landmark Tool - ENHANCED with floor context
                    _buildEditingToolButton(
                      icon: Icons.place,
                      tool: EditingTool.landmark,
                      tooltip: buildingProvider.isIndoorMode 
                          ? 'Add Indoor Landmark' 
                          : 'Add Outdoor Landmark',
                      badge: buildingProvider.isIndoorMode ? '🏢' : '🌍',
                    ),
                    const SizedBox(height: 8),
                    
                    // Building Tool (only in outdoor mode)
                    if (buildingProvider.isOutdoorMode)
                      _buildEditingToolButton(
                        icon: Icons.business,
                        tool: EditingTool.building,
                        tooltip: 'Add Building',
                      ),
                    
                    // NEW: Floor-specific tools (only in indoor mode)
                    if (buildingProvider.isIndoorMode) ...[
                      const SizedBox(height: 8),
                      _buildEditingToolButton(
                        icon: Icons.elevator,
                        tool: EditingTool.verticalCirculation,
                        tooltip: 'Add Elevator/Stairs',
                      ),
                      const SizedBox(height: 8),
                      _buildEditingToolButton(
                        icon: Icons.door_front_door,
                        tool: EditingTool.roomEntrance,
                        tooltip: 'Add Room/Entrance',
                      ),
                    ],
                  ],
                ),
              ),

            // Bottom-left panel toggle
            Positioned(
              bottom: 16,
              left: 16,
              child: _buildControlButton(
                icon: Icons.layers,
                onPressed: widget.onTogglePanel,
                tooltip: 'Toggle Panel',
              ),
            ),

            // Top-left system selector - ENHANCED
            Positioned(
              top: 16,
              left: 16,
              child: Consumer<RoadSystemProvider>(
                builder: (context, provider, child) {
                  if (provider.roadSystems.isEmpty) {
                    return _buildControlButton(
                      icon: Icons.add,
                      onPressed: () => _showNewSystemDialog(context),
                      tooltip: 'Create Road System',
                    );
                  }

                  return Container(
                    constraints: const BoxConstraints(maxWidth: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // System selector
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: provider.currentSystem?.id,
                            hint: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('Select System'),
                            ),
                            onChanged: (systemId) {
                              if (systemId != null) {
                                if (systemId == 'new') {
                                  _showNewSystemDialog(context);
                                } else {
                                  provider.setCurrentSystem(systemId);
                                  // Reset to outdoor mode when switching systems
                                  buildingProvider.switchToOutdoorMode();
                                }
                              }
                            },
                            items: [
                              ...provider.roadSystems.map((system) {
                                return DropdownMenuItem(
                                  value: system.id,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      system.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                );
                              }),
                              const DropdownMenuItem(
                                value: 'new',
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Row(
                                    children: [
                                      Icon(Icons.add, size: 16),
                                      SizedBox(width: 4),
                                      Text('New System'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // NEW: Quick building access (if in indoor mode)
                        if (buildingProvider.isIndoorMode && provider.currentSystem != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: const BoxDecoration(
                              color: Colors.purple,
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(8),
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                            child: Text(
                              buildingProvider.getCurrentContextDescription(provider.currentSystem),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Enhanced status indicators
            Positioned(
              top: 70,
              left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getLocationStatusColor(locationProvider),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getLocationStatusIcon(locationProvider),
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getLocationStatusText(locationProvider),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Recording status
                  if (_isRoadRecording()) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fiber_manual_record, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Recording ${buildingProvider.isIndoorMode ? 'Indoor' : 'Outdoor'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // Connection mode status
                  if (_isConnectingRoads()) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.call_merge, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Connecting',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ENHANCED: Quick action panel for active modes
            if (_currentTool != EditingTool.none && _isEditMode)
              Positioned(
                bottom: 280,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getToolInstructions(_currentTool, buildingProvider),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      _buildToolActionButtons(),
                    ],
                  ),
                ),
              ),

            // NEW: Compact floor switcher for edit mode
            if (buildingProvider.isIndoorMode && _isEditMode && !_showFloorSwitcher)
              Positioned(
                bottom: 16,
                left: 80,
                child: FloorSwitcher(
                  onFloorChanged: _onFloorChanged,
                  isCompact: true,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    Color? backgroundColor,
  }) {
    return FloatingActionButton(
      mini: true,
      heroTag: tooltip,
      backgroundColor: backgroundColor ?? Colors.white,
      foregroundColor: backgroundColor != null ? Colors.white : Colors.black87,
      onPressed: onPressed,
      tooltip: tooltip,
      child: Icon(icon),
    );
  }

  Widget _buildEditingToolButton({
    required IconData icon,
    required EditingTool tool,
    required String tooltip,
    Color? backgroundColor,
    String? badge,
  }) {
    final isSelected = _currentTool == tool;
    return Stack(
      children: [
        FloatingActionButton(
          mini: true,
          heroTag: tooltip,
          backgroundColor: backgroundColor ?? (isSelected ? Colors.blue : Colors.white),
          foregroundColor: (backgroundColor != null || isSelected) ? Colors.white : Colors.black87,
          onPressed: () => _selectTool(tool),
          tooltip: tooltip,
          child: Icon(icon),
        ),
        if (badge != null)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildToolActionButtons() {
    switch (_currentTool) {
      case EditingTool.roadRecord:
        if (_isRoadRecording()) {
          return ElevatedButton.icon(
            onPressed: _forceStopRecording,
            icon: const Icon(Icons.stop, size: 16),
            label: const Text('Stop', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 32),
            ),
          );
        }
        break;
      case EditingTool.connect:
        return Column(
          children: [
            ElevatedButton.icon(
              onPressed: _clearRoadSelection,
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(80, 32),
              ),
            ),
            const SizedBox(height: 4),
            ElevatedButton.icon(
              onPressed: _stopConnectingRoads,
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Exit', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                minimumSize: const Size(80, 32),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
    return const SizedBox.shrink();
  }

  void _toggleIndoorOutdoorMode(BuildingProvider buildingProvider, RoadSystemProvider roadSystemProvider) {
    if (buildingProvider.isIndoorMode) {
      // Switch to outdoor
      buildingProvider.switchToOutdoorMode();
      widget.mapController.move(
        roadSystemProvider.currentSystem?.centerPosition ?? widget.mapController.camera.center,
        16.0,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🌍 Switched to outdoor view'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      // Show building selection
      _showBuildingSelectionDialog(roadSystemProvider, buildingProvider);
    }
  }

  void _showBuildingSelectionDialog(RoadSystemProvider roadSystemProvider, BuildingProvider buildingProvider) {
    final currentSystem = roadSystemProvider.currentSystem;
    if (currentSystem == null || currentSystem.buildings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No buildings available in current system'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Building'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: currentSystem.buildings.length,
            itemBuilder: (context, index) {
              final building = currentSystem.buildings[index];
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
                  widget.mapController.move(building.centerPosition, 21.0);
                  Navigator.pop(context);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🏢 Entered ${building.name}'),
                      backgroundColor: Colors.purple,
                    ),
                  );
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

  void _onFloorChanged() {
    // Update map zoom and position when floor changes
    final buildingProvider = Provider.of<BuildingProvider>(context, listen: false);
    final roadSystemProvider = Provider.of<RoadSystemProvider>(context, listen: false);
    
    if (buildingProvider.isIndoorMode) {
      final building = buildingProvider.getSelectedBuilding(roadSystemProvider.currentSystem);
      if (building != null) {
        widget.mapController.move(building.centerPosition, 21.0);
      }
    }
  }

  // Standard control methods
  void _centerOnLocation() {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    if (locationProvider.currentLatLng != null) {
      widget.mapController.move(locationProvider.currentLatLng!, 20.0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available')),
      );
    }
  }

  void _zoomIn() {
    final zoom = widget.mapController.camera.zoom;
    widget.mapController.move(widget.mapController.camera.center, zoom + 1);
  }

  void _zoomOut() {
    final zoom = widget.mapController.camera.zoom;
    widget.mapController.move(widget.mapController.camera.center, zoom - 1);
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      if (!_isEditMode) {
        _currentTool = EditingTool.none;
        _stopAllActiveOperations();
      }
      // Toggle floor switcher visibility in edit mode
      _showFloorSwitcher = !_isEditMode;
    });
  }

  void _selectTool(EditingTool tool) {
    setState(() {
      if (_currentTool == tool) {
        _currentTool = EditingTool.none;
        _stopAllActiveOperations();
        return;
      }
      
      _stopAllActiveOperations();
      _currentTool = tool;
    });

    switch (tool) {
      case EditingTool.roadRecord:
        _toggleRoadRecording();
        break;
      case EditingTool.intersection:
        _startIntersectionMode();
        break;
      case EditingTool.connect:
        _startRoadConnectionMode();
        break;
      case EditingTool.landmark:
        _showLandmarkInstructions();
        break;
      case EditingTool.building:
        _showBuildingInstructions();
        break;
      case EditingTool.verticalCirculation:
        _showVerticalCirculationInstructions();
        break;
      case EditingTool.roomEntrance:
        _showRoomEntranceInstructions();
        break;
      case EditingTool.none:
        break;
    }
  }

  // Tool-specific methods
  void _toggleRoadRecording() {
    if (_isRoadRecording()) {
      _stopRoadRecording();
    } else {
      _startRoadRecording();
    }
  }

  void _startRoadRecording() {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    if (locationProvider.currentLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available. Enable GPS and try again.')),
      );
      return;
    }

    widget.mapWidgetKey?.currentState?.startRoadRecording();
    final buildingProvider = Provider.of<BuildingProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🚶 Recording ${buildingProvider.isIndoorMode ? 'indoor' : 'outdoor'} road! Walk to create your path.'
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _stopRoadRecording() {
    widget.mapWidgetKey?.currentState?.stopRoadConnectionMode();
  }

  void _forceStopRecording() {
    setState(() {
      _currentTool = EditingTool.none;
    });
    _stopRoadRecording();
  }

  void _startIntersectionMode() {
    widget.mapWidgetKey?.currentState?.startAddingIntersection();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔄 Tap on map to add intersection points'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _startRoadConnectionMode() {
    widget.mapWidgetKey?.currentState?.startRoadConnectionMode();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔗 Tap roads to select them for connection'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _clearRoadSelection() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Road selection cleared')),
    );
  }

  void _stopConnectingRoads() {
    widget.mapWidgetKey?.currentState?.stopRoadConnectionMode();
    setState(() {
      _currentTool = EditingTool.none;
    });
  }

  void _showLandmarkInstructions() {
    final buildingProvider = Provider.of<BuildingProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '📍 Long-press on map to add ${buildingProvider.isIndoorMode ? 'indoor' : 'outdoor'} landmarks'
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showBuildingInstructions() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🏢 Long-press on map to add buildings'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showVerticalCirculationInstructions() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🏗️ Long-press on map to add elevators or stairs'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showRoomEntranceInstructions() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚪 Long-press on map to add room entrances'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _stopAllActiveOperations() {
    widget.mapWidgetKey?.currentState?.stopRoadConnectionMode();
  }

  String _getToolInstructions(EditingTool tool, BuildingProvider buildingProvider) {
    final context = buildingProvider.isIndoorMode ? 'indoor' : 'outdoor';
    
    switch (tool) {
      case EditingTool.roadRecord:
        return _isRoadRecording() 
            ? 'Recording $context path\nWalk to add points'
            : 'Tap to start recording\nyour walking path';
      case EditingTool.intersection:
        return 'Tap map to add\nintersection points';
      case EditingTool.connect:
        return 'Tap roads to select\nthem for connection';
      case EditingTool.landmark:
        return 'Long-press map to add\n$context landmarks';
      case EditingTool.building:
        return 'Long-press map\nto add buildings';
      case EditingTool.verticalCirculation:
        return 'Long-press to add\nelevators or stairs';
      case EditingTool.roomEntrance:
        return 'Long-press to add\nroom entrances';
      case EditingTool.none:
        return '';
    }
  }

  // Helper methods
  bool _isRoadRecording() {
    return widget.mapWidgetKey?.currentState?.isRecordingRoad ?? false;
  }

  bool _isConnectingRoads() {
    return widget.mapWidgetKey?.currentState?.isConnectingRoads ?? false;
  }

  void _showNewSystemDialog(BuildContext context) {
    final nameController = TextEditingController();
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Road System'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'System Name',
                hintText: 'Enter road system name',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'The system will be centered at your current location.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                final center = locationProvider.currentLatLng ?? 
                              widget.mapController.camera.center;
                Provider.of<RoadSystemProvider>(context, listen: false)
                    .createNewRoadSystem(nameController.text, center);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Color _getLocationStatusColor(LocationProvider provider) {
    if (provider.error != null) return Colors.red;
    if (provider.isTracking) return Colors.green;
    return Colors.orange;
  }

  IconData _getLocationStatusIcon(LocationProvider provider) {
    if (provider.error != null) return Icons.location_off;
    if (provider.isTracking) return Icons.location_on;
    return Icons.location_searching;
  }

  String _getLocationStatusText(LocationProvider provider) {
    if (provider.error != null) return 'Error';
    if (provider.isTracking) return 'Tracking';
    return 'Searching';
  }
}

enum EditingTool {
  none,
  roadRecord,
  intersection,
  connect,
  landmark,
  building,
  verticalCirculation,  // NEW: For elevators/stairs
  roomEntrance,         // NEW: For room/entrance markers
}