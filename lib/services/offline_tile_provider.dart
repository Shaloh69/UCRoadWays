import 'dart:convert' hide Codec;
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'offline_tile_service.dart';

class OfflineTileProvider extends TileProvider {
  final OfflineTileService _offlineService;
  final String onlineUrlTemplate;
  final bool preferOffline;
  
  OfflineTileProvider({
    required this.onlineUrlTemplate,
    this.preferOffline = true,
  }) : _offlineService = OfflineTileService();

  @override
  ImageProvider<Object> getImage(TileCoordinates coordinates, TileLayer options) {
    return OfflineFirstImageProvider(
      coordinates: coordinates,
      options: options,
      offlineService: _offlineService,
      onlineUrlTemplate: onlineUrlTemplate,
      preferOffline: preferOffline,
    );
  }
}

class OfflineFirstImageProvider extends ImageProvider<OfflineFirstImageProvider> {
  final TileCoordinates coordinates;
  final TileLayer options;
  final OfflineTileService offlineService;
  final String onlineUrlTemplate;
  final bool preferOffline;

  const OfflineFirstImageProvider({
    required this.coordinates,
    required this.options,
    required this.offlineService,
    required this.onlineUrlTemplate,
    required this.preferOffline,
  });

  @override
  Future<OfflineFirstImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<OfflineFirstImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(OfflineFirstImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: 'OfflineFirstImageProvider(${coordinates.z}/${coordinates.x}/${coordinates.y})',
    );
  }

  Future<Codec> _loadAsync(OfflineFirstImageProvider key, ImageDecoderCallback decode) async {
    try {
      Uint8List? bytes;

      if (preferOffline) {
        // Try offline first
        bytes = await offlineService.getTile(coordinates.z, coordinates.x, coordinates.y);
        
        if (bytes == null) {
          // Fallback to online
          bytes = await _downloadOnlineTile();
          
          // Cache the downloaded tile for future use
          if (bytes != null) {
            await offlineService.downloadTile(coordinates.z, coordinates.x, coordinates.y);
          }
        }
      } else {
        // Try online first
        bytes = await _downloadOnlineTile();
        
        bytes ??= await offlineService.getTile(coordinates.z, coordinates.x, coordinates.y);
      }

      if (bytes == null) {
        throw Exception('Could not load tile ${coordinates.z}/${coordinates.x}/${coordinates.y}');
      }

      final buffer = await ImmutableBuffer.fromUint8List(bytes);
      return await decode(buffer);
    } catch (e) {
      debugPrint('Error loading tile ${coordinates.z}/${coordinates.x}/${coordinates.y}: $e');
      
      // Return a placeholder/error tile
      return _createErrorTile(decode);
    }
  }

  Future<Uint8List?> _downloadOnlineTile() async {
    try {
      final url = onlineUrlTemplate
          .replaceAll('{z}', coordinates.z.toString())
          .replaceAll('{x}', coordinates.x.toString())
          .replaceAll('{y}', coordinates.y.toString());

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'UCRoadWays/1.0.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      debugPrint('Failed to download online tile: $e');
      return null;
    }
  }

  Future<Codec> _createErrorTile(ImageDecoderCallback decode) async {
    // Create a simple error tile (grey square with X)
    const int size = 256;
    final bytes = Uint8List(size * size * 4); // RGBA
    
    // Fill with light grey
    for (int i = 0; i < bytes.length; i += 4) {
      bytes[i] = 240;     // R
      bytes[i + 1] = 240; // G
      bytes[i + 2] = 240; // B
      bytes[i + 3] = 255; // A
    }
    
    // Draw a simple X pattern
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        if ((x == y) || (x == size - 1 - y)) {
          final index = (y * size + x) * 4;
          bytes[index] = 200;     // R
          bytes[index + 1] = 200; // G
          bytes[index + 2] = 200; // B
          bytes[index + 3] = 255; // A
        }
      }
    }

    final buffer = await ImmutableBuffer.fromUint8List(bytes);
    return await decode(buffer);
  }

  @override
  bool operator ==(Object other) {
    if (other is! OfflineFirstImageProvider) return false;
    return coordinates.z == other.coordinates.z &&
        coordinates.x == other.coordinates.x &&
        coordinates.y == other.coordinates.y &&
        onlineUrlTemplate == other.onlineUrlTemplate;
  }

  @override
  int get hashCode => Object.hash(
    coordinates.z,
    coordinates.x,
    coordinates.y,
    onlineUrlTemplate,
  );
}