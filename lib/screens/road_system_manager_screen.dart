import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../providers/road_system_provider.dart';
import '../providers/location_provider.dart';
import '../models/models.dart';

class RoadSystemManagerScreen extends StatefulWidget {
  const RoadSystemManagerScreen({super.key});

  @override
  State<RoadSystemManagerScreen> createState() => _RoadSystemManagerScreenState();
}

class _RoadSystemManagerScreenState extends State<RoadSystemManagerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Road Systems'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateSystemDialog(),
            tooltip: 'Create New System',
          ),
        ],
      ),
      body: Consumer<RoadSystemProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${provider.error}',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadRoadSystems(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.roadSystems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Road Systems',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create your first road system to get started',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateSystemDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Road System'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.roadSystems.length,
            itemBuilder: (context, index) {
              final system = provider.roadSystems[index];
              final isActive = system.id == provider.currentSystem?.id;

              return Card(
                elevation: isActive ? 4 : 1,
                margin: const EdgeInsets.only(bottom: 16),
                color: isActive ? Colors.blue[50] : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  system.name,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isActive ? Colors.blue[700] : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Center: ${system.centerPosition.latitude.toStringAsFixed(4)}, '
                                  '${system.centerPosition.longitude.toStringAsFixed(4)}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          PopupMenuButton<String>(
                            onSelected: (action) => _handleSystemAction(action, system),
                            itemBuilder: (context) => [
                              if (!isActive)
                                const PopupMenuItem(
                                  value: 'activate',
                                  child: ListTile(
                                    leading: Icon(Icons.check_circle),
                                    title: Text('Activate'),
                                  ),
                                ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(Icons.edit),
                                  title: Text('Edit'),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'export',
                                child: ListTile(
                                  leading: Icon(Icons.file_upload),
                                  title: Text('Export'),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'duplicate',
                                child: ListTile(
                                  leading: Icon(Icons.copy),
                                  title: Text('Duplicate'),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  leading: Icon(Icons.delete, color: Colors.red),
                                  title: Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildStatCard(
                            'Buildings',
                            system.buildings.length.toString(),
                            Icons.business,
                            Colors.purple,
                          ),
                          const SizedBox(width: 12),
                          _buildStatCard(
                            'Roads',
                            system.outdoorRoads.length.toString(),
                            Icons.route,
                            Colors.green,
                          ),
                          const SizedBox(width: 12),
                          _buildStatCard(
                            'Landmarks',
                            system.outdoorLandmarks.length.toString(),
                            Icons.place,
                            Colors.orange,
                          ),
                        ],
                      ),
                      if (!isActive) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => provider.setCurrentSystem(system.id),
                            child: const Text('Activate System'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateSystemDialog(),
        tooltip: 'Create New System',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
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
              style: TextStyle(
                fontSize: 10,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateSystemDialog() {
    final nameController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    
    // Pre-fill with current location if available
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    if (locationProvider.currentLatLng != null) {
      latController.text = locationProvider.currentLatLng!.latitude.toStringAsFixed(6);
      lngController.text = locationProvider.currentLatLng!.longitude.toStringAsFixed(6);
    } else {
      // Default to UC Riverside
      latController.text = '33.9737';
      lngController.text = '-117.3281';
    }

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
                hintText: 'Enter a name for your road system',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: latController,
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: lngController,
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    if (locationProvider.currentLatLng != null) {
                      latController.text = locationProvider.currentLatLng!.latitude.toStringAsFixed(6);
                      lngController.text = locationProvider.currentLatLng!.longitude.toStringAsFixed(6);
                    }
                  },
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text('Use Current'),
                ),
                TextButton.icon(
                  onPressed: () {
                    latController.text = '33.9737';
                    lngController.text = '-117.3281';
                  },
                  icon: const Icon(Icons.school, size: 16),
                  label: const Text('UC Riverside'),
                ),
              ],
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
                final lat = double.tryParse(latController.text);
                final lng = double.tryParse(lngController.text);
                
                if (lat != null && lng != null) {
                  final center = LatLng(lat, lng);
                  Provider.of<RoadSystemProvider>(context, listen: false)
                      .createRoadSystem (nameController.text, center);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid coordinates')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _handleSystemAction(String action, RoadSystem system) async {
    final provider = Provider.of<RoadSystemProvider>(context, listen: false);
    
    switch (action) {
      case 'activate':
        await provider.setCurrentSystem(system.id);
        break;
        
      case 'edit':
        _showEditSystemDialog(system);
        break;
        
      case 'export':
        await _exportSystem(system);
        break;
        
      case 'duplicate':
        await _duplicateSystem(system);
        break;
        
      case 'delete':
        _showDeleteConfirmation(system);
        break;
    }
  }

  void _showEditSystemDialog(RoadSystem system) {
    final nameController = TextEditingController(text: system.name);
    final latController = TextEditingController(
      text: system.centerPosition.latitude.toStringAsFixed(6),
    );
    final lngController = TextEditingController(
      text: system.centerPosition.longitude.toStringAsFixed(6),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Road System'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'System Name',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: latController,
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: lngController,
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
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
                final lat = double.tryParse(latController.text);
                final lng = double.tryParse(lngController.text);
                
                if (lat != null && lng != null) {
                  final updatedSystem = system.copyWith(
                    name: nameController.text,
                    centerPosition: LatLng(lat, lng),
                  );
                  Provider.of<RoadSystemProvider>(context, listen: false)
                      .updateCurrentSystem(updatedSystem);
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportSystem(RoadSystem system) async {
    // Implementation would use DataStorageService.exportRoadSystemToJson
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exporting ${system.name}...')),
    );
  }

  Future<void> _duplicateSystem(RoadSystem system) async {
    final nameController = TextEditingController(text: '${system.name} (Copy)');
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate System'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'New System Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      // Create a copy of the system with new ID and name
      // This would be implemented in the provider
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Duplicated as "$result"')),
      );
    }
  }

  void _showDeleteConfirmation(RoadSystem system) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Road System'),
        content: Text(
          'Are you sure you want to delete "${system.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<RoadSystemProvider>(context, listen: false)
                  .deleteRoadSystem(system.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}