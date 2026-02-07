import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/websocket_service.dart';
import '../../services/auth_service.dart';
import '../../services/admin_service.dart';
import 'meeting_screen.dart';

class HMTeamCollaborationPage extends StatefulWidget {
  const HMTeamCollaborationPage({super.key});

  @override
  State<HMTeamCollaborationPage> createState() =>
      _HMTeamCollaborationPageState();
}

class _HMTeamCollaborationPageState extends State<HMTeamCollaborationPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final List<TeamMember> _teamMembers = [];
  final List<SharedNote> _sharedNotes = [];

  WebSocketService? _webSocketService;
  final AdminService _apiService = AdminService();
  bool _isConnected = false;
  int? _currentThreadId;
  String _currentThreadTitle = 'Team Chat';
  List<dynamic> _chatThreads = [];
  Map<int, String> _typingUsers = {};

  bool _isLoading = true;
  bool _isSending = false;

  // Cache user ID locally for synchronous access
  int? _cachedUserId;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _loadTeamData();
    _loadUserId();
  }

  /// Load user ID asynchronously and cache it
  Future<void> _loadUserId() async {
    try {
      // Try WebSocketService first (fastest, already connected)
      final wsUserId = _webSocketService?.userId;
      if (wsUserId != null) {
        _cachedUserId = wsUserId;
        return;
      }
      // Fallback to AuthService (handles int, double, string including "42.0")
      final userInfo = await AuthService.getUserInfo();
      final parsed = _safeUserIdFromDynamic(userInfo?['id']);
      if (parsed != null) {
        _cachedUserId = parsed;
      }
      // Never overwrite _cachedUserId with null - preserves existing valid value
    } catch (e) {
      debugPrint('Error loading user ID: $e');
    } finally {
      if (mounted) setState(() {});
    }
  }

  /// Safely parses user ID from dynamic (int, double, string e.g. "42.0")
  static int? _safeUserIdFromDynamic(dynamic id) {
    if (id == null) return null;
    if (id is int) return id;
    if (id is double) return id.toInt();
    if (id is String) {
      final i = int.tryParse(id);
      if (i != null) return i;
      final d = double.tryParse(id);
      return d?.toInt();
    }
    return null;
  }

  Future<void> _initializeChat() async {
    try {
      // Initialize WebSocket
      _webSocketService = WebSocketService();
      await _webSocketService!.initialize();

      // Set up WebSocket listeners
      _setupWebSocketListeners();

      // Fetch chat threads
      await _fetchChatThreads();

      // Update presence to online
      _webSocketService!.updatePresence('online');

      final uid = _webSocketService?.userId;
      if (uid != null) _cachedUserId = uid;
      setState(() => _isConnected = true);
      // Ensure user ID is cached (in case onConnected hasn't fired yet)
      await _loadUserId();
    } catch (e) {
      debugPrint("Error initializing chat: $e");
      setState(() {
        _isConnected = false;
      });
    }
  }

  void _setupWebSocketListeners() {
    if (_webSocketService == null) return;

    _webSocketService!.onConnected = () {
      final uid = _webSocketService?.userId;
      if (uid != null) _cachedUserId = uid;
      setState(() => _isConnected = true);
    };

    _webSocketService!.onDisconnected = () {
      setState(() {
        _isConnected = false;
      });
    };

    _webSocketService!.onError = (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chat error: $error', style: GoogleFonts.inter()),
          backgroundColor: AppColors.primaryRed,
        ),
      );
    };

    _webSocketService!.onNewMessage = (message) async {
      final threadId = message['thread_id'] as int;
      if (_currentThreadId == threadId) {
        setState(() {
          _messages.insert(0, ChatMessage.fromJson(message));
        });

        // Mark message as read
        try {
          await _apiService.markMessagesAsRead(
            threadId: threadId,
            messageIds: [message['id'] as int],
          );
        } catch (e) {
          debugPrint("Error marking message as read: $e");
        }
      }
    };

    _webSocketService!.onUserTyping = (data) {
      final threadId = data['thread_id'] as int;
      final userId = data['user_id'] as int;
      final isTyping = data['is_typing'] as bool;

      if (_currentThreadId == threadId) {
        if (isTyping) {
          // Get user name for typing indicator
          final user = _teamMembers.firstWhere(
            (member) => member.userId == userId,
            orElse: () => TeamMember(
              name: 'User $userId',
              role: 'Team Member',
              isOnline: true,
              userId: userId,
            ),
          );

          setState(() {
            _typingUsers[threadId] = '${user.name} is typing...';
          });

          // Clear typing indicator after 3 seconds
          Future.delayed(Duration(seconds: 3), () {
            if (mounted && _typingUsers[threadId] != null) {
              setState(() {
                _typingUsers.remove(threadId);
              });
            }
          });
        } else {
          setState(() {
            _typingUsers.remove(threadId);
          });
        }
      }
    };

    _webSocketService!.onNewThread = (data) async {
      await _fetchChatThreads();
    };

    _webSocketService!.onMessagesRead = (data) {
      // Handle read receipts if needed
      debugPrint("Messages read: $data");
    };
  }

  Future<void> _fetchChatThreads() async {
    try {
      final threads = await _apiService.getChatThreads();
      setState(() {
        _chatThreads = threads;
        if (_chatThreads.isNotEmpty && _currentThreadId == null) {
          _currentThreadId = _chatThreads.first['id'];
          _currentThreadTitle = _chatThreads.first['title'] ?? 'Team Chat';
          _loadThreadMessages(_currentThreadId!);
        }
      });
    } catch (e) {
      debugPrint("Error fetching chat threads: $e");
    }
  }

  Future<void> _loadThreadMessages(int threadId) async {
    try {
      final messages = await _apiService.getChatMessages(threadId: threadId);
      setState(() {
        _messages.clear();
        _messages
            .addAll(messages.map((msg) => ChatMessage.fromJson(msg)).toList());
        _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      });

      // Join thread via WebSocket
      _webSocketService?.joinThread(threadId);

      // Mark all messages as read
      if (_messages.isNotEmpty) {
        final messageIds = _messages.map((msg) => msg.id).toList();
        await _apiService.markMessagesAsRead(
          threadId: threadId,
          messageIds: messageIds,
        );
      }
    } catch (e) {
      debugPrint("Error loading messages: $e");
    }
  }

  Future<void> _loadTeamData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load shared notes from API
      final notesResponse = await _apiService.getNotes(page: 1, perPage: 10);
      final notesData = notesResponse['notes'] as List<dynamic>;

      setState(() {
        _sharedNotes.clear();
        _sharedNotes.addAll(notesData
            .map((note) => SharedNote(
                  id: note['id'] ?? 0,
                  title: note['title'] ?? 'Untitled',
                  content: note['content'] ?? '',
                  author: note['author_name'] ?? 'Unknown',
                  lastModified:
                      DateTime.parse(note['updated_at'] ?? note['created_at']),
                ))
            .toList());
      });

      // Load team members - using getUsers from AdminService
      final usersResponse = await _apiService.getUsers();
      final usersData = usersResponse;

      setState(() {
        _teamMembers.clear();
        _teamMembers.addAll(usersData
            .map((user) => TeamMember(
                  name: user['full_name'] ?? 'Unknown User',
                  role: user['role'] ?? 'Team Member',
                  isOnline: user['is_online'] ?? false,
                  userId: user['id'] ?? 0,
                ))
            .toList());
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load data: $e', style: GoogleFonts.inter()),
          backgroundColor: AppColors.primaryRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode
          ? const Color(0xFF0F0E17)
          : const Color(0xFFF8F9FA),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(themeProvider),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState(themeProvider)
                  : _buildMainContent(themeProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryRed.withValues(alpha: 0.9),
            const Color(0xFFEF4444),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryRed.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.group_work, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Team Collaboration Hub',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Connect, communicate, and collaborate in real-time',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isConnected ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isConnected ? 'Live' : 'Offline',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeProvider themeProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryRed, const Color(0xFFEF4444)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryRed.withValues(alpha: 0.3),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading workspace...',
            style: GoogleFonts.poppins(
              color: themeProvider.isDarkMode ? Colors.white : Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(ThemeProvider themeProvider) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column - Team Members & Quick Actions
        SizedBox(
          width: 280,
          child: Column(
            children: [
              Expanded(child: _buildTeamMembersPanel(themeProvider)),
              const SizedBox(height: 16),
              _buildQuickActionsPanel(themeProvider),
              const SizedBox(height: 16),
              Expanded(child: _buildSharedNotesPanel(themeProvider)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Right Column - Chat
        Expanded(
          child: _buildChatPanel(themeProvider),
        ),
      ],
    );
  }

  Widget _buildTeamMembersPanel(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:
            themeProvider.isDarkMode ? const Color(0xFF1A1925) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryRed, const Color(0xFFEF4444)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.people, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Team Members',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const Spacer(),
              Text(
                '${_teamMembers.where((m) => m.isOnline).length}/${_teamMembers.length}',
                style: GoogleFonts.inter(
                  color: AppColors.primaryRed,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_teamMembers.isEmpty)
            _buildEmptyTeamState(themeProvider)
          else
            Expanded(
              child: ListView.builder(
                itemCount: _teamMembers.length,
                itemBuilder: (context, index) {
                  final member = _teamMembers[index];
                  return _buildTeamMemberTile(member, themeProvider);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTeamMemberTile(TeamMember member, ThemeProvider themeProvider) {
    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: themeProvider.isDarkMode
              ? const Color(0xFF252433)
              : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: themeProvider.isDarkMode
                ? const Color(0xFF3A3949)
                : const Color(0xFFE9ECEF),
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryRed.withValues(alpha: 0.8),
                        const Color(0xFFEF4444),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      member.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: member.isOnline ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: themeProvider.isDarkMode
                            ? const Color(0xFF252433)
                            : const Color(0xFFF8F9FA),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: GoogleFonts.inter(
                      color: themeProvider.isDarkMode
                          ? Colors.white
                          : Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    member.role,
                    style: GoogleFonts.inter(
                      color: themeProvider.isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _startChatWithUser(member),
              icon: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  size: 16,
                  color: AppColors.primaryRed,
                ),
              ),
              splashRadius: 20,
            ),
          ],
        ));
  }

  Widget _buildEmptyTeamState(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: 48,
            color: themeProvider.isDarkMode
                ? Colors.grey.shade600
                : Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'No team members yet',
            style: GoogleFonts.inter(
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsPanel(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:
            themeProvider.isDarkMode ? const Color(0xFF1A1925) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          // Use Wrap instead of fixed height rows to prevent overflow
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildQuickActionButton(
                label: 'New Note',
                color: Colors.blue,
                onPressed: _createSharedNote,
              ),
              _buildQuickActionButton(
                label: 'Meeting',
                color: Colors.purple,
                onPressed: _scheduleMeeting,
              ),
              _buildQuickActionButton(
                label: 'New Chat',
                color: Colors.green,
                onPressed: _createNewChatThread,
              ),
              _buildQuickActionButton(
                label: 'Settings',
                color: Colors.orange,
                onPressed: () {
                  // Settings action
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 110, // Fixed width to prevent overflow
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSharedNotesPanel(ThemeProvider themeProvider) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:
              themeProvider.isDarkMode ? const Color(0xFF1A1925) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue, Colors.blue.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(Icons.note, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Shared Notes',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color:
                        themeProvider.isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _createSharedNote,
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add,
                      size: 20,
                      color: Colors.blue,
                    ),
                  ),
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_sharedNotes.isEmpty)
              _buildEmptyNotesState(themeProvider)
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _sharedNotes.length,
                  itemBuilder: (context, index) {
                    final note = _sharedNotes[index];
                    return _buildSharedNoteItem(note, themeProvider);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedNoteItem(SharedNote note, ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _viewSharedNote(note),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode
                  ? const Color(0xFF252433)
                  : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: themeProvider.isDarkMode
                    ? const Color(0xFF3A3949)
                    : const Color(0xFFE9ECEF),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.title,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.black,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _formatTimeAgo(note.lastModified),
                        style: GoogleFonts.inter(
                          color: Colors.blue,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  note.content,
                  style: GoogleFonts.inter(
                    color: themeProvider.isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          note.author.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      note.author,
                      style: GoogleFonts.inter(
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyNotesState(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.note_add_outlined,
            size: 48,
            color: themeProvider.isDarkMode
                ? Colors.grey.shade600
                : Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'No shared notes yet',
            style: GoogleFonts.inter(
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a note to start collaborating',
            style: GoogleFonts.inter(
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade500
                  : Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPanel(ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        color:
            themeProvider.isDarkMode ? const Color(0xFF1A1925) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Chat Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode
                  ? const Color(0xFF252433)
                  : const Color(0xFFF8F9FA),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(
                  color: themeProvider.isDarkMode
                      ? const Color(0xFF3A3949)
                      : const Color(0xFFE9ECEF),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryRed, const Color(0xFFEF4444)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(Icons.chat, color: Colors.white, size: 20),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                      if (_typingUsers.containsKey(_currentThreadId))
                        Text(
                          _typingUsers[_currentThreadId]!,
                          style: GoogleFonts.inter(
                            color: AppColors.primaryRed,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_chatThreads.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode
                          ? const Color(0xFF3A3949)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<int>(
                      value: _currentThreadId,
                      items: _chatThreads
                          .map((thread) => DropdownMenuItem<int>(
                                value: thread['id'],
                                child: SizedBox(
                                  width: 150,
                                  child: Text(
                                    thread['title'] ?? 'Untitled Chat',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: themeProvider.isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          final thread = _chatThreads.firstWhere(
                            (t) => t['id'] == value,
                            orElse: () => {'title': 'Chat'},
                          );
                          setState(() {
                            _currentThreadId = value;
                            _currentThreadTitle = thread['title'] ?? 'Chat';
                          });
                          _loadThreadMessages(value);
                        }
                      },
                      underline: const SizedBox(),
                      icon: Icon(Icons.arrow_drop_down,
                          size: 16,
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.black),
                    ),
                  ),
              ],
            ),
          ),
          // Messages Area
          Expanded(
            child: _currentThreadId == null
                ? _buildNoThreadSelectedState(themeProvider)
                : _messages.isEmpty
                    ? _buildNoMessagesState(themeProvider)
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(20),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) => _buildMessageBubble(
                            _messages[index], themeProvider),
                      ),
          ),
          // Message Input
          _buildMessageInput(themeProvider),
        ],
      ),
    );
  }

  Widget _buildNoThreadSelectedState(ThemeProvider themeProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: themeProvider.isDarkMode
                ? Colors.grey.shade600
                : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Select a chat to start messaging',
            style: GoogleFonts.poppins(
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a thread or create a new one',
            style: GoogleFonts.inter(
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade500
                  : Colors.grey.shade500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMessagesState(ThemeProvider themeProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: themeProvider.isDarkMode
                ? Colors.grey.shade600
                : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: GoogleFonts.poppins(
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send your first message to start the conversation',
            style: GoogleFonts.inter(
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade500
                  : Colors.grey.shade500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, ThemeProvider themeProvider) {
    final isCurrentUser = message.authorId == _getCurrentUserId();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isCurrentUser)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue, Colors.blue.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  message.authorName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (!isCurrentUser) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isCurrentUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isCurrentUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      message.authorName,
                      style: GoogleFonts.inter(
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.6,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurrentUser
                        ? AppColors.primaryRed
                        : (themeProvider.isDarkMode
                            ? const Color(0xFF252433)
                            : const Color(0xFFF8F9FA)),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.content,
                    style: GoogleFonts.inter(
                      color: isCurrentUser
                          ? Colors.white
                          : (themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.black),
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimeAgo(message.timestamp),
                  style: GoogleFonts.inter(
                    color: themeProvider.isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (isCurrentUser) const SizedBox(width: 8),
          if (isCurrentUser)
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.primaryRed,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'ME',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? const Color(0xFF252433)
            : const Color(0xFFF8F9FA),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(
          top: BorderSide(
            color: themeProvider.isDarkMode
                ? const Color(0xFF3A3949)
                : const Color(0xFFE9ECEF),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode
                    ? const Color(0xFF1A1925)
                    : Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: themeProvider.isDarkMode
                      ? const Color(0xFF3A3949)
                      : const Color(0xFFE9ECEF),
                ),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  border: InputBorder.none,
                  hintStyle: GoogleFonts.inter(
                    color: themeProvider.isDarkMode
                        ? Colors.grey.shade500
                        : Colors.grey.shade500,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                style: GoogleFonts.inter(
                  color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                ),
                enabled: !_isSending,
                onChanged: (value) {
                  if (_currentThreadId != null && _webSocketService != null) {
                    _webSocketService!
                        .sendTyping(_currentThreadId!, value.isNotEmpty);
                  }
                },
                onSubmitted: (value) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryRed, const Color(0xFFEF4444)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryRed.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: !_isSending ? _sendMessage : null,
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // All other methods remain exactly the same (unchanged)
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final content = _messageController.text.trim();

      // Create a default thread if none selected
      if (_currentThreadId == null) {
        final participantIds = _teamMembers.map((m) => m.userId).toList();
        final newThread = await _apiService.createChatThread(
          title: 'Team Chat',
          participantIds: participantIds,
        );
        setState(() {
          _currentThreadId = newThread['id'];
          _currentThreadTitle = newThread['title'] ?? 'Team Chat';
          _chatThreads.insert(0, newThread);
        });
      }

      final threadId = _currentThreadId!;

      // Send via API for persistence (also broadcasts to other participants)
      final response = await _apiService.sendMessage(
        threadId: threadId,
        content: content,
      );

      final messageData = response['message_data'] ?? response;
      if (messageData is Map<String, dynamic>) {
        setState(() {
          _messages.insert(0, ChatMessage.fromJson(messageData));
        });
      }

      _messageController.clear();

      // Clear typing indicator
      _webSocketService?.sendTyping(threadId, false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Failed to send message: $e', style: GoogleFonts.inter()),
          backgroundColor: AppColors.primaryRed,
        ),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _startChatWithUser(TeamMember member) async {
    try {
      // Create a new chat thread with the selected user
      final newThread = await _apiService.createChatThread(
        title: 'Chat with ${member.name}',
        participantIds: [member.userId],
      );

      setState(() {
        _currentThreadId = newThread['id'];
        _currentThreadTitle = newThread['title'] ?? 'Chat';
        _chatThreads.insert(0, newThread);
      });

      await _loadThreadMessages(_currentThreadId!);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start chat: $e', style: GoogleFonts.inter()),
          backgroundColor: AppColors.primaryRed,
        ),
      );
    }
  }

  Future<void> _createNewChatThread() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white,
        title: Text('New Chat Thread',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black,
            )),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Chat Title',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                labelStyle: GoogleFonts.inter(
                  color: themeProvider.isDarkMode
                      ? Colors.grey.shade400
                      : Colors.black,
                ),
              ),
              style: GoogleFonts.inter(
                color: themeProvider.isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: themeProvider.isDarkMode
                        ? Colors.grey.shade400
                        : AppColors.textGrey)),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryRed.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a title',
                          style: GoogleFonts.inter()),
                      backgroundColor: AppColors.primaryRed,
                    ),
                  );
                  return;
                }

                try {
                  // Create thread with all team members
                  final participantIds =
                      _teamMembers.map((m) => m.userId).toList();

                  final newThread = await _apiService.createChatThread(
                    title: titleController.text.trim(),
                    participantIds: participantIds,
                  );

                  Navigator.pop(context);

                  setState(() {
                    _currentThreadId = newThread['id'];
                    _currentThreadTitle = newThread['title'] ?? 'Chat';
                    _chatThreads.insert(0, newThread);
                  });

                  await _loadThreadMessages(_currentThreadId!);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to create chat: $e',
                          style: GoogleFonts.inter()),
                      backgroundColor: AppColors.primaryRed,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('Create',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  void _createSharedNote() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white,
        title: Text('Create Shared Note',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black,
            )),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                labelStyle: GoogleFonts.inter(
                  color: themeProvider.isDarkMode
                      ? Colors.grey.shade400
                      : Colors.black,
                ),
              ),
              style: GoogleFonts.inter(
                color: themeProvider.isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentController,
              decoration: InputDecoration(
                labelText: 'Content',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                labelStyle: GoogleFonts.inter(
                  color: themeProvider.isDarkMode
                      ? Colors.grey.shade400
                      : Colors.black,
                ),
              ),
              maxLines: 4,
              style: GoogleFonts.inter(
                color: themeProvider.isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: themeProvider.isDarkMode
                        ? Colors.grey.shade400
                        : AppColors.textGrey)),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryRed.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty ||
                    contentController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please fill in both title and content',
                          style: GoogleFonts.inter()),
                      backgroundColor: AppColors.primaryRed,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                  return;
                }

                try {
                  await _apiService.createNote({
                    'title': titleController.text.trim(),
                    'content': contentController.text.trim(),
                  });

                  Navigator.pop(context);
                  await _loadTeamData(); // Refresh the notes list

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Shared note created successfully',
                          style: GoogleFonts.inter()),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to create note: $e',
                          style: GoogleFonts.inter()),
                      backgroundColor: AppColors.primaryRed,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('Create',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  void _viewSharedNote(SharedNote note) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white,
        title: Text(note.title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black,
            )),
        content: SingleChildScrollView(
          child: Text(note.content,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: themeProvider.isDarkMode ? Colors.white : Colors.black,
              )),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close',
                style: GoogleFonts.inter(color: AppColors.primaryRed)),
          ),
        ],
      ),
    );
  }

  void _scheduleMeeting() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const HMMeetingsPage(),
      ),
    );
  }

  int _getCurrentUserId() {
    // Return cached value if available
    if (_cachedUserId != null) return _cachedUserId!;

    // Try WebSocketService synchronously
    if (_webSocketService?.userId != null) {
      _cachedUserId = _webSocketService!.userId;
      return _cachedUserId!;
    }

    // Last resort: return 0 (no message will match, isCurrentUser will be false)
    // Prefer this over throwing to avoid build-time crashes
    return 0;
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _webSocketService?.disconnect();
    super.dispose();
  }
}

// Models - These remain exactly the same
class ChatMessage {
  final int id;
  final int authorId;
  final String authorName;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: _safeToInt(json['id']),
      authorId: _safeToInt(json['author_id'] ?? json['user_id']),
      authorName: json['author_name']?.toString() ??
          json['user_name']?.toString() ??
          'Unknown',
      content: json['content']?.toString() ?? '',
      timestamp: _parseDateTime(json['created_at'] ?? json['timestamp']),
    );
  }

// Helper methods to add to your class
  static int _safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime _parseDateTime(dynamic value) {
    try {
      if (value == null) return DateTime.now();
      if (value is String) return DateTime.parse(value);
      if (value is int)
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }
}

class TeamMember {
  final String name;
  final String role;
  final bool isOnline;
  final int userId;

  TeamMember({
    required this.name,
    required this.role,
    required this.isOnline,
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
