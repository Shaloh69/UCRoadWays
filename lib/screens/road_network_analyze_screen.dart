import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/road_system_provider.dart';
import '../models/models.dart';

class RoadNetworkAnalyzerScreen extends StatefulWidget {
  const RoadNetworkAnalyzerScreen({super.key});

  @override
  State<RoadNetworkAnalyzerScreen> createState() => _RoadNetworkAnalyzerScreenState();
}

class _RoadNetworkAnalyzerScreenState extends State<RoadNetworkAnalyzerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _analysisResults;
  List<Intersection>? _potentialIntersections;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _performAnalysis();
  }

  Future<void> _performAnalysis() async {
    setState(() {
      _isAnalyzing = true;
    });

    final provider = Provider.of<RoadSystemProvider>(context, listen: false);
    
    // Perform network analysis
    _analysisResults = provider.analyzeRoadNetwork();
    
    // Detect potential intersections
    _potentialIntersections = await provider.detectPotentialIntersections();

    setState(() {
      _isAnalyzing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Road Network Analyzer'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _performAnalysis,
            tooltip: 'Refresh Analysis',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.analytics)),
            Tab(text: 'Connections', icon: Icon(Icons.call_merge)),
            Tab(text: 'Intersections', icon: Icon(Icons.multiple_stop)),
          ],
        ),
      ),
      body: _isAnalyzing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analyzing road network...'),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildConnectionsTab(),
                _buildIntersectionsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return Consumer<RoadSystemProvider>(
      builder: (context, provider, child) {
        final currentSystem = provider.currentSystem;
        
        if (currentSystem == null) {
          return const Center(
            child: Text('No road system selected'),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // System Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentSystem.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Center: ${currentSystem.centerPosition.latitude.toStringAsFixed(4)}, '
                        '${currentSystem.centerPosition.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Statistics Cards
              if (_analysisResults != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Roads',
                        _analysisResults!['total_roads'].toString(),
                        Icons.route,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Intersections',
                        _analysisResults!['total_intersections'].toString(),
                        Icons.multiple_stop,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Buildings',
                        _analysisResults!['total_buildings'].toString(),
                        Icons.business,
                        Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Connected Roads',
                        _analysisResults!['connected_roads'].toString(),
                        Icons.link,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Connectivity Analysis
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Network Connectivity',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        LinearProgressIndicator(
                          value: _analysisResults!['connectivity_percentage'] / 100.0,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getConnectivityColor(_analysisResults!['connectivity_percentage']),
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${_analysisResults!['connectivity_percentage']}% Connected'),
                            Text('${_analysisResults!['isolated_roads']} Isolated Roads'),
                          ],
                        ),
                        
                        if (_analysisResults!['connectivity_percentage'] < 80) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning, color: Colors.orange[700]),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Low connectivity detected. Consider adding more intersections.',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Quick Actions
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _autoConnectNearbyRoads,
                              icon: const Icon(Icons.auto_fix_high),
                              label: const Text('Auto-Connect'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _tabController.animateTo(2),
                              icon: const Icon(Icons.add_road),
                              label: const Text('Add Intersections'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionsTab() {
    if (_analysisResults == null) return const SizedBox.shrink();

    final potentialConnections = _analysisResults!['potential_connections'] as List<Map<String, dynamic>>;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info, color: Colors.blue[600]),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'These roads are close enough to potentially connect. Tap to create intersections.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: potentialConnections.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 64, color: Colors.green),
                      SizedBox(height: 16),
                      Text(
                        'Great! No nearby unconnected roads found.',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        'Your road network appears well-connected.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: potentialConnections.length,
                  itemBuilder: (context, index) {
                    final connection = potentialConnections[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.orange,
                          child: Icon(Icons.call_merge, color: Colors.white),
                        ),
                        title: Text(
                          '${connection['road1_name']} ↔ ${connection['road2_name']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Distance: ${connection['distance'].toStringAsFixed(1)}m',
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _connectRoads(connection),
                          child: const Text('Connect'),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildIntersectionsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.amber[600]),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Auto-detected intersection points where roads cross.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: (_potentialIntersections?.isEmpty ?? true)
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No potential intersections detected.',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        'Roads may not be crossing or intersections already exist.',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _potentialIntersections!.length,
                  itemBuilder: (context, index) {
                    final intersection = _potentialIntersections![index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.red,
                          child: Icon(Icons.multiple_stop, color: Colors.white),
                        ),
                        title: Text(
                          '${intersection.properties['road1_name']} × ${intersection.properties['road2_name']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Position: ${intersection.position.latitude.toStringAsFixed(4)}, '
                          '${intersection.position.longitude.toStringAsFixed(4)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _viewOnMap(intersection.position),
                              icon: const Icon(Icons.map),
                              tooltip: 'View on Map',
                            ),
                            ElevatedButton(
                              onPressed: () => _addIntersection(intersection),
                              child: const Text('Add'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getConnectivityColor(int percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }

  void _autoConnectNearbyRoads() async {
    if (_analysisResults == null) return;

    final potentialConnections = _analysisResults!['potential_connections'] as List<Map<String, dynamic>>;
    
    if (potentialConnections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No nearby roads found to connect automatically.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auto-Connect Roads'),
        content: Text(
          'This will automatically create ${potentialConnections.length} intersection(s) '
          'to connect nearby roads. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Connect All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final provider = Provider.of<RoadSystemProvider>(context, listen: false);
      int connectionsCreated = 0;

      for (final connection in potentialConnections) {
        await provider.connectRoads(
          [connection['road1_id'], connection['road2_id']],
          connection['connection_point'],
        );
        connectionsCreated++;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Created $connectionsCreated intersection(s)'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh analysis
      _performAnalysis();
    }
  }

  void _connectRoads(Map<String, dynamic> connection) async {
    final provider = Provider.of<RoadSystemProvider>(context, listen: false);
    
    await provider.connectRoads(
      [connection['road1_id'], connection['road2_id']],
      connection['connection_point'],
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Connected ${connection['road1_name']} and ${connection['road2_name']}'),
        backgroundColor: Colors.green,
      ),
    );

    // Refresh analysis
    _performAnalysis();
  }

  void _addIntersection(Intersection intersection) {
    final provider = Provider.of<RoadSystemProvider>(context, listen: false);
    provider.addIntersectionToCurrentSystem(intersection);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Intersection added'),
        backgroundColor: Colors.green,
      ),
    );

    // Refresh analysis
    _performAnalysis();
  }

  void _viewOnMap(LatLng position) {
    // This would navigate back to the main screen and center on the position
    Navigator.pop(context);
    // You could pass the position back to center the map
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}