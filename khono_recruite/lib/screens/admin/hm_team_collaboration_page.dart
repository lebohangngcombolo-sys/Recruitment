import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:khono_recruite/constants/app_colors.dart';
import 'package:khono_recruite/providers/theme_provider.dart';
import 'package:khono_recruite/services/websocket_service.dart';
import '../../services/admin_service.dart';
import '../../services/app_state_manager.dart';

class HMTeamCollaborationPage extends StatefulWidget {
  const HMTeamCollaborationPage({super.key});

  @override
  State<HMTeamCollaborationPage> createState() =>
      _HMTeamCollaborationPageState();
}

class _HMTeamCollaborationPageState extends State<HMTeamCollaborationPage> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final List<CollaborationMessage> _messages = [];
  final List<TeamMember> _teamMembers = [];
  final List<SharedNote> _sharedNotes = [];
  final List<ChatThread> _chatThreads = [];

  WebSocketService? _webSocketService;
  final AdminService _apiService = AdminService();
  bool _isConnected = false;
  int? _currentThreadId;
  String _currentThreadTitle = 'Team Chat';
  bool _isLoading = true;
  bool _isLoadingMessages = false;
  bool _showNotesPanel = false;

  @override
  void initState() {
    super.initState();
    _initializeWebSocket();
    _loadTeamData();
    _loadChatThreads();
    appStateManager.startHealthCheck();
  }

  @override
  void dispose() {
    _webSocketService?.disconnect();
    _messageController.dispose();
    _noteController.dispose();
    appStateManager.stopHealthCheck();
    super.dispose();
  }

  Future<void> _loadChatThreads() async {
    try {
      final threads = await _apiService.getChatThreads(entityType: 'general');
      if (mounted) {
        setState(() {
          _chatThreads.clear();
          _chatThreads.addAll(threads.map((thread) => ChatThread(
                id: thread['id'] ?? 0,
                title: thread['title'] ?? 'Team Chat',
                entityType: thread['entity_type'] ?? 'general',
                entityId: thread['entity_id']?.toString(),
                lastMessageAt: thread['last_message_at'] != null
                    ? DateTime.tryParse(thread['last_message_at'])
                    : null,
              )));
        });

        // Load the first thread or create one if none exists
        if (_chatThreads.isNotEmpty) {
          _selectThread(_chatThreads.first);
        } else {
          _createGeneralThread();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading chat threads: $e')),
        );
      }
    }
  }

  Future<void> _createGeneralThread() async {
    try {
      final participantIds =
          _teamMembers.map((member) => member.userId).toList();
      final threadData = await _apiService.createChatThread(
        title: 'Team Chat',
        participantIds: participantIds,
        entityType: 'general',
      );

      if (mounted) {
        final newThread = ChatThread(
          id: threadData['id'] ?? 0,
          title: threadData['title'] ?? 'Team Chat',
          entityType: 'general',
        );
        setState(() {
          _chatThreads.add(newThread);
          _currentThreadId = newThread.id;
        });
        _loadMessages(newThread.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating chat thread: $e')),
        );
      }
    }
  }

  Future<void> _loadMessages(int threadId) async {
    if (mounted) {
      setState(() => _isLoadingMessages = true);
    }

    try {
      final messages = await _apiService.getChatMessages(threadId: threadId);
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(messages.map((msg) => CollaborationMessage(
                id: msg['id'] ?? 0,
                authorId: msg['author_id'] ?? 0,
                authorName: msg['author_name'] ?? 'Unknown',
                content: msg['content'] ?? '',
                timestamp:
                    DateTime.tryParse(msg['created_at']) ?? DateTime.now(),
              )));
          _isLoadingMessages = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMessages = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading messages: $e')),
        );
      }
    }
  }

  void _selectThread(ChatThread thread) {
    setState(() {
      _currentThreadId = thread.id;
      _currentThreadTitle = thread.title;
    });
    _loadMessages(thread.id);
  }

  void _initializeWebSocket() {
    _webSocketService = WebSocketService();
    _webSocketService!.initialize();

    _webSocketService!.onNewMessage = (message) {
      if (mounted &&
          _currentThreadId != null &&
          message['thread_id'] == _currentThreadId) {
        setState(() {
          _messages.add(CollaborationMessage(
            id: message['id'] ?? DateTime.now().millisecondsSinceEpoch,
            authorId: message['author_id'] ?? 0,
            authorName: message['author_name'] ?? 'Unknown',
            content: message['content'] ?? '',
            timestamp:
                DateTime.tryParse(message['timestamp']) ?? DateTime.now(),
          ));
        });
      }
    };
  }

  Future<void> _loadTeamData({bool refresh = false}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        if (refresh) {
          _teamMembers.clear();
          _sharedNotes.clear();
        }
      });
    }

    try {
      // Load team members - using the new team collaboration endpoint
      final teamResponse = await _apiService.getTeamCollaborationUsers();
      final teamData = teamResponse;

      // Combine all users from different role categories
      List<dynamic> allUsers = [];
      if (teamData['admins'] != null) allUsers.addAll(teamData['admins']);
      if (teamData['hiring_managers'] != null)
        allUsers.addAll(teamData['hiring_managers']);
      if (teamData['candidates'] != null)
        allUsers.addAll(teamData['candidates']);
      if (teamData['hr'] != null) allUsers.addAll(teamData['hr']);

      final usersData = allUsers;

      if (mounted) {
        setState(() {
          _teamMembers.clear();
          _teamMembers.addAll(usersData
              .map((user) => TeamMember(
                    name: user['full_name'] ?? user['name'] ?? 'Unknown User',
                    role: user['role'] ?? 'Unknown',
                    avatar: user['profile_picture'],
                    isOnline: user['is_online'] ?? false,
                    lastSeen: user['last_seen'] != null
                        ? DateTime.tryParse(user['last_seen'])
                        : null,
                    userId: user['id'] ?? 0,
                  ))
              .toList());
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading team data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Team Collaboration',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor:
            (themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white)
                .withOpacity(0.95),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.note_add,
                color:
                    themeProvider.isDarkMode ? Colors.white : Colors.black87),
            onPressed: () => setState(() => _showNotesPanel = !_showNotesPanel),
            tooltip: 'Shared Notes',
          ),
          IconButton(
            icon: Icon(Icons.event,
                color:
                    themeProvider.isDarkMode ? Colors.white : Colors.black87),
            onPressed: _scheduleMeeting,
            tooltip: 'Schedule Meeting',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadTeamData(refresh: true),
            tooltip: 'Refresh team data',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(themeProvider.backgroundImage),
            fit: BoxFit.cover,
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Row(
                children: [
                  // Left panel - Team members
                  Expanded(
                    flex: 1,
                    child: _buildTeamPanel(themeProvider),
                  ),
                  // Right panel - Chat
                  Expanded(
                    flex: 2,
                    child: _buildChatPanel(themeProvider),
                  ),
                  // Notes panel (conditional)
                  if (_showNotesPanel)
                    Expanded(
                      flex: 1,
                      child: _buildNotesPanel(themeProvider),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildTeamPanel(ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.white)
            .withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Team Members',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const Divider(height: 1),
          // Team members list
          Expanded(
            child: _teamMembers.isEmpty
                ? Center(
                    child: Text(
                      'No team members found',
                      style: GoogleFonts.poppins(
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _teamMembers.length,
                    itemBuilder: (context, index) {
                      final member = _teamMembers[index];
                      return _buildTeamMemberCard(member, themeProvider);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamMemberCard(TeamMember member, ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? Colors.grey.shade700
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary,
            backgroundImage: member.avatar?.isNotEmpty == true
                ? NetworkImage(member.avatar!)
                : null,
            child: member.avatar?.isEmpty != false
                ? Text(
                    member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                Text(
                  member.role,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: themeProvider.isDarkMode
                        ? Colors.grey.shade300
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          // Online status
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: member.isOnline ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPanel(ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.white)
            .withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Chat header
          _buildChatHeader(themeProvider),
          const Divider(height: 1),
          // Messages area
          Expanded(
            child: _isLoadingMessages
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet. Start the conversation!',
                          style: GoogleFonts.poppins(
                            color: themeProvider.isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return _buildMessageBubble(message, themeProvider);
                        },
                      ),
          ),
          // Message input
          _buildMessageInput(themeProvider),
        ],
      ),
    );
  }

  Widget _buildChatHeader(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary,
            child: Icon(
              Icons.group,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentThreadTitle,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                Text(
                  '${_teamMembers.length} members',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: themeProvider.isDarkMode
                        ? Colors.grey.shade300
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isConnected ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _isConnected ? 'Connected' : 'Disconnected',
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
      CollaborationMessage message, ThemeProvider themeProvider) {
    final isMe = message.authorId == _getCurrentUserId();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: Text(
                message.authorName.isNotEmpty
                    ? message.authorName[0].toUpperCase()
                    : '?',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.primary
                    : themeProvider.isDarkMode
                        ? Colors.grey.shade700
                        : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: isMe ? Radius.circular(16) : Radius.circular(4),
                  bottomRight: isMe ? Radius.circular(4) : Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(
                      message.authorName,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isMe ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  Text(
                    message.content,
                    style: GoogleFonts.poppins(
                      color: isMe ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimeAgo(message.timestamp),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: isMe ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: Text(
                'ME',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? Colors.grey.shade900
            : Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: GoogleFonts.poppins(
                  color: themeProvider.isDarkMode
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: themeProvider.isDarkMode
                    ? Colors.grey.shade800
                    : Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: GoogleFonts.poppins(
                color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _sendMessage,
            backgroundColor: AppColors.primary,
            mini: true,
            child: const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesPanel(ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.white)
            .withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Shared Notes',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _showCreateNoteDialog,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Notes list
          Expanded(
            child: _sharedNotes.isEmpty
                ? Center(
                    child: Text(
                      'No notes yet',
                      style: GoogleFonts.poppins(
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _sharedNotes.length,
                    itemBuilder: (context, index) {
                      final note = _sharedNotes[index];
                      return _buildNoteCard(note, themeProvider);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(SharedNote note, ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? Colors.grey.shade700
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note.title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note.content,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade300
                  : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'By ${note.author}',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: themeProvider.isDarkMode
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                ),
              ),
              Text(
                _formatTimeAgo(note.lastModified),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: themeProvider.isDarkMode
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreateNoteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Create Note',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: _noteController,
          decoration: const InputDecoration(
            hintText: 'Enter your note...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () {
              _noteController.clear();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _createSharedNote();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _currentThreadId == null) return;

    // Add message to local state immediately for better UX
    final tempMessage = CollaborationMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      authorId: _getCurrentUserId(),
      authorName: 'Me',
      content: message,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(tempMessage);
    });

    try {
      // Send via API for persistence
      await _apiService.sendMessage(
        threadId: _currentThreadId!,
        content: message,
      );

      // Also send via WebSocket for real-time updates
      _webSocketService?.sendMessage(
        threadId: _currentThreadId!,
        content: message,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
        // Remove the temporary message if it failed
        setState(() {
          _messages.remove(tempMessage);
        });
      }
    }

    _messageController.clear();
  }

  Future<void> _createSharedNote() async {
    final noteText = _noteController.text.trim();
    if (noteText.isEmpty) return;

    try {
      // This would call a notes API - for now using local storage
      final newNote = SharedNote(
        id: DateTime.now().millisecondsSinceEpoch,
        title: 'Team Note',
        content: noteText,
        author: 'Me',
        lastModified: DateTime.now(),
      );

      setState(() {
        _sharedNotes.add(newNote);
      });

      _noteController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating note: $e')),
        );
      }
    }
  }

  Future<void> _scheduleMeeting() async {
    // This would open a meeting scheduling dialog
    // For now, showing a placeholder
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Schedule Meeting'),
          content: const Text('Meeting scheduling feature coming soon!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  int _getCurrentUserId() {
    // Get current user ID from auth service or storage
    return 1; // Placeholder - should get actual user ID
  }

  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

// Data models
class CollaborationMessage {
  final int id;
  final int authorId;
  final String authorName;
  final String content;
  final DateTime timestamp;

  CollaborationMessage({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.timestamp,
  });
}

class TeamMember {
  final String name;
  final String role;
  final String? avatar;
  final bool isOnline;
  final DateTime? lastSeen;
  final int userId;

  TeamMember({
    required this.name,
    required this.role,
    this.avatar,
    required this.isOnline,
    this.lastSeen,
    required this.userId,
  });
}

class SharedNote {
  final int id;
  final String title;
  final String content;
  final String author;
  final DateTime lastModified;

  SharedNote({
    required this.id,
    required this.title,
    required this.content,
    required this.author,
    required this.lastModified,
  });
}

class ChatThread {
  final int id;
  final String title;
  final String entityType;
  final String? entityId;
  final DateTime? lastMessageAt;

  ChatThread({
    required this.id,
    required this.title,
    required this.entityType,
    this.entityId,
    this.lastMessageAt,
  });
}

final appStateManager = AppStateManager();
