import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import 'offline_tile_service.dart';

class DataStorageService {
  static const String _roadSystemsKey = 'road_systems';
  static const String _currentSystemKey = 'current_system_id';
  static const String _settingsKey = 'app_settings';
  static const String _offlineSettingsKey = 'offline_settings';

  // Save road system to SharedPreferences
  Future<void> saveRoadSystem(RoadSystem roadSystem) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final systemJson = json.encode(roadSystem.toJson());
      await prefs.setString('road_system_${roadSystem.id}', systemJson);
      
      // Update the list of system IDs
      final systemIds = prefs.getStringList('road_system_ids') ?? [];
      if (!systemIds.contains(roadSystem.id)) {
        systemIds.add(roadSystem.id);
        await prefs.setStringList('road_system_ids', systemIds);
      }
      
      debugPrint('Road system ${roadSystem.name} saved successfully');
    } catch (e) {
      debugPrint('Error saving road system: $e');
      rethrow;
    }
  }

  // Load all road systems from SharedPreferences
  Future<List<RoadSystem>> loadRoadSystems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final systemIds = prefs.getStringList('road_system_ids') ?? [];
      final systems = <RoadSystem>[];
      
      for (final id in systemIds) {
        final systemJson = prefs.getString('road_system_$id');
        if (systemJson != null) {
          final systemData = json.decode(systemJson) as Map<String, dynamic>;
          systems.add(RoadSystem.fromJson(systemData));
        }
      }
      
      debugPrint('Loaded ${systems.length} road systems');
      return systems;
    } catch (e) {
      debugPrint('Error loading road systems: $e');
      return [];
    }
  }

  // Delete a road system
  Future<void> deleteRoadSystem(String systemId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('road_system_$systemId');
      
      final systemIds = prefs.getStringList('road_system_ids') ?? [];
      systemIds.remove(systemId);
      await prefs.setStringList('road_system_ids', systemIds);
      
      debugPrint('Road system $systemId deleted successfully');
    } catch (e) {
      debugPrint('Error deleting road system: $e');
      rethrow;
    }
  }

  // Save current system ID
  Future<void> saveCurrentSystemId(String? systemId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (systemId != null) {
        await prefs.setString(_currentSystemKey, systemId);
      } else {
        await prefs.remove(_currentSystemKey);
      }
    } catch (e) {
      debugPrint('Error saving current system ID: $e');
      rethrow;
    }
  }

  // Load current system ID
  Future<String?> loadCurrentSystemId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currentSystemKey);
    } catch (e) {
      debugPrint('Error loading current system ID: $e');
      return null;
    }
  }

  // Save app settings
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = json.encode(settings);
      await prefs.setString(_settingsKey, settingsJson);
      debugPrint('Settings saved successfully');
    } catch (e) {
      debugPrint('Error saving settings: $e');
      rethrow;
    }
  }

  // Load app settings
  Future<Map<String, dynamic>> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);
      if (settingsJson != null) {
        return json.decode(settingsJson) as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      debugPrint('Error loading settings: $e');
      return {};
    }
  }

  // Save offline map preferences
  Future<void> saveOfflineSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = json.encode(settings);
      await prefs.setString(_offlineSettingsKey, settingsJson);
      debugPrint('Offline settings saved successfully');
    } catch (e) {
      debugPrint('Error saving offline settings: $e');
      rethrow;
    }
  }

  // Load offline map preferences
  Future<Map<String, dynamic>> loadOfflineSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_offlineSettingsKey);
      if (settingsJson != null) {
        return json.decode(settingsJson) as Map<String, dynamic>;
      }
      return {
        'preferOffline': true,
        'autoDownload': false,
        'maxCacheSize': 500 * 1024 * 1024, // 500MB
        'autoCleanupDays': 30,
      };
    } catch (e) {
      debugPrint('Error loading offline settings: $e');
      return {
        'preferOffline': true,
        'autoDownload': false,
        'maxCacheSize': 500 * 1024 * 1024,
        'autoCleanupDays': 30,
      };
    }
  }

  // Export road system to JSON file
  Future<File> exportRoadSystemToFile(RoadSystem roadSystem) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${roadSystem.name}_export.json');
      
      final exportData = {
        'version': '1.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'roadSystem': roadSystem.toJson(),
      };
      
      await file.writeAsString(json.encode(exportData));
      debugPrint('Road system exported to: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('Error exporting road system: $e');
      rethrow;
    }
  }

  // Import road system from JSON file
  Future<RoadSystem> importRoadSystemFromFile(File file) async {
    try {
      final content = await file.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;
      
      if (data['roadSystem'] != null) {
        return RoadSystem.fromJson(data['roadSystem'] as Map<String, dynamic>);
      } else {
        throw Exception('Invalid export file format');
      }
    } catch (e) {
      debugPrint('Error importing road system: $e');
      rethrow;
    }
  }

  // Clear all data
  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear road systems
      final systemIds = prefs.getStringList('road_system_ids') ?? [];
      for (final id in systemIds) {
        await prefs.remove('road_system_$id');
      }
      await prefs.remove('road_system_ids');
      
      // Clear other settings
      await prefs.remove(_currentSystemKey);
      await prefs.remove(_settingsKey);
      await prefs.remove(_offlineSettingsKey);
      
      debugPrint('All data cleared successfully');
    } catch (e) {
      debugPrint('Error clearing data: $e');
      rethrow;
    }
  }

  // Get storage usage info
  Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final systemIds = prefs.getStringList('road_system_ids') ?? [];
      
      int totalSystems = systemIds.length;
      int totalSize = 0;
      
      // Calculate approximate size
      for (final id in systemIds) {
        final systemJson = prefs.getString('road_system_$id');
        if (systemJson != null) {
          totalSize += systemJson.length;
        }
      }
      
      // Get offline map storage
      final offlineService = OfflineTileService();
      await offlineService.initialize();
      final offlineSize = await offlineService.getTotalStorageSize();
      final offlineRegions = await offlineService.getDownloadedRegions();
      
      return {
        'roadSystems': totalSystems,
        'roadSystemsSize': totalSize,
        'offlineMapSize': offlineSize,
        'offlineRegions': offlineRegions.length,
        'totalSize': totalSize + offlineSize,
      };
    } catch (e) {
      debugPrint('Error getting storage info: $e');
      return {
        'roadSystems': 0,
        'roadSystemsSize': 0,
        'offlineMapSize': 0,
        'offlineRegions': 0,
        'totalSize': 0,
      };
    }
  }

  // Backup data to external storage
  Future<File?> backupAllData() async {
    try {
      final systems = await loadRoadSystems();
      final settings = await loadSettings();
      final offlineSettings = await loadOfflineSettings();
      
      final backupData = {
        'version': '1.0',
        'backupDate': DateTime.now().toIso8601String(),
        'roadSystems': systems.map((s) => s.toJson()).toList(),
        'settings': settings,
        'offlineSettings': offlineSettings,
      };
      
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/ucroadways_backup_$timestamp.json');
      
      await file.writeAsString(json.encode(backupData));
      debugPrint('Backup created: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('Error creating backup: $e');
      return null;
    }
  }

  // Restore data from backup
  Future<bool> restoreFromBackup(File backupFile) async {
    try {
      final content = await backupFile.readAsString();
      final backupData = json.decode(content) as Map<String, dynamic>;
      
      // Validate backup format
      if (backupData['version'] == null || backupData['roadSystems'] == null) {
        throw Exception('Invalid backup file format');
      }
      
      // Clear existing data
      await clearAllData();
      
      // Restore road systems
      final systems = backupData['roadSystems'] as List;
      for (final systemData in systems) {
        final system = RoadSystem.fromJson(systemData as Map<String, dynamic>);
        await saveRoadSystem(system);
      }
      
      // Restore settings
      if (backupData['settings'] != null) {
        await saveSettings(backupData['settings'] as Map<String, dynamic>);
      }
      
      if (backupData['offlineSettings'] != null) {
        await saveOfflineSettings(backupData['offlineSettings'] as Map<String, dynamic>);
      }
      
      debugPrint('Data restored successfully from backup');
      return true;
    } catch (e) {
      debugPrint('Error restoring from backup: $e');
      return false;
    }
  }
}

