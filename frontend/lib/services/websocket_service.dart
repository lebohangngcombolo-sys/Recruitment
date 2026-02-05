import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../utils/api_endpoints.dart';

/// WebSocket service for real-time chat functionality
class WebSocketService {
  // Singleton instance
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  // Socket connection
  io.Socket? _socket;
  String? _userId;
  bool _isConnected = false;
  String _serverUrl = ApiEndpoints.webSocketUrl;

  // Reconnection settings
  final int _maxReconnectAttempts = 5;
  final int _reconnectDelay = 1000;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  // Event callbacks
  VoidCallback? onConnected;
  VoidCallback? onDisconnected;
  Function(String error)? onError;
  Function(Map<String, dynamic> data)? onNewMessage;
  Function(Map<String, dynamic> data)? onUserTyping;
  Function(Map<String, dynamic> data)? onPresenceUpdate;
  Function(Map<String, dynamic> data)? onNewThread;
  Function(Map<String, dynamic> data)? onMessageSent;
  Function(Map<String, dynamic> data)? onMessagesRead;
  Function(Map<String, dynamic> data)? onJoinedThread;
  Function(Map<String, dynamic> data)? onMessageEdited;
  Function(Map<String, dynamic> data)? onMessageDeleted;
  Function(Map<String, dynamic> data)? onParticipantAdded;
  Function(Map<String, dynamic> data)? onThreadsData;

