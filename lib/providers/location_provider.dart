import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
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

  // Location history
  final List<LatLng> _locationHistory = [];
  static const int _maxHistoryLength = 100;

  // Streams
  StreamSubscription<Position>? _positionSubscription;
  final StreamController<LatLng> _locationStreamController = StreamController<LatLng>.broadcast();

  // Distance tracking
  double _totalDistance = 0.0;
  LatLng? _lastLocationForDistance;

  // Getters
  LatLng? get currentLatLng => _currentLatLng;
  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  bool get hasPermission => _hasPermission;
  String? get error => _error;
  double get accuracy => _accuracy;
  double get speed => _speed;
  double get heading => _heading;
  List<LatLng> get locationHistory => List.unmodifiable(_locationHistory);
  Stream<LatLng> get locationStream => _locationStreamController.stream;
  double get totalDistance => _totalDistance;
  bool get hasLocation => _currentLatLng != null;

  // Location settings
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 1, // Update every 1 meter
    timeLimit: Duration(seconds: 10),
  );

  // Initialization
  LocationProvider() {
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      await _checkPermissions();
      if (_hasPermission) {
        await _getCurrentLocation();
      }
    } catch (e) {
      _setError('Failed to initialize location: $e');
    }
  }

  // Permission handling
  Future<bool> _checkPermissions() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setError('Location services are disabled');
        return false;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _setError('Location permissions are denied');
          return false;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _setError('Location permissions are permanently denied');
        return false;
      }

      _hasPermission = true;
      _clearError();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Permission check failed: $e');
      return false;
    }
  }

  // Get current location once
  Future<LatLng?> getCurrentLocation() async {
    try {
      if (!_hasPermission) {
        final permissionGranted = await _checkPermissions();
        if (!permissionGranted) return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      _updateLocation(position);
      return _currentLatLng;
    } catch (e) {
      _setError('Failed to get current location: $e');
      return null;
    }
  }

  // Start continuous location tracking
  Future<void> startLocationTracking() async {
    try {
      if (_isTracking) return;

      if (!_hasPermission) {
        final permissionGranted = await _checkPermissions();
        if (!permissionGranted) return;
      }

      _isTracking = true;
      _clearError();
      notifyListeners();

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: _locationSettings,
      ).listen(
        _updateLocation,
        onError: (error) {
          _setError('Location tracking error: $error');
          _stopLocationTracking();
        },
      );

      debugPrint('Location tracking started');
    } catch (e) {
      _setError('Failed to start location tracking: $e');
      _isTracking = false;
      notifyListeners();
    }
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
    notifyListeners();
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

  // Update location data
  void _updateLocation(Position position) {
    _currentPosition = position;
    final newLatLng = LatLng(position.latitude, position.longitude);
    
    // Update distance tracking
    if (_lastLocationForDistance != null) {
      final distance = _calculateDistance(_lastLocationForDistance!, newLatLng);
      _totalDistance += distance;
    }
    _lastLocationForDistance = newLatLng;

    _currentLatLng = newLatLng;
    _accuracy = position.accuracy;
    _speed = position.speed;
    _heading = position.heading;

    // Add to history
    _addToHistory(newLatLng);

    // Clear any errors
    _clearError();

    // Notify listeners
    notifyListeners();
    
    // Emit to stream
    _locationStreamController.add(newLatLng);
  }

  // Add location to history
  void _addToHistory(LatLng location) {
    _locationHistory.add(location);
    
    // Keep history within limits
    if (_locationHistory.length > _maxHistoryLength) {
      _locationHistory.removeAt(0);
    }
  }

  // Calculate distance between two points in meters
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // meters
    final double lat1Rad = point1.latitude * pi / 180;
    final double lat2Rad = point2.latitude * pi / 180;
    final double deltaLatRad = (point2.latitude - point1.latitude) * pi / 180;
    final double deltaLngRad = (point2.longitude - point1.longitude) * pi / 180;

    final double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // Calculate distance to a point
  double? getDistanceTo(LatLng destination) {
    if (_currentLatLng == null) return null;
    return _calculateDistance(_currentLatLng!, destination);
  }

  // Get bearing to a point
  double? getBearingTo(LatLng destination) {
    if (_currentLatLng == null) return null;
    
    final double lat1Rad = _currentLatLng!.latitude * pi / 180;
    final double lat2Rad = destination.latitude * pi / 180;
    final double deltaLngRad = (destination.longitude - _currentLatLng!.longitude) * pi / 180;

    final double y = sin(deltaLngRad) * cos(lat2Rad);
    final double x = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(deltaLngRad);

    double bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360; // Normalize to 0-360
  }

  // Check if location is accurate enough
  bool get isLocationAccurate => _accuracy > 0 && _accuracy <= 10; // Within 10 meters

  // Get location accuracy status
  String get accuracyStatus {
    if (_accuracy <= 5) return 'Excellent';
    if (_accuracy <= 10) return 'Good';
    if (_accuracy <= 20) return 'Fair';
    return 'Poor';
  }

  // Get speed in different units
  double get speedKmh => _speed * 3.6; // Convert m/s to km/h
  double get speedMph => _speed * 2.237; // Convert m/s to mph

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

  // Get location statistics
  Map<String, dynamic> getLocationStats() {
    return {
      'isTracking': _isTracking,
      'hasPermission': _hasPermission,
      'hasLocation': hasLocation,
      'accuracy': _accuracy,
      'speed': _speed,
      'heading': _heading,
      'compassDirection': compassDirection,
      'totalDistance': _totalDistance,
      'historyCount': _locationHistory.length,
      'accuracyStatus': accuracyStatus,
      'isLocationAccurate': isLocationAccurate,
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
      await openAppSettings();
    } catch (e) {
      debugPrint('Failed to open app settings: $e');
    }
  }

  // Mock location for testing (only in debug mode)
  void setMockLocation(LatLng location) {
    if (kDebugMode) {
      _currentLatLng = location;
      _accuracy = 5.0; // Mock good accuracy
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
      minLat = min(minLat, location.latitude);
      maxLat = max(maxLat, location.latitude);
      minLng = min(minLng, location.longitude);
      maxLng = max(maxLng, location.longitude);
    }
    
    return {
      'southWest': LatLng(minLat, minLng),
      'northEast': LatLng(maxLat, maxLng),
    };
  }

  @override
  void dispose() {
    _stopLocationTracking();
    _locationStreamController.close();
    super.dispose();
  }
}