import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:latlong2/latlong.dart';

class LocationProvider extends ChangeNotifier {
  // Location state
  LatLng? _currentLatLng;
  Position? _currentPosition;
  bool _isTracking = false;
  bool _hasPermission = false;
  String? _error;
  double _accuracy = 0.0;
  double _speed = 0.0;
  double _heading = 0.0;
  DateTime? _lastUpdateTime;

  // Location history
  final List<LatLng> _locationHistory = [];
  static const int _maxHistoryLength = 100;

  // Streams
  StreamSubscription<Position>? _positionSubscription;
  final StreamController<LatLng> _locationStreamController = StreamController<LatLng>.broadcast();

  // Distance and movement tracking
  double _totalDistance = 0.0;
  LatLng? _lastLocationForDistance;
  double _currentTrip = 0.0;
  DateTime? _tripStartTime;

  // Location quality tracking
  final List<double> _accuracyHistory = [];
  int _poorSignalCount = 0;
  bool _isLocationStale = false;

  // Auto-retry mechanism
  Timer? _retryTimer;
  int _retryCount = 0;
  static const int _maxRetries = 5;
  static const Duration _retryInterval = Duration(seconds: 10);

  // Getters
  LatLng? get currentLatLng => _currentLatLng;
  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  bool get hasPermission => _hasPermission;
  String? get error => _error;
  double get accuracy => _accuracy;
  double get speed => _speed;
  double get heading => _heading;
  DateTime? get lastUpdateTime => _lastUpdateTime;
  List<LatLng> get locationHistory => List.unmodifiable(_locationHistory);
  Stream<LatLng> get locationStream => _locationStreamController.stream;
  double get totalDistance => _totalDistance;
  double get currentTrip => _currentTrip;
  bool get hasLocation => _currentLatLng != null;
  bool get isLocationStale => _isLocationStale;
  double get averageAccuracy => _accuracyHistory.isNotEmpty 
      ? _accuracyHistory.reduce((a, b) => a + b) / _accuracyHistory.length 
      : 0.0;

