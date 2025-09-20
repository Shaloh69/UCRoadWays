import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:math' as math;

class OfflineTileService {
  Database? _database;
  final String _tableName = 'offline_tiles';
  final String _regionsTableName = 'offline_regions';
  bool _isCancelled = false;

  Future<Database> get database async {
    _database ??= await _initializeDatabase();
    return _database!;
  }

  Future<Database> _initializeDatabase() async {
    final databasePath = await getDatabasesPath();
    final dbPath = path.join(databasePath, 'offline_tiles.db');

    return await openDatabase(
      dbPath,
      version: 2, // Updated version to include regions table
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Create tiles table
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        z INTEGER NOT NULL,
        x INTEGER NOT NULL,
        y INTEGER NOT NULL,
        tile_data BLOB NOT NULL,
        region_name TEXT,
        downloaded_at INTEGER NOT NULL,
        UNIQUE(z, x, y)
      )
    ''');

    // Create regions table
    await db.execute('''
      CREATE TABLE $_regionsTableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        north_east_lat REAL NOT NULL,
        north_east_lng REAL NOT NULL,
        south_west_lat REAL NOT NULL,
        south_west_lng REAL NOT NULL,
        min_zoom INTEGER NOT NULL,
        max_zoom INTEGER NOT NULL,
        tile_count INTEGER NOT NULL,
        size_bytes INTEGER NOT NULL,
        downloaded_at INTEGER NOT NULL
      )
    ''');

    // Create indices for better performance
    await db.execute('CREATE INDEX idx_tiles_zxy ON $_tableName (z, x, y)');
    await db.execute('CREATE INDEX idx_tiles_region ON $_tableName (region_name)');
    await db.execute('CREATE INDEX idx_regions_name ON $_regionsTableName (name)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add regions table in version 2
      await db.execute('''
        CREATE TABLE $_regionsTableName (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE NOT NULL,
          north_east_lat REAL NOT NULL,
          north_east_lng REAL NOT NULL,
          south_west_lat REAL NOT NULL,
          south_west_lng REAL NOT NULL,
          min_zoom INTEGER NOT NULL,
          max_zoom INTEGER NOT NULL,
          tile_count INTEGER NOT NULL,
          size_bytes INTEGER NOT NULL,
          downloaded_at INTEGER NOT NULL
        )
      ''');
      
      await db.execute('CREATE INDEX idx_regions_name ON $_regionsTableName (name)');
    }
  }

  /// Download a single tile
  Future<bool> downloadTile(int z, int x, int y, {String? regionName}) async {
    try {
      final url = 'https://tile.openstreetmap.org/$z/$x/$y.png';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        await saveTile(z, x, y, response.bodyBytes, regionName: regionName);
        return true;
      } else {
        debugPrint('Failed to download tile $z/$x/$y: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error downloading tile $z/$x/$y: $e');
      return false;
    }
  }

  /// Save tile to database
  Future<void> saveTile(int z, int x, int y, Uint8List tileData, {String? regionName}) async {
    try {
      final db = await database;
      await db.insert(
        _tableName,
        {
          'z': z,
          'x': x,
          'y': y,
          'tile_data': tileData,
          'region_name': regionName,
          'downloaded_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error saving tile $z/$x/$y: $e');
      rethrow;
    }
  }

  /// Get tile from database
  Future<Uint8List?> getTile(int z, int x, int y) async {
    try {
      final db = await database;
      final result = await db.query(
        _tableName,
        columns: ['tile_data'],
        where: 'z = ? AND x = ? AND y = ?',
        whereArgs: [z, x, y],
        limit: 1,
      );

      if (result.isNotEmpty) {
        return result.first['tile_data'] as Uint8List;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting tile $z/$x/$y: $e');
      return null;
    }
  }

  /// Download region with progress callback
  Future<void> downloadRegion({
    required LatLng northEast,
    required LatLng southWest,
    required String regionName,
    required int minZoom,
    required int maxZoom,
    Function(int current, int total)? onProgress,
  }) async {
    _isCancelled = false;
    final tiles = _calculateTilesInBounds(northEast, southWest, minZoom, maxZoom);
    int downloaded = 0;
    int failed = 0;
    int totalSize = 0;

    debugPrint('Starting download of ${tiles.length} tiles for region: $regionName');

    // Save region metadata first
    await _saveRegionMetadata(
      regionName,
      northEast,
      southWest,
      minZoom,
      maxZoom,
      tiles.length,
      0, // Size will be updated after download
    );

    for (int i = 0; i < tiles.length; i++) {
      if (_isCancelled) {
        debugPrint('Download cancelled for region: $regionName');
        break;
      }

      final tile = tiles[i];
      
      // Check if tile already exists
      final existingTile = await getTile(tile.z, tile.x, tile.y);
      if (existingTile != null) {
        downloaded++;
        totalSize += existingTile.length;
        onProgress?.call(downloaded, tiles.length);
        continue;
      }

      // Download new tile
      final success = await downloadTile(tile.z, tile.x, tile.y, regionName: regionName);
      if (success) {
        downloaded++;
        // Get the saved tile to calculate its size
        final savedTile = await getTile(tile.z, tile.x, tile.y);
        if (savedTile != null) {
          totalSize += savedTile.length;
        }
      } else {
        failed++;
      }

      onProgress?.call(downloaded, tiles.length);

      // Add small delay to be respectful to tile server
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Update region metadata with actual size
    await _updateRegionSize(regionName, totalSize);

    debugPrint('Download complete for $regionName: $downloaded downloaded, $failed failed, size: ${_formatBytes(totalSize)}');
  }

  /// Save region metadata
  Future<void> _saveRegionMetadata(
    String regionName,
    LatLng northEast,
    LatLng southWest,
    int minZoom,
    int maxZoom,
    int tileCount,
    int sizeBytes,
  ) async {
    try {
      final db = await database;
      await db.insert(
        _regionsTableName,
        {
          'name': regionName,
          'north_east_lat': northEast.latitude,
          'north_east_lng': northEast.longitude,
          'south_west_lat': southWest.latitude,
          'south_west_lng': southWest.longitude,
          'min_zoom': minZoom,
          'max_zoom': maxZoom,
          'tile_count': tileCount,
          'size_bytes': sizeBytes,
          'downloaded_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error saving region metadata: $e');
      rethrow;
    }
  }

  /// Update region size
  Future<void> _updateRegionSize(String regionName, int sizeBytes) async {
    try {
      final db = await database;
      await db.update(
        _regionsTableName,
        {'size_bytes': sizeBytes},
        where: 'name = ?',
        whereArgs: [regionName],
      );
    } catch (e) {
      debugPrint('Error updating region size: $e');
    }
  }

  /// Cancel ongoing download
  Future<void> cancelDownload() async {
    _isCancelled = true;
    debugPrint('Download cancellation requested');
  }

  /// Calculate all tiles needed for a bounding box
  List<TileCoordinate> _calculateTilesInBounds(
    LatLng northEast,
    LatLng southWest,
    int minZoom,
    int maxZoom,
  ) {
    final tiles = <TileCoordinate>[];

    for (int z = minZoom; z <= maxZoom; z++) {
      final nwTile = _deg2tile(northEast.latitude, southWest.longitude, z);
      final seTile = _deg2tile(southWest.latitude, northEast.longitude, z);

      for (int x = nwTile.x; x <= seTile.x; x++) {
        for (int y = nwTile.y; y <= seTile.y; y++) {
          tiles.add(TileCoordinate(z, x, y));
        }
      }
    }

    return tiles;
  }

  /// Convert lat/lng to tile coordinates
  TileCoordinate _deg2tile(double lat, double lng, int zoom) {
    final x = ((lng + 180.0) / 360.0 * (1 << zoom)).floor();
    final y = ((1.0 - math.log(math.tan(lat * math.pi / 180.0) + 1.0 / math.cos(lat * math.pi / 180.0)) / math.pi) / 2.0 * (1 << zoom)).floor();
    return TileCoordinate(zoom, x, y);
  }

  /// Get all downloaded regions with full metadata
  Future<List<OfflineRegion>> getDownloadedRegions() async {
    try {
      final db = await database;
      final result = await db.query(
        _regionsTableName,
        orderBy: 'downloaded_at DESC',
      );

      return result.map((row) => OfflineRegion(
        name: row['name'] as String,
        northEast: LatLng(
          row['north_east_lat'] as double,
          row['north_east_lng'] as double,
        ),
        southWest: LatLng(
          row['south_west_lat'] as double,
          row['south_west_lng'] as double,
        ),
        minZoom: row['min_zoom'] as int,
        maxZoom: row['max_zoom'] as int,
        tileCount: row['tile_count'] as int,
        sizeBytes: row['size_bytes'] as int,
        downloadedAt: DateTime.fromMillisecondsSinceEpoch(row['downloaded_at'] as int),
      )).toList();
    } catch (e) {
      debugPrint('Error getting downloaded regions: $e');
      return [];
    }
  }

  /// Delete a region's tiles and metadata
  Future<void> deleteRegion(String regionName) async {
    try {
      final db = await database;
      
      // Delete tiles
      await db.delete(
        _tableName,
        where: 'region_name = ?',
        whereArgs: [regionName],
      );
      
      // Delete region metadata
      await db.delete(
        _regionsTableName,
        where: 'name = ?',
        whereArgs: [regionName],
      );
      
      debugPrint('Deleted region: $regionName');
    } catch (e) {
      debugPrint('Error deleting region $regionName: $e');
      rethrow;
    }
  }

  /// Get total storage size
  Future<int> getTotalStorageSize() async {
    try {
      final db = await database;
      final result = await db.rawQuery('''
        SELECT SUM(LENGTH(tile_data)) as total_size FROM $_tableName
      ''');
      
      if (result.isNotEmpty && result.first['total_size'] != null) {
        return result.first['total_size'] as int;
      }
      return 0;
    } catch (e) {
      debugPrint('Error getting storage size: $e');
      return 0;
    }
  }

  /// Clear old tiles (older than specified days)
  Future<void> clearOldTiles(int olderThanDays) async {
    try {
      final db = await database;
      final cutoffTime = DateTime.now().subtract(Duration(days: olderThanDays)).millisecondsSinceEpoch;
      
      await db.delete(
        _tableName,
        where: 'downloaded_at < ?',
        whereArgs: [cutoffTime],
      );
      debugPrint('Cleared tiles older than $olderThanDays days');
    } catch (e) {
      debugPrint('Error clearing old tiles: $e');
      rethrow;
    }
  }

  /// Check if tile exists locally
  Future<bool> hasTile(int z, int x, int y) async {
    final tile = await getTile(z, x, y);
    return tile != null;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void dispose() {
    _database?.close();
    _database = null;
  }
}

class TileCoordinate {
  final int z, x, y;
  TileCoordinate(this.z, this.x, this.y);

  @override
  String toString() => 'Tile($z, $x, $y)';
}

class OfflineRegion {
  final String name;
  final LatLng northEast;
  final LatLng southWest;
  final int minZoom;
  final int maxZoom;
  final int tileCount;
  final int sizeBytes;
  final DateTime downloadedAt;

  OfflineRegion({
    required this.name,
    required this.northEast,
    required this.southWest,
    required this.minZoom,
    required this.maxZoom,
    required this.tileCount,
    required this.sizeBytes,
    required this.downloadedAt,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '${sizeBytes} B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    if (sizeBytes < 1024 * 1024 * 1024) return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get the coverage area in square kilometers
  double get coverageAreaKm2 {
    const double earthRadius = 6371.0; // km
    
    final lat1 = southWest.latitude * math.pi / 180;
    final lat2 = northEast.latitude * math.pi / 180;
    final deltaLat = (northEast.latitude - southWest.latitude) * math.pi / 180;
    final deltaLng = (northEast.longitude - southWest.longitude) * math.pi / 180;

    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(deltaLng / 2) * math.sin(deltaLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    final distance = earthRadius * c;
    
    // Approximate area calculation
    final avgLat = (lat1 + lat2) / 2;
    final latDistance = earthRadius * deltaLat;
    final lngDistance = earthRadius * deltaLng * math.cos(avgLat);
    
    return latDistance * lngDistance;
  }
}