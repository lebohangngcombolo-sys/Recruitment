import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/admin_service.dart';
import '../../providers/theme_provider.dart';

class SyncHistoryScreen extends StatefulWidget {
  final int? jobId;
  final String? jobTitle;

  const SyncHistoryScreen({Key? key, this.jobId, this.jobTitle})
      : super(key: key);

  @override
  State<SyncHistoryScreen> createState() => _SyncHistoryScreenState();
}

class _SyncHistoryScreenState extends State<SyncHistoryScreen> {
  List<dynamic> _history = [];
  bool _loading = true;
  String? _error;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final adminService = Provider.of<AdminService>(context, listen: false);
      final history = await adminService.getSyncHistory(
        entityType: 'job',
        entityId: widget.jobId,
        status: _selectedFilter == 'all' ? null : _selectedFilter,
        limit: 50,
      );
      setState(() {
        _history = history;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _onFilterChanged(String? value) {
    if (value != null && value != _selectedFilter) {
      setState(() => _selectedFilter = value);
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode
          ? const Color(0xFF0A0A0A)
          : Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          widget.jobTitle != null
              ? 'Sync History: ${widget.jobTitle}'
              : 'Sync History',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor:
            themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white,
        elevation: 0,
        actions: [
          // Filter dropdown
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFilter,
                icon: const Icon(Icons.filter_list),
                dropdownColor: themeProvider.isDarkMode
                    ? const Color(0xFF1E1E1E)
                    : Colors.white,
                items: [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('All Status',
                        style: GoogleFonts.inter(
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black)),
                  ),
                  DropdownMenuItem(
                    value: 'success',
                    child: Text('Success',
                        style: GoogleFonts.inter(color: Colors.green)),
                  ),
                  DropdownMenuItem(
                    value: 'failed',
                    child: Text('Failed',
                        style: GoogleFonts.inter(color: Colors.red)),
                  ),
                  DropdownMenuItem(
                    value: 'pending',
                    child: Text('Pending',
                        style: GoogleFonts.inter(color: Colors.orange)),
                  ),
                ],
                onChanged: _onFilterChanged,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _history.isEmpty
                  ? _buildEmptyView()
                  : _buildHistoryList(),
    );
  }

  Widget _buildErrorView() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            'Error loading history',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: GoogleFonts.inter(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadHistory,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_outlined,
            size: 64,
            color: themeProvider.isDarkMode
                ? Colors.grey.shade600
                : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No Sync History',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.jobId != null
                ? 'This job has not been synced yet'
                : 'No sync records found',
            style: GoogleFonts.inter(
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade500
                  : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        return _buildHistoryTile(item, themeProvider);
      },
    );
  }

  Widget _buildHistoryTile(
      Map<String, dynamic> item, ThemeProvider themeProvider) {
    final status = item['status'] as String? ?? 'unknown';
    final action = item['action'] as String? ?? 'unknown';
    final createdAt =
        item['created_at'] != null ? DateTime.parse(item['created_at']) : null;
    final errorMessage = item['error_message'] as String?;
    final retryCount = item['retry_count'] ?? 0;
    final maxRetries = item['max_retries'] ?? 3;
    final nextRetryAt = item['next_retry_at'] != null
        ? DateTime.parse(item['next_retry_at'])
        : null;
    final syncedBy = item['synced_by_user'] as Map<String, dynamic>?;

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'success':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      case 'skipped':
        statusColor = Colors.grey;
        statusIcon = Icons.skip_next;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white,
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(statusIcon, color: statusColor, size: 20),
        ),
        title: Text(
          '${action.toUpperCase()} - ${status.toUpperCase()}',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (errorMessage != null)
              Text(
                errorMessage,
                style: GoogleFonts.inter(
                  color: Colors.red,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (status == 'failed' && retryCount < maxRetries)
              Text(
                'Retry $retryCount/$maxRetries scheduled',
                style: GoogleFonts.inter(
                  color: Colors.orange,
                  fontSize: 12,
                ),
              ),
            if (status == 'pending' && nextRetryAt != null)
              Text(
                'Next retry: ${_timeUntil(nextRetryAt)}',
                style: GoogleFonts.inter(
                  color: Colors.blue,
                  fontSize: 12,
                ),
              ),
            Text(
              _formatDate(createdAt),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: themeProvider.isDarkMode
                    ? Colors.grey.shade500
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (syncedBy != null)
                  _buildDetailRow('Synced By',
                      syncedBy['name'] ?? syncedBy['email'] ?? 'Unknown'),
                if (item['recruitee_id'] != null)
                  _buildDetailRow('Recruitee ID', item['recruitee_id']),
                _buildDetailRow('Entity Type', item['entity_type'] ?? 'N/A'),
                _buildDetailRow(
                    'Entity ID', item['entity_id']?.toString() ?? 'N/A'),
                if (item['request_data'] != null)
                  _buildJsonView('Request Data', item['request_data']),
                if (item['response_data'] != null)
                  _buildJsonView('Response Data', item['response_data']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJsonView(String label, dynamic data) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? const Color(0xFF0A0A0A)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.toString(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade300
                  : Colors.grey.shade800,
            ),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _timeUntil(DateTime dateTime) {
    final diff = dateTime.difference(DateTime.now());
    if (diff.isNegative) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
