import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/admin_service.dart';
import '../providers/theme_provider.dart';
import '../screens/admin/sync_history_screen.dart';

class RecruiteeIntegrationCard extends StatefulWidget {
  const RecruiteeIntegrationCard({Key? key}) : super(key: key);

  @override
  State<RecruiteeIntegrationCard> createState() => _RecruiteeIntegrationCardState();
}

class _RecruiteeIntegrationCardState extends State<RecruiteeIntegrationCard> {
  Map<String, dynamic>? _status;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final adminService = Provider.of<AdminService>(context, listen: false);
      final status = await adminService.getRecruiteeStatus();
      setState(() {
        _status = status;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _processRetries() async {
    try {
      final adminService = Provider.of<AdminService>(context, listen: false);
      final result = await adminService.processRetries();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Processed ${result['processed'] ?? 0} pending retries'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh status
      _loadStatus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Card(
      elevation: 4,
      color: themeProvider.isDarkMode 
          ? const Color(0xFF14131E) 
          : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _loading
            ? _buildLoadingView()
            : _error != null
                ? _buildErrorView()
                : _buildContentView(themeProvider),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorView() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
        const SizedBox(height: 16),
        Text(
          'Failed to load status',
          style: GoogleFonts.inter(
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
        ElevatedButton.icon(
          onPressed: _loadStatus,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }

  Widget _buildContentView(ThemeProvider themeProvider) {
    final enabled = _status!['enabled'] ?? false;
    final configured = _status!['configured'] ?? false;
    final connected = _status!['connected'] ?? false;
    final companyId = _status!['company_id'] as String?;
    final error = _status!['error'] as String?;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (!enabled) {
      statusColor = Colors.grey;
      statusIcon = Icons.cloud_off;
      statusText = 'Disabled';
    } else if (!configured) {
      statusColor = Colors.orange;
      statusIcon = Icons.settings;
      statusText = 'Not Configured';
    } else if (connected) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Connected';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = 'Connection Failed';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with status
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(statusIcon, color: statusColor, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recruitee ATS',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: GoogleFonts.inter(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Company info
        if (connected && companyId != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode 
                  ? const Color(0xFF1E1E1E) 
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.business,
                  size: 16,
                  color: themeProvider.isDarkMode 
                      ? Colors.grey.shade400 
                      : Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  'Company ID: ',
                  style: GoogleFonts.inter(
                    color: themeProvider.isDarkMode 
                        ? Colors.grey.shade400 
                        : Colors.grey.shade600,
                  ),
                ),
                Text(
                  companyId,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Error message
        if (error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error,
                    style: GoogleFonts.inter(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        const Divider(),
        const SizedBox(height: 16),

        // Action buttons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: _loadStatus,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Test Connection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SyncHistoryScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.history, size: 18),
              label: const Text('View History'),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeProvider.isDarkMode 
                    ? const Color(0xFF1E1E1E) 
                    : Colors.grey.shade200,
                foregroundColor: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            if (connected)
              ElevatedButton.icon(
                onPressed: _processRetries,
                icon: const Icon(Icons.sync, size: 18),
                label: const Text('Process Retries'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
