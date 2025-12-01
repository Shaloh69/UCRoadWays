import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/location_provider.dart';
import 'providers/road_system_provider.dart';
import 'providers/building_provider.dart';
import 'providers/offline_map_provider.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const UCRoadWaysApp());
}

class UCRoadWaysApp extends StatelessWidget {
  const UCRoadWaysApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Location services
        ChangeNotifierProvider(create: (context) => LocationProvider()),

        // Road system management
        ChangeNotifierProvider(create: (context) => RoadSystemProvider()),

        // Building and floor management
        ChangeNotifierProvider(create: (context) => BuildingProvider()),

        // Offline map management
        ChangeNotifierProvider(create: (context) => OfflineMapProvider()),
      ],
      child: MaterialApp(
        title: 'UCRoadWays',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const SplashScreen(),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
    ));
    
    _startSplashSequence();
  }

  void _startSplashSequence() async {
    // Start animations
    _animationController.forward();
    
    // Initialize app services
    await _initializeServices();
    
    // Wait for animations to complete
    await _animationController.forward();
    
    // Navigate to main screen
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  Future<void> _initializeServices() async {
    try {
      final offlineMapProvider = Provider.of<OfflineMapProvider>(context, listen: false);
      final roadSystemProvider = Provider.of<RoadSystemProvider>(context, listen: false);
      // ignore: unused_local_variable
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      
      // Initialize offline map service first (critical for map functionality)
      await offlineMapProvider.initialize();
      
      // Load saved road systems
      await roadSystemProvider.loadRoadSystems();

      // Initialize location services (LocationProvider auto-initializes)
      // No need to call initialize() - it happens in constructor
      
      // Small delay to show splash screen
      await Future.delayed(const Duration(milliseconds: 1000));
      
    } catch (e) {
      debugPrint('Error during initialization: $e');
      // Continue anyway - the app should still work with limited functionality
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primaryContainer,
                ],
              ),
            ),
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App logo/icon
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.map,
                          size: 60,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // App name
                      const Text(
                        'UCRoadWays',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Subtitle
                      Text(
                        'Indoor & Outdoor Navigation',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 0.5,
                        ),
                      ),
                      
                      const SizedBox(height: 48),
                      
                      // Loading indicator
                      const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 3,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Loading text
                      Text(
                        'Initializing offline maps...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}