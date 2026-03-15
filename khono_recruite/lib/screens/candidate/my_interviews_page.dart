import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/candidate_service.dart';

class MyInterviewsPage extends StatefulWidget {
  final String token;

  const MyInterviewsPage({super.key, required this.token});

  @override
  State<MyInterviewsPage> createState() => _MyInterviewsPageState();
}

class _MyInterviewsPageState extends State<MyInterviewsPage> {
  List<Map<String, dynamic>> _interviews = [];
  bool _loading = true;
  int _scheduledCount = 0;
  int _focusedIndex = 0;
  bool _showDetailView = false;
  final Set<int> _acceptingIds = {};
  final Set<int> _decliningIds = {};

  static const Color _primaryRed = Color(0xFF991A1A);
  static const Color _accentRed = Color(0xFFC10D00);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await CandidateService.getInterviews(widget.token);
      final list = data['interviews'];
      final count = data['scheduled_count'] is int
          ? data['scheduled_count'] as int
          : (int.tryParse(data['scheduled_count']?.toString() ?? '') ?? 0);
      if (mounted) {
        setState(() {
          _interviews = list is List
              ? list
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : [];
          _sortAndFocusInterviews();
          _scheduledCount = count;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() {
        _interviews = [];
        _scheduledCount = 0;
        _loading = false;
        _focusedIndex = 0;
        _showDetailView = false;
      });
    }
  }

  void _sortAndFocusInterviews() {
    final now = DateTime.now();
    final upcoming = <Map<String, dynamic>>[];
    final past = <Map<String, dynamic>>[];
    for (final i in _interviews) {
      final iso = i['scheduled_time']?.toString();
      if (iso == null || iso.isEmpty) {
        upcoming.add(i);
        continue;
      }
      try {
        if (DateTime.parse(iso).isAfter(now)) {
          upcoming.add(i);
        } else {
          past.add(i);
        }
      } catch (_) {
        upcoming.add(i);
      }
    }
    upcoming.sort((a, b) {
      try {
        return DateTime.parse(a['scheduled_time']?.toString() ?? '')
            .compareTo(DateTime.parse(b['scheduled_time']?.toString() ?? ''));
      } catch (_) {
        return 0;
      }
    });
    past.sort((a, b) {
      try {
        return DateTime.parse(b['scheduled_time']?.toString() ?? '')
            .compareTo(DateTime.parse(a['scheduled_time']?.toString() ?? ''));
      } catch (_) {
        return 0;
      }
    });
    _interviews = [...upcoming, ...past];
    _focusedIndex = 0;
  }