  /// Initialize WebSocket connection
  Future<void> initialize() async {
    try {
      debugPrint('🔌 Initializing WebSocket connection to $_serverUrl...');

      // Get authentication data
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? prefs.getString('token');
      final userId = prefs.getString('user_id');

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please log in.');
      }

      if (userId == null || userId.isEmpty) {
        throw Exception('User ID not found. Please log in.');
      }

      // Parse user ID to integer
      try {
        _userId = userId;
        debugPrint('✅ User ID parsed: $_userId (type: ${_userId.runtimeType})');
      } catch (e) {
        throw Exception('Invalid user ID format: $userId');
      }

      // Clean token
      String cleanToken = token;
      if (token.startsWith('Bearer ')) {
        cleanToken = token.substring(7);
      }

      debugPrint(
          '🔑 Using token (first 20 chars): ${cleanToken.substring(0, min(20, cleanToken.length))}...');

      // Create socket options
      final options = io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(_reconnectDelay)
          .setReconnectionDelayMax(5000)
          .setReconnectionAttempts(_maxReconnectAttempts)
          .setExtraHeaders({'Authorization': 'Bearer $cleanToken'})
          .setQuery({'token': cleanToken})
          .setTimeout(10)
          .build();

      // Create socket instance
      _socket = io.io(_serverUrl, options);

      // Set up event listeners
      _setupEventListeners();

      // Connect manually
      _socket!.connect();

      debugPrint('✅ WebSocket initialization complete');
    } catch (e, stackTrace) {
      debugPrint('❌ WebSocket initialization failed: $e');
      debugPrint('Stack trace: $stackTrace');
      onError?.call('Initialization failed: $e');
      _scheduleReconnect();
    }
  }

  /// Set up WebSocket event listeners
  void _setupEventListeners() {
    if (_socket == null) return;

    // Connection events
    _socket!.on('connect', (_) {
      debugPrint('✅ WebSocket connected to server');
      _isConnected = true;
      _reconnectAttempts = 0;
      onConnected?.call();
    });

    _socket!.on('disconnect', (reason) {
      debugPrint('🔴 WebSocket disconnected: $reason');
      _isConnected = false;
      onDisconnected?.call();
      _scheduleReconnect();
    });

    _socket!.on('connect_error', (error) {
      debugPrint('❌ WebSocket connection error: $error');
      onError?.call('Connection error: $error');
      _scheduleReconnect();
    });

    _socket!.on('error', (error) {
      debugPrint('❌ WebSocket error: $error');
      onError?.call('Socket error: $error');
    });

    _socket!.on('connecting', (_) {
      debugPrint('🔄 Connecting to WebSocket server...');
    });

    _socket!.on('reconnect', (attempt) {
      debugPrint('🔄 Reconnected (attempt $attempt)');
    });

    _socket!.on('reconnect_attempt', (attempt) {
      debugPrint('🔄 Reconnection attempt $attempt');
    });

    _socket!.on('reconnect_failed', (_) {
      debugPrint('❌ Reconnection failed');
      onError
          ?.call('Reconnection failed after $_maxReconnectAttempts attempts');
    });

    // Server events
    _socket!.on('connected', (data) {
      debugPrint('🎉 Connected to chat server: $data');
      _isConnected = true;
    });

    // Chat events
    _socket!.on('new_message', (data) {
      _handleEvent('new_message', data, onNewMessage);
    });

    _socket!.on('user_typing', (data) {
      _handleEvent('user_typing', data, onUserTyping);
    });

    _socket!.on('presence_update', (data) {
      _handleEvent('presence_update', data, onPresenceUpdate);
    });

    _socket!.on('new_thread', (data) {
      _handleEvent('new_thread', data, onNewThread);
    });

    _socket!.on('message_sent', (data) {
      _handleEvent('message_sent', data, onMessageSent);
    });

    _socket!.on('messages_read', (data) {
      _handleEvent('messages_read', data, onMessagesRead);
    });

    _socket!.on('joined_thread', (data) {
      _handleEvent('joined_thread', data, onJoinedThread);
    });

    _socket!.on('message_edited', (data) {
      _handleEvent('message_edited', data, onMessageEdited);
    });

    _socket!.on('message_deleted', (data) {
      _handleEvent('message_deleted', data, onMessageDeleted);
    });

    _socket!.on('participant_added', (data) {
      _handleEvent('participant_added', data, onParticipantAdded);
    });

    _socket!.on('threads_data', (data) {
      _handleEvent('threads_data', data, onThreadsData);
    });

    _socket!.on('error', (data) {
      if (data is Map<String, dynamic>) {
        final error = data['message'] ?? 'Unknown error';
        debugPrint('❌ Server error: $error');
        onError?.call('Server error: $error');
      }
    });
  }

  /// Handle socket events with type safety
  void _handleEvent(
    String eventName,
    dynamic data,
    Function(Map<String, dynamic> data)? callback,
  ) {
    try {
      debugPrint('📨 Event received: $eventName');

      if (data is Map<String, dynamic>) {
        // Ensure all IDs are parsed as integers where appropriate
        final processedData = _parseIds(data);
        callback?.call(processedData);
      } else if (data is String) {
        // Try to parse as JSON
        try {
          final parsed = json.decode(data) as Map<String, dynamic>;
          final processedData = _parseIds(parsed);
          callback?.call(processedData);
        } catch (e) {
          debugPrint('❌ Failed to parse event data as JSON: $e');
        }
      } else {
        debugPrint(
            '⚠️ Event data is not in expected format: ${data.runtimeType}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error handling event $eventName: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Parse string IDs to integers in event data
  Map<String, dynamic> _parseIds(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);

    // Common ID fields that should be integers
    final idFields = [
      'id',
      'user_id',
      'thread_id',
      'sender_id',
      'author_id',
      'message_id',
      'parent_message_id',
      'created_by',
      'added_by',
      'candidate_id',
      'requisition_id',
      'application_id'
    ];

    for (final field in idFields) {
      if (result.containsKey(field) && result[field] != null) {
        try {
          if (result[field] is String) {
            result[field] = int.parse(result[field] as String);
          } else if (result[field] is double) {
            result[field] = (result[field] as double).toInt();
          }
        } catch (e) {
          debugPrint('⚠️ Could not parse $field as int: ${result[field]}');
        }
      }
    }

    // Handle nested structures
    if (result.containsKey('thread') &&
        result['thread'] is Map<String, dynamic>) {
      result['thread'] = _parseIds(result['thread'] as Map<String, dynamic>);
    }

    if (result.containsKey('message') &&
        result['message'] is Map<String, dynamic>) {
      result['message'] = _parseIds(result['message'] as Map<String, dynamic>);
    }

    if (result.containsKey('sender') &&
        result['sender'] is Map<String, dynamic>) {
      result['sender'] = _parseIds(result['sender'] as Map<String, dynamic>);
    }

    return result;
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    if (_reconnectTimer != null && _reconnectTimer!.isActive) {
      return;
    }

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('❌ Max reconnection attempts reached');
      return;
    }

    _reconnectTimer = Timer(Duration(milliseconds: _reconnectDelay), () {
      _reconnectAttempts++;
      debugPrint(
          '🔄 Attempting reconnection ($_reconnectAttempts/$_maxReconnectAttempts)...');

      if (_socket != null && !_isConnected) {
        _socket!.connect();
      } else {
        // Re-initialize if socket is null
        initialize();
      }
    });
  }

  // ------------------- PUBLIC METHODS -------------------

  /// Join a chat thread
  void joinThread(int threadId) {
    if (!_isConnected || _socket == null) {
      debugPrint('⚠️ Cannot join thread - socket not connected');
      onError?.call('Not connected to chat server');
      return;
    }

    debugPrint('📨 Joining thread $threadId');
    _socket!.emit('join_thread', {'thread_id': threadId});
  }

  /// Leave a chat thread
  void leaveThread(int threadId) {
    if (_isConnected && _socket != null) {
      _socket!.emit('leave_thread', {'thread_id': threadId});
      debugPrint('📤 Left thread $threadId');
    }
  }

  /// Send a message
  void sendMessage({
    required int threadId,
    required String content,
    String messageType = 'text',
    Map<String, dynamic>? metadata,
    int? parentMessageId,
  }) {
    if (!_isConnected || _socket == null) {
      debugPrint('⚠️ Cannot send message - socket not connected');
      onError?.call('Not connected to chat server');
      return;
    }

    final messageData = {
      'thread_id': threadId,
      'content': content.trim(),
      'message_type': messageType,
      'metadata': metadata ?? {},
    };

    if (parentMessageId != null) {
      messageData['parent_message_id'] = parentMessageId;
    }

    debugPrint(
        '📤 Sending message to thread $threadId: ${content.substring(0, min(50, content.length))}...');
    _socket!.emit('send_message', messageData);
  }

  /// Send typing indicator
  void sendTyping(int threadId, bool isTyping) {
    if (_isConnected && _socket != null) {
      _socket!.emit('typing', {
        'thread_id': threadId,
        'is_typing': isTyping,
      });
    }
  }

  /// Mark messages as read
  void markMessagesAsRead(int threadId, {List<int>? messageIds}) {
    if (_isConnected && _socket != null) {
      _socket!.emit('mark_read', {
        'thread_id': threadId,
        'message_ids': messageIds ?? [],
      });
    }
  }

  /// Update user presence
  void updatePresence(String status) {
    if (_isConnected && _socket != null) {
      _socket!.emit('presence', {'status': status});
    }
  }

  /// Get presence of users
  void getPresence(List<int> userIds) {
    if (_isConnected && _socket != null) {
      _socket!.emit('get_presence', {'user_ids': userIds});
    }
  }

  /// Get user's chat threads
  void getThreads({String? entityType, String? entityId}) {
    if (!_isConnected || _socket == null) {
      debugPrint('⚠️ Cannot get threads - socket not connected');
      return;
    }

    final data = <String, dynamic>{};
    if (entityType != null) data['entity_type'] = entityType;
    if (entityId != null) data['entity_id'] = entityId;

    _socket!.emit('get_threads', data);
  }

  /// Edit a message
  void editMessage(int messageId, String newContent) {
    if (!_isConnected || _socket == null) {
      debugPrint('⚠️ Cannot edit message - socket not connected');
      return;
    }

    _socket!.emit('edit_message', {
      'message_id': messageId,
      'content': newContent.trim(),
    });
  }

  /// Delete a message
  void deleteMessage(int messageId, {bool permanent = false}) {
    if (!_isConnected || _socket == null) {
      debugPrint('⚠️ Cannot delete message - socket not connected');
      return;
    }

    _socket!.emit('delete_message', {
      'message_id': messageId,
      'permanent': permanent,
    });
  }

  /// Disconnect WebSocket
  void disconnect() {
    if (_socket != null) {
      debugPrint('🔌 Disconnecting WebSocket...');
      updatePresence('offline');
      _socket!.disconnect();
      _socket = null;
      _isConnected = false;

      if (_reconnectTimer != null && _reconnectTimer!.isActive) {
        _reconnectTimer!.cancel();
        _reconnectTimer = null;
      }
    }
  }

  /// Check if connected
  bool get isConnected => _isConnected;

  /// Get user ID
  int? get userId => _userId != null ? int.tryParse(_userId!.toString()) : null;

  /// Get socket ID
  String? get socketId => _socket?.id;

  /// Helper for min function
  int min(int a, int b) => a < b ? a : b;
}
