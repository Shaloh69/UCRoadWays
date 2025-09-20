import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/offline_tile_service.dart';
import 'dart:math' as math;
import 'dart:async';

class OfflineMapProvider extends ChangeNotifier {
  final OfflineTileService _offlineService = OfflineTileService();
  
  // Download state
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _currentRegionName = '';
  int _currentTileCount = 0;
  int _totalTileCount = 0;
  String? _downloadError;
  
  // Offline preference
  bool _preferOffline = true;
  bool _autoDownload = false;
  int _maxCacheSize = 500 * 1024 * 1024; // 500MB default
  int _autoCleanupDays = 30;
  
  // Downloaded regions
  List<OfflineRegion> _downloadedRegions = [];
  bool _isLoadingRegions = false;
  String? _regionsError;
  
  // Initialization state
  bool _isInitialized = false;
  String? _initializationError;
  
  // Download queue management
  final List<_DownloadRequest> _downloadQueue = [];
  bool _isProcessingQueue = false;
  
  // Statistics
  int _totalDownloadedTiles = 0;
  int _totalDownloadedSize = 0;
  DateTime? _lastDownloadTime;

  // Getters
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String get currentRegionName => _currentRegionName;
  int get currentTileCount => _currentTileCount;
  int get totalTileCount => _totalTileCount;
  String? get downloadError => _downloadError;
  bool get preferOffline => _preferOffline;
  bool get autoDownload => _autoDownload;
  int get maxCacheSize => _maxCacheSize;
  int get autoCleanupDays => _autoCleanupDays;
  List<OfflineRegion> get downloadedRegions => List.unmodifiable(_downloadedRegions);
  bool get isLoadingRegions => _isLoadingRegions;
  String? get regionsError => _regionsError;
  bool get isInitialized => _isInitialized;
  String? get initializationError => _initializationError;
  bool get hasQueuedDownloads => _downloadQueue.isNotEmpty;
  int get queuedDownloadsCount => _downloadQueue.length;
  int get totalDownloadedTiles => _totalDownloadedTiles;
  String get formattedDownloadedSize => formatBytes(_totalDownloadedSize);

  String get downloadProgressText {
    if (!_isDownloading) return '';
    final percentage = (_downloadProgress * 100).toStringAsFixed(1);
    return 'Downloading $_currentRegionName: $_currentTileCount/$_totalTileCount tiles ($percentage%)';
  }

  String get downloadStatusText {
    if (_isDownloading) return downloadProgressText;
    if (_downloadError != null) return 'Download failed: $_downloadError';
    if (_downloadQueue.isNotEmpty) return '${_downloadQueue.length} downloads queued';
    if (_lastDownloadTime != null) {
      final timeSince = DateTime.now().difference(_lastDownloadTime!);
      if (timeSince.inDays > 0) {
        return 'Last download: ${timeSince.inDays} days ago';
      } else if (timeSince.inHours > 0) {
        return 'Last download: ${timeSince.inHours} hours ago';
      } else {
        return 'Last download: ${timeSince.inMinutes} minutes ago';
      }
    }
    return 'No downloads yet';
  }

