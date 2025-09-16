import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import '../providers/road_system_provider.dart';

class FloatingControls extends StatefulWidget {
  final MapController mapController;
  final VoidCallback onTogglePanel;

  const FloatingControls({
    super.key,
    required this.mapController,
    required this.onTogglePanel,
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

        // Bottom-right editing tools (shown when in edit mode)
        if (_isEditMode)
          Positioned(
            bottom: 100,
            right: 16,
            child: Column(
              children: [
                _buildEditingToolButton(
                  icon: Icons.road,
                  tool: EditingTool.road,
                  tooltip: 'Add Road',
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 8),
                _buildEditingToolButton(
                  icon: Icons.delete,
                  tool: EditingTool.delete,
                  tooltip: 'Delete Mode',
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
                        provider.setCurrentSystem(systemId);
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

        // Location status indicator
        Positioned(
          top: 70,
          left: 16,
          child: Consumer<LocationProvider>(
            builder: (context, provider, child) {
              return Container(
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
              );
            },
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
  }) {
    final isSelected = _currentTool == tool;
    return FloatingActionButton(
      mini: true,
      heroTag: tooltip,
      backgroundColor: isSelected ? Colors.blue : Colors.white,
      foregroundColor: isSelected ? Colors.white : Colors.black87,
      onPressed: () => _selectTool(tool),
      tooltip: tooltip,
      child: Icon(icon),
    );
  }

  void _centerOnLocation() {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    if (locationProvider.currentLatLng != null) {
      widget.mapController.move(locationProvider.currentLatLng!, 18.0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available')),
      );
    }
  }

  void _zoomIn() {
    final zoom = widget.mapController.zoom;
    widget.mapController.move(widget.mapController.center, zoom + 1);
  }

  void _zoomOut() {
    final zoom = widget.mapController.zoom;
    widget.mapController.move(widget.mapController.center, zoom - 1);
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      if (!_isEditMode) {
        _currentTool = EditingTool.none;
      }
    });
  }

  void _selectTool(EditingTool tool) {
    setState(() {
      _currentTool = _currentTool == tool ? EditingTool.none : tool;
    });
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
              'The system will be centered at your current location or the map center.',
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
                              widget.mapController.center;
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
  road,
  landmark,
  building,
  delete,
}