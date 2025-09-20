import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import 'offline_tile_service.dart';
import 'geojson_export_service.dart';

class DataStorageService {
  static const String _roadSystemsKey = 'road_systems';
  static const String _currentSystemKey = 'current_system_id';
  static const String _settingsKey = 'app_settings';
  static const String _offlineSettingsKey = 'offline_settings';
  static const String _appVersionKey = 'app_version';
  static const String _lastBackupKey = 'last_backup_date';
  
  // Cache for performance
  static SharedPreferences? _prefs;
  static final Map<String, RoadSystem> _systemCache = {};
  static bool _cacheLoaded = false;

  // Initialize SharedPreferences instance
  static Future<void> initialize() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _loadSystemCache();
      debugPrint('DataStorageService initialized');
    } catch (e) {
      debugPrint('Failed to initialize DataStorageService: $e');
      rethrow;
    }
  }

  static Future<void> _loadSystemCache() async {
    if (_cacheLoaded) return;
    
    try {
      final systemIds = await _getStringList('road_system_ids') ?? [];
      _systemCache.clear();
      
      for (final id in systemIds) {
        final systemJson = await _getString('road_system_$id');
        if (systemJson != null) {
          final systemData = json.decode(systemJson) as Map<String, dynamic>;
          _systemCache[id] = RoadSystem.fromJson(systemData);
        }
      }
      
      _cacheLoaded = true;
      debugPrint('Loaded ${_systemCache.length} road systems into cache');
    } catch (e) {
      debugPrint('Failed to load system cache: $e');
    }
  }

  // Enhanced save road system with backup and validation
  static Future<void> saveRoadSystem(RoadSystem roadSystem) async {
    try {
      await initialize();
      
      // Validate road system before saving
      final validationErrors = _validateRoadSystem(roadSystem);
      if (validationErrors.isNotEmpty) {
        debugPrint('Road system validation failed: $validationErrors');
        throw Exception('Invalid road system: ${validationErrors.first}');
      }

      // Create backup before saving if system already exists
      if (_systemCache.containsKey(roadSystem.id)) {
        await _createBackup(roadSystem.id);
      }

      // Save to storage
      final systemJson = json.encode(roadSystem.toJson());
      await _setString('road_system_${roadSystem.id}', systemJson);
      
      // Update system IDs list
      final systemIds = await _getStringList('road_system_ids') ?? [];
      if (!systemIds.contains(roadSystem.id)) {
        systemIds.add(roadSystem.id);
        await _setStringList('road_system_ids', systemIds);
      }
      
      // Update cache
      _systemCache[roadSystem.id] = roadSystem;
      
      // Update metadata
      await _updateSystemMetadata(roadSystem);
      
      debugPrint('Road system ${roadSystem.name} saved successfully');
    } catch (e) {
      debugPrint('Error saving road system: $e');
      rethrow;
    }
  }

  static List<String> _validateRoadSystem(RoadSystem roadSystem) {
    final errors = <String>[];
    
    if (roadSystem.name.trim().isEmpty) {
      errors.add('Road system name cannot be empty');
    }
    
    if (roadSystem.id.trim().isEmpty) {
      errors.add('Road system ID cannot be empty');
    }
    
    // Validate buildings
    for (final building in roadSystem.buildings) {
      if (building.name.trim().isEmpty) {
        errors.add('Building name cannot be empty');
      }
      
      if (building.floors.isEmpty) {
        errors.add('Building "${building.name}" must have at least one floor');
      }
      
      // Check for duplicate floor levels
      final levels = building.floors.map((f) => f.level).toList();
      final uniqueLevels = levels.toSet();
      if (levels.length != uniqueLevels.length) {
        errors.add('Building "${building.name}" has duplicate floor levels');
      }
    }
    
    // Validate roads
    for (final road in roadSystem.allRoads) {
      if (road.points.length < 2) {
        errors.add('Road "${road.name}" must have at least 2 points');
      }
      
      if (road.width <= 0) {
        errors.add('Road "${road.name}" must have positive width');
      }
    }
    
    return errors;
  }

  static Future<void> _createBackup(String systemId) async {
    try {
      final existingSystem = _systemCache[systemId];
      if (existingSystem != null) {
        final backupKey = 'backup_${systemId}_${DateTime.now().millisecondsSinceEpoch}';
        final backupJson = json.encode(existingSystem.toJson());
        await _setString(backupKey, backupJson);
        
        // Keep only last 5 backups per system
        await _cleanupOldBackups(systemId);
      }
    } catch (e) {
      debugPrint('Failed to create backup for system $systemId: $e');
    }
  }

  static Future<void> _cleanupOldBackups(String systemId) async {
    try {
      final allKeys = _prefs?.getKeys() ?? {};
      final backupKeys = allKeys
          .where((key) => key.startsWith('backup_$systemId'))
          .toList();
      
      backupKeys.sort(); // Sort by timestamp (included in key)
      
      // Remove old backups, keep only latest 5
      while (backupKeys.length > 5) {
        final oldKey = backupKeys.removeAt(0);
        await _prefs?.remove(oldKey);
      }
    } catch (e) {
      debugPrint('Failed to cleanup old backups: $e');
    }
  }

  static Future<void> _updateSystemMetadata(RoadSystem roadSystem) async {
    try {
      final metadata = {
        'id': roadSystem.id,
        'name': roadSystem.name,
        'lastModified': DateTime.now().toIso8601String(),
        'buildingCount': roadSystem.buildings.length,
        'roadCount': roadSystem.allRoads.length,
        'landmarkCount': roadSystem.allLandmarks.length,
      };
      
      await _setString('metadata_${roadSystem.id}', json.encode(metadata));
    } catch (e) {
      debugPrint('Failed to update system metadata: $e');
    }
  }

  // Enhanced load road systems with error recovery
  static Future<List<RoadSystem>> loadRoadSystems() async {
    try {
      await initialize();
      
      if (_cacheLoaded && _systemCache.isNotEmpty) {
        return _systemCache.values.toList();
      }

      final systemIds = await _getStringList('road_system_ids') ?? [];
      final systems = <RoadSystem>[];
      final corruptedIds = <String>[];
      
      for (final id in systemIds) {
        try {
          final systemJson = await _getString('road_system_$id');
          if (systemJson != null) {
            final systemData = json.decode(systemJson) as Map<String, dynamic>;
            final system = RoadSystem.fromJson(systemData);
            systems.add(system);
            _systemCache[id] = system;
          } else {
            corruptedIds.add(id);
          }
        } catch (e) {
          debugPrint('Failed to load road system $id: $e');
          corruptedIds.add(id);
          
          // Try to recover from backup
          final recovered = await _tryRecoverFromBackup(id);
          if (recovered != null) {
            systems.add(recovered);
            _systemCache[id] = recovered;
            debugPrint('Recovered system $id from backup');
          }
        }
      }
      
      // Clean up corrupted system IDs
      if (corruptedIds.isNotEmpty) {
        await _cleanupCorruptedSystems(corruptedIds);
      }
      
      _cacheLoaded = true;
      debugPrint('Loaded ${systems.length} road systems');
      return systems;
    } catch (e) {
      debugPrint('Error loading road systems: $e');
      return [];
    }
  }

  static Future<RoadSystem?> _tryRecoverFromBackup(String systemId) async {
    try {
      final allKeys = _prefs?.getKeys() ?? {};
      final backupKeys = allKeys
          .where((key) => key.startsWith('backup_$systemId'))
          .toList();
      
      if (backupKeys.isEmpty) return null;
      
      // Try latest backup first
      backupKeys.sort();
      final latestBackupKey = backupKeys.last;
      
      final backupJson = await _getString(latestBackupKey);
      if (backupJson != null) {
        final systemData = json.decode(backupJson) as Map<String, dynamic>;
        return RoadSystem.fromJson(systemData);
      }
    } catch (e) {
      debugPrint('Failed to recover from backup: $e');
    }
    
    return null;
  }

  static Future<void> _cleanupCorruptedSystems(List<String> corruptedIds) async {
    try {
      final systemIds = await _getStringList('road_system_ids') ?? [];
      systemIds.removeWhere((id) => corruptedIds.contains(id));
      await _setStringList('road_system_ids', systemIds);
      
      // Remove corrupted system data
      for (final id in corruptedIds) {
        await _prefs?.remove('road_system_$id');
        await _prefs?.remove('metadata_$id');
      }
      
      debugPrint('Cleaned up ${corruptedIds.length} corrupted systems');
    } catch (e) {
      debugPrint('Failed to cleanup corrupted systems: $e');
    }
  }

  // Enhanced delete with confirmation and backup
  static Future<void> deleteRoadSystem(String systemId) async {
    try {
      await initialize();
      
      // Create final backup before deletion
      await _createBackup(systemId);
      
      // Remove from storage
      await _prefs?.remove('road_system_$systemId');
      await _prefs?.remove('metadata_$systemId');
      
      // Update system IDs list
      final systemIds = await _getStringList('road_system_ids') ?? [];
      systemIds.remove(systemId);
      await _setStringList('road_system_ids', systemIds);
      
      // Remove from cache
      _systemCache.remove(systemId);
      
      debugPrint('Road system $systemId deleted successfully');
    } catch (e) {
      debugPrint('Error deleting road system: $e');
      rethrow;
    }
  }

  // Get road system by ID with caching
  static Future<RoadSystem?> getRoadSystemById(String systemId) async {
    try {
      await initialize();
      
      // Check cache first
      if (_systemCache.containsKey(systemId)) {
        return _systemCache[systemId];
      }
      
      // Load from storage
      final systemJson = await _getString('road_system_$systemId');
      if (systemJson != null) {
        final systemData = json.decode(systemJson) as Map<String, dynamic>;
        final system = RoadSystem.fromJson(systemData);
        _systemCache[systemId] = system;
        return system;
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting road system $systemId: $e');
      return null;
    }
  }

  // Current system management
  static Future<void> saveCurrentSystemId(String? systemId) async {
    try {
      await initialize();
      
      if (systemId != null) {
        await _setString(_currentSystemKey, systemId);
      } else {
        await _prefs?.remove(_currentSystemKey);
      }
      
      debugPrint('Current system ID set to: $systemId');
    } catch (e) {
      debugPrint('Error saving current system ID: $e');
      rethrow;
    }
  }

  static Future<String?> getCurrentSystemId() async {
    try {
      await initialize();
      return await _getString(_currentSystemKey);
    } catch (e) {
      debugPrint('Error loading current system ID: $e');
      return null;
    }
  }

  // Enhanced settings management
  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    try {
      await initialize();
      final settingsJson = json.encode(settings);
      await _setString(_settingsKey, settingsJson);
      debugPrint('Settings saved successfully');
    } catch (e) {
      debugPrint('Error saving settings: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> loadSettings() async {
    try {
      await initialize();
      final settingsJson = await _getString(_settingsKey);
      if (settingsJson != null) {
        return json.decode(settingsJson) as Map<String, dynamic>;
      }
      
      // Return default settings
      return _getDefaultSettings();
    } catch (e) {
      debugPrint('Error loading settings: $e');
      return _getDefaultSettings();
    }
  }

  static Map<String, dynamic> _getDefaultSettings() {
    return {
      'theme': 'system',
      'units': 'metric',
      'autoSave': true,
      'showLocationHistory': true,
      'maxLocationHistory': 100,
      'defaultZoom': 18.0,
      'enableNotifications': true,
      'enableHapticFeedback': true,
    };
  }

  // Offline map settings
  static Future<void> saveOfflineSettings(Map<String, dynamic> settings) async {
    try {
      await initialize();
      final settingsJson = json.encode(settings);
      await _setString(_offlineSettingsKey, settingsJson);
      debugPrint('Offline settings saved successfully');
    } catch (e) {
      debugPrint('Error saving offline settings: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> loadOfflineSettings() async {
    try {
      await initialize();
      final settingsJson = await _getString(_offlineSettingsKey);
      if (settingsJson != null) {
        return json.decode(settingsJson) as Map<String, dynamic>;
      }
      
      return _getDefaultOfflineSettings();
    } catch (e) {
      debugPrint('Error loading offline settings: $e');
      return _getDefaultOfflineSettings();
    }
  }

  static Map<String, dynamic> _getDefaultOfflineSettings() {
    return {
      'preferOffline': true,
      'autoDownload': false,
      'maxCacheSize': 500 * 1024 * 1024, // 500MB
      'autoCleanupDays': 30,
      'downloadOnWiFiOnly': true,
      'defaultMinZoom': 10,
      'defaultMaxZoom': 18,
    };
  }

  // Enhanced export functionality
  static Future<File> exportRoadSystemToFile(RoadSystem roadSystem) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = '${roadSystem.name}_export_$timestamp.json';
      final file = File('${directory.path}/$fileName');
      
      // Get system metadata
      final metadata = await _getSystemMetadata(roadSystem.id);
      
      final exportData = {
        'version': '2.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'exportedBy': 'UCRoadWays',
        'roadSystem': roadSystem.toJson(),
        'metadata': metadata,
        'statistics': _calculateSystemStatistics(roadSystem),
      };
      
      await file.writeAsString(json.encode(exportData));
      debugPrint('Road system exported to: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('Error exporting road system: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> _getSystemMetadata(String systemId) async {
    try {
      final metadataJson = await _getString('metadata_$systemId');
      if (metadataJson != null) {
        return json.decode(metadataJson) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Failed to get system metadata: $e');
    }
    return null;
  }

  static Map<String, dynamic> _calculateSystemStatistics(RoadSystem roadSystem) {
    double totalRoadLength = 0.0;
    final landmarkTypes = <String, int>{};
    final floorDistribution = <int, int>{};
    
    // Calculate road lengths
    for (final road in roadSystem.allRoads) {
      for (int i = 0; i < road.points.length - 1; i++) {
        totalRoadLength += _calculateDistance(road.points[i], road.points[i + 1]);
      }
    }
    
    // Count landmark types
    for (final landmark in roadSystem.allLandmarks) {
      landmarkTypes[landmark.type] = (landmarkTypes[landmark.type] ?? 0) + 1;
    }
    
    // Floor distribution
    for (final building in roadSystem.buildings) {
      for (final floor in building.floors) {
        floorDistribution[floor.level] = (floorDistribution[floor.level] ?? 0) + 1;
      }
    }
    
    return {
      'totalBuildings': roadSystem.buildings.length,
      'totalFloors': roadSystem.allFloors.length,
      'totalRoads': roadSystem.allRoads.length,
      'totalLandmarks': roadSystem.allLandmarks.length,
      'totalRoadLength': totalRoadLength,
      'landmarkTypes': landmarkTypes,
      'floorDistribution': floorDistribution,
      'averageFloorsPerBuilding': roadSystem.buildings.isNotEmpty 
          ? roadSystem.allFloors.length / roadSystem.buildings.length 
          : 0.0,
    };
  }

  static double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // meters
    final double lat1Rad = point1.latitude * math.pi / 180;
    final double lat2Rad = point2.latitude * math.pi / 180;
    final double deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180;
    final double deltaLngRad = (point2.longitude - point1.longitude) * math.pi / 180;

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  // Enhanced import with validation
  static Future<RoadSystem> importRoadSystemFromFile(File file) async {
    try {
      final content = await file.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;
      
      // Validate import data
      if (!data.containsKey('roadSystem')) {
        throw Exception('Invalid export file: missing roadSystem data');
      }
      
      final version = data['version'] as String? ?? '1.0';
      if (version != '2.0' && version != '1.0') {
        throw Exception('Unsupported export version: $version');
      }
      
      final roadSystem = RoadSystem.fromJson(data['roadSystem'] as Map<String, dynamic>);
      
      // Validate imported system
      final validationErrors = _validateRoadSystem(roadSystem);
      if (validationErrors.isNotEmpty) {
        throw Exception('Invalid road system data: ${validationErrors.first}');
      }
      
      debugPrint('Road system imported successfully: ${roadSystem.name}');
      return roadSystem;
    } catch (e) {
      debugPrint('Error importing road system: $e');
      rethrow;
    }
  }

  // Bulk operations
  static Future<void> exportAllRoadSystems() async {
    try {
      final systems = await loadRoadSystems();
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'ucroads_backup_$timestamp.json';
      final file = File('${directory.path}/$fileName');
      
      final exportData = {
        'version': '2.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'exportedBy': 'UCRoadWays',
        'roadSystems': systems.map((system) => system.toJson()).toList(),
        'systemCount': systems.length,
      };
      
      await file.writeAsString(json.encode(exportData));
      debugPrint('All road systems exported to: ${file.path}');
    } catch (e) {
      debugPrint('Error exporting all road systems: $e');
      rethrow;
    }
  }

  static Future<List<RoadSystem>> importAllRoadSystemsFromFile(File file) async {
    try {
      final content = await file.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;
      
      if (!data.containsKey('roadSystems')) {
        throw Exception('Invalid backup file: missing roadSystems data');
      }
      
      final systemsData = data['roadSystems'] as List<dynamic>;
      final systems = <RoadSystem>[];
      
      for (final systemData in systemsData) {
        try {
          final system = RoadSystem.fromJson(systemData as Map<String, dynamic>);
          systems.add(system);
        } catch (e) {
          debugPrint('Failed to import one road system: $e');
          // Continue with other systems
        }
      }
      
      debugPrint('Imported ${systems.length} road systems from backup');
      return systems;
    } catch (e) {
      debugPrint('Error importing road systems from backup: $e');
      rethrow;
    }
  }

  // Data cleanup and maintenance
  static Future<void> clearAllData() async {
    try {
      await initialize();
      
      // Create final backup before clearing
      await exportAllRoadSystems();
      
      // Clear road systems
      final systemIds = await _getStringList('road_system_ids') ?? [];
      for (final id in systemIds) {
        await _prefs?.remove('road_system_$id');
        await _prefs?.remove('metadata_$id');
      }
      
      // Clear system list
      await _prefs?.remove('road_system_ids');
      await _prefs?.remove(_currentSystemKey);
      
      // Clear cache
      _systemCache.clear();
      _cacheLoaded = false;
      
      debugPrint('All data cleared successfully');
    } catch (e) {
      debugPrint('Error clearing all data: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getStorageStatistics() async {
    try {
      await initialize();
      
      final systemIds = await _getStringList('road_system_ids') ?? [];
      int totalSize = 0;
      int totalBackups = 0;
      
      // Calculate total storage usage
      final allKeys = _prefs?.getKeys() ?? {};
      for (final key in allKeys) {
        if (key.startsWith('road_system_') || 
            key.startsWith('metadata_') || 
            key.startsWith('backup_')) {
          final value = await _getString(key) ?? '';
          totalSize += value.length;
          
          if (key.startsWith('backup_')) {
            totalBackups++;
          }
        }
      }
      
      return {
        'totalSystems': systemIds.length,
        'totalSize': totalSize,
        'formattedSize': _formatBytes(totalSize),
        'totalBackups': totalBackups,
        'lastModified': await _getString('last_modified_date'),
        'cacheLoaded': _cacheLoaded,
        'cacheSize': _systemCache.length,
      };
    } catch (e) {
      debugPrint('Error getting storage statistics: $e');
      return {};
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // GeoJSON Export functionality (OpenLayers compatible)
  static Future<File> exportToGeoJSON(RoadSystem roadSystem, {
    bool includeIndoorData = true,
    bool includeMetadata = true,
    List<String>? layerFilter,
  }) async {
    return await GeoJsonExportService.exportToGeoJSON(
      roadSystem,
      includeIndoorData: includeIndoorData,
      includeMetadata: includeMetadata,
      layerFilter: layerFilter,
    );
  }

  // Export multiple GeoJSON layer files for complex OpenLayers applications
  static Future<Map<String, File>> exportToLayeredGeoJSON(RoadSystem roadSystem) async {
    return await GeoJsonExportService.exportToLayeredGeoJSON(roadSystem);
  }

  // Export OpenLayers configuration file
  static Future<File> exportOpenLayersConfig(RoadSystem roadSystem) async {
    return await GeoJsonExportService.exportOpenLayersConfig(roadSystem);
  }

  // KML Export functionality
  static Future<File> exportToKML(RoadSystem roadSystem) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = '${roadSystem.name}_$timestamp.kml';
      final file = File('${directory.path}/$fileName');
      
      final kmlContent = _generateKMLContent(roadSystem);
      await file.writeAsString(kmlContent);
      
      debugPrint('KML exported to: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('Error exporting to KML: $e');
      rethrow;
    }
  }

  static String _generateKMLContent(RoadSystem roadSystem) {
    final buffer = StringBuffer();
    
    // KML header
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    buffer.writeln('  <Document>');
    buffer.writeln('    <name>${roadSystem.name}</name>');
    buffer.writeln('    <description>${roadSystem.description}</description>');
    
    // Road styles
    buffer.writeln('    <Style id="roadStyle">');
    buffer.writeln('      <LineStyle>');
    buffer.writeln('        <color>ff0000ff</color>');
    buffer.writeln('        <width>3</width>');
    buffer.writeln('      </LineStyle>');
    buffer.writeln('    </Style>');
    
    // Landmark styles
    buffer.writeln('    <Style id="landmarkStyle">');
    buffer.writeln('      <IconStyle>');
    buffer.writeln('        <color>ff00ff00</color>');
    buffer.writeln('        <scale>1.2</scale>');
    buffer.writeln('      </IconStyle>');
    buffer.writeln('    </Style>');
    
    // Add roads
    for (final road in roadSystem.outdoorRoads) {
      buffer.writeln('    <Placemark>');
      buffer.writeln('      <name>${road.name}</name>');
      buffer.writeln('      <description>Type: ${road.type}, Width: ${road.width}m</description>');
      buffer.writeln('      <styleUrl>#roadStyle</styleUrl>');
      buffer.writeln('      <LineString>');
      buffer.writeln('        <coordinates>');
      
      for (final point in road.points) {
        buffer.writeln('          ${point.longitude},${point.latitude},0');
      }
      
      buffer.writeln('        </coordinates>');
      buffer.writeln('      </LineString>');
      buffer.writeln('    </Placemark>');
    }
    
    // Add landmarks
    for (final building in roadSystem.buildings) {
      for (final floor in building.floors) {
        if (floor.level == 0) { // Only ground floor landmarks for KML
          for (final landmark in floor.landmarks) {
            buffer.writeln('    <Placemark>');
            buffer.writeln('      <name>${landmark.name}</name>');
            buffer.writeln('      <description>Type: ${landmark.type}<br/>Building: ${building.name}<br/>${landmark.description}</description>');
            buffer.writeln('      <styleUrl>#landmarkStyle</styleUrl>');
            buffer.writeln('      <Point>');
            buffer.writeln('        <coordinates>${landmark.position.longitude},${landmark.position.latitude},0</coordinates>');
            buffer.writeln('      </Point>');
            buffer.writeln('    </Placemark>');
          }
        }
      }
    }
    
    buffer.writeln('  </Document>');
    buffer.writeln('</kml>');
    return buffer.toString();
  }

  // Helper methods for SharedPreferences operations
  static Future<String?> _getString(String key) async {
    try {
      return _prefs?.getString(key);
    } catch (e) {
      debugPrint('Error getting string for key $key: $e');
      return null;
    }
  }

  static Future<void> _setString(String key, String value) async {
    try {
      await _prefs?.setString(key, value);
    } catch (e) {
      debugPrint('Error setting string for key $key: $e');
      rethrow;
    }
  }

  static Future<List<String>?> _getStringList(String key) async {
    try {
      return _prefs?.getStringList(key);
    } catch (e) {
      debugPrint('Error getting string list for key $key: $e');
      return null;
    }
  }

  static Future<void> _setStringList(String key, List<String> value) async {
    try {
      await _prefs?.setStringList(key, value);
    } catch (e) {
      debugPrint('Error setting string list for key $key: $e');
      rethrow;
    }
  }

  // Cleanup cache
  static void clearCache() {
    _systemCache.clear();
    _cacheLoaded = false;
    debugPrint('Storage cache cleared');
  }
}