  // Enhanced location settings with fallback options
  static const LocationSettings _highAccuracySettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 1, // Update every 1 meter
    timeLimit: Duration(seconds: 15),
  );

  static const LocationSettings _balancedSettings = LocationSettings(
    accuracy: LocationAccuracy.medium,
    distanceFilter: 3, // Update every 3 meters
    timeLimit: Duration(seconds: 10),
  );

  static const LocationSettings _lowPowerSettings = LocationSettings(
    accuracy: LocationAccuracy.low,
    distanceFilter: 10, // Update every 10 meters
    timeLimit: Duration(seconds: 8),
  );

  LocationSettings _currentSettings = _highAccuracySettings;

  // Initialization
  LocationProvider() {
    _initializeLocation();
    _startLocationQualityMonitoring();
  }

  Future<void> _initializeLocation() async {
    try {
      await _checkPermissions();
      if (_hasPermission) {
        await _getCurrentLocation();
        // Auto-start tracking if permission is granted
        await startLocationTracking();
      }
    } catch (e) {
      _setError('Failed to initialize location services: $e');
      _startRetryMechanism();
    }
  }

  // Enhanced permission handling with detailed error messages
  Future<bool> _checkPermissions() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setError('Location services are disabled. Please enable location services in device settings.');
        return false;
      }

      // Check location permission with detailed handling
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _setError('Location permissions denied. Please grant location access in app settings.');
          return false;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _setError('Location permissions permanently denied. Please enable location access in app settings.');
        return false;
      }

      // Additional permission check for background location (if needed)
      if (permission == LocationPermission.whileInUse) {
        debugPrint('Location permission granted for foreground use only');
      }

      _hasPermission = true;
      _clearError();
      _retryCount = 0; // Reset retry count on success
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Permission check failed: $e');
      return false;
    }
  }

  // Get current location with enhanced error handling
  Future<LatLng?> getCurrentLocation() async {
    try {
      if (!_hasPermission) {
        final permissionGranted = await _checkPermissions();
        if (!permissionGranted) return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('Location request timed out'),
      );

      _updateLocation(position);
      return _currentLatLng;
    } on TimeoutException catch (e) {
      _setError('Location request timed out. Please check your GPS signal.');
      return null;
    } on LocationServiceDisabledException {
      _setError('Location services are disabled. Please enable GPS.');
      return null;
    } on PermissionDeniedException {
      _setError('Location permission denied. Please grant location access.');
      return null;
    } catch (e) {
      _setError('Failed to get current location: $e');
      return null;
    }
  }

  // Enhanced location tracking with adaptive quality
  Future<void> startLocationTracking() async {
    try {
      if (_isTracking) return;

      if (!_hasPermission) {
        final permissionGranted = await _checkPermissions();
        if (!permissionGranted) return;
      }

      _isTracking = true;
      _clearError();
      _tripStartTime = DateTime.now();
      _currentTrip = 0.0;
      notifyListeners();

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: _currentSettings,
      ).listen(
        _updateLocation,
        onError: (error) {
          _handleLocationError(error);
        },
        onDone: () {
          debugPrint('Location stream completed');
        },
      );

      debugPrint('Location tracking started with ${_getSettingsName(_currentSettings)} settings');
    } catch (e) {
      _setError('Failed to start location tracking: $e');
      _isTracking = false;
      notifyListeners();
      _startRetryMechanism();
    }
  }

  void _handleLocationError(dynamic error) {
    debugPrint('Location stream error: $error');
    
    if (error is LocationServiceDisabledException) {
      _setError('GPS disabled. Please enable location services.');
    } else if (error is PermissionDeniedException) {
      _setError('Location permission denied.');
      _hasPermission = false;
    } else {
      _setError('Location tracking error: $error');
    }
    
    // Try to recover with lower accuracy settings
    _adaptLocationSettings();
    _startRetryMechanism();
  }

  // Stop location tracking
  void stopLocationTracking() {
    _stopLocationTracking();
    debugPrint('Location tracking stopped');
  }

  void _stopLocationTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    notifyListeners();
  }

  // Enhanced location update with quality checks
  void _updateLocation(Position position) {
    try {
      _currentPosition = position;
      final newLatLng = LatLng(position.latitude, position.longitude);
      
      // Validate coordinates
      if (!isValidLocation(newLatLng)) {
        debugPrint('Invalid location coordinates received: ${newLatLng.latitude}, ${newLatLng.longitude}');
        return;
      }
      
      // Check for significant movement to avoid noise
      if (_currentLatLng != null) {
        final distance = _calculateDistance(_currentLatLng!, newLatLng);
        if (distance < 1.0 && position.accuracy > 20) {
          // Skip small movements with poor accuracy
          return;
        }
      }

      // Update distance tracking
      if (_lastLocationForDistance != null) {
        final distance = _calculateDistance(_lastLocationForDistance!, newLatLng);
        _totalDistance += distance;
        _currentTrip += distance;
      }
      _lastLocationForDistance = newLatLng;

      _currentLatLng = newLatLng;
      _accuracy = position.accuracy;
      _speed = position.speed;
      _heading = position.heading;
      _lastUpdateTime = DateTime.now();
      _isLocationStale = false;

      // Update quality tracking
      _accuracyHistory.add(position.accuracy);
      if (_accuracyHistory.length > 10) {
        _accuracyHistory.removeAt(0);
      }

      // Monitor signal quality
      if (position.accuracy > 50) {
        _poorSignalCount++;
        if (_poorSignalCount > 5) {
          _adaptLocationSettings();
          _poorSignalCount = 0;
        }
      } else {
        _poorSignalCount = math.max(0, _poorSignalCount - 1);
      }

      // Add to history
      _addToHistory(newLatLng);

      // Clear any errors and reset retry count
      _clearError();
      _retryCount = 0;

      // Notify listeners
      notifyListeners();
      
      // Emit to stream
      _locationStreamController.add(newLatLng);
      
      debugPrint('Location updated: ${newLatLng.latitude}, ${newLatLng.longitude} (±${position.accuracy.toStringAsFixed(1)}m)');
    } catch (e) {
      debugPrint('Error updating location: $e');
    }
  }

  // Adaptive location settings based on signal quality
  void _adaptLocationSettings() {
    if (_currentSettings == _highAccuracySettings) {
      _currentSettings = _balancedSettings;
      debugPrint('Switching to balanced location settings');
    } else if (_currentSettings == _balancedSettings) {
      _currentSettings = _lowPowerSettings;
      debugPrint('Switching to low power location settings');
    }
    
    // Restart tracking with new settings if currently tracking
    if (_isTracking) {
      _restartLocationTracking();
    }
  }

  void _restartLocationTracking() async {
    _stopLocationTracking();
    await Future.delayed(const Duration(seconds: 2));
    await startLocationTracking();
  }

  String _getSettingsName(LocationSettings settings) {
    if (settings == _highAccuracySettings) return 'High Accuracy';
    if (settings == _balancedSettings) return 'Balanced';
    if (settings == _lowPowerSettings) return 'Low Power';
    return 'Custom';
  }

  // Auto-retry mechanism for failed location requests
  void _startRetryMechanism() {
    if (_retryCount >= _maxRetries) {
      debugPrint('Maximum retry attempts reached');
      return;
    }

    _retryTimer?.cancel();
    _retryTimer = Timer(_retryInterval, () async {
      _retryCount++;
      debugPrint('Retrying location initialization (attempt $_retryCount/$_maxRetries)');
      
      try {
        await _checkPermissions();
        if (_hasPermission && !_isTracking) {
          await startLocationTracking();
        }
      } catch (e) {
        debugPrint('Retry failed: $e');
        if (_retryCount < _maxRetries) {
          _startRetryMechanism();
        }
      }
    });
  }

  // Location quality monitoring
  void _startLocationQualityMonitoring() {
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_lastUpdateTime != null) {
        final timeSinceUpdate = DateTime.now().difference(_lastUpdateTime!);
        if (timeSinceUpdate.inMinutes > 2) {
          _isLocationStale = true;
          notifyListeners();
        }
      }
    });
  }

  // Internal method to get current location
  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      _updateLocation(position);
    } catch (e) {
      debugPrint('Failed to get initial location: $e');
    }
  }

  // Add location to history with optimization
  void _addToHistory(LatLng location) {
    // Only add if significantly different from last location
    if (_locationHistory.isNotEmpty) {
      final lastLocation = _locationHistory.last;
      final distance = _calculateDistance(lastLocation, location);
      if (distance < 5.0) return; // Skip if less than 5 meters difference
    }

    _locationHistory.add(location);
    
    // Keep history within limits
    if (_locationHistory.length > _maxHistoryLength) {
      _locationHistory.removeAt(0);
    }
  }

  // Enhanced distance calculation with caching
  final Map<String, double> _distanceCache = {};
  
  double _calculateDistance(LatLng point1, LatLng point2) {
    final key = '${point1.latitude},${point1.longitude}-${point2.latitude},${point2.longitude}';
    if (_distanceCache.containsKey(key)) {
      return _distanceCache[key]!;
    }

    const double earthRadius = 6371000; // meters
    final double lat1Rad = point1.latitude * math.pi / 180;
    final double lat2Rad = point2.latitude * math.pi / 180;
    final double deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180;
    final double deltaLngRad = (point2.longitude - point1.longitude) * math.pi / 180;

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    final double distance = earthRadius * c;
    _distanceCache[key] = distance;
    
    // Keep cache size manageable
    if (_distanceCache.length > 100) {
      _distanceCache.clear();
    }
    
    return distance;
  }

  // Calculate distance to a point
  double? getDistanceTo(LatLng destination) {
    if (_currentLatLng == null) return null;
    return _calculateDistance(_currentLatLng!, destination);
  }

  // Get bearing to a point
  double? getBearingTo(LatLng destination) {
    if (_currentLatLng == null) return null;
    
    final double lat1Rad = _currentLatLng!.latitude * math.pi / 180;
    final double lat2Rad = destination.latitude * math.pi / 180;
    final double deltaLngRad = (destination.longitude - _currentLatLng!.longitude) * math.pi / 180;

    final double y = math.sin(deltaLngRad) * math.cos(lat2Rad);
    final double x = math.cos(lat1Rad) * math.sin(lat2Rad) - math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(deltaLngRad);

    double bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360; // Normalize to 0-360
  }

  // Enhanced location accuracy checking
  bool get isLocationAccurate => _accuracy > 0 && _accuracy <= 10; // Within 10 meters
  bool get isLocationGood => _accuracy > 0 && _accuracy <= 20; // Within 20 meters
  bool get isLocationUsable => _accuracy > 0 && _accuracy <= 50; // Within 50 meters

  // Get location accuracy status
  String get accuracyStatus {
    if (_accuracy <= 5) return 'Excellent';
    if (_accuracy <= 10) return 'Good';
    if (_accuracy <= 20) return 'Fair';
    if (_accuracy <= 50) return 'Poor';
    return 'Very Poor';
  }

  Color get accuracyColor {
    if (_accuracy <= 10) return const Color(0xFF4CAF50); // Green
    if (_accuracy <= 20) return const Color(0xFFFF9800); // Orange
    return const Color(0xFFF44336); // Red
  }

  // Get speed in different units
  double get speedKmh => _speed * 3.6; // Convert m/s to km/h
  double get speedMph => _speed * 2.237; // Convert m/s to mph

  // Enhanced movement detection
  bool get isMoving => _speed > 0.5; // Moving if speed > 0.5 m/s
  bool get isWalking => _speed > 0.5 && _speed <= 2.0; // Walking speed range
  bool get isRunning => _speed > 2.0 && _speed <= 5.0; // Running speed range
  bool get isDriving => _speed > 5.0; // Likely driving

  String get movementType {
    if (!isMoving) return 'Stationary';
    if (isWalking) return 'Walking';
    if (isRunning) return 'Running';
    if (isDriving) return 'Driving';
    return 'Moving';
  }

  // Format heading as compass direction
  String get compassDirection {
    if (_heading < 0) return 'Unknown';
    
    const directions = [
      'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
      'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'
    ];
    
    final index = ((_heading + 11.25) / 22.5).floor() % 16;
    return directions[index];
  }

  // Trip management
  void resetTrip() {
    _currentTrip = 0.0;
    _tripStartTime = DateTime.now();
    notifyListeners();
  }

  Duration? get tripDuration {
    if (_tripStartTime == null) return null;
    return DateTime.now().difference(_tripStartTime!);
  }

  double? get averageSpeed {
    final duration = tripDuration;
    if (duration == null || duration.inSeconds == 0) return null;
    return _currentTrip / duration.inSeconds; // m/s
  }

  // Reset distance tracking
  void resetDistanceTracking() {
    _totalDistance = 0.0;
    _lastLocationForDistance = _currentLatLng;
    notifyListeners();
  }

  // Clear location history
  void clearLocationHistory() {
    _locationHistory.clear();
    notifyListeners();
  }

  // Enhanced location statistics
  Map<String, dynamic> getLocationStats() {
    return {
      'isTracking': _isTracking,
      'hasPermission': _hasPermission,
      'hasLocation': hasLocation,
      'accuracy': _accuracy,
      'accuracyStatus': accuracyStatus,
      'isLocationAccurate': isLocationAccurate,
      'isLocationStale': _isLocationStale,
      'speed': _speed,
      'speedKmh': speedKmh,
      'heading': _heading,
      'compassDirection': compassDirection,
      'movementType': movementType,
      'totalDistance': _totalDistance,
      'currentTrip': _currentTrip,
      'tripDuration': tripDuration?.inMinutes,
      'averageSpeed': averageSpeed,
      'averageAccuracy': averageAccuracy,
      'historyCount': _locationHistory.length,
      'lastUpdate': _lastUpdateTime?.toIso8601String(),
      'currentSettings': _getSettingsName(_currentSettings),
      'retryCount': _retryCount,
    };
  }

  // Open device location settings
  Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('Failed to open location settings: $e');
    }
  }

  // Open app settings
  Future<void> openAppSettings() async {
    try {
      await Permission.location.request();
    } catch (e) {
      debugPrint('Failed to open app settings: $e');
    }
  }

  // Mock location for testing (only in debug mode)
  void setMockLocation(LatLng location) {
    if (kDebugMode) {
      _currentLatLng = location;
      _accuracy = 5.0; // Mock good accuracy
      _lastUpdateTime = DateTime.now();
      _isLocationStale = false;
      _addToHistory(location);
      notifyListeners();
      _locationStreamController.add(location);
      debugPrint('Mock location set: ${location.latitude}, ${location.longitude}');
    }
  }

  // Simulate movement for testing
  void simulateMovement(List<LatLng> waypoints, {Duration? interval}) {
    if (!kDebugMode) return;
    
    final intervalDuration = interval ?? const Duration(seconds: 2);
    int currentIndex = 0;
    
    Timer.periodic(intervalDuration, (timer) {
      if (currentIndex >= waypoints.length) {
        timer.cancel();
        return;
      }
      
      setMockLocation(waypoints[currentIndex]);
      currentIndex++;
    });
  }

  // Error handling
  void _setError(String error) {
    _error = error;
    notifyListeners();
    debugPrint('LocationProvider error: $error');
  }

  void _clearError() {
    _error = null;
  }

  // Validate location coordinates
  bool isValidLocation(LatLng location) {
    return location.latitude >= -90 && 
           location.latitude <= 90 && 
           location.longitude >= -180 && 
           location.longitude <= 180;
  }

  // Check if location is within a geographic bounds
  bool isLocationWithinBounds(LatLng location, LatLng northEast, LatLng southWest) {
    return location.latitude <= northEast.latitude &&
           location.latitude >= southWest.latitude &&
           location.longitude <= northEast.longitude &&
           location.longitude >= southWest.longitude;
  }

  // Get center point of location history
  LatLng? getHistoryCenter() {
    if (_locationHistory.isEmpty) return null;
    
    double totalLat = 0;
    double totalLng = 0;
    
    for (final location in _locationHistory) {
      totalLat += location.latitude;
      totalLng += location.longitude;
    }
    
    return LatLng(
      totalLat / _locationHistory.length,
      totalLng / _locationHistory.length,
    );
  }

  // Get bounding box of location history
  Map<String, LatLng>? getHistoryBounds() {
    if (_locationHistory.isEmpty) return null;
    
    double minLat = _locationHistory.first.latitude;
    double maxLat = _locationHistory.first.latitude;
    double minLng = _locationHistory.first.longitude;
    double maxLng = _locationHistory.first.longitude;
    
    for (final location in _locationHistory) {
      minLat = math.min(minLat, location.latitude);
      maxLat = math.max(maxLat, location.latitude);
      minLng = math.min(minLng, location.longitude);
      maxLng = math.max(maxLng, location.longitude);
    }
    
    return {
      'southWest': LatLng(minLat, minLng),
      'northEast': LatLng(maxLat, maxLng),
    };
  }

  // Get estimated accuracy based on recent readings
  double get estimatedAccuracy {
    if (_accuracyHistory.isEmpty) return _accuracy;
    
    // Use median for better estimation
    final sorted = List<double>.from(_accuracyHistory)..sort();
    final middle = sorted.length ~/ 2;
    
    if (sorted.length % 2 == 0) {
      return (sorted[middle - 1] + sorted[middle]) / 2;
    } else {
      return sorted[middle];
    }
  }

  // Force location settings reset to high accuracy
  void resetToHighAccuracy() {
    _currentSettings = _highAccuracySettings;
    _poorSignalCount = 0;
    
    if (_isTracking) {
      _restartLocationTracking();
    }
  }

  @override
  void dispose() {
    _stopLocationTracking();
    _retryTimer?.cancel();
    _locationStreamController.close();
    super.dispose();
  }
}