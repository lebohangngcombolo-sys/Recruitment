// models/chat_models.dart

class ChatThread {
  final int id;
  final String title;
  final String entityType;
  final String? entityId;
  final List<ChatParticipant> participants;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatThread({
    required this.id,
    required this.title,
    required this.entityType,
    this.entityId,
    required this.participants,
    this.lastMessage,
    required this.unreadCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title'] ?? '',
      entityType: json['entity_type'] ?? 'general',
      entityId: json['entity_id']?.toString(),
      participants: (json['participants'] as List? ?? [])
          .map((p) => ChatParticipant.fromJson(p))
          .toList(),
      lastMessage: json['last_message'] != null
          ? ChatMessage.fromJson(json['last_message'])
          : null,
      unreadCount: int.tryParse(json['unread_count']?.toString() ?? '0') ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'entity_type': entityType,
        'entity_id': entityId,
        'participants': participants.map((p) => p.toJson()).toList(),
        'last_message': lastMessage?.toJson(),
        'unread_count': unreadCount,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class ChatParticipant {
  final int userId;
  final String name;
  final String email;
  final String role;
  final String? avatarUrl;

  ChatParticipant({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      userId: int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
      avatarUrl: json['avatar_url'],
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
        'email': email,
        'role': role,
        'avatar_url': avatarUrl,
      };
}

class ChatMessage {
  final int id;
  final int threadId;
  final ChatSender sender;
  final String content;
  final String messageType;
  final Map<String, dynamic> metadata;
  final bool isEdited;
  final bool isDeleted;
  final int? parentMessageId;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatMessage({
    required this.id,
    required this.threadId,
    required this.sender,
    required this.content,
    this.messageType = 'text',
    this.metadata = const {},
    this.isEdited = false,
    this.isDeleted = false,
    this.parentMessageId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      threadId: int.tryParse(json['thread_id']?.toString() ?? '0') ?? 0,
      sender: ChatSender.fromJson(json['sender'] ?? {}),
      content: json['content'] ?? '',
      messageType: json['message_type'] ?? 'text',
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : {},
      isEdited: json['is_edited'] ?? false,
      isDeleted: json['is_deleted'] ?? false,
      parentMessageId: json['parent_message_id'] != null
          ? int.tryParse(json['parent_message_id'].toString())
          : null,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'thread_id': threadId,
        'sender': sender.toJson(),
        'content': content,
        'message_type': messageType,
        'metadata': metadata,
        'is_edited': isEdited,
        'is_deleted': isDeleted,
        'parent_message_id': parentMessageId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class ChatSender {
  final int userId;
  final String name;
  final String role;
  final String? avatarUrl;

  ChatSender({
    required this.userId,
    required this.name,
    required this.role,
    this.avatarUrl,
  });

  factory ChatSender.fromJson(Map<String, dynamic> json) {
    return ChatSender(
      userId: int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      name: json['name'] ?? 'Unknown',
      role: json['role'] ?? 'user',
      avatarUrl: json['avatar_url'],
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
        'role': role,
        'avatar_url': avatarUrl,
      };
}

class UserPresence {
  final int userId;
  final String status; // 'online', 'away', 'offline'
  final DateTime? lastSeen;
  final bool isTyping;
  final int? typingInThread;

  UserPresence({
    required this.userId,
    required this.status,
    this.lastSeen,
    this.isTyping = false,
    this.typingInThread,
  });

  factory UserPresence.fromJson(Map<String, dynamic> json) {
    return UserPresence(
      userId: int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      status: json['status'] ?? 'offline',
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'])
          : null,
      isTyping: json['is_typing'] ?? false,
      typingInThread: json['typing_in_thread'] != null
          ? int.tryParse(json['typing_in_thread'].toString())
          : null,
    );
  }

  bool get isOnline => status == 'online';
}
