import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../services/offline_tile_service.dart';
import 'dart:math';

class OfflineMapProvider extends ChangeNotifier {
  final OfflineTileService _offlineService = OfflineTileService();
  
  // Download state
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _currentRegionName = '';
  int _currentTileCount = 0;
  int _totalTileCount = 0;
  
  // Offline preference
  bool _preferOffline = true;
  
  // Downloaded regions
  List<OfflineRegion> _downloadedRegions = [];
  bool _isLoadingRegions = false;

  // Getters
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String get currentRegionName => _currentRegionName;
  int get currentTileCount => _currentTileCount;
  int get totalTileCount => _totalTileCount;
  bool get preferOffline => _preferOffline;
  List<OfflineRegion> get downloadedRegions => _downloadedRegions;
  bool get isLoadingRegions => _isLoadingRegions;

  String get downloadProgressText {
    if (!_isDownloading) return '';
    final percentage = (_downloadProgress * 100).toStringAsFixed(1);
    return 'Downloading $_currentRegionName: $_currentTileCount/$_totalTileCount tiles ($percentage%)';
  }

  Future<void> initialize() async {
    await _offlineService.initialize();
    await loadDownloadedRegions();
  }

  /// Download tiles for a specific region
  Future<void> downloadRegion({
    required LatLng northEast,
    required LatLng southWest,
    required String regionName,
    int minZoom = 10,
    int maxZoom = 18,
  }) async {
    if (_isDownloading) {
      throw Exception('Another download is already in progress');
    }

    _isDownloading = true;
    _downloadProgress = 0.0;
    _currentRegionName = regionName;
    _currentTileCount = 0;
    _totalTileCount = 0;
    notifyListeners();

    try {
      await _offlineService.downloadRegion(
        northEast: northEast,
        southWest: southWest,
        regionName: regionName,
        minZoom: minZoom,
        maxZoom: maxZoom,
        onProgress: (current, total) {
          _currentTileCount = current;
          _totalTileCount = total;
          _downloadProgress = total > 0 ? current / total : 0.0;
          notifyListeners();
        },
      );

      // Refresh regions list
      await loadDownloadedRegions();
      
      debugPrint('Successfully downloaded region: $regionName');
    } catch (e) {
      debugPrint('Error downloading region $regionName: $e');
      rethrow;
    } finally {
      _isDownloading = false;
      _downloadProgress = 0.0;
      _currentRegionName = '';
      _currentTileCount = 0;
      _totalTileCount = 0;
      notifyListeners();
    }
  }

  /// Download tiles for current map view
  Future<void> downloadCurrentView({
    required LatLng center,
    required double zoom,
    required String regionName,
    double radiusKm = 1.0,
  }) async {
    // Calculate bounding box around center point
    const double earthRadius = 6371; // km
    final double latRadiusDegrees = (radiusKm / earthRadius) * (180 / pi);
    final double lngRadiusDegrees = latRadiusDegrees / cos(center.latitude * pi / 180);

    final northEast = LatLng(
      center.latitude + latRadiusDegrees,
      center.longitude + lngRadiusDegrees,
    );
    final southWest = LatLng(
      center.latitude - latRadiusDegrees,
      center.longitude - lngRadiusDegrees,
    );

    // Determine zoom levels based on current zoom
    final minZoom = (zoom - 2).clamp(10, 19).round();
    final maxZoom = (zoom + 2).clamp(10, 19).round();

    await downloadRegion(
      northEast: northEast,
      southWest: southWest,
      regionName: regionName,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );
  }

  /// Load list of downloaded regions
  Future<void> loadDownloadedRegions() async {
    _isLoadingRegions = true;
    notifyListeners();

    try {
      _downloadedRegions = await _offlineService.getDownloadedRegions();
    } catch (e) {
      debugPrint('Error loading downloaded regions: $e');
      _downloadedRegions = [];
    } finally {
      _isLoadingRegions = false;
      notifyListeners();
    }
  }

  /// Delete a downloaded region
  Future<void> deleteRegion(String regionName) async {
    try {
      await _offlineService.deleteRegion(regionName);
      await loadDownloadedRegions();
      debugPrint('Successfully deleted region: $regionName');
    } catch (e) {
      debugPrint('Error deleting region $regionName: $e');
      rethrow;
    }
  }

  /// Toggle offline preference
  void setPreferOffline(bool prefer) {
    _preferOffline = prefer;
    notifyListeners();
  }

  /// Get total storage size
  Future<int> getTotalStorageSize() async {
    return await _offlineService.getTotalStorageSize();
  }

  /// Clear old tiles
  Future<void> clearOldTiles(int olderThanDays) async {
    try {
      await _offlineService.clearOldTiles(olderThanDays);
      await loadDownloadedRegions();
      debugPrint('Successfully cleared old tiles');
    } catch (e) {
      debugPrint('Error clearing old tiles: $e');
      rethrow;
    }
  }

  /// Check if a tile exists locally
  Future<bool> hasTile(int z, int x, int y) async {
    return await _offlineService.hasTile(z, x, y);
  }

  /// Cancel current download
  void cancelDownload() {
    if (_isDownloading) {
      _isDownloading = false;
      _downloadProgress = 0.0;
      _currentRegionName = '';
      _currentTileCount = 0;
      _totalTileCount = 0;
      notifyListeners();
    }
  }

  /// Calculate estimated download size
  int estimateDownloadSize({
    required LatLng northEast,
    required LatLng southWest,
    int minZoom = 10,
    int maxZoom = 18,
  }) {
    int totalTiles = 0;
    
    for (int z = minZoom; z <= maxZoom; z++) {
      final nwTile = _deg2tile(northEast.latitude, southWest.longitude, z);
      final seTile = _deg2tile(southWest.latitude, northEast.longitude, z);
      
      final tilesInZoom = (seTile.x - nwTile.x + 1) * (seTile.y - nwTile.y + 1);
      totalTiles += tilesInZoom;
    }
    
    // Estimate: average tile size is ~20KB
    return totalTiles * 20 * 1024;
  }

  TileCoordinate _deg2tile(double lat, double lng, int zoom) {
    final x = ((lng + 180.0) / 360.0 * (1 << zoom)).floor();
    final y = ((1.0 - log(tan(lat * pi / 180.0) + 1.0 / cos(lat * pi / 180.0)) / pi) / 2.0 * (1 << zoom)).floor();
    return TileCoordinate(zoom, x, y);
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  void dispose() {
    _offlineService.dispose();
    super.dispose();
  }
}