import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import '../providers/road_system_provider.dart';
import '../widgets/map_widget.dart';

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

  @override
  Widget build(BuildContext context) {
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
              _buildControlButton(
                icon: _isEditMode ? Icons.edit_off : Icons.edit,
                onPressed: _toggleEditMode,
                tooltip: _isEditMode ? 'Exit Edit Mode' : 'Enter Edit Mode',
                backgroundColor: _isEditMode ? Colors.orange : null,
              ),
            ],
          ),
        ),

        // Bottom-right editing tools (enhanced)
        if (_isEditMode)
          Positioned(
            bottom: 100,
            right: 16,
            child: Column(
              children: [
                // ENHANCED: Road Recording Toggle
                _buildEditingToolButton(
                  icon: _isRoadRecording() ? Icons.stop_circle : Icons.directions_walk,
                  tool: EditingTool.roadRecord,
                  tooltip: _isRoadRecording() ? 'Stop Recording' : 'Start Walking Record',
                  backgroundColor: _isRoadRecording() ? Colors.red : null,
                ),
                const SizedBox(height: 8),
                
                // NEW: Intersection Tool
                _buildEditingToolButton(
                  icon: Icons.multiple_stop,
                  tool: EditingTool.intersection,
                  tooltip: 'Add Intersection',
                ),
                const SizedBox(height: 8),
                
                // NEW: Road Connection Tool
                _buildEditingToolButton(
                  icon: Icons.call_merge,
                  tool: EditingTool.connect,
                  tooltip: 'Connect Roads',
                ),
                const SizedBox(height: 8),
                
                // Existing tools
                _buildEditingToolButton(
                  icon: Icons.place,
                  tool: EditingTool.landmark,
                  tooltip: 'Add Landmark',
                ),
                const SizedBox(height: 8),
                _buildEditingToolButton(
                  icon: Icons.business,
                  tool: EditingTool.building,
                  tooltip: 'Add Building',
                ),
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

        // Top-left system selector
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
                child: DropdownButtonHideUnderline(
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
              );
            },
          ),
        ),

        // Enhanced status indicators
        Positioned(
          top: 70,
          left: 16,
          child: Consumer<LocationProvider>(
            builder: (context, provider, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getLocationStatusColor(provider),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getLocationStatusIcon(provider),
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getLocationStatusText(provider),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // ENHANCED: Recording status
                  if (_isRoadRecording()) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fiber_manual_record, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Recording',
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
                  
                  // NEW: Connection mode status
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
              );
            },
          ),
        ),

        // ENHANCED: Quick action panel for active modes
        if (_currentTool != EditingTool.none && _isEditMode)
          Positioned(
            bottom: 180,
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
                    _getToolInstructions(_currentTool),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  if (_currentTool == EditingTool.roadRecord && _isRoadRecording())
                    ElevatedButton.icon(
                      onPressed: _forceStopRecording,
                      icon: const Icon(Icons.stop, size: 16),
                      label: const Text('Stop', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(80, 32),
                      ),
                    )
                  else if (_currentTool == EditingTool.connect)
                    Column(
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
                    ),
                ],
              ),
            ),
          ),
      ],
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
  }) {
    final isSelected = _currentTool == tool;
    return FloatingActionButton(
      mini: true,
      heroTag: tooltip,
      backgroundColor: backgroundColor ?? (isSelected ? Colors.blue : Colors.white),
      foregroundColor: (backgroundColor != null || isSelected) ? Colors.white : Colors.black87,
      onPressed: () => _selectTool(tool),
      tooltip: tooltip,
      child: Icon(icon),
    );
  }

  void _centerOnLocation() {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    if (locationProvider.currentLatLng != null) {
      widget.mapController.move(locationProvider.currentLatLng!, 20.0); // Closer zoom
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
        // Stop any active operations
        _stopAllActiveOperations();
      }
    });
  }

  void _selectTool(EditingTool tool) {
    setState(() {
      // If same tool is selected, toggle it off
      if (_currentTool == tool) {
        _currentTool = EditingTool.none;
        _stopAllActiveOperations();
        return;
      }
      
      // Stop previous operation
      _stopAllActiveOperations();
      
      // Set new tool
      _currentTool = tool;
    });

    // Start appropriate operation
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
      case EditingTool.none:
        break;
    }
  }

  // ENHANCED: Road recording methods
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚶 Recording started! Walk to create your road path.'),
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

  // NEW: Intersection methods
  void _startIntersectionMode() {
    widget.mapWidgetKey?.currentState?.startAddingIntersection();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔄 Tap on map to add intersection points'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  // NEW: Road connection methods
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
    // Implementation to clear selected roads
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📍 Long-press on map to add landmarks'),
        duration: Duration(seconds: 2),
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

  void _stopAllActiveOperations() {
    // Stop all active operations when changing tools
    widget.mapWidgetKey?.currentState?.stopRoadConnectionMode();
    // Add other stop methods as needed
  }

  String _getToolInstructions(EditingTool tool) {
    switch (tool) {
      case EditingTool.roadRecord:
        return _isRoadRecording() 
            ? 'Recording your path\nWalk to add points'
            : 'Tap to start recording\nyour walking path';
      case EditingTool.intersection:
        return 'Tap map to add\nintersection points';
      case EditingTool.connect:
        return 'Tap roads to select\nthem for connection';
      case EditingTool.landmark:
        return 'Long-press map\nto add landmarks';
      case EditingTool.building:
        return 'Long-press map\nto add buildings';
      case EditingTool.none:
        return '';
    }
  }

  // Helper methods to check current states
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
  roadRecord,    // NEW: Walking road recording
  intersection,  // NEW: Intersection points
  connect,       // NEW: Road connection
  landmark,
  building,
}