  int get _upcomingCount {
    final now = DateTime.now();
    return _interviews.where((i) {
      final iso = i['scheduled_time']?.toString();
      if (iso == null || iso.isEmpty) return true;
      try {
        return DateTime.parse(iso).isAfter(now);
      } catch (_) {
        return true;
      }
    }).length;
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso);
      const months = 'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec';
      final m = months.split(',')[dt.month - 1];
      return '${m} ${dt.day}, ${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  String? _countdownTo(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      final dt = DateTime.parse(iso);
      if (dt.isBefore(DateTime.now())) return null;
      final diff = dt.difference(DateTime.now());
      final hours = diff.inHours;
      final minutes = diff.inMinutes.remainder(60);
      if (hours > 24) {
        final days = diff.inDays;
        return '${days}d ${hours % 24}h';
      }
      return '${hours}h ${minutes}m';
    } catch (_) {
      return null;
    }
  }

  bool _canAcceptOrDecline(Map<String, dynamic> i) {
    final status = i['status']?.toString().toLowerCase();
    if (status == null) return true;
    if (status == 'scheduled' || status == 'pending' || status == 'invited') return true;
    return false;
  }

  Future<void> _acceptInvite(Map<String, dynamic> i) async {
    final id = i['id'];
    if (id == null) {
      _showSnack('This interview cannot be accepted.', isError: true);
      return;
    }
    final interviewId = id is int ? id : int.tryParse(id.toString());
    if (interviewId == null) {
      _showSnack('Invalid interview.', isError: true);
      return;
    }
    setState(() => _acceptingIds.add(interviewId));
    try {
      await CandidateService.acceptInterview(widget.token, interviewId);
      if (!mounted) return;
      _showSnack('You have accepted the interview invite.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _acceptingIds.remove(interviewId));
    }
  }

  Future<void> _declineInvite(Map<String, dynamic> i) async {
    final id = i['id'];
    if (id == null) {
      _showSnack('This interview cannot be declined.', isError: true);
      return;
    }
    final interviewId = id is int ? id : int.tryParse(id.toString());
    if (interviewId == null) {
      _showSnack('Invalid interview.', isError: true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text(
          'Decline interview?',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'The hiring team will be notified. You can request a new time if needed.',
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Decline', style: GoogleFonts.poppins(color: _accentRed)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _decliningIds.add(interviewId));
    try {
      await CandidateService.declineInterview(widget.token, interviewId);
      if (!mounted) return;
      _showSnack('You have declined the interview.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _decliningIds.remove(interviewId));
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF2A2A2A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _isUpcoming(String? iso) {
    if (iso == null || iso.isEmpty) return false;
    try {
      return DateTime.parse(iso).isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/dark.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                Expanded(
                  child: _loading
                      ? _buildLoadingPlaceholder()
                      : (_interviews.isEmpty
                          ? _buildEmptyState()
                          : _showDetailView
                              ? _buildTwoColumnContent()
                              : _buildInterviewListView()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isListView = !_showDetailView;
    if (isListView) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'My Interviews',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (_upcomingCount > 0)
                    Text(
                      '$_upcomingCount upcoming',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
                    )
                  else if (_interviews.isNotEmpty)
                    Text(
                      _scheduledCount > 0 ? '$_scheduledCount scheduled' : '${_interviews.length} interviews',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final focus = _interviews.isNotEmpty && _focusedIndex < _interviews.length
        ? _interviews[_focusedIndex]
        : null;
    final jobTitle = focus?['job_title']?.toString() ?? '—';
    final scheduledTime = focus?['scheduled_time']?.toString();
    final countdown = _countdownTo(scheduledTime);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => setState(() => _showDetailView = false),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  jobTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (countdown != null && _isUpcoming(scheduledTime))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _primaryRed.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accentRed.withValues(alpha: 0.4)),
              ),
              child: Text(
                'Starts in $countdown',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          if (countdown != null) const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Icon(Icons.event_available_rounded, size: 56, color: Colors.white.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            Text(
              'No interviews yet',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'When a hiring manager schedules an interview, it will appear here. You can accept or decline invites from this screen.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.white60, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Khonology',
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: _accentRed,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Preparing your interviews',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'We’re fetching your latest interview schedule.\nThis will only take a moment.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 8,
                width: 220,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const LinearProgressIndicator(
                  value: null,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2ECC71)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterviewListView() {
    final now = DateTime.now();
    int upcomingEndIndex = 0;
    for (; upcomingEndIndex < _interviews.length; upcomingEndIndex++) {
      final iso = _interviews[upcomingEndIndex]['scheduled_time']?.toString();
      if (iso == null || iso.isEmpty) continue;
      try {
        if (!DateTime.parse(iso).isAfter(now)) break;
      } catch (_) {}
    }
    final upcomingIndices = List.generate(upcomingEndIndex, (i) => i);
    final pastIndices = List.generate(_interviews.length - upcomingEndIndex, (i) => upcomingEndIndex + i);
    final hasNextUp = upcomingIndices.isNotEmpty;
    final nextUpIndex = hasNextUp ? 0 : (pastIndices.isNotEmpty ? pastIndices.first : null);
    final restUpcoming = upcomingIndices.length > 1 ? upcomingIndices.sublist(1) : <int>[];

    return RefreshIndicator(
      onRefresh: _load,
      color: _accentRed,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          if (nextUpIndex != null) ...[
            _sectionLabel(hasNextUp ? 'Next up' : 'Most recent'),
            const SizedBox(height: 8),
            _buildListCard(nextUpIndex, isNextUp: hasNextUp),
            const SizedBox(height: 24),
          ],
          if (restUpcoming.isNotEmpty) ...[
            _sectionLabel('Upcoming'),
            const SizedBox(height: 8),
            ...restUpcoming.map((index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildListCard(index),
            )),
            const SizedBox(height: 24),
          ],
          if (pastIndices.isNotEmpty) ...[
            _sectionLabel('Past'),
            const SizedBox(height: 8),
            ...pastIndices.map((index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildListCard(index, isPast: true),
            )),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _buildListCard(int index, {bool isNextUp = false, bool isPast = false}) {
    final i = _interviews[index];
    final jobTitle = i['job_title']?.toString() ?? '—';
    final scheduledTime = i['scheduled_time']?.toString();
    final interviewType = i['interview_type']?.toString() ?? 'Online';
    final countdown = _countdownTo(scheduledTime);
    final upcoming = !isPast && _isUpcoming(scheduledTime);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _focusedIndex = index;
            _showDetailView = true;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isNextUp
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isNextUp ? _accentRed.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.12),
                  width: isNextUp ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: upcoming
                              ? _primaryRed.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          upcoming ? Icons.video_call_rounded : Icons.event_note_rounded,
                          color: upcoming ? _accentRed : Colors.white70,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              jobTitle,
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  _formatDate(scheduledTime),
                                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatTime(scheduledTime),
                                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '· $interviewType',
                                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.white54),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isNextUp && countdown != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _primaryRed.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _accentRed.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'Starts in $countdown',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
                          ),
                        )
                      else if (isNextUp && !upcoming)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Past',
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 24),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTwoColumnContent() {
    final i = _interviews[_focusedIndex];
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    final invitationCard = _buildInvitationBlock(i);
    final timelineCard = _buildTimelineCard();

    if (isWide) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: invitationCard),
                      const SizedBox(width: 20),
                      SizedBox(width: 360, child: timelineCard),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildPrepareSection(i),
                ],
              ),
            ),
            const SizedBox(width: 20),
            if (_interviews.length > 1)
              SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 0),
                  child: _buildOtherInterviews(),
                ),
              ),
          ],
        ),
      );
    }

    final leftColumn = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInvitationBlock(i),
          const SizedBox(height: 32),
          _buildPrepareSection(i),
        ],
      ),
    );

    final rightColumn = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          timelineCard,
          if (_interviews.length > 1) ...[
            const SizedBox(height: 24),
            _buildOtherInterviews(),
          ],
        ],
      ),
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: leftColumn),
          SizedBox(width: 360, child: rightColumn),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        leftColumn,
        const SizedBox(height: 16),
        rightColumn,
      ],
    );
  }

  Widget _buildInvitationBlock(Map<String, dynamic> i, {bool stretchToFill = false}) {
    final jobTitle = i['job_title']?.toString() ?? '—';
    final scheduledTime = i['scheduled_time']?.toString();
    final interviewType = i['interview_type']?.toString() ?? 'Online';
    final meetingLink = i['meeting_link']?.toString().trim();
    final interviewer = i['interviewer_name']?.toString() ?? i['hiring_manager_name']?.toString() ?? 'Hiring Manager';
    final duration = i['duration_minutes'] != null
        ? '${i['duration_minutes']} minutes'
        : '45 minutes';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: stretchToFill ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: stretchToFill ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "You're invited to interview for $jobTitle",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Congratulations! The hiring manager would like to meet you.',
                style: GoogleFonts.inter(fontSize: 15, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 18, color: Colors.white.withValues(alpha: 0.7)),
                  const SizedBox(width: 10),
                  Text(_formatDate(scheduledTime), style: GoogleFonts.poppins(fontSize: 14, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 18, color: Colors.white.withValues(alpha: 0.7)),
                  const SizedBox(width: 10),
                  Text(_formatTime(scheduledTime), style: GoogleFonts.poppins(fontSize: 14, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.video_call_rounded, size: 18, color: Colors.white.withValues(alpha: 0.7)),
                  const SizedBox(width: 10),
                  Text(interviewType, style: GoogleFonts.poppins(fontSize: 14, color: Colors.white)),
                ],
              ),
              if (meetingLink != null && meetingLink.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.link_rounded, size: 18, color: Colors.white.withValues(alpha: 0.7)),
                    const SizedBox(width: 10),
                    Text(
                      'Join meeting:',
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _openUrl(meetingLink),
                      child: Text(
                        'Open link',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: _accentRed,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                          decorationColor: _accentRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
                  children: [
                    const TextSpan(text: 'Interviewer: '),
                    TextSpan(
                      text: interviewer,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Duration: $duration',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
              ),
                ],
              ),
              const SizedBox(height: 24),
              _buildActionButtons(i),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> i) {
    final canAct = _canAcceptOrDecline(i);
    final id = i['id'];
    final interviewId = id is int ? id : int.tryParse(id?.toString() ?? '');
    final isAccepting = interviewId != null && _acceptingIds.contains(interviewId);
    final isDeclining = interviewId != null && _decliningIds.contains(interviewId);

    if (!canAct) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.end,
        children: [
          SizedBox(
            width: 200,
            child: FilledButton.icon(
              onPressed: isAccepting ? null : () => _acceptInvite(i),
              icon: isAccepting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 22),
              label: Text(
                isAccepting ? 'Accepting…' : 'Accept Interview',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _accentRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _showSnack('Request reschedule is coming soon.'),
            icon: const Icon(Icons.event_rounded, size: 20),
            label: Text(
              'Request Reschedule',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          OutlinedButton.icon(
            onPressed: isDeclining ? null : () => _declineInvite(i),
            icon: isDeclining
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                  )
                : const Icon(Icons.cancel_outlined, size: 20),
            label: Text(
              isDeclining ? 'Declining…' : 'Decline Interview',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrepareSection(Map<String, dynamic> i) {
    final prepItems = [
      ('Common Interview Questions', Icons.quiz_outlined, () => _showSnack('Practice questions coming soon.')),
      ('AI Interview Practice', Icons.smart_toy_outlined, () => _showSnack('AI practice coming soon.')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prepare for Your Interview',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  for (int row = 0; row < prepItems.length; row += 2) ...[
                    Row(
                      children: [
                        for (int col = 0; col < 2 && row + col < prepItems.length; col++) ...[
                          if (col > 0) const SizedBox(width: 12),
                          Expanded(
                            child: _buildPrepCard(
                              prepItems[row + col].$1,
                              prepItems[row + col].$2,
                              prepItems[row + col].$3,
                            ),
                          ),
                        ],
                        if (row + 1 >= prepItems.length && prepItems.length.isOdd) const Expanded(child: SizedBox()),
                      ],
                    ),
                    if (row + 2 < prepItems.length) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrepCard(String title, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: _accentRed.withValues(alpha: 0.9)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineCard() {
    const steps = [
      ('Application Submitted', true),
      ('Shortlisted', true),
      ('Interview Scheduled', false), // current
      ('Decision', false),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Application Timeline',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              for (int i = 0; i < steps.length; i++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      steps[i].$2 ? Icons.check_circle_rounded : (i == 2 ? Icons.info_outline_rounded : Icons.radio_button_unchecked_rounded),
                      size: 20,
                      color: steps[i].$2
                          ? Colors.greenAccent
                          : (i == 2 ? _accentRed : Colors.white38),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        steps[i].$1,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: i == 2 ? Colors.white : Colors.white70,
                          fontWeight: i == 2 ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (i == 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Day 1',
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.greenAccent, fontWeight: FontWeight.w500),
                        ),
                      ),
                    if (i == 2)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _primaryRed.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Current',
                          style: GoogleFonts.poppins(fontSize: 11, color: _accentRed, fontWeight: FontWeight.w500),
                        ),
                      ),
                  ],
                ),
                if (i < steps.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 9, top: 6, bottom: 6),
                    child: Container(
                      width: 2,
                      height: 12,
                      decoration: BoxDecoration(
                        color: steps[i].$2 ? Colors.greenAccent.withValues(alpha: 0.5) : Colors.white24,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtherInterviews() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Other interviews',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(_interviews.length, (index) {
          if (index == _focusedIndex) return const SizedBox.shrink();
          final i = _interviews[index];
          final title = i['job_title']?.toString() ?? '—';
          final date = _formatDate(i['scheduled_time']?.toString());
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _focusedIndex = index),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_rounded, size: 18, color: _accentRed.withValues(alpha: 0.9)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              date,
                              style: GoogleFonts.poppins(fontSize: 11, color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 20, color: Colors.white54),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