  /// Initialize the provider
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _loadPreferences();
      await loadDownloadedRegions();
      _isInitialized = true;
      debugPrint('OfflineMapProvider initialized successfully');
    } catch (e) {
      _initializationError = e.toString();
      debugPrint('Failed to initialize OfflineMapProvider: $e');
    } finally {
      notifyListeners();
    }
  }

  /// Load preferences from SharedPreferences
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _preferOffline = prefs.getBool('prefer_offline') ?? true;
      _autoDownload = prefs.getBool('auto_download') ?? false;
      _maxCacheSize = prefs.getInt('max_cache_size') ?? (500 * 1024 * 1024);
      _autoCleanupDays = prefs.getInt('auto_cleanup_days') ?? 30;
      
      debugPrint('Loaded preferences: preferOffline=$_preferOffline, autoDownload=$_autoDownload');
    } catch (e) {
      debugPrint('Failed to load preferences: $e');
    }
  }

  /// Save preferences to SharedPreferences
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('prefer_offline', _preferOffline);
      await prefs.setBool('auto_download', _autoDownload);
      await prefs.setInt('max_cache_size', _maxCacheSize);
      await prefs.setInt('auto_cleanup_days', _autoCleanupDays);
    } catch (e) {
      debugPrint('Failed to save preferences: $e');
    }
  }

  /// Download tiles for a specific region
  Future<void> downloadRegion({
    required LatLng northEast,
    required LatLng southWest,
    required String regionName,
    int minZoom = 10,
    int maxZoom = 18,
    bool priority = false,
  }) async {
    // Validate parameters
    if (regionName.trim().isEmpty) {
      throw ArgumentError('Region name cannot be empty');
    }
    
    if (minZoom < 0 || maxZoom > 19 || minZoom > maxZoom) {
      throw ArgumentError('Invalid zoom levels: minZoom=$minZoom, maxZoom=$maxZoom');
    }
    
    if (!_isValidBounds(northEast, southWest)) {
      throw ArgumentError('Invalid bounds provided');
    }

    final request = _DownloadRequest(
      northEast: northEast,
      southWest: southWest,
      regionName: regionName.trim(),
      minZoom: minZoom,
      maxZoom: maxZoom,
      priority: priority,
      requestTime: DateTime.now(),
    );

    // Check if already downloading this region
    if (_isDownloading && _currentRegionName == regionName) {
      debugPrint('Region $regionName is already being downloaded');
      return;
    }

    // Check if region already exists
    if (_downloadedRegions.any((r) => r.name == regionName)) {
      final shouldReplace = await _confirmReplaceRegion(regionName);
      if (!shouldReplace) return;
      
      await deleteRegion(regionName);
    }

    // Add to queue or start immediately
    if (priority || !_isDownloading) {
      if (priority && _downloadQueue.isNotEmpty) {
        _downloadQueue.insert(0, request);
      } else {
        _downloadQueue.add(request);
      }
      
      if (!_isDownloading) {
        await _processDownloadQueue();
      }
    } else {
      _downloadQueue.add(request);
    }
    
    notifyListeners();
  }

  /// Download current map view
  Future<void> downloadCurrentView({
    required LatLng center,
    required double zoom,
    String? regionName,
    double radiusKm = 2.0,
    int minZoom = 10,
    int maxZoom = 17,
  }) async {
    // Calculate bounds from center and radius
    const double kmToLatDegrees = 1.0 / 110.574;
    final double kmToLngDegrees = 1.0 / (111.320 * math.cos(center.latitude * math.pi / 180));
    
    final double latOffset = radiusKm * kmToLatDegrees;
    final double lngOffset = radiusKm * kmToLngDegrees;
    
    final northEast = LatLng(
      center.latitude + latOffset,
      center.longitude + lngOffset,
    );
    
    final southWest = LatLng(
      center.latitude - latOffset,
      center.longitude - lngOffset,
    );
    
    final finalRegionName = regionName ?? 'Location_${DateTime.now().millisecondsSinceEpoch}';
    
    await downloadRegion(
      northEast: northEast,
      southWest: southWest,
      regionName: finalRegionName,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );
  }

  /// Refresh/update existing region
  Future<void> refreshRegion(String regionName) async {
    final region = getRegion(regionName);
    if (region == null) {
      throw ArgumentError('Region $regionName not found');
    }
    
    await downloadRegion(
      northEast: region.northEast,
      southWest: region.southWest,
      regionName: regionName,
      minZoom: region.minZoom,
      maxZoom: region.maxZoom,
    );
  }

  /// Export region data (for backup/sharing)
  Map<String, dynamic> exportRegionInfo(String regionName) {
    final region = getRegion(regionName);
    if (region == null) {
      throw ArgumentError('Region $regionName not found');
    }
    
    return {
      'name': region.name,
      'northEast': {
        'latitude': region.northEast.latitude,
        'longitude': region.northEast.longitude,
      },
      'southWest': {
        'latitude': region.southWest.latitude,
        'longitude': region.southWest.longitude,
      },
      'minZoom': region.minZoom,
      'maxZoom': region.maxZoom,
      'tileCount': region.tileCount,
      'sizeBytes': region.sizeBytes,
      'downloadedAt': region.downloadedAt.toIso8601String(),
    };
  }

  /// Import region info (for restoration)
  Future<void> importAndDownloadRegion(Map<String, dynamic> regionInfo) async {
    final northEast = LatLng(
      regionInfo['northEast']['latitude'],
      regionInfo['northEast']['longitude'],
    );
    
    final southWest = LatLng(
      regionInfo['southWest']['latitude'],
      regionInfo['southWest']['longitude'],
    );
    
    await downloadRegion(
      northEast: northEast,
      southWest: southWest,
      regionName: regionInfo['name'],
      minZoom: regionInfo['minZoom'],
      maxZoom: regionInfo['maxZoom'],
    );
  }

  Future<bool> _confirmReplaceRegion(String regionName) async {
    // In a real implementation, show a confirmation dialog
    // For now, assume user confirms
    return true;
  }

  bool _isValidBounds(LatLng northEast, LatLng southWest) {
    return northEast.latitude > southWest.latitude &&
           northEast.longitude > southWest.longitude &&
           northEast.latitude <= 90 &&
           southWest.latitude >= -90 &&
           northEast.longitude <= 180 &&
           southWest.longitude >= -180;
  }

  Future<void> _processDownloadQueue() async {
    if (_isProcessingQueue || _downloadQueue.isEmpty) return;
    
    _isProcessingQueue = true;
    
    while (_downloadQueue.isNotEmpty && !(_downloadError?.isNotEmpty ?? false)) {
      final request = _downloadQueue.removeAt(0);
      await _executeDownload(request);
    }
    
    _isProcessingQueue = false;
  }

  Future<void> _executeDownload(_DownloadRequest request) async {
    try {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _currentRegionName = request.regionName;
      _currentTileCount = 0;
      _totalTileCount = 0;
      _downloadError = null;
      notifyListeners();

      // Calculate estimated tile count
      _totalTileCount = _calculateTileCount(
        request.northEast,
        request.southWest,
        request.minZoom,
        request.maxZoom,
      );

      debugPrint('Starting download of ${request.regionName}: $_totalTileCount estimated tiles');

      await _offlineService.downloadRegion(
        northEast: request.northEast,
        southWest: request.southWest,
        regionName: request.regionName,
        minZoom: request.minZoom,
        maxZoom: request.maxZoom,
        onProgress: (current, total) {
          _currentTileCount = current;
          _totalTileCount = total;
          _downloadProgress = total > 0 ? current / total : 0.0;
          notifyListeners();
        },
      );

      // Update statistics
      _totalDownloadedTiles += _currentTileCount;
      _lastDownloadTime = DateTime.now();
      
      // Reload regions to include the new one
      await loadDownloadedRegions();

      debugPrint('Successfully downloaded ${request.regionName}: $_currentTileCount tiles');
      
    } catch (e) {
      _downloadError = e.toString();
      debugPrint('Download failed for ${request.regionName}: $e');
    } finally {
      _isDownloading = false;
      _downloadProgress = 0.0;
      _currentRegionName = '';
      _currentTileCount = 0;
      _totalTileCount = 0;
      notifyListeners();
    }
  }

  int _calculateTileCount(LatLng northEast, LatLng southWest, int minZoom, int maxZoom) {
    int totalTiles = 0;
    
    for (int zoom = minZoom; zoom <= maxZoom; zoom++) {
      final tilesPerSide = math.pow(2, zoom).round();
      
      // Calculate tile boundaries
      final minX = _longitudeToTileX(southWest.longitude, zoom);
      final maxX = _longitudeToTileX(northEast.longitude, zoom);
      final minY = _latitudeToTileY(northEast.latitude, zoom);
      final maxY = _latitudeToTileY(southWest.latitude, zoom);
      
      final tilesX = (maxX - minX + 1).clamp(0, tilesPerSide);
      final tilesY = (maxY - minY + 1).clamp(0, tilesPerSide);
      
      totalTiles += tilesX * tilesY;
    }
    
    return totalTiles;
  }

  int _longitudeToTileX(double longitude, int zoom) {
    return ((longitude + 180.0) / 360.0 * math.pow(2, zoom)).floor();
  }

  int _latitudeToTileY(double latitude, int zoom) {
    final latRad = latitude * math.pi / 180.0;
    return ((1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) / 2.0 * math.pow(2, zoom)).floor();
  }

  /// Cancel current download
  Future<void> cancelDownload() async {
    if (!_isDownloading) return;
    
    try {
      await _offlineService.cancelDownload();
      _downloadError = 'Download cancelled by user';
      debugPrint('Download cancelled for $_currentRegionName');
    } catch (e) {
      debugPrint('Failed to cancel download: $e');
    } finally {
      _isDownloading = false;
      _downloadProgress = 0.0;
      _currentRegionName = '';
      _currentTileCount = 0;
      _totalTileCount = 0;
      notifyListeners();
    }
  }

  /// Clear download queue
  void clearDownloadQueue() {
    _downloadQueue.clear();
    notifyListeners();
  }

  /// Load downloaded regions
  Future<void> loadDownloadedRegions() async {
    _isLoadingRegions = true;
    _regionsError = null;
    notifyListeners();
    
    try {
      _downloadedRegions = await _offlineService.getDownloadedRegions();
      
      // Update statistics
      _totalDownloadedSize = _downloadedRegions.fold<int>(
        0, 
        (sum, region) => sum + region.sizeBytes,
      );
      
      debugPrint('Loaded ${_downloadedRegions.length} offline regions');
    } catch (e) {
      _regionsError = 'Failed to load regions: $e';
      debugPrint(_regionsError);
    } finally {
      _isLoadingRegions = false;
      notifyListeners();
    }
  }

  /// Delete a specific region
  Future<void> deleteRegion(String regionName) async {
    try {
      await _offlineService.deleteRegion(regionName);
      
      // Remove from local list
      _downloadedRegions.removeWhere((region) => region.name == regionName);
      
      // Update statistics
      _totalDownloadedSize = _downloadedRegions.fold<int>(
        0,
        (sum, region) => sum + region.sizeBytes,
      );
      
      debugPrint('Deleted region: $regionName');
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to delete region $regionName: $e');
      rethrow;
    }
  }

  /// Delete all offline regions
  Future<void> deleteAllRegions() async {
    try {
      for (final region in _downloadedRegions) {
        await _offlineService.deleteRegion(region.name);
      }
      
      _downloadedRegions.clear();
      _totalDownloadedSize = 0;
      
      debugPrint('Deleted all offline regions');
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to delete all regions: $e');
      rethrow;
    }
  }

  /// Set offline preference
  void setPreferOffline(bool prefer) {
    if (_preferOffline != prefer) {
      _preferOffline = prefer;
      _savePreferences();
      notifyListeners();
      debugPrint('Prefer offline set to: $prefer');
    }
  }

  /// Set auto-download preference
  void setAutoDownload(bool auto) {
    if (_autoDownload != auto) {
      _autoDownload = auto;
      _savePreferences();
      notifyListeners();
      debugPrint('Auto-download set to: $auto');
    }
  }

  /// Set maximum cache size
  void setMaxCacheSize(int sizeBytes) {
    if (_maxCacheSize != sizeBytes) {
      _maxCacheSize = sizeBytes;
      _savePreferences();
      notifyListeners();
      debugPrint('Max cache size set to: ${formatBytes(sizeBytes)}');
    }
  }

  /// Set auto-cleanup days
  void setAutoCleanupDays(int days) {
    if (_autoCleanupDays != days) {
      _autoCleanupDays = days;
      _savePreferences();
      notifyListeners();
      debugPrint('Auto-cleanup days set to: $days');
    }
  }

  /// Get storage statistics
  Map<String, dynamic> getStorageStats() {
    return {
      'totalRegions': _downloadedRegions.length,
      'totalSize': _totalDownloadedSize,
      'formattedSize': formatBytes(_totalDownloadedSize),
      'totalTiles': _totalDownloadedTiles,
      'maxCacheSize': _maxCacheSize,
      'formattedMaxSize': formatBytes(_maxCacheSize),
      'usagePercentage': _maxCacheSize > 0 ? (_totalDownloadedSize / _maxCacheSize * 100).clamp(0.0, 100.0) : 0.0,
      'lastDownload': _lastDownloadTime?.toIso8601String(),
    };
  }

  /// Check if a region exists by name
  bool hasRegion(String regionName) {
    return _downloadedRegions.any((region) => region.name == regionName);
  }

  /// Get region by name
  OfflineRegion? getRegion(String regionName) {
    try {
      return _downloadedRegions.firstWhere((region) => region.name == regionName);
    } catch (e) {
      return null;
    }
  }

  /// Get regions that cover a specific point
  List<OfflineRegion> getRegionsContaining(LatLng point) {
    return _downloadedRegions.where((region) {
      return point.latitude <= region.northEast.latitude &&
             point.latitude >= region.southWest.latitude &&
             point.longitude <= region.northEast.longitude &&
             point.longitude >= region.southWest.longitude;
    }).toList();
  }

  /// Estimate download size for a region
  int estimateDownloadSize(LatLng northEast, LatLng southWest, int minZoom, int maxZoom) {
    final tileCount = _calculateTileCount(northEast, southWest, minZoom, maxZoom);
    const avgTileSize = 15 * 1024; // Estimate 15KB per tile
    return tileCount * avgTileSize;
  }

  /// Format bytes to human readable string
  String formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Auto-cleanup old tiles
  Future<void> _scheduleAutoCleanup() async {
    if (_autoCleanupDays <= 0) return;
    
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: _autoCleanupDays));
      int deletedCount = 0;
      
      final regionsToDelete = _downloadedRegions.where((region) => 
          region.downloadedAt.isBefore(cutoffDate)).toList();
      
      for (final region in regionsToDelete) {
        await deleteRegion(region.name);
        deletedCount++;
      }
      
      if (deletedCount > 0) {
        debugPrint('Auto-cleanup removed $deletedCount old regions');
      }
    } catch (e) {
      debugPrint('Auto-cleanup failed: $e');
    }
  }

  /// Manual cleanup of old tiles
  Future<int> cleanupOldTiles(int daysOld) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      int deletedCount = 0;
      
      final regionsToDelete = _downloadedRegions.where((region) => 
          region.downloadedAt.isBefore(cutoffDate)).toList();
      
      for (final region in regionsToDelete) {
        await deleteRegion(region.name);
        deletedCount++;
      }
      
      debugPrint('Manual cleanup removed $deletedCount regions older than $daysOld days');
      return deletedCount;
    } catch (e) {
      debugPrint('Manual cleanup failed: $e');
      return 0;
    }
  }

  /// Cleanup by size limit
  Future<int> cleanupBySize() async {
    if (_totalDownloadedSize <= _maxCacheSize) return 0;
    
    try {
      // Sort regions by download date (oldest first)
      final sortedRegions = List<OfflineRegion>.from(_downloadedRegions);
      sortedRegions.sort((a, b) => a.downloadedAt.compareTo(b.downloadedAt));
      
      int deletedCount = 0;
      int currentSize = _totalDownloadedSize;
      
      for (final region in sortedRegions) {
        if (currentSize <= _maxCacheSize) break;
        
        await deleteRegion(region.name);
        currentSize -= region.sizeBytes;
        deletedCount++;
      }
      
      debugPrint('Size-based cleanup removed $deletedCount regions');
      return deletedCount;
    } catch (e) {
      debugPrint('Size-based cleanup failed: $e');
      return 0;
    }
  }

  /// Quick download around current location
  Future<void> downloadAroundLocation(
    LatLng center, 
    double radiusKm, {
    String? customName,
    int minZoom = 12,
    int maxZoom = 17,
  }) async {
    // Calculate bounds from center and radius
    const double kmToLatDegrees = 1.0 / 110.574;
    final double kmToLngDegrees = 1.0 / (111.320 * math.cos(center.latitude * math.pi / 180));
    
    final double latOffset = radiusKm * kmToLatDegrees;
    final double lngOffset = radiusKm * kmToLngDegrees;
    
    final northEast = LatLng(
      center.latitude + latOffset,
      center.longitude + lngOffset,
    );
    
    final southWest = LatLng(
      center.latitude - latOffset,
      center.longitude - lngOffset,
    );
    
    final regionName = customName ?? 'Location_${DateTime.now().millisecondsSinceEpoch}';
    
    await downloadRegion(
      northEast: northEast,
      southWest: southWest,
      regionName: regionName,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );
  }

  @override
  void dispose() {
    cancelDownload();
    super.dispose();
  }
}

class _DownloadRequest {
  final LatLng northEast;
  final LatLng southWest;
  final String regionName;
  final int minZoom;
  final int maxZoom;
  final bool priority;
  final DateTime requestTime;

  _DownloadRequest({
    required this.northEast,
    required this.southWest,
    required this.regionName,
    required this.minZoom,
    required this.maxZoom,
    required this.priority,
    required this.requestTime,
  });
}