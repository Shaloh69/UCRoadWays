import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/services.dart';

class LocationProvider extends ChangeNotifier {
  Position? _currentPosition;
  LatLng? _currentLatLng;
  StreamSubscription<Position>? _positionSubscription;
  bool _isTracking = false;
  String? _error;

  Position? get currentPosition => _currentPosition;
  LatLng? get currentLatLng => _currentLatLng;
  bool get isTracking => _isTracking;
  String? get error => _error;

  Future<void> startLocationTracking() async {
    try {
      _error = null;
      
      if (!await PermissionService.hasLocationPermission()) {
        await PermissionService.requestPermissions();
      }

      // Get initial position
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        _updatePosition(position);
      }

      // Start position stream
      _positionSubscription = LocationService.getPositionStream().listen(
        _updatePosition,
        onError: (error) {
          _error = error.toString();
          _isTracking = false;
          notifyListeners();
        },
      );

      _isTracking = true;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isTracking = false;
      notifyListeners();
    }
  }

  void stopLocationTracking() {
    _positionSubscription?.cancel();
    _isTracking = false;
    notifyListeners();
  }

  void _updatePosition(Position position) {
    _currentPosition = position;
    _currentLatLng = LatLng(position.latitude, position.longitude);
    notifyListeners();
  }

  @override
  void dispose() {
    stopLocationTracking();
    super.dispose();
  }
}
