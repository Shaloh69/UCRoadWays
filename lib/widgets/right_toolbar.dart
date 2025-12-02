import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../providers/road_system_provider.dart';
import '../providers/building_provider.dart';
import '../screens/road_system_manager_screen.dart';
import '../screens/building_manager_screen.dart';
import '../screens/navigation_screen.dart';
import '../screens/road_network_analyze_screen.dart';
import '../screens/node_management_screen.dart';
import '../services/geojson_export_service.dart';
import '../theme/app_theme.dart';

class RightToolbar extends StatefulWidget {
  const RightToolbar({super.key});

  @override
  State<RightToolbar> createState() => _RightToolbarState();
}

class _RightToolbarState extends State<RightToolbar> with SingleTickerProviderStateMixin {
  bool _isExpanded = true;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
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
        final hasSystem = roadSystemProvider.currentSystem != null;
        final screenHeight = MediaQuery.of(context).size.height;
        final topPadding = MediaQuery.of(context).padding.top;
        final bottomPadding = MediaQuery.of(context).padding.bottom;

        return Stack(
          children: [
            // Main toolbar panel - slides in/out
            Positioned(
              right: 0,
              top: topPadding + 60,
              bottom: bottomPadding + 160, // Dynamic bottom padding
              child: AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_isExpanded ? 0 : 64, 0), // Only hide the main panel, not toggle
                    child: Container(
                      width: 64,
                      constraints: BoxConstraints(
                        maxHeight: screenHeight - topPadding - bottomPadding - 220,
                        minHeight: 200,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.95),
                            Colors.white.withOpacity(0.98),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(-2, 0),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 8),

                            // Road Systems Manager
                            _buildToolButton(
                              icon: Icons.alt_route,
                              label: 'Systems',
                              color: AppTheme.primaryBlue,
                              onTap: () => _openScreen(const RoadSystemManagerScreen()),
                            ),

                            // Buildings Manager
                            if (hasSystem)
                              _buildToolButton(
                                icon: Icons.business,
                                label: 'Buildings',
                                color: AppTheme.secondaryPurple,
                                onTap: () => _openScreen(const BuildingManagerScreen()),
                              ),

                            // Node Management
                            if (hasSystem)
                              _buildToolButton(
                                icon: Icons.circle,
                                label: 'Nodes',
                                color: AppTheme.warningAmber,
                                onTap: () => _openScreen(NodeManagementScreen(
                                  roadSystem: roadSystemProvider.currentSystem!,
                                )),
                              ),

                            // Network Analysis
                            if (hasSystem)
                              _buildToolButton(
                                icon: Icons.analytics,
                                label: 'Analyze',
                                color: AppTheme.accentTeal,
                                onTap: () => _openScreen(const RoadNetworkAnalyzeScreen()),
                              ),

                            // Navigation
                            if (hasSystem)
                              _buildToolButton(
                                icon: Icons.navigation,
                                label: 'Navigate',
                                color: AppTheme.successGreen,
                                onTap: () => _openScreen(const NavigationScreen()),
                              ),

                            // Export Data
                            if (hasSystem)
                              _buildToolButton(
                                icon: Icons.file_download,
                                label: 'Export',
                                color: Colors.blue,
                                onTap: () => _showExportDialog(roadSystemProvider),
                              ),

                            const SizedBox(height: 12),

                            // Mode indicator
                            if (hasSystem)
                              _buildModeIndicator(buildingProvider),

                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Toggle button - ALWAYS VISIBLE
            Positioned(
              right: 0,
              top: topPadding + 60,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggleExpanded,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                  child: Container(
                    width: 32,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isExpanded
                          ? [AppTheme.primaryBlue, AppTheme.secondaryPurple]
                          : [AppTheme.successGreen, AppTheme.accentTeal],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(-2, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isExpanded ? Icons.chevron_right : Icons.chevron_left,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color,
                      color.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.neutralGray700,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeIndicator(BuildingProvider buildingProvider) {
    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: buildingProvider.isIndoorMode
            ? AppTheme.secondaryPurple.withOpacity(0.1)
            : AppTheme.successGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: buildingProvider.isIndoorMode
              ? AppTheme.secondaryPurple
              : AppTheme.successGreen,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            buildingProvider.isIndoorMode ? Icons.business : Icons.landscape,
            color: buildingProvider.isIndoorMode
                ? AppTheme.secondaryPurple
                : AppTheme.successGreen,
            size: 18,
          ),
          const SizedBox(height: 2),
          Text(
            buildingProvider.isIndoorMode ? 'In' : 'Out',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: buildingProvider.isIndoorMode
                  ? AppTheme.secondaryPurple
                  : AppTheme.successGreen,
            ),
          ),
        ],
      ),
    );
  }

  void _openScreen(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  void _showExportDialog(RoadSystemProvider roadSystemProvider) {
    if (roadSystemProvider.currentSystem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No road system loaded. Please create or load a system first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.file_download, color: Colors.blue),
            SizedBox(width: 8),
            Text('Export Data'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export: ${roadSystemProvider.currentSystem!.name}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text('Choose export format:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),

            // GeoJSON Export
            ListTile(
              leading: const Icon(Icons.map, color: Colors.green, size: 20),
              title: const Text('GeoJSON', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Single file', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _exportToGeoJSON(roadSystemProvider);
              },
            ),

            // Layered GeoJSON Export
            ListTile(
              leading: const Icon(Icons.layers, color: Colors.blue, size: 20),
              title: const Text('GeoJSON (Layered)', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Multiple files', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _exportToLayeredGeoJSON(roadSystemProvider);
              },
            ),

            // JSON Export
            ListTile(
              leading: const Icon(Icons.code, color: Colors.orange, size: 20),
              title: const Text('JSON', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Native format', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _exportToJSON(roadSystemProvider);
              },
            ),
          ],
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

  Future<void> _exportToGeoJSON(RoadSystemProvider roadSystemProvider) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Exporting...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      final file = await GeoJsonExportService.exportToGeoJSON(
        roadSystemProvider.currentSystem!,
        includeIndoorData: true,
        includeMetadata: true,
      );

      if (mounted) {
        _showExportSuccess(file, 'GeoJSON');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToLayeredGeoJSON(RoadSystemProvider roadSystemProvider) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Exporting layers...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );

      final files = await GeoJsonExportService.exportToLayeredGeoJSON(
        roadSystemProvider.currentSystem!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${files.length} files successfully!'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View',
              onPressed: () => _showLayeredExportSuccess(files),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToJSON(RoadSystemProvider roadSystemProvider) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Exporting...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      final jsonString = roadSystemProvider.exportToJson(
        roadSystemProvider.currentSystem!.id,
      );

      final directory = await Directory.systemTemp.createTemp('ucroadways_export');
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = '${roadSystemProvider.currentSystem!.name}_$timestamp.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonString);

      if (mounted) {
        _showExportSuccess(file, 'JSON');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showExportSuccess(File file, String format) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 24),
            const SizedBox(width: 8),
            const Text('Success!', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exported to $format'),
            const SizedBox(height: 12),
            const Text('Location:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            SelectableText(
              file.path,
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await Share.shareXFiles([XFile(file.path)]);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Share failed: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }

  void _showLayeredExportSuccess(Map<String, File> files) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 24),
            const SizedBox(width: 8),
            const Text('Export Complete', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Exported ${files.length} layers:', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: files.keys.map((name) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.insert_drive_file, size: 14, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(name, style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              const Text('Saved to:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              SelectableText(
                files.values.first.parent.path,
                style: const TextStyle(fontSize: 9, fontFamily: 'monospace'),
              ),
            ],
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
}
