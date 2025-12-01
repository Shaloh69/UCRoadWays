import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../providers/road_system_provider.dart';
import '../providers/location_provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/sample_network_generator.dart';

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
            icon: const Icon(Icons.add_road),
            onPressed: () => _showCreateSystemDialog(),
            tooltip: 'Create New System',
          ),
          IconButton(
            icon: const Icon(Icons.science),
            onPressed: () => _showSampleNetworksDialog(),
            tooltip: 'Generate Sample Network',
          ),
        ],
      ),
      body: Consumer<RoadSystemProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading road systems...',
                    style: TextStyle(
                      color: AppTheme.neutralGray600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.errorRed),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppTheme.errorRed,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error Loading Systems',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.errorRed,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.error!,
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => provider.loadRoadSystems(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorRed,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (provider.roadSystems.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppTheme.primaryGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.map_outlined,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No Road Systems',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first road system or generate a sample network',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.neutralGray600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _showCreateSystemDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Create Road System'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _showSampleNetworksDialog(),
                          icon: const Icon(Icons.science),
                          label: const Text('Generate Sample'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.roadSystems.length,
            itemBuilder: (context, index) {
              final system = provider.roadSystems[index];
              final isActive = system.id == provider.currentSystem?.id;

              return _buildSystemCard(system, isActive, provider);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSystemDialog(),
        icon: const Icon(Icons.add),
        label: const Text('New System'),
      ),
    );
  }

  Widget _buildSystemCard(RoadSystem system, bool isActive, RoadSystemProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: isActive ? null : () => provider.setCurrentSystem(system.id),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isActive
                ? LinearGradient(
                    colors: [
                      AppTheme.primaryBlue.withOpacity(0.1),
                      AppTheme.secondaryPurple.withOpacity(0.05),
                    ],
                  )
                : null,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppTheme.primaryGradient,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.map,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                system.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: AppTheme.primaryGradient,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: AppTheme.neutralGray500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${system.centerPosition.latitude.toStringAsFixed(4)}, '
                              '${system.centerPosition.longitude.toStringAsFixed(4)}',
                              style: TextStyle(
                                color: AppTheme.neutralGray600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (action) => _handleSystemAction(action, system),
                    icon: Icon(Icons.more_vert, color: AppTheme.neutralGray600),
                    itemBuilder: (context) => [
                      if (!isActive)
                        const PopupMenuItem(
                          value: 'activate',
                          child: ListTile(
                            leading: Icon(Icons.check_circle),
                            title: Text('Activate'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('Edit'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: ListTile(
                          leading: Icon(Icons.copy),
                          title: Text('Duplicate'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: Colors.red),
                          title: Text('Delete'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildStatChip(
                    'Buildings',
                    system.buildings.length.toString(),
                    Icons.business,
                    AppTheme.secondaryPurple,
                  ),
                  _buildStatChip(
                    'Roads',
                    system.outdoorRoads.length.toString(),
                    Icons.route,
                    AppTheme.successGreen,
                  ),
                  _buildStatChip(
                    'POIs',
                    system.outdoorLandmarks.length.toString(),
                    Icons.place,
                    AppTheme.accentTeal,
                  ),
                  _buildStatChip(
                    'Nodes',
                    system.outdoorIntersections.length.toString(),
                    Icons.circle,
                    AppTheme.warningAmber,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
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
        ],
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
      latController.text =
          locationProvider.currentLatLng!.latitude.toStringAsFixed(6);
      lngController.text =
          locationProvider.currentLatLng!.longitude.toStringAsFixed(6);
    } else {
      // Default to UC Riverside
      latController.text = '33.9737';
      lngController.text = '-117.3281';
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: AppTheme.primaryGradient),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_road, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Create Road System',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'System Name',
                  hintText: 'e.g., UC Riverside Campus',
                  prefixIcon: Icon(Icons.title),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text(
                'Center Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: lngController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      if (locationProvider.currentLatLng != null) {
                        latController.text =
                            locationProvider.currentLatLng!.latitude
                                .toStringAsFixed(6);
                        lngController.text =
                            locationProvider.currentLatLng!.longitude
                                .toStringAsFixed(6);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Current location not available'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.my_location, size: 18),
                    label: const Text('Current Location'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      latController.text = '33.9737';
                      lngController.text = '-117.3281';
                    },
                    icon: const Icon(Icons.school, size: 18),
                    label: const Text('UC Riverside'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (nameController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a system name'),
                          ),
                        );
                        return;
                      }

                      final lat = double.tryParse(latController.text);
                      final lng = double.tryParse(lngController.text);

                      if (lat == null || lng == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invalid coordinates'),
                          ),
                        );
                        return;
                      }

                      final center = LatLng(lat, lng);
                      try {
                        await Provider.of<RoadSystemProvider>(context,
                                listen: false)
                            .createRoadSystem(nameController.text, center);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Road system "${nameController.text}" created successfully',
                            ),
                            backgroundColor: AppTheme.successGreen,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: AppTheme.errorRed,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSampleNetworksDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: AppTheme.primaryGradient),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.science, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Generate Sample Network',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSampleNetworkOption(
                'UC Riverside Campus',
                '4×4 grid with 16 intersections, connected roads, buildings, and POIs',
                Icons.school,
                AppTheme.primaryBlue,
                () => _generateSampleNetwork('campus'),
              ),
              const SizedBox(height: 12),
              _buildSampleNetworkOption(
                'Simple Test Network',
                '3 intersections in a line - perfect for testing pathfinding',
                Icons.timeline,
                AppTheme.accentTeal,
                () => _generateSampleNetwork('simple'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSampleNetworkOption(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.neutralGray600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  void _generateSampleNetwork(String type) async {
    Navigator.pop(context); // Close dialog

    final generator = SampleNetworkGenerator();
    RoadSystem sampleSystem;

    if (type == 'campus') {
      sampleSystem = generator.generateUCRiversideCampus();
    } else {
      sampleSystem = generator.generateSimpleTestNetwork();
    }

    try {
      final provider = Provider.of<RoadSystemProvider>(context, listen: false);
      await provider.importRoadSystem(sampleSystem.toJson());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sample network "${sampleSystem.name}" generated!'),
            backgroundColor: AppTheme.successGreen,
            action: SnackBarAction(
              label: 'ACTIVATE',
              textColor: Colors.white,
              onPressed: () => provider.setCurrentSystem(sampleSystem.id),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating sample: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _handleSystemAction(String action, RoadSystem system) async {
    final provider = Provider.of<RoadSystemProvider>(context, listen: false);

    switch (action) {
      case 'activate':
        await provider.setCurrentSystem(system.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${system.name} activated'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
        break;

      case 'edit':
        _showEditSystemDialog(system);
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
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Road System',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'System Name',
                  prefixIcon: Icon(Icons.title),
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
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: lngController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (nameController.text.isNotEmpty) {
                        final lat = double.tryParse(latController.text);
                        final lng = double.tryParse(lngController.text);

                        if (lat != null && lng != null) {
                          final updatedSystem = system.copyWith(
                            name: nameController.text,
                            centerPosition: LatLng(lat, lng),
                          );
                          Provider.of<RoadSystemProvider>(context,
                                  listen: false)
                              .updateCurrentSystem(updatedSystem);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('System updated'),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final provider = Provider.of<RoadSystemProvider>(context, listen: false);
        await provider.duplicateRoadSystem(system.id, result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('System duplicated as "$result"'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error duplicating: $e'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
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
          ElevatedButton(
            onPressed: () {
              Provider.of<RoadSystemProvider>(context, listen: false)
                  .deleteRoadSystem(system.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${system.name} deleted'),
                  backgroundColor: AppTheme.successGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
