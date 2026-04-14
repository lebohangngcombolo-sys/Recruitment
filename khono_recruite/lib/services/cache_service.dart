import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

/// Cache service for storing and retrieving data with expiration
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const String _cachePrefix = 'cache_';
  static const String _timestampPrefix = 'timestamp_';
  static const int _maxMemoryItems = 100;
  static const int _maxDiskItems = 500;

  final Map<String, CacheItem> _memoryCache = {};
  final Map<String, DateTime> _memoryTimestamps = {};
  SharedPreferences? _prefs;

  /// Initialize the cache service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _cleanupExpiredCache();
  }

  /// Store data in cache with optional expiration time
  Future<void> set(
    String key,
    dynamic value, {
    Duration? expiration,
    bool persistToDisk = true,
  }) async {
    final cacheKey = _getCacheKey(key);
    final expirationTime = expiration ?? const Duration(hours: 1);
    final expiresAt = DateTime.now().add(expirationTime);

    final cacheItem = CacheItem(
      value: value,
      expiresAt: expiresAt,
      persisted: persistToDisk,
    );

    // Store in memory cache
    _memoryCache[cacheKey] = cacheItem;
    _memoryTimestamps[cacheKey] = expiresAt;

    // Cleanup memory cache if it's too large
    if (_memoryCache.length > _maxMemoryItems) {
      _cleanupMemoryCache();
    }

    // Persist to disk if requested
    if (persistToDisk && _prefs != null) {
      try {
        await _prefs!.setString(cacheKey, jsonEncode(cacheItem.toJson()));
        await _prefs!
            .setString(_getTimestampKey(key), expiresAt.toIso8601String());

        // Cleanup disk cache if it's too large
        await _cleanupDiskCache();
      } catch (e) {
        debugPrint('Failed to persist cache to disk: $e');
      }
    }
  }

  /// Retrieve data from cache
  Future<T?> get<T>(String key) async {
    final cacheKey = _getCacheKey(key);

    // Check memory cache first
    final memoryItem = _memoryCache[cacheKey];
    if (memoryItem != null && !memoryItem.isExpired) {
      return memoryItem.value as T?;
    }

    // Check disk cache
    if (_prefs != null) {
      try {
        final cachedData = _prefs!.getString(cacheKey);
        final timestampData = _prefs!.getString(_getTimestampKey(key));

        if (cachedData != null && timestampData != null) {
          final expiresAt = DateTime.parse(timestampData);

          if (DateTime.now().isBefore(expiresAt)) {
            final cacheItem = CacheItem.fromJson(jsonDecode(cachedData));

            // Store in memory cache for faster access
            _memoryCache[cacheKey] = cacheItem;
            _memoryTimestamps[cacheKey] = expiresAt;

            return cacheItem.value as T?;
          } else {
            // Cache expired, remove it
            await remove(key);
          }
        }
      } catch (e) {
        debugPrint('Failed to retrieve cache from disk: $e');
      }
    }

    return null;
  }

  /// Check if key exists in cache and is not expired
  Future<bool> exists(String key) async {
    final value = await get(key);
    return value != null;
  }

  /// Remove specific key from cache
  Future<void> remove(String key) async {
    final cacheKey = _getCacheKey(key);
    final timestampKey = _getTimestampKey(key);

    // Remove from memory
    _memoryCache.remove(cacheKey);
    _memoryTimestamps.remove(cacheKey);

    // Remove from disk
    if (_prefs != null) {
      try {
        await _prefs!.remove(cacheKey);
        await _prefs!.remove(timestampKey);
      } catch (e) {
        debugPrint('Failed to remove cache from disk: $e');
      }
    }
  }

  /// Clear all cache
  Future<void> clear() async {
    _memoryCache.clear();
    _memoryTimestamps.clear();

    if (_prefs != null) {
      try {
        final keys = _prefs!.getKeys();
        final cacheKeys =
            keys.where((key) => key.startsWith(_cachePrefix)).toList();
        final timestampKeys =
            keys.where((key) => key.startsWith(_timestampPrefix)).toList();

        for (final key in [...cacheKeys, ...timestampKeys]) {
          await _prefs!.remove(key);
        }
      } catch (e) {
        debugPrint('Failed to clear cache from disk: $e');
      }
    }
  }

  /// Clear expired cache items
  Future<void> _cleanupExpiredCache() async {
    final now = DateTime.now();

    // Cleanup memory cache
    final expiredMemoryKeys = _memoryTimestamps.entries
        .where((entry) => now.isAfter(entry.value))
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredMemoryKeys) {
      _memoryCache.remove(key);
      _memoryTimestamps.remove(key);
    }

    // Cleanup disk cache
    if (_prefs != null) {
      try {
        final keys = _prefs!.getKeys();
        final timestampKeys =
            keys.where((key) => key.startsWith(_timestampPrefix)).toList();

        for (final timestampKey in timestampKeys) {
          final timestampData = _prefs!.getString(timestampKey);
          if (timestampData != null) {
            final expiresAt = DateTime.parse(timestampData);
            if (now.isAfter(expiresAt)) {
              final cacheKey =
                  timestampKey.replaceFirst(_timestampPrefix, _cachePrefix);
              await _prefs!.remove(cacheKey);
              await _prefs!.remove(timestampKey);
            }
          }
        }
      } catch (e) {
        debugPrint('Failed to cleanup expired cache: $e');
      }
    }
  }

  /// Cleanup memory cache to maintain size limit
  void _cleanupMemoryCache() {
    if (_memoryTimestamps.length <= _maxMemoryItems) return;

    final sortedEntries = _memoryTimestamps.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final itemsToRemove =
        sortedEntries.take(_memoryTimestamps.length - _maxMemoryItems);

    for (final entry in itemsToRemove) {
      _memoryCache.remove(entry.key);
      _memoryTimestamps.remove(entry.key);
    }
  }

  /// Cleanup disk cache to maintain size limit
  Future<void> _cleanupDiskCache() async {
    if (_prefs == null) return;

    try {
      final keys = _prefs!.getKeys();
      final cacheKeys =
          keys.where((key) => key.startsWith(_cachePrefix)).toList();

      if (cacheKeys.length <= _maxDiskItems) return;

      // Get timestamps for all cache items
      final Map<String, DateTime> itemTimestamps = {};
      for (final cacheKey in cacheKeys) {
        final timestampKey =
            cacheKey.replaceFirst(_cachePrefix, _timestampPrefix);
        final timestampData = _prefs!.getString(timestampKey);
        if (timestampData != null) {
          itemTimestamps[cacheKey] = DateTime.parse(timestampData);
        }
      }

      // Sort by timestamp and remove oldest items
      final sortedEntries = itemTimestamps.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      final itemsToRemove =
          sortedEntries.take(cacheKeys.length - _maxDiskItems);

      for (final entry in itemsToRemove) {
        final cacheKey = entry.key;
        final timestampKey =
            cacheKey.replaceFirst(_cachePrefix, _timestampPrefix);
        await _prefs!.remove(cacheKey);
        await _prefs!.remove(timestampKey);
      }
    } catch (e) {
      debugPrint('Failed to cleanup disk cache: $e');
    }
  }

  /// Get cache statistics
  Future<CacheStats> getStats() async {
    final memorySize = _memoryCache.length;
    int diskSize = 0;

    if (_prefs != null) {
      try {
        final keys = _prefs!.getKeys();
        diskSize = keys.where((key) => key.startsWith(_cachePrefix)).length;
      } catch (e) {
        debugPrint('Failed to get disk cache size: $e');
      }
    }

    return CacheStats(
      memoryItems: memorySize,
      diskItems: diskSize,
      maxMemoryItems: _maxMemoryItems,
      maxDiskItems: _maxDiskItems,
    );
  }

  /// Cache large files to disk
  Future<void> cacheFile(String key, File file, {Duration? expiration}) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${appDir.path}/cache');

      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final cacheFile = File('${cacheDir.path}/$key');
      await file.copy(cacheFile.path);

      // Store metadata
      final metadata = {
        'filePath': cacheFile.path,
        'expiresAt': (DateTime.now().add(expiration ?? const Duration(days: 7)))
            .toIso8601String(),
      };

      await set('file_$key', metadata, expiration: expiration);
    } catch (e) {
      debugPrint('Failed to cache file: $e');
    }
  }

  /// Get cached file
  Future<File?> getCachedFile(String key) async {
    try {
      final metadata = await get<Map<String, dynamic>>('file_$key');
      if (metadata == null) return null;

      final expiresAt = DateTime.parse(metadata['expiresAt']);
      if (DateTime.now().isAfter(expiresAt)) {
        await remove('file_$key');
        return null;
      }

      final filePath = metadata['filePath'];
      final file = File(filePath);

      if (await file.exists()) {
        return file;
      } else {
        await remove('file_$key');
        return null;
      }
    } catch (e) {
      debugPrint('Failed to get cached file: $e');
      return null;
    }
  }

  /// Remove cached file
  Future<void> removeCachedFile(String key) async {
    try {
      final metadata = await get<Map<String, dynamic>>('file_$key');
      if (metadata != null) {
        final filePath = metadata['filePath'];
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      await remove('file_$key');
    } catch (e) {
      debugPrint('Failed to remove cached file: $e');
    }
  }

  String _getCacheKey(String key) => '$_cachePrefix$key';
  String _getTimestampKey(String key) => '$_timestampPrefix$key';
}

