import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:khono_recruite/services/auth_service.dart';

/// Global state manager for consistent app state across screens
class AppStateManager extends ChangeNotifier {
  static final AppStateManager _instance = AppStateManager._internal();
  factory AppStateManager() => _instance;
  AppStateManager._internal();

  // Cache for frequently accessed data
  Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);
  
  // Connection status
  bool _isConnected = true;
  bool get isConnected => _isConnected;
  
  // Last refresh times
  final Map<String, DateTime> _lastRefreshTimes = {};
  
  // Error tracking
  final List<String> _recentErrors = [];
  List<String> get recentErrors => List.unmodifiable(_recentErrors);

  void setConnectionStatus(bool connected) {
    if (_isConnected != connected) {
      _isConnected = connected;
      notifyListeners();
      
      if (!connected) {
        addError('Network connection lost');
      } else {
        // Clear network errors when reconnected
        _recentErrors.removeWhere((error) => error.contains('Network'));
        notifyListeners();
      }
    }
  }

  void addError(String error) {
    _recentErrors.add('${DateTime.now().toString().substring(11, 19)}: $error');
    if (_recentErrors.length > 10) {
      _recentErrors.removeAt(0);
    }
    notifyListeners();
  }

  void clearErrors() {
    _recentErrors.clear();
    notifyListeners();
  }

  // Cache management
  void setCache(String key, dynamic data) {
    _cache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
    notifyListeners();
  }

  T? getCache<T>(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null || DateTime.now().difference(timestamp) > _cacheExpiry) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
      return null;
    }
    return _cache[key] as T?;
  }

  void clearCache(String? key) {
    if (key == null) {
      _cache.clear();
      _cacheTimestamps.clear();
    } else {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
    }
    notifyListeners();
  }

  void setLastRefreshTime(String key) {
    _lastRefreshTimes[key] = DateTime.now();
    notifyListeners();
  }

  DateTime? getLastRefreshTime(String key) {
    return _lastRefreshTimes[key];
  }

  bool shouldRefresh(String key, {Duration interval = const Duration(minutes: 2)}) {
    final lastRefresh = _lastRefreshTimes[key];
    if (lastRefresh == null) return true;
    return DateTime.now().difference(lastRefresh) > interval;
  }

  // Enhanced API call with caching and error handling
  Future<Map<String, dynamic>> fetchWithCache(
    String cacheKey,
    Future<Map<String, dynamic>> Function() fetcher, {
    bool forceRefresh = false,
    Duration? cacheExpiry,
  }) async {
    // Check cache first
    if (!forceRefresh) {
      final cached = getCache<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        return cached;
      }
    }

    try {
      setConnectionStatus(true);
      final data = await fetcher();
      setCache(cacheKey, data);
      setLastRefreshTime(cacheKey);
      return data;
    } catch (e) {
      setConnectionStatus(false);
      addError('API call failed: $e');
      
      // Return cached data if available, even if expired
      final cached = _cache[cacheKey];
      if (cached != null) {
        addError('Using cached data due to network error');
        return cached as Map<String, dynamic>;
      }
      
      rethrow;
    }
  }

  // Token validation and refresh
  Future<bool> validateAndRefreshToken() async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null || token.isEmpty) {
        addError('No authentication token found');
        return false;
      }

      // Test token with a simple API call
      final response = await AuthService.authorizedGet('/api/auth/current');
      if (response.statusCode == 401) {
        // Token expired, try to refresh
        final newToken = await AuthService.refreshAccessToken();
        if (newToken != null) {
          addError('Token refreshed successfully');
          return true;
        } else {
          addError('Token refresh failed - please login again');
          return false;
        }
      }
      
      return true;
    } catch (e) {
      addError('Token validation failed: $e');
      return false;
    }
  }

  // Periodic health check
  Timer? _healthCheckTimer;
  
  void startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(Duration(minutes: 1), (timer) async {
      await validateAndRefreshToken();
    });
  }

  void stopHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  @override
  void dispose() {
    stopHealthCheck();
    super.dispose();
  }
}

// Global instance
final appStateManager = AppStateManager();
