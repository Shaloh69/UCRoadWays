import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:math';

class OfflineTileService {
  static const String _dbName = 'offline_tiles.db';
  static const String _tableName = 'tiles';
  static const int _maxZoomLevel = 19;
  static const int _minZoomLevel = 10;
  
  Database? _database;
  
  static final OfflineTileService _instance = OfflineTileService._internal();
  factory OfflineTileService() => _instance;
  OfflineTileService._internal();

  Future<void> initialize() async {
    if (_database != null) return;
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final dbPath = path.join(directory.path, _dbName);
      
      _database = await openDatabase(
        dbPath,
        version: 1,
        onCreate: _createDatabase,
      );
      
      debugPrint('Offline tile database initialized');
    } catch (e) {
      debugPrint('Error initializing tile database: $e');
      rethrow;
    }
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        z INTEGER NOT NULL,
        x INTEGER NOT NULL,
        y INTEGER NOT NULL,
        tile_data BLOB NOT NULL,
        downloaded_at INTEGER NOT NULL,
        region_name TEXT,
        UNIQUE(z, x, y)
      )
    ''');
    
    await db.execute('''
      CREATE INDEX idx_tile_coords ON $_tableName (z, x, y)
    ''');
    
    await db.execute('''
      CREATE INDEX idx_region ON $_tableName (region_name)
    ''');
  }

  Future<Database> get database async {
    if (_database == null) {
      await initialize();
    }
    return _database!;
  }

  /// Get tile data from local storage
  Future<Uint8List?> getTile(int z, int x, int y) async {
    try {
      final db = await database;
      final result = await db.query(
        _tableName,
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

  /// Download and store a single tile
  Future<bool> downloadTile(int z, int x, int y, {String? regionName}) async {
    try {
      final url = 'https://tile.openstreetmap.org/$z/$x/$y.png';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'UCRoadWays/1.0.0',
        },
      );

      if (response.statusCode == 200) {
        await _storeTile(z, x, y, response.bodyBytes, regionName);
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

  /// Store tile data in database
  Future<void> _storeTile(int z, int x, int y, Uint8List tileData, String? regionName) async {
    final db = await database;
    await db.insert(
      _tableName,
      {
        'z': z,
        'x': x,
        'y': y,
        'tile_data': tileData,
        'downloaded_at': DateTime.now().millisecondsSinceEpoch,
        'region_name': regionName,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Download tiles for a specific region
  Future<void> downloadRegion({
    required LatLng northEast,
    required LatLng southWest,
    required String regionName,
    int minZoom = _minZoomLevel,
    int maxZoom = _maxZoomLevel,
    Function(int current, int total)? onProgress,
  }) async {
    final tiles = _calculateTilesInBounds(northEast, southWest, minZoom, maxZoom);
    int downloaded = 0;
    int failed = 0;

    debugPrint('Starting download of ${tiles.length} tiles for region: $regionName');

    for (int i = 0; i < tiles.length; i++) {
      final tile = tiles[i];
      
      // Check if tile already exists
      final existingTile = await getTile(tile.z, tile.x, tile.y);
      if (existingTile != null) {
        downloaded++;
        onProgress?.call(downloaded, tiles.length);
        continue;
      }

      // Download new tile
      final success = await downloadTile(tile.z, tile.x, tile.y, regionName: regionName);
      if (success) {
        downloaded++;
      } else {
        failed++;
      }

      onProgress?.call(downloaded, tiles.length);

      // Add small delay to be respectful to tile server
      await Future.delayed(const Duration(milliseconds: 100));
    }

    debugPrint('Download complete for $regionName: $downloaded downloaded, $failed failed');
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
    final y = ((1.0 - log(tan(lat * pi / 180.0) + 1.0 / cos(lat * pi / 180.0)) / pi) / 2.0 * (1 << zoom)).floor();
    return TileCoordinate(zoom, x, y);
  }

  /// Get all downloaded regions
  Future<List<OfflineRegion>> getDownloadedRegions() async {
    try {
      final db = await database;
      final result = await db.rawQuery('''
        SELECT region_name, COUNT(*) as tile_count, MIN(downloaded_at) as first_download
        FROM $_tableName 
        WHERE region_name IS NOT NULL 
        GROUP BY region_name
        ORDER BY first_download DESC
      ''');

      return result.map((row) => OfflineRegion(
        name: row['region_name'] as String,
        tileCount: row['tile_count'] as int,
        downloadedAt: DateTime.fromMillisecondsSinceEpoch(row['first_download'] as int),
      )).toList();
    } catch (e) {
      debugPrint('Error getting downloaded regions: $e');
      return [];
    }
  }

  /// Delete a region's tiles
  Future<void> deleteRegion(String regionName) async {
    try {
      final db = await database;
      await db.delete(
        _tableName,
        where: 'region_name = ?',
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
  final int tileCount;
  final DateTime downloadedAt;

  OfflineRegion({
    required this.name,
    required this.tileCount,
    required this.downloadedAt,
  });

  String get formattedSize {
    // Rough estimate: average tile size is ~20KB
    final sizeBytes = tileCount * 20 * 1024;
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}