/// Cache item model
class CacheItem {
  final dynamic value;
  final DateTime expiresAt;
  final bool persisted;

  CacheItem({
    required this.value,
    required this.expiresAt,
    required this.persisted,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'expiresAt': expiresAt.toIso8601String(),
      'persisted': persisted,
    };
  }

  factory CacheItem.fromJson(Map<String, dynamic> json) {
    return CacheItem(
      value: json['value'],
      expiresAt: DateTime.parse(json['expiresAt']),
      persisted: json['persisted'] ?? false,
    );
  }
}

/// Cache statistics model
class CacheStats {
  final int memoryItems;
  final int diskItems;
  final int maxMemoryItems;
  final int maxDiskItems;

  CacheStats({
    required this.memoryItems,
    required this.diskItems,
    required this.maxMemoryItems,
    required this.maxDiskItems,
  });

  double get memoryUsagePercent => (memoryItems / maxMemoryItems) * 100;
  double get diskUsagePercent => (diskItems / maxDiskItems) * 100;

  @override
  String toString() {
    return 'CacheStats(memory: $memoryItems/$maxMemoryItems (${memoryUsagePercent.toStringAsFixed(1)}%), '
        'disk: $diskItems/$maxDiskItems (${diskUsagePercent.toStringAsFixed(1)}%))';
  }
}

/// Specialized cache for API responses
class ApiCacheService {
  static final ApiCacheService _instance = ApiCacheService._internal();
  factory ApiCacheService() => _instance;
  ApiCacheService._internal();

  final CacheService _cache = CacheService();

  /// Cache API response
  Future<void> cacheResponse(
    String endpoint,
    Map<String, dynamic> response, {
    Duration? expiration,
  }) async {
    await _cache.set('api_$endpoint', response, expiration: expiration);
  }

  /// Get cached API response
  Future<Map<String, dynamic>?> getCachedResponse(String endpoint) async {
    return await _cache.get<Map<String, dynamic>>('api_$endpoint');
  }

  /// Cache paginated response
  Future<void> cachePaginatedResponse(
    String endpoint,
    int page,
    Map<String, dynamic> response, {
    Duration? expiration,
  }) async {
    final key = 'api_${endpoint}_page_$page';
    await _cache.set(key, response, expiration: expiration);
  }

  /// Get cached paginated response
  Future<Map<String, dynamic>?> getCachedPaginatedResponse(
      String endpoint, int page) async {
    final key = 'api_${endpoint}_page_$page';
    return await _cache.get<Map<String, dynamic>>(key);
  }

  /// Invalidate cache for specific endpoint
  Future<void> invalidateEndpoint(String endpoint) async {
    // Remove main endpoint cache
    await _cache.remove('api_$endpoint');

    // Remove paginated caches (we don't know exact page numbers, so we'll clear all)
    // This is a simple approach - in production, you might want to track page numbers
    if (kDebugMode) {
      debugPrint('Invalidated cache for endpoint: $endpoint');
    }
  }

  /// Clear all API cache
  Future<void> clearApiCache() async {
    // In a real implementation, you'd track all API cache keys
    // For now, we'll just clear everything
    await _cache.clear();
  }
}

/// Cache manager for different types of data
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  final CacheService _generalCache = CacheService();

  /// Get appropriate cache service for data type
  CacheService getCacheForType(CacheType type) {
    switch (type) {
      case CacheType.api:
        return _generalCache; // Use general cache for API data
      case CacheType.image:
        return _generalCache;
      case CacheType.document:
        return _generalCache;
      case CacheType.userPreferences:
        return _generalCache;
      case CacheType.general:
        return _generalCache;
    }
  }

  /// Cache data with appropriate expiration based on type
  Future<void> cache<T>(
    String key,
    T data,
    CacheType type, {
    Duration? customExpiration,
  }) async {
    final cache = getCacheForType(type);
    final expiration = customExpiration ?? _getDefaultExpiration(type);
    await cache.set(key, data, expiration: expiration);
  }

  /// Get cached data
  Future<T?> get<T>(String key, CacheType type) async {
    final cache = getCacheForType(type);
    return await cache.get<T>(key);
  }

  Duration _getDefaultExpiration(CacheType type) {
    switch (type) {
      case CacheType.api:
        return const Duration(minutes: 5);
      case CacheType.image:
        return const Duration(days: 7);
      case CacheType.document:
        return const Duration(hours: 1);
      case CacheType.userPreferences:
        return const Duration(days: 30);
      case CacheType.general:
        return const Duration(hours: 1);
    }
  }
}

enum CacheType {
  api,
  image,
  document,
  userPreferences,
  general,
}
