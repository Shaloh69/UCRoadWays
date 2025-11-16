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

  // Streams - FIXED: Single stream management
  StreamSubscription<Position>? _positionSubscription;
  StreamController<LatLng>? _locationStreamController;
  bool _isStreamControllerClosed = false;

  // Distance and movement tracking
  double _totalDistance = 0.0;
  LatLng? _lastLocationForDistance;
  double _currentTrip = 0.0;
  DateTime? _tripStartTime;

  // Location quality tracking
  final List<double> _accuracyHistory = [];
  int _poorSignalCount = 0;
  bool _isLocationStale = false;

  // Auto-retry mechanism - FIXED: Better state management
  Timer? _retryTimer;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _retryInterval = Duration(seconds: 15);
  bool _isRetrying = false;
  bool _isInitializing = false;

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
  Stream<LatLng> get locationStream {
    _ensureStreamController();
    return _locationStreamController!.stream;
  }
  double get totalDistance => _totalDistance;
  double get currentTrip => _currentTrip;
  bool get hasLocation => _currentLatLng != null;
  bool get isLocationStale => _isLocationStale;
  double get averageAccuracy => _accuracyHistory.isNotEmpty 
      ? _accuracyHistory.reduce((a, b) => a + b) / _accuracyHistory.length 
      : 0.0;

  // FIXED: More conservative location settings to prevent timeouts
  static const LocationSettings _highAccuracySettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 2, // Update every 2 meters
    timeLimit: Duration(seconds: 30), // Increased timeout
  );

  static const LocationSettings _balancedSettings = LocationSettings(
    accuracy: LocationAccuracy.medium,
    distanceFilter: 5, // Update every 5 meters
    timeLimit: Duration(seconds: 25), // Increased timeout
  );

  static const LocationSettings _lowPowerSettings = LocationSettings(
    accuracy: LocationAccuracy.low,
    distanceFilter: 10, // Update every 10 meters
    timeLimit: Duration(seconds: 20), // Increased timeout
  );

  LocationSettings _currentSettings = _balancedSettings; // Start with balanced

  // FIXED: Stream controller management
  void _ensureStreamController() {
    if (_locationStreamController == null || _isStreamControllerClosed) {
      _locationStreamController = StreamController<LatLng>.broadcast();
      _isStreamControllerClosed = false;
    }
  }

  // Initialization
  LocationProvider() {
    _ensureStreamController();
    _initializeLocation();
    _startLocationQualityMonitoring();
  }

  @override
  void dispose() {
    _stopLocationTracking();
    _retryTimer?.cancel();
    if (_locationStreamController != null && !_isStreamControllerClosed) {
      _locationStreamController!.close();
      _isStreamControllerClosed = true;
    }
    super.dispose();
  }

  // FIXED: Prevent multiple concurrent initializations
  Future<void> _initializeLocation() async {
    if (_isInitializing) {
      debugPrint('Location initialization already in progress');
      return;
    }

    _isInitializing = true;
    try {
      await _checkPermissions();
      if (_hasPermission) {
        await _getCurrentLocation();
        // Only auto-start if not already tracking
        if (!_isTracking) {
          await startLocationTracking();
        }
      }
    } catch (e) {
      _setError('Failed to initialize location services: $e');
      _startRetryMechanism();
    } finally {
      _isInitializing = false;
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

  // FIXED: Better timeout handling and error recovery
  Future<LatLng?> getCurrentLocation() async {
    try {
      if (!_hasPermission) {
        final permissionGranted = await _checkPermissions();
        if (!permissionGranted) return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, // Use medium for better reliability
        timeLimit: const Duration(seconds: 20),
      ).timeout(
        const Duration(seconds: 25),
        onTimeout: () => throw TimeoutException('Location request timed out'),
      );

      _updateLocation(position);
      return _currentLatLng;
    } on TimeoutException catch (e) {
      _setError('Location request timed out. Trying with lower accuracy...');
      return _getCurrentLocationFallback();
    } on LocationServiceDisabledException {
      _setError('Location services are disabled. Please enable GPS.');
      return null;
    } on PermissionDeniedException {
      _setError('Location permission denied. Please grant location access.');
      return null;
    } catch (e) {
      _setError('Failed to get current location: $e');
      return _getCurrentLocationFallback();
    }
  }

  // FIXED: Fallback location method with lower accuracy
  Future<LatLng?> _getCurrentLocationFallback() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 15),
      );
      _updateLocation(position);
      _clearError(); // Clear previous timeout error
      return _currentLatLng;
    } catch (e) {
      debugPrint('Fallback location also failed: $e');
      return null;
    }
  }

  // FIXED: Enhanced location tracking with proper stream management
  Future<void> startLocationTracking() async {
    if (_isTracking) {
      debugPrint('Location tracking already active');
      return;
    }

    try {
      if (!_hasPermission) {
        final permissionGranted = await _checkPermissions();
        if (!permissionGranted) return;
      }

      // FIXED: Ensure previous subscription is properly disposed
      await _stopLocationTracking();

      _isTracking = true;
      _clearError();
      _tripStartTime = DateTime.now();
      _currentTrip = 0.0;
      _ensureStreamController();
      notifyListeners();

      debugPrint('Starting location tracking with ${_getSettingsName(_currentSettings)} settings');

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: _currentSettings,
      ).listen(
        _updateLocation,
        onError: (error) {
          _handleLocationError(error);
        },
        onDone: () {
          debugPrint('Location stream completed');
          _isTracking = false;
          notifyListeners();
        },
      );

    } catch (e) {
      _setError('Failed to start location tracking: $e');
      _isTracking = false;
      notifyListeners();
      _startRetryMechanism();
    }
  }

  // FIXED: Proper stream disposal
  Future<void> _stopLocationTracking() async {
    if (_positionSubscription != null) {
      await _positionSubscription!.cancel();
      _positionSubscription = null;
      debugPrint('Location subscription cancelled');
    }
  }

  Future<void> stopLocationTracking() async {
    if (!_isTracking) return;

    await _stopLocationTracking();
    _isTracking = false;
    _retryTimer?.cancel();
    notifyListeners();
    debugPrint('Location tracking stopped');
  }

  // FIXED: Better error handling with smart fallback
  void _handleLocationError(dynamic error) {
    debugPrint('Location stream error: $error');
    
    if (error is TimeoutException || error.toString().contains('timeout') || error.toString().contains('Time limit reached')) {
      _handleTimeoutError();
    } else if (error is LocationServiceDisabledException) {
      _setError('GPS disabled. Please enable location services.');
      _isTracking = false;
    } else if (error is PermissionDeniedException) {
      _setError('Location permission denied.');
      _isTracking = false;
    } else {
      _setError('Location error: $error');
      _fallbackToLowerAccuracy();
    }
    
    notifyListeners();
  }

  // FIXED: Timeout handling with progressive fallback
  void _handleTimeoutError() {
    _poorSignalCount++;
    debugPrint('Location timeout (count: $_poorSignalCount)');
    
    if (_poorSignalCount >= 2) {
      _fallbackToLowerAccuracy();
    } else {
      _setError('GPS signal weak. Retrying...');
      _restartLocationTracking();
    }
  }

  // FIXED: Smart settings fallback
  void _fallbackToLowerAccuracy() {
    if (_currentSettings == _highAccuracySettings) {
      _currentSettings = _balancedSettings;
      debugPrint('Switching to balanced location settings');
    } else if (_currentSettings == _balancedSettings) {
      _currentSettings = _lowPowerSettings;
      debugPrint('Switching to low power location settings');
    } else {
      // Already at lowest setting, just restart
      debugPrint('Already at lowest settings, restarting...');
    }
    
    // FIXED: Don't restart immediately if already tracking
    if (_isTracking) {
      _restartLocationTracking();
    }
  }

  // FIXED: Prevent rapid restart loops
  void _restartLocationTracking() async {
    if (_isRetrying) return;
    
    _isRetrying = true;
    await _stopLocationTracking();
    await Future.delayed(const Duration(seconds: 3)); // Wait before restart
    if (_isTracking) { // Only restart if still supposed to be tracking
      await startLocationTracking();
    }
    _isRetrying = false;
  }

  String _getSettingsName(LocationSettings settings) {
    if (settings == _highAccuracySettings) return 'High Accuracy';
    if (settings == _balancedSettings) return 'Balanced';
    if (settings == _lowPowerSettings) return 'Low Power';
    return 'Custom';
  }

  // FIXED: Improved retry mechanism
  void _startRetryMechanism() {
    if (_retryCount >= _maxRetries || _isRetrying) {
      debugPrint('Maximum retry attempts reached or already retrying');
      return;
    }

    _retryTimer?.cancel();
    _isRetrying = true;
    
    final backoffDelay = Duration(seconds: _retryInterval.inSeconds * (_retryCount + 1));
    _retryTimer = Timer(backoffDelay, () async {
      _retryCount++;
      debugPrint('Retrying location initialization (attempt $_retryCount/$_maxRetries)');
      
      try {
        await _checkPermissions();
        if (_hasPermission && !_isTracking && !_isInitializing) {
          await startLocationTracking();
        }
        _isRetrying = false;
      } catch (e) {
        debugPrint('Retry failed: $e');
        _isRetrying = false;
        if (_retryCount < _maxRetries) {
          _startRetryMechanism();
        }
      }
    });
  }

  // Location update with enhanced filtering
  void _updateLocation(Position position) {
    final newLocation = LatLng(position.latitude, position.longitude);
    
    // FIXED: Validate location data
    if (!isValidLocation(newLocation)) {
      debugPrint('Invalid location received: ${position.latitude}, ${position.longitude}');
      return;
    }

    // FIXED: Filter out obviously bad readings
    if (position.accuracy > 100) {
      debugPrint('Location accuracy too poor: ${position.accuracy}m');
      return;
    }

    _currentPosition = position;
    _currentLatLng = newLocation;
    _accuracy = position.accuracy;
    _speed = position.speed;
    _heading = position.heading;
    _lastUpdateTime = DateTime.now();
    _isLocationStale = false;
    _poorSignalCount = 0; // Reset on successful update

    // Update accuracy history
    _accuracyHistory.add(_accuracy);
    if (_accuracyHistory.length > 10) {
      _accuracyHistory.removeAt(0);
    }

    // Distance calculation
    if (_lastLocationForDistance != null) {
      final distance = _calculateDistance(_lastLocationForDistance!, newLocation);
      if (distance > 2.0) { // Only count significant movements
        _totalDistance += distance;
        _currentTrip += distance;
      }
    }
    _lastLocationForDistance = newLocation;

    _addToHistory(newLocation);
    
    // FIXED: Safe stream addition
    _ensureStreamController();
    if (!_isStreamControllerClosed) {
      _locationStreamController!.add(newLocation);
    }
    
    notifyListeners();
    
    debugPrint('Location updated: ${position.latitude}, ${position.longitude} (±${_accuracy.toStringAsFixed(1)}m)');
  }

  // Internal method to get current location
  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );
      _updateLocation(position);
    } catch (e) {
      debugPrint('Failed to get initial location: $e');
    }
  }

  // Location quality monitoring
  void _startLocationQualityMonitoring() {
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_lastUpdateTime != null) {
        final timeSinceUpdate = DateTime.now().difference(_lastUpdateTime!);
        if (timeSinceUpdate.inMinutes > 3) { // Increased threshold
          _isLocationStale = true;
          notifyListeners();
        }
      }
    });
  }

  // Add location to history with optimization
  void _addToHistory(LatLng location) {
    // Only add if significantly different from last location
    if (_locationHistory.isNotEmpty) {
      final lastLocation = _locationHistory.last;
      final distance = _calculateDistance(lastLocation, location);
      if (distance < 3.0) return; // Increased threshold to reduce noise
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
    final key = '${point1.latitude.toStringAsFixed(6)},${point1.longitude.toStringAsFixed(6)}-${point2.latitude.toStringAsFixed(6)},${point2.longitude.toStringAsFixed(6)}';
    
    if (_distanceCache.containsKey(key)) {
      return _distanceCache[key]!;
    }

    const double earthRadius = 6371000; // Earth radius in meters
    
    final lat1Rad = point1.latitude * (math.pi / 180);
    final lat2Rad = point2.latitude * (math.pi / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (math.pi / 180);

    final a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    final distance = earthRadius * c;
    
    // Cache the result
    if (_distanceCache.length > 100) {
      _distanceCache.clear(); // Clear cache if it gets too large
    }
    _distanceCache[key] = distance;
    
    return distance;
  }

  // Enhanced accuracy status
  String get accuracyStatus {
    if (_accuracy <= 5) return 'Excellent';
    if (_accuracy <= 10) return 'Good';
    if (_accuracy <= 20) return 'Fair';
    if (_accuracy <= 50) return 'Poor';
    return 'Very Poor';
  }

  bool get isLocationAccurate => _accuracy <= 20;

  // Enhanced speed calculation
  double get speedKmh => _speed * 3.6; // Convert m/s to km/h

  // Movement detection
  String get movementType {
    if (_speed < 0.5) return 'Stationary';
    if (_speed < 2.0) return 'Walking';
    if (_speed < 6.0) return 'Running';
    if (_speed < 15.0) return 'Cycling';
    return 'Vehicle';
  }

  // Compass direction
  String get compassDirection {
    if (_heading < 0) return 'Unknown';
    
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((_heading + 22.5) / 45).floor() % 8;
    return directions[index];
  }

  // Trip duration
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
      'isRetrying': _isRetrying,
      'isInitializing': _isInitializing,
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
      _ensureStreamController();
      if (!_isStreamControllerClosed) {
        _locationStreamController!.add(location);
      }
      debugPrint('Mock location set: ${location.latitude}, ${location.longitude}');
    }
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
           location.longitude <= 180 &&
           location.latitude != 0.0 && 
           location.longitude != 0.0; // Exclude null island
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
}