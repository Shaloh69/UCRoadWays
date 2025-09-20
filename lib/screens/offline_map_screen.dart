import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/offline_map_provider.dart';
import '../providers/location_provider.dart';
import '../services/offline_tile_service.dart';
import 'dart:math';

class OfflineMapScreen extends StatefulWidget {
  const OfflineMapScreen({super.key});

  @override
  State<OfflineMapScreen> createState() => _OfflineMapScreenState();
}

class _OfflineMapScreenState extends State<OfflineMapScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final MapController _mapController = MapController();
  
  // Download region selection
  LatLng? _selectionStart;
  LatLng? _selectionEnd;
  bool _isSelectingRegion = false;
  double _selectedRadius = 2.0; // FIXED: Added missing _selectedRadius variable
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeOfflineProvider();
    });
  }

  void _initializeOfflineProvider() async {
    final offlineProvider = Provider.of<OfflineMapProvider>(context, listen: false);
    await offlineProvider.initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Maps'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.download), text: 'Download'),
            Tab(icon: Icon(Icons.folder), text: 'My Maps'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDownloadTab(),
          _buildMyMapsTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  Widget _buildDownloadTab() {
    return Consumer2<OfflineMapProvider, LocationProvider>(
      builder: (context, offlineProvider, locationProvider, child) {
        return Column(
          children: [
            // Quick download section
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Download',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text('Download maps around your current location'),
                    const SizedBox(height: 16),
                    
                    // Radius selection
                    Row(
                      children: [
                        const Text('Radius: '),
                        Expanded(
                          child: Slider(
                            value: _selectedRadius,
                            min: 0.5,
                            max: 5.0,
                            divisions: 9,
                            label: '${_selectedRadius.toStringAsFixed(1)} km',
                            onChanged: (value) {
                              setState(() {
                                _selectedRadius = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    // Estimated size
                    FutureBuilder<int>(
                      future: _calculateEstimatedSize(locationProvider.currentLatLng),
                      builder: (context, snapshot) {
                        final size = snapshot.data ?? 0;
                        return Text(
                          'Estimated size: ${offlineProvider.formatBytes(size)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        );
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: locationProvider.currentLatLng != null && !offlineProvider.isDownloading
                                ? () => _downloadCurrentArea(offlineProvider, locationProvider.currentLatLng!)
                                : null,
                            icon: const Icon(Icons.download),
                            label: const Text('Download Current Area'),
                          ),
                        ),
                      ],
                    ),
                    
                    // Download progress
                    if (offlineProvider.isDownloading) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(value: offlineProvider.downloadProgress),
                      const SizedBox(height: 8),
                      Text(
                        offlineProvider.downloadProgressText,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Custom region selection
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Custom Region',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text('Select a custom area to download'),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isSelectingRegion = !_isSelectingRegion;
                                if (!_isSelectingRegion) {
                                  _selectionStart = null;
                                  _selectionEnd = null;
                                }
                              });
                            },
                            icon: Icon(_isSelectingRegion ? Icons.cancel : Icons.crop_free),
                            label: Text(_isSelectingRegion ? 'Cancel Selection' : 'Select Region'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _selectionStart != null && _selectionEnd != null && !offlineProvider.isDownloading
                                ? () => _downloadSelectedRegion(offlineProvider)
                                : null,
                            icon: const Icon(Icons.download),
                            label: const Text('Download Selected'),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Selection map preview
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildSelectionMap(locationProvider),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMyMapsTab() {
    return Consumer<OfflineMapProvider>(
      builder: (context, offlineProvider, child) {
        if (offlineProvider.isLoadingRegions) {
          return const Center(child: CircularProgressIndicator());
        }

        if (offlineProvider.downloadedRegions.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No offline maps downloaded',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Use the Download tab to get started',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: offlineProvider.downloadedRegions.length,
          itemBuilder: (context, index) {
            final region = offlineProvider.downloadedRegions[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.map, color: Colors.blue),
                title: Text(region.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${region.tileCount} tiles • ${region.formattedSize}'),
                    Text(
                      'Downloaded: ${_formatDate(region.downloadedAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDeleteRegion(region.name, offlineProvider),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingsTab() {
    return Consumer<OfflineMapProvider>(
      builder: (context, offlineProvider, child) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Storage info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Storage',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<int>(
                      // FIXED: Get storage size through the service instead of provider
                      future: _getTotalStorageSize(),
                      builder: (context, snapshot) {
                        final size = snapshot.data ?? 0;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total size: ${offlineProvider.formatBytes(size)}'),
                            Text('Regions: ${offlineProvider.downloadedRegions.length}'),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            // Preferences
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Preferences',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Prefer Offline Maps'),
                      subtitle: const Text('Use offline maps when available'),
                      value: offlineProvider.preferOffline,
                      onChanged: offlineProvider.setPreferOffline,
                    ),
                  ],
                ),
              ),
            ),
            
            // Maintenance
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Maintenance',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      title: const Text('Clear Old Tiles'),
                      subtitle: const Text('Remove tiles older than 30 days'),
                      trailing: const Icon(Icons.cleaning_services),
                      onTap: () => _clearOldTiles(offlineProvider),
                    ),
                    ListTile(
                      title: const Text('Refresh Regions'),
                      subtitle: const Text('Reload the regions list'),
                      trailing: const Icon(Icons.refresh),
                      onTap: offlineProvider.loadDownloadedRegions,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSelectionMap(LocationProvider locationProvider) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: locationProvider.currentLatLng ?? const LatLng(33.9737, -117.3281),
        initialZoom: 15.0,
        onTap: _isSelectingRegion ? (tapPosition, point) {
          setState(() {
            if (_selectionStart == null) {
              _selectionStart = point;
            } else if (_selectionEnd == null) {
              _selectionEnd = point;
            } else {
              // Reset selection
              _selectionStart = point;
              _selectionEnd = null;
            }
          });
        } : null,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.ucr.roadways',
        ),
        
        // Selection overlay
        if (_selectionStart != null) ...[
          MarkerLayer(
            markers: [
              Marker(
                point: _selectionStart!,
                child: const Icon(Icons.location_on, color: Colors.red, size: 30),
              ),
              if (_selectionEnd != null)
                Marker(
                  point: _selectionEnd!,
                  child: const Icon(Icons.location_on, color: Colors.red, size: 30),
                ),
            ],
          ),
          
          // Selection rectangle
          if (_selectionEnd != null)
            PolygonLayer(
              polygons: [
                Polygon(
                  points: _getSelectionPolygon(),
                  color: Colors.blue.withOpacity(0.3),
                  borderColor: Colors.blue,
                  borderStrokeWidth: 2,
                ),
              ],
            ),
        ],
      ],
    );
  }

  List<LatLng> _getSelectionPolygon() {
    if (_selectionStart == null || _selectionEnd == null) return [];

    final north = _selectionStart!.latitude > _selectionEnd!.latitude 
        ? _selectionStart!.latitude : _selectionEnd!.latitude;
    final south = _selectionStart!.latitude < _selectionEnd!.latitude 
        ? _selectionStart!.latitude : _selectionEnd!.latitude;
    final east = _selectionStart!.longitude > _selectionEnd!.longitude 
        ? _selectionStart!.longitude : _selectionEnd!.longitude;
    final west = _selectionStart!.longitude < _selectionEnd!.longitude 
        ? _selectionStart!.longitude : _selectionEnd!.longitude;

    return [
      LatLng(north, west),
      LatLng(north, east),
      LatLng(south, east),
      LatLng(south, west),
    ];
  }

  Future<int> _calculateEstimatedSize(LatLng? center) async {
    if (center == null) return 0;

    const double earthRadius = 6371; // km
    final double latRadiusDegrees = (_selectedRadius / earthRadius) * (180 / pi);
    final double lngRadiusDegrees = latRadiusDegrees / cos(center.latitude * pi / 180);

    final northEast = LatLng(
      center.latitude + latRadiusDegrees,
      center.longitude + lngRadiusDegrees,
    );
    final southWest = LatLng(
      center.latitude - latRadiusDegrees,
      center.longitude - lngRadiusDegrees,
    );

    final offlineProvider = Provider.of<OfflineMapProvider>(context, listen: false);
    // FIXED: Use positional arguments instead of named parameters
    return offlineProvider.estimateDownloadSize(
      northEast,
      southWest,
      10,
      18,
    );
  }

  void _downloadCurrentArea(OfflineMapProvider offlineProvider, LatLng center) async {
    final regionName = 'Area_${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      await offlineProvider.downloadCurrentView(
        center: center,
        zoom: _mapController.camera.zoom,
        regionName: regionName,
        radiusKm: _selectedRadius,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded $regionName successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _downloadSelectedRegion(OfflineMapProvider offlineProvider) async {
    if (_selectionStart == null || _selectionEnd == null) return;

    final regionName = 'Custom_${DateTime.now().millisecondsSinceEpoch}';
    
    // Calculate bounds
    final north = _selectionStart!.latitude > _selectionEnd!.latitude 
        ? _selectionStart!.latitude : _selectionEnd!.latitude;
    final south = _selectionStart!.latitude < _selectionEnd!.latitude 
        ? _selectionStart!.latitude : _selectionEnd!.latitude;
    final east = _selectionStart!.longitude > _selectionEnd!.longitude 
        ? _selectionStart!.longitude : _selectionEnd!.longitude;
    final west = _selectionStart!.longitude < _selectionEnd!.longitude 
        ? _selectionStart!.longitude : _selectionEnd!.longitude;

    final northEast = LatLng(north, east);
    final southWest = LatLng(south, west);

    try {
      await offlineProvider.downloadRegion(
        northEast: northEast,
        southWest: southWest,
        regionName: regionName,
        minZoom: 10,
        maxZoom: 18,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded $regionName successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reset selection
        setState(() {
          _selectionStart = null;
          _selectionEnd = null;
          _isSelectingRegion = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmDeleteRegion(String regionName, OfflineMapProvider offlineProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Region'),
        content: Text('Are you sure you want to delete "$regionName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await offlineProvider.deleteRegion(regionName);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Deleted $regionName'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _clearOldTiles(OfflineMapProvider offlineProvider) async {
    try {
      // FIXED: Use cleanupOldTiles method from provider instead of clearOldTiles
      await offlineProvider.cleanupOldTiles(30);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Old tiles cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear tiles: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // FIXED: Create helper method to get storage size from service
  Future<int> _getTotalStorageSize() async {
    try {
      final service = OfflineTileService();
      return await service.getTotalStorageSize();
    } catch (e) {
      debugPrint('Error getting storage size: $e');
      return 0;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}