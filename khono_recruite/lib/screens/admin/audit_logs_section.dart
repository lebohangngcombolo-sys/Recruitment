import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/admin_state_provider.dart';
import '../../widgets/themed_surface_card.dart';
import '../../widgets/audit_log_components.dart';

/// Audit logs section component
class AuditLogsSection extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onRefresh;

  const AuditLogsSection({
    super.key,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final adminProvider = Provider.of<AdminStateProvider>(context);

    return ThemedSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Audit Logs',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color:
                      themeProvider.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              Row(
                children: [
                  if (!isLoading)
                    IconButton(
                      onPressed: onRefresh,
                      icon: Icon(
                        Icons.refresh,
                        size: 20,
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  TextButton(
                    onPressed: () {
                      // Navigate to full audit logs view
                    },
                    child: Text(
                      'View All',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFC10D00),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (adminProvider.auditLogs.isEmpty)
            SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_outlined,
                      size: 64,
                      color: themeProvider.isDarkMode
                          ? Colors.grey.shade600
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Audit Logs',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No audit logs to display.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 300,
              child: AuditLogsTable(
                logs: adminProvider.auditLogs
                    .take(5)
                    .map((log) => AuditLogEntry(
                          id: log['id'] ?? 0,
                          userId: log['user_id']?.toString() ?? '',
                          userName: log['user_name'] ?? 'Unknown',
                          action: log['action'] ?? '',
                          resourceType: log['resource_type'] ?? '',
                          resourceId: log['resource_id'] as int?,
                          timestamp:
                              DateTime.tryParse(log['timestamp'] ?? '') ??
                                  DateTime.now(),
                          details: log['details'] ?? '',
                        ))
                    .toList(),
                currentPage: 1,
                totalPages: adminProvider.auditLogsTotalPages,
                onPageChanged: (page) {
                  adminProvider.setAuditLogsPage(page);
                  adminProvider.fetchAuditLogs();
                },
              ),
            ),
        ],
      ),
    );
  }
}
