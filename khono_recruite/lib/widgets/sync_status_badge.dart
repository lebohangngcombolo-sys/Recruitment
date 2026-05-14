import 'package:flutter/material.dart';

/// Status badge for Recruitee sync status
class SyncStatusBadge extends StatelessWidget {
  final Map<String, dynamic> job;

  const SyncStatusBadge({Key? key, required this.job}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final approvalStatus = job['approval_status'] ?? 'draft';
    final syncToRecruitee = job['sync_to_recruitee'] ?? false;
    final recruiteeId = job['recruitee_id'];
    final lastSyncedSource = job['last_synced_source'];

    Color color;
    String text;
    IconData icon;

    if (approvalStatus != 'approved') {
      color = Colors.grey;
      text = 'Not approved';
      icon = Icons.block;
    } else if (!syncToRecruitee) {
      color = Colors.grey;
      text = 'Sync off';
      icon = Icons.cloud_off;
    } else if (recruiteeId == null) {
      color = Colors.orange;
      text = 'Not synced';
      icon = Icons.cloud_upload;
    } else if (lastSyncedSource == 'recruitee') {
      color = Colors.blue;
      text = 'From ATS';
      icon = Icons.sync;
    } else {
      color = Colors.green;
      text = 'Synced';
      icon = Icons.check_circle;
    }

    // Use a Chip which handles overflow and small spaces gracefully
    return Chip(
      avatar: Icon(icon, size: 14, color: color),
      label: Text(
        text,
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87),
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
    );
  }
}
