import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/road_system_provider.dart';
import '../providers/building_provider.dart';
import '../providers/location_provider.dart';
import '../models/models.dart';

class BottomPanel extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  const BottomPanel({
    super.key,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  @override
  State<BottomPanel> createState() => _BottomPanelState();
}

class _BottomPanelState extends State<BottomPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<RoadSystemProvider, BuildingProvider, LocationProvider>(
      builder: (context, roadSystemProvider, buildingProvider, locationProvider, child) {
        final currentSystem = roadSystemProvider.currentSystem;
        
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          bottom: 0,
          left: 0,
          right: 0,
          height: widget.isExpanded ? MediaQuery.of(context).size.height * 0.6 : 120,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Handle and header
                _buildPanelHeader(currentSystem, buildingProvider),
                
                // Content based on expanded state
                if (widget.isExpanded) ...[
                  // Tab bar
                  _buildTabBar(),
                  
                  // Tab content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(currentSystem, buildingProvider, roadSystemProvider),
                        _buildLocationsTab(currentSystem, buildingProvider),
                        _buildStatsTab(currentSystem, roadSystemProvider),
                      ],
                    ),
                  ),
                ] else ...[
                  // Collapsed content
                  _buildCollapsedContent(currentSystem, buildingProvider, locationProvider),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPanelHeader(RoadSystem? currentSystem, BuildingProvider buildingProvider) {
    return GestureDetector(
      onTap: widget.onToggleExpanded,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            
            // Header content
            Row(
              children: [
                Icon(
                  buildingProvider.isIndoorMode ? Icons.business : Icons.map,
                  color: buildingProvider.isIndoorMode ? Colors.purple : Colors.blue,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentSystem?.name ?? 'No System Selected',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        buildingProvider.getCurrentContextDescription(currentSystem),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  widget.isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.blue,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Colors.blue,
        tabs: const [
          Tab(text: 'Overview', icon: Icon(Icons.dashboard, size: 16)),
          Tab(text: 'Locations', icon: Icon(Icons.place, size: 16)),
          Tab(text: 'Stats', icon: Icon(Icons.analytics, size: 16)),
        ],
      ),
    );
  }

  Widget _buildCollapsedContent(
    RoadSystem? currentSystem,
    BuildingProvider buildingProvider,
    LocationProvider locationProvider,
  ) {
    if (currentSystem == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No road system selected. Create or select a system to get started.',
          style: TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _buildQuickStat(
            'Buildings',
            currentSystem.buildings.length.toString(),
            Icons.business,
            Colors.purple,
          ),
          const SizedBox(width: 16),
          _buildQuickStat(
            'Roads',
            currentSystem.allRoads.length.toString(),
            Icons.route,
            Colors.blue,
          ),
          const SizedBox(width: 16),
          _buildQuickStat(
            'Landmarks',
            currentSystem.allLandmarks.length.toString(),
            Icons.place,
            Colors.green,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: locationProvider.isTracking ? Colors.green[100] : Colors.red[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  locationProvider.isTracking ? Icons.gps_fixed : Icons.gps_off,
                  size: 12,
                  color: locationProvider.isTracking ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  locationProvider.isTracking ? 'GPS ON' : 'GPS OFF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: locationProvider.isTracking ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 14,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewTab(
    RoadSystem? currentSystem,
    BuildingProvider buildingProvider,
    RoadSystemProvider roadSystemProvider,
  ) {
    if (currentSystem == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Road System Selected',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text('Create or select a road system to get started'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current location context
          if (buildingProvider.isIndoorMode) ...[
            _buildContextCard(buildingProvider, currentSystem),
            const SizedBox(height: 16),
          ],
          
          // Recent activity
          _buildRecentActivityCard(currentSystem),
          const SizedBox(height: 16),
          
          // Quick actions
          _buildQuickActionsCard(),
          const SizedBox(height: 16),
          
          // System health
          _buildSystemHealthCard(currentSystem, roadSystemProvider),
        ],
      ),
    );
  }

  Widget _buildContextCard(BuildingProvider buildingProvider, RoadSystem currentSystem) {
    final building = buildingProvider.getSelectedBuilding(currentSystem);
    final floor = buildingProvider.getSelectedFloor(currentSystem);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.business, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Current Location',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (building != null) ...[
              Text('Building: ${building.name}'),
              if (floor != null) ...[
                Text('Floor: ${buildingProvider.getFloorDisplayName(floor)}'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildMiniStat('Roads', floor.roads.length.toString()),
                    const SizedBox(width: 16),
                    _buildMiniStat('Landmarks', floor.landmarks.length.toString()),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildRecentActivityCard(RoadSystem currentSystem) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.history, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Recent Activity',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (currentSystem.buildings.isNotEmpty) ...[
              _buildActivityItem(
                'Last building added: ${currentSystem.buildings.last.name}',
                Icons.business,
                Colors.purple,
              ),
            ],
            if (currentSystem.outdoorLandmarks.isNotEmpty) ...[
              _buildActivityItem(
                'Last landmark: ${currentSystem.outdoorLandmarks.last.name}',
                Icons.place,
                Colors.green,
              ),
            ],
            if (currentSystem.outdoorRoads.isNotEmpty) ...[
              _buildActivityItem(
                'Last road: ${currentSystem.outdoorRoads.last.name}',
                Icons.route,
                Colors.blue,
              ),
            ],
            if (currentSystem.buildings.isEmpty && 
                currentSystem.outdoorLandmarks.isEmpty && 
                currentSystem.outdoorRoads.isEmpty) ...[
              const Text(
                'No activity yet. Start by adding buildings or landmarks!',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.flash_on, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Quick Actions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    'Add Building',
                    Icons.business,
                    Colors.purple,
                    () => Navigator.pushNamed(context, '/buildings'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildQuickActionButton(
                    'Navigate',
                    Icons.navigation,
                    Colors.green,
                    () => Navigator.pushNamed(context, '/navigation'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSystemHealthCard(RoadSystem currentSystem, RoadSystemProvider roadSystemProvider) {
    final stats = roadSystemProvider.getSystemStatistics(currentSystem.id);
    final totalElements = (stats['totalRoads'] ?? 0) + (stats['totalLandmarks'] ?? 0) + (stats['buildings'] ?? 0);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.health_and_safety, color: Colors.teal),
                SizedBox(width: 8),
                Text(
                  'System Health',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  totalElements > 0 ? Icons.check_circle : Icons.warning,
                  color: totalElements > 0 ? Colors.green : Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  totalElements > 0 
                      ? 'System is active with $totalElements elements'
                      : 'System is empty - add some content!',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationsTab(RoadSystem? currentSystem, BuildingProvider buildingProvider) {
    if (currentSystem == null) {
      return const Center(child: Text('No system selected'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Buildings section
          if (currentSystem.buildings.isNotEmpty) ...[
            _buildSectionHeader('Buildings', Icons.business, Colors.purple),
            const SizedBox(height: 8),
            ...currentSystem.buildings.map((building) => _buildLocationItem(
              building.name,
              '${building.floors.length} floors',
              Icons.business,
              Colors.purple,
              () => _selectBuilding(building.id, buildingProvider),
            )),
            const SizedBox(height: 16),
          ],
          
          // Outdoor landmarks section
          if (currentSystem.outdoorLandmarks.isNotEmpty) ...[
            _buildSectionHeader('Outdoor Landmarks', Icons.place, Colors.green),
            const SizedBox(height: 8),
            ...currentSystem.outdoorLandmarks.map((landmark) => _buildLocationItem(
              landmark.name,
              landmark.type.toUpperCase(),
              _getLandmarkIcon(landmark.type),
              Colors.green,
              () => _showLandmarkDetails(landmark),
            )),
            const SizedBox(height: 16),
          ],
          
          // Recent locations
          _buildSectionHeader('Recent', Icons.history, Colors.blue),
          const SizedBox(height: 8),
          const Text(
            'Location history will appear here',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationItem(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildStatsTab(RoadSystem? currentSystem, RoadSystemProvider roadSystemProvider) {
    if (currentSystem == null) {
      return const Center(child: Text('No system selected'));
    }

    final stats = roadSystemProvider.getSystemStatistics(currentSystem.id);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatCard('Buildings', stats['buildings'] ?? 0, Icons.business, Colors.purple),
          _buildStatCard('Total Floors', stats['floors'] ?? 0, Icons.layers, Colors.indigo),
          _buildStatCard('Total Roads', stats['totalRoads'] ?? 0, Icons.route, Colors.blue),
          _buildStatCard('Total Landmarks', stats['totalLandmarks'] ?? 0, Icons.place, Colors.green),
          _buildStatCard('Intersections', stats['intersections'] ?? 0, Icons.fork_right, Colors.orange),
          
          const SizedBox(height: 20),
          _buildDetailedStatsCard(stats),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.toString(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedStatsCard(Map<String, dynamic> stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Breakdown',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatRow('Outdoor Roads', stats['outdoorRoads'] ?? 0),
            _buildStatRow('Indoor Roads', stats['indoorRoads'] ?? 0),
            _buildStatRow('Outdoor Landmarks', stats['outdoorLandmarks'] ?? 0),
            _buildStatRow('Indoor Landmarks', stats['indoorLandmarks'] ?? 0),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _selectBuilding(String buildingId, BuildingProvider buildingProvider) {
    buildingProvider.selectBuilding(buildingId);
    widget.onToggleExpanded(); // Collapse panel
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Building selected')),
    );
  }

  void _showLandmarkDetails(Landmark landmark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(landmark.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${landmark.type.toUpperCase()}'),
            if (landmark.description.isNotEmpty)
              Text('Description: ${landmark.description}'),
          ],
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

  IconData _getLandmarkIcon(String type) {
    switch (type) {
      case 'bathroom':
        return Icons.wc;
      case 'classroom':
        return Icons.school;
      case 'office':
        return Icons.work;
      case 'entrance':
        return Icons.door_front_door;
      case 'elevator':
        return Icons.elevator;
      case 'stairs':
        return Icons.stairs;
      default:
        return Icons.place;
    }
  }
}