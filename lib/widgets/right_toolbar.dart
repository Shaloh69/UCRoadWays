import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/road_system_provider.dart';
import '../providers/building_provider.dart';
import '../screens/road_system_manager_screen.dart';
import '../screens/building_manager_screen.dart';
import '../screens/navigation_screen.dart';
import '../screens/road_network_analyze_screen.dart';
import '../screens/node_management_screen.dart';
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

        return Positioned(
          right: 0,
          top: MediaQuery.of(context).padding.top + 60,
          bottom: 200,
          child: AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_isExpanded ? 0 : 200, 0),
                child: Container(
                  width: 80,
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
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(-2, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Toggle button
                      _buildToggleButton(),

                      const Divider(height: 1),

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

                      const Spacer(),

                      // Mode indicator
                      _buildModeIndicator(buildingProvider),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildToggleButton() {
    return InkWell(
      onTap: _toggleExpanded,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Icon(
          _isExpanded ? Icons.chevron_right : Icons.chevron_left,
          color: AppTheme.neutralGray600,
          size: 24,
        ),
      ),
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
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color,
                      color.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.neutralGray700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeIndicator(BuildingProvider buildingProvider) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: buildingProvider.isIndoorMode
            ? AppTheme.secondaryPurple.withOpacity(0.1)
            : AppTheme.successGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: buildingProvider.isIndoorMode
              ? AppTheme.secondaryPurple
              : AppTheme.successGreen,
          width: 2,
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
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            buildingProvider.isIndoorMode ? 'Indoor' : 'Outdoor',
            style: TextStyle(
              fontSize: 9,
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
}
