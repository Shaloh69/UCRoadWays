import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'geojson_export_service.dart';

class DataStorageService {
  static SharedPreferences? _prefs;
  static bool _isInitialized = false;
  static final Map<String, RoadSystem> _systemCache = {};
  static bool _cacheLoaded = false;

  // Initialize shared preferences
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
      debugPrint('DataStorageService initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize DataStorageService: $e');
      rethrow;
    }
  }

  // Ensure initialization before any operation
  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  // Load all road systems from storage
  static Future<List<RoadSystem>> loadRoadSystems() async {
    await _ensureInitialized();
    
    if (_cacheLoaded) {
      return _systemCache.values.toList();
    }

    try {
      final systemIds = await _getStringList('road_system_ids') ?? [];
      final systems = <RoadSystem>[];

      for (final id in systemIds) {
        try {
          final systemData = await _getString('road_system_$id');
          if (systemData != null) {
            final system = RoadSystem.fromJson(json.decode(systemData));
            systems.add(system);
            _systemCache[system.id] = system;
          }
        } catch (e) {
          debugPrint('Failed to load road system $id: $e');
          // Remove corrupted system ID
          systemIds.remove(id);
          await _setStringList('road_system_ids', systemIds);
        }
      }

      _cacheLoaded = true;
      debugPrint('Loaded ${systems.length} road systems');
      return systems;
    } catch (e) {
      debugPrint('Error loading road systems: $e');
      return [];
    }
  }

  // Save a road system
  static Future<void> saveRoadSystem(RoadSystem roadSystem) async {
    await _ensureInitialized();
    
    try {
      final systemData = json.encode(roadSystem.toJson());
      await _setString('road_system_${roadSystem.id}', systemData);
      
      // Update system IDs list
      final systemIds = await _getStringList('road_system_ids') ?? [];
      if (!systemIds.contains(roadSystem.id)) {
        systemIds.add(roadSystem.id);
        await _setStringList('road_system_ids', systemIds);
      }
      
      // Update cache
      _systemCache[roadSystem.id] = roadSystem;
      
      debugPrint('Saved road system: ${roadSystem.name}');
    } catch (e) {
      debugPrint('Error saving road system: $e');
      rethrow;
    }
  }

  // Delete a road system
  static Future<void> deleteRoadSystem(String systemId) async {
    await _ensureInitialized();
    
    try {
      // Remove from storage
      _prefs?.remove('road_system_$systemId');
      
      // Update system IDs list
      final systemIds = await _getStringList('road_system_ids') ?? [];
      systemIds.remove(systemId);
      await _setStringList('road_system_ids', systemIds);
      
      // Remove from cache
      _systemCache.remove(systemId);
      
      debugPrint('Deleted road system: $systemId');
    } catch (e) {
      debugPrint('Error deleting road system: $e');
      rethrow;
    }
  }

  // Get a specific road system
  static Future<RoadSystem?> getRoadSystem(String systemId) async {
    await _ensureInitialized();
    
    // Check cache first
    if (_systemCache.containsKey(systemId)) {
      return _systemCache[systemId];
    }
    
    try {
      final systemData = await _getString('road_system_$systemId');
      if (systemData != null) {
        final system = RoadSystem.fromJson(json.decode(systemData));
        _systemCache[systemId] = system;
        return system;
      }
    } catch (e) {
      debugPrint('Error getting road system $systemId: $e');
    }
    
    return null;
  }

  // Export functionality
  static Future<File> exportRoadSystemToJson(RoadSystem roadSystem) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = '${roadSystem.name}_$timestamp.json';
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
        _prefs?.remove('road_system_$id');
        _prefs?.remove('metadata_$id');
      }
      _prefs?.remove('road_system_ids');
      
      // Clear cache
      _systemCache.clear();
      _cacheLoaded = false;
      
      debugPrint('All data cleared');
    } catch (e) {
      debugPrint('Error clearing all data: $e');
      rethrow;
    }
  }

  // Validation methods
  static List<String> _validateRoadSystem(RoadSystem system) {
    final errors = <String>[];
    
    if (system.name.trim().isEmpty) {
      errors.add('Road system name cannot be empty');
    }
    
    if (system.id.trim().isEmpty) {
      errors.add('Road system ID cannot be empty');
    }
    
    // Validate building structure
    for (final building in system.buildings) {
      if (building.name.trim().isEmpty) {
        errors.add('Building name cannot be empty');
      }
      
      if (building.floors.isEmpty) {
        errors.add('Building "${building.name}" has no floors');
      }
    }
    
    return errors;
  }

  // Settings management
  static Future<void> saveSetting(String key, dynamic value) async {
    await _ensureInitialized();
    
    try {
      if (value is String) {
        await _setString('setting_$key', value);
      } else if (value is int) {
        await _prefs?.setInt('setting_$key', value);
      } else if (value is bool) {
        await _prefs?.setBool('setting_$key', value);
      } else if (value is double) {
        await _prefs?.setDouble('setting_$key', value);
      } else {
        await _setString('setting_$key', json.encode(value));
      }
    } catch (e) {
      debugPrint('Error saving setting $key: $e');
      rethrow;
    }
  }

  static Future<T?> getSetting<T>(String key, {T? defaultValue}) async {
    await _ensureInitialized();
    
    try {
      if (T == String) {
        return _prefs?.getString('setting_$key') as T? ?? defaultValue;
      } else if (T == int) {
        return _prefs?.getInt('setting_$key') as T? ?? defaultValue;
      } else if (T == bool) {
        return _prefs?.getBool('setting_$key') as T? ?? defaultValue;
      } else if (T == double) {
        return _prefs?.getDouble('setting_$key') as T? ?? defaultValue;
      } else {
        final jsonString = _prefs?.getString('setting_$key');
        if (jsonString != null) {
          return json.decode(jsonString) as T;
        }
        return defaultValue;
      }
    } catch (e) {
      debugPrint('Error getting setting $key: $e');
      return defaultValue;
    }
  }

  // GeoJSON Export functionality
  static Future<File> exportToGeoJSON(
    RoadSystem roadSystem, {
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
    
    // FIXED: Generate description from available data instead of accessing non-existent property
    final description = _generateSystemDescription(roadSystem);
    buffer.writeln('    <description>$description</description>');
    
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

  // FIXED: Helper method to generate system description from available data
  static String _generateSystemDescription(RoadSystem roadSystem) {
    // Check if description is stored in properties
    if (roadSystem.properties.containsKey('description')) {
      return roadSystem.properties['description'] as String;
    }
    
    // Generate description from system statistics
    final stats = _calculateSystemStatistics(roadSystem);
    final List<String> descriptionParts = [];
    
    descriptionParts.add('Road system: ${roadSystem.name}');
    
    if (stats['totalBuildings'] > 0) {
      descriptionParts.add('${stats['totalBuildings']} buildings');
    }
    
    if (stats['totalFloors'] > 0) {
      descriptionParts.add('${stats['totalFloors']} floors');
    }
    
    if (stats['totalRoads'] > 0) {
      descriptionParts.add('${stats['totalRoads']} roads');
    }
    
    if (stats['totalLandmarks'] > 0) {
      descriptionParts.add('${stats['totalLandmarks']} landmarks');
    }
    
    if (stats['totalRoadLength'] > 0) {
      final lengthKm = (stats['totalRoadLength'] as double) / 1000;
      descriptionParts.add('${lengthKm.toStringAsFixed(1)} km total length');
    }
    
    return descriptionParts.join(' • ');
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