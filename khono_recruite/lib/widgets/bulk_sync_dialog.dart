import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/admin_service.dart';
import '../providers/theme_provider.dart';

class BulkSyncDialog extends StatefulWidget {
  final List<Map<String, dynamic>> jobs;

  const BulkSyncDialog({Key? key, required this.jobs}) : super(key: key);

  @override
  State<BulkSyncDialog> createState() => _BulkSyncDialogState();
}

class _BulkSyncDialogState extends State<BulkSyncDialog> {
  List<int> _selectedJobIds = [];
  bool _onlyActive = true;
  bool _syncing = false;
  Map<String, dynamic>? _result;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    // Filter eligible jobs
    final eligibleJobs = widget.jobs.where((job) {
      if (!_onlyActive) return true;
      return job['is_active'] == true;
    }).where((job) {
      return job['approval_status'] == 'approved';
    }).toList();

    return Dialog(
      backgroundColor: themeProvider.isDarkMode 
          ? const Color(0xFF14131E) 
          : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.cloud_sync, 
                  color: themeProvider.isDarkMode ? Colors.blue : Colors.blue.shade700,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bulk Sync to Recruitee',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filter toggle
            SwitchListTile(
              title: Text(
                'Only Active Jobs',
                style: GoogleFonts.inter(
                  color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              value: _onlyActive,
              onChanged: _syncing 
                  ? null 
                  : (v) => setState(() => _onlyActive = v),
              activeColor: Colors.blue,
            ),
            const Divider(),

            // Results summary (if available)
            if (_result != null) ...[
              _buildResultCard(themeProvider),
              const SizedBox(height: 16),
            ],

            // Syncing indicator
            if (_syncing) ...[
              LinearProgressIndicator(
                backgroundColor: Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Syncing jobs...',
                  style: GoogleFonts.inter(
                    color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Selection actions
            Row(
              children: [
                TextButton.icon(
                  onPressed: _syncing ? null : () {
                    setState(() {
                      _selectedJobIds = eligibleJobs.map((j) => j['id'] as int).toList();
                    });
                  },
                  icon: const Icon(Icons.select_all, size: 18),
                  label: Text('Select All', style: GoogleFonts.inter()),
                ),
                TextButton.icon(
                  onPressed: _syncing ? null : () {
                    setState(() => _selectedJobIds = []);
                  },
                  icon: const Icon(Icons.clear, size: 18),
                  label: Text('Clear', style: GoogleFonts.inter()),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selectedJobIds.length} selected',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Job list
            Expanded(
              child: eligibleJobs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.work_off_outlined,
                            size: 48,
                            color: themeProvider.isDarkMode 
                                ? Colors.grey.shade600 
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No eligible jobs',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: themeProvider.isDarkMode 
                                  ? Colors.grey.shade400 
                                  : Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            'Jobs must be approved to sync',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: themeProvider.isDarkMode 
                                  ? Colors.grey.shade500 
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: eligibleJobs.length,
                      itemBuilder: (context, index) {
                        final job = eligibleJobs[index];
                        final jobId = job['id'] as int;
                        final isSelected = _selectedJobIds.contains(jobId);
                        final hasRecruiteeId = job['recruitee_id'] != null;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isSelected
                              ? Colors.blue.withOpacity(0.1)
                              : themeProvider.isDarkMode 
                                  ? const Color(0xFF1E1E1E) 
                                  : Colors.grey.shade50,
                          child: CheckboxListTile(
                            value: isSelected,
                            onChanged: _syncing 
                                ? null 
                                : (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        _selectedJobIds.add(jobId);
                                      } else {
                                        _selectedJobIds.remove(jobId);
                                      }
                                    });
                                  },
                            title: Text(
                              job['title'] ?? 'Untitled',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w500,
                                color: themeProvider.isDarkMode 
                                    ? Colors.white 
                                    : Colors.black87,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                if (hasRecruiteeId)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Synced',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: Colors.green,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Not Synced',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ),
                                if (job['location'] != null)
                                  Text(
                                    job['location'],
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: themeProvider.isDarkMode 
                                          ? Colors.grey.shade500 
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                            secondary: hasRecruiteeId
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : const Icon(Icons.cloud_upload_outlined, color: Colors.orange),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 16),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _syncing ? null : () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      color: themeProvider.isDarkMode 
                          ? Colors.grey.shade400 
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _selectedJobIds.isEmpty || _syncing
                      ? null
                      : _performBulkSync,
                  icon: _syncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(
                    _syncing 
                        ? 'Syncing...' 
                        : 'Sync ${_selectedJobIds.length} Jobs',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(ThemeProvider themeProvider) {
    final total = _result!['total'] ?? 0;
    final successful = _result!['successful'] ?? 0;
    final failed = _result!['failed'] ?? 0;
    final errors = (_result!['errors'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: failed > 0 
            ? Colors.orange.withOpacity(0.1) 
            : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: failed > 0 ? Colors.orange : Colors.green,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sync Results',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ResultStat(label: 'Total', value: total, color: Colors.blue),
              _ResultStat(label: 'Success', value: successful, color: Colors.green),
              _ResultStat(label: 'Failed', value: failed, color: Colors.red),
            ],
          ),
          if (errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Errors:',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 4),
            ...errors.take(3).map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• ${e['job_title'] ?? 'Job'}: ${e['error']}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: themeProvider.isDarkMode 
                      ? Colors.grey.shade400 
                      : Colors.grey.shade700,
                ),
              ),
            )).toList(),
          ],
        ],
      ),
    );
  }

  Future<void> _performBulkSync() async {
    setState(() => _syncing = true);

    try {
      final adminService = Provider.of<AdminService>(context, listen: false);
      final result = await adminService.bulkSyncJobs(
        jobIds: _selectedJobIds,
        onlyActive: _onlyActive,
      );
      
      setState(() {
        _syncing = false;
        _result = result;
      });

      // Show success message if all succeeded
      if (result['failed'] == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully synced ${result['successful']} jobs!'),
            backgroundColor: Colors.green,
          ),
        );
        // Auto-close after success
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } catch (e) {
      setState(() => _syncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _ResultStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _ResultStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