class LocationService {
  static const double defaultLatitude = 33.9737; // UC Riverside
  static const double defaultLongitude = -117.3281;

  // Get formatted address from coordinates (placeholder)
  static String getFormattedAddress(double latitude, double longitude) {
    // This would typically use a geocoding service
    return 'Lat: ${latitude.toStringAsFixed(6)}, Lng: ${longitude.toStringAsFixed(6)}';
  }

  // Calculate distance between two points
  static double calculateDistance(
        double lat1, double lng1, double lat2, double lng2) {
      const double earthRadius = 6371000.0; // meters
  
      final lat1Rad = lat1 * (math.pi / 180.0);
      final lat2Rad = lat2 * (math.pi / 180.0);
      final deltaLatRad = (lat2 - lat1) * (math.pi / 180.0);
      final deltaLngRad = (lng2 - lng1) * (math.pi / 180.0);
  
      final a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
          math.cos(lat1Rad) * math.cos(lat2Rad) *
              math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
  
      // Clamp 'a' to [0,1] to avoid domain errors due to floating point.
      final aClamped = a.clamp(0.0, 1.0) as double;
      final c = 2 * math.atan2(math.sqrt(aClamped), math.sqrt(1 - aClamped));
  
      return earthRadius * c;
    }

  // Check if coordinates are within UC Riverside campus bounds
  static bool isWithinCampusBounds(double latitude, double longitude) {
    // UC Riverside approximate bounds
    const double northBound = 33.9800;
    const double southBound = 33.9650;
    const double eastBound = -117.3200;
    const double westBound = -117.3350;
    
    return latitude >= southBound && 
           latitude <= northBound && 
           longitude >= westBound && 
           longitude <= eastBound;
  }
}

