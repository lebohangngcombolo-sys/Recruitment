import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Status badge for Recruitee sync status
class SyncStatusBadge extends StatelessWidget {
  final Map<String, dynamic> job;

  const SyncStatusBadge({Key? key, required this.job}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final approvalStatus = job['approval_status'] ?? 'draft';
    final syncToRecruitee = job['sync_to_recruitee'] ?? false;
    final recruiteeId = job['recruitee_id'] as String?;
    final lastSyncedSource = job['last_synced_source'];

    Color color;
    String text;
    IconData icon;

    if (approvalStatus != 'approved') {
      color = Colors.grey;
      text = 'Needs Approval';
      icon = Icons.lock;
    } else if (!syncToRecruitee) {
      color = Colors.grey;
      text = 'Sync Disabled';
      icon = Icons.cloud_off;
    } else if (recruiteeId == null) {
      color = Colors.orange;
      text = 'Ready to Sync';
      icon = Icons.cloud_upload;
    } else if (lastSyncedSource == 'recruitee') {
      color = Colors.blue;
      text = 'From Recruitee';
      icon = Icons.sync;
    } else {
      color = Colors.green;
      text = 'Synced';
      icon = Icons.check_circle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
