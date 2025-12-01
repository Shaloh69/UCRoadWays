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
}
