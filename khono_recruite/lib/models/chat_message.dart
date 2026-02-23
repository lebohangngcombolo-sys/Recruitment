class ChatMessage {
  final int id;
  final int authorId;
  final String authorName;
  final String content;
  final DateTime timestamp;
  final int? threadId;
  final MessageType type;
  final bool isRead;
  final List<int> readBy;
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.timestamp,
    this.threadId,
    this.type = MessageType.text,
    this.isRead = false,
    this.readBy = const [],
    this.metadata,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int,
      authorId: json['author_id'] as int,
      authorName: json['author_name'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      threadId: json['thread_id'] as int?,
      type: MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => MessageType.text,
      ),
      isRead: json['is_read'] as bool? ?? false,
      readBy: List<int>.from(json['read_by'] ?? []),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author_id': authorId,
      'author_name': authorName,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'thread_id': threadId,
      'type': type.toString().split('.').last,
      'is_read': isRead,
      'read_by': readBy,
      'metadata': metadata,
    };
  }

  ChatMessage copyWith({
    int? id,
    int? authorId,
    String? authorName,
    String? content,
    DateTime? timestamp,
    int? threadId,
    MessageType? type,
    bool? isRead,
    List<int>? readBy,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      threadId: threadId ?? this.threadId,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      readBy: readBy ?? this.readBy,
      metadata: metadata ?? this.metadata,
    );
  }
}

enum MessageType { text, file, image, system, thread }

// Thread Model
class ChatThread {
  final int id;
  final String title;
  final String? description;
  final List<int> participants;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final bool isArchived;
  final DateTime createdAt;

  ChatThread({
    required this.id,
    required this.title,
    this.description,
    required this.participants,
    this.lastMessage,
    this.unreadCount = 0,
    this.isArchived = false,
    required this.createdAt,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      participants: List<int>.from(json['participants'] ?? []),
      lastMessage: json['last_message'] != null
          ? ChatMessage.fromJson(json['last_message'] as Map<String, dynamic>)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
      isArchived: json['is_archived'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// Typing Indicator Model
class TypingData {
  final int userId;
  final String userName;
  final int threadId;
  final bool isTyping;

  TypingData({
    required this.userId,
    required this.userName,
    required this.threadId,
    required this.isTyping,
  });
}