class ExportService {
  // Export to GPX format
  static Future<File> exportToGPX(RoadSystem roadSystem) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${roadSystem.name}.gpx');
      
      final gpxContent = _generateGPXContent(roadSystem);
      await file.writeAsString(gpxContent);
      
      debugPrint('GPX exported to: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('Error exporting to GPX: $e');
      rethrow;
    }
  }

  static String _generateGPXContent(RoadSystem roadSystem) {
    final buffer = StringBuffer();
    
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gpx version="1.1" creator="UCRoadWays">');
    buffer.writeln('  <metadata>');
    buffer.writeln('    <name>${roadSystem.name}</name>');
    buffer.writeln('    <desc>UCRoadWays road system: ${roadSystem.name}</desc>');
    buffer.writeln('  </metadata>');
    
    // Add outdoor roads as tracks
    for (final road in roadSystem.outdoorRoads) {
      buffer.writeln('  <trk>');
      buffer.writeln('    <name>${road.name}</name>');
      buffer.writeln('    <type>${road.type}</type>');
      buffer.writeln('    <trkseg>');
      
      for (final point in road.points) {
        buffer.writeln('      <trkpt lat="${point.latitude}" lon="${point.longitude}"></trkpt>');
      }
      
      buffer.writeln('    </trkseg>');
      buffer.writeln('  </trk>');
    }
    
    // Add landmarks as waypoints
    for (final building in roadSystem.buildings) {
      for (final floor in building.floors) {
        if (floor.level == 0) { // Ground floor landmarks only
          for (final landmark in floor.landmarks) {
            buffer.writeln('  <wpt lat="${landmark.position.latitude}" lon="${landmark.position.longitude}">');
            buffer.writeln('    <name>${landmark.name}</name>');
            buffer.writeln('    <desc>${landmark.description}</desc>');
            buffer.writeln('    <type>${landmark.type}</type>');
            buffer.writeln('  </wpt>');
          }
        }
      }
    }
    
    buffer.writeln('</gpx>');
    return buffer.toString();
  }

  // Export to KML format
  static Future<File> exportToKML(RoadSystem roadSystem) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${roadSystem.name}.kml');
      
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
    
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    buffer.writeln('  <Document>');
    buffer.writeln('    <name>${roadSystem.name}</name>');
    // buffer.writeln('    <description>${roadSystem.description}</description>');
    
    // Road styles
    buffer.writeln('    <Style id="roadStyle">');
    buffer.writeln('      <LineStyle>');
    buffer.writeln('        <color>ff0000ff</color>');
    buffer.writeln('        <width>3</width>');
    buffer.writeln('      </LineStyle>');
    buffer.writeln('    </Style>');
    
    // Add roads
    for (final road in roadSystem.outdoorRoads) {
      buffer.writeln('    <Placemark>');
      buffer.writeln('      <name>${road.name}</name>');
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
        if (floor.level == 0) {
          for (final landmark in floor.landmarks) {
            buffer.writeln('    <Placemark>');
            buffer.writeln('      <name>${landmark.name}</name>');
            buffer.writeln('      <description>${landmark.description}</description>');
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
}