import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/theme_provider.dart';
import 'themed_surface_card.dart';
import 'package:flutter/material.dart' as material show FilterChip;

/// Audit log entry model
class AuditLogEntry {
  final int id;
  final String userId;
  final String userName;
  final String action;
  final String resourceType;
  final int? resourceId;
  final String? ipAddress;
  final DateTime timestamp;
  final String? details;

  AuditLogEntry({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    required this.resourceType,
    this.resourceId,
    this.ipAddress,
    required this.timestamp,
    this.details,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id'] ?? 0,
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name'] ?? json['username'] ?? 'Unknown',
      action: json['action'] ?? '',
      resourceType: json['resource_type'] ?? '',
      resourceId: json['resource_id'],
      ipAddress: json['ip_address'],
      timestamp:
          DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      details: json['details'],
    );
  }
}

/// Audit logs table component
class AuditLogsTable extends StatefulWidget {
  final List<AuditLogEntry> logs;
  final bool isLoading;
  final VoidCallback? onRefresh;
  final Function(AuditLogEntry)? onLogSelected;
  final int currentPage;
  final int totalPages;
  final Function(int)? onPageChanged;

  const AuditLogsTable({
    super.key,
    required this.logs,
    this.isLoading = false,
    this.onRefresh,
    this.onLogSelected,
    this.currentPage = 1,
    this.totalPages = 1,
    this.onPageChanged,
  });

  @override
  State<AuditLogsTable> createState() => _AuditLogsTableState();
}

class _AuditLogsTableState extends State<AuditLogsTable> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return ThemedSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Audit Logs',
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
                  if (widget.onRefresh != null)
                    IconButton(
                      onPressed: widget.isLoading ? null : widget.onRefresh,
                      icon: widget.isLoading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  themeProvider.isDarkMode
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.refresh,
                              color: themeProvider.isDarkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (widget.logs.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.history,
                      size: 48,
                      color: themeProvider.isDarkMode
                          ? Colors.grey.shade600
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No audit logs found',
                      style: TextStyle(
                        fontSize: 16,
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
            Column(
              children: [
                // Table header
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode
                        ? Colors.grey.shade800
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: _buildHeaderCell('Timestamp')),
                      Expanded(flex: 2, child: _buildHeaderCell('User')),
                      Expanded(flex: 2, child: _buildHeaderCell('Action')),
                      Expanded(flex: 2, child: _buildHeaderCell('Resource')),
                      Expanded(flex: 1, child: _buildHeaderCell('IP Address')),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Table rows
                ...widget.logs.map((log) => _buildLogRow(log, themeProvider)),
                const SizedBox(height: 16),
                // Pagination
                if (widget.totalPages > 1) _buildPagination(themeProvider),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: themeProvider.isDarkMode
            ? Colors.grey.shade300
            : Colors.grey.shade700,
      ),
    );
  }

  Widget _buildLogRow(AuditLogEntry log, ThemeProvider themeProvider) {
    return GestureDetector(
      onTap: widget.onLogSelected != null
          ? () => widget.onLogSelected!(log)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: themeProvider.isDarkMode
              ? Colors.grey.shade800.withValues(alpha: 0.3)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: themeProvider.isDarkMode
                ? Colors.grey.shade700
                : Colors.grey.shade200,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
                flex: 2,
                child: _buildTimestampCell(log.timestamp, themeProvider)),
            Expanded(
                flex: 2, child: _buildTextCell(log.userName, themeProvider)),
            Expanded(
                flex: 2, child: _buildActionCell(log.action, themeProvider)),
            Expanded(
                flex: 2,
                child: _buildTextCell(
                    '${log.resourceType} #${log.resourceId ?? ''}',
                    themeProvider)),
            Expanded(
                flex: 1,
                child: _buildTextCell(log.ipAddress ?? 'N/A', themeProvider)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimestampCell(DateTime timestamp, ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('MMM dd, yyyy').format(timestamp),
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: themeProvider.isDarkMode
                ? Colors.grey.shade300
                : Colors.grey.shade700,
          ),
        ),
        Text(
          DateFormat('HH:mm:ss').format(timestamp),
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            color: themeProvider.isDarkMode
                ? Colors.grey.shade500
                : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildTextCell(String text, ThemeProvider themeProvider) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 11,
        color: themeProvider.isDarkMode
            ? Colors.grey.shade300
            : Colors.grey.shade700,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildActionCell(String action, ThemeProvider themeProvider) {
    Color actionColor = _getActionColor(action);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: actionColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        action.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: actionColor,
        ),
      ),
    );
  }

  Color _getActionColor(String action) {
    switch (action.toLowerCase()) {
      case 'create':
        return Colors.green;
      case 'update':
        return Colors.blue;
      case 'delete':
        return Colors.red;
      case 'login':
        return Colors.purple;
      case 'logout':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPagination(ThemeProvider themeProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: widget.currentPage > 1 && widget.onPageChanged != null
              ? () => widget.onPageChanged!(widget.currentPage - 1)
              : null,
          icon: Icon(
            Icons.chevron_left,
            color: themeProvider.isDarkMode
                ? Colors.grey.shade400
                : Colors.grey.shade600,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Page ${widget.currentPage} of ${widget.totalPages}',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
            ),
          ),
        ),
        IconButton(
          onPressed: widget.currentPage < widget.totalPages &&
                  widget.onPageChanged != null
              ? () => widget.onPageChanged!(widget.currentPage + 1)
              : null,
          icon: Icon(
            Icons.chevron_right,
            color: themeProvider.isDarkMode
                ? Colors.grey.shade400
                : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

/// Audit log filters component
class AuditLogFilters extends StatefulWidget {
  final String? selectedAction;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? searchQuery;
  final List<String> availableActions;
  final Function(String?)? onActionChanged;
  final Function(DateTime?)? onStartDateChanged;
  final Function(DateTime?)? onEndDateChanged;
  final Function(String)? onSearchChanged;

  const AuditLogFilters({
    super.key,
    this.selectedAction,
    this.startDate,
    this.endDate,
    this.searchQuery,
    required this.availableActions,
    this.onActionChanged,
    this.onStartDateChanged,
    this.onEndDateChanged,
    this.onSearchChanged,
  });

  @override
  State<AuditLogFilters> createState() => _AuditLogFiltersState();
}

class _AuditLogFiltersState extends State<AuditLogFilters> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return ThemedSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filters',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Action filter
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Action',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        material.FilterChip(
                          label: Text('All'),
                          selected: widget.selectedAction == null,
                          onSelected: (selected) {
                            if (selected) widget.onActionChanged?.call(null);
                          },
                        ),
                        ...widget.availableActions
                            .map((action) => material.FilterChip(
                                  label: Text(action),
                                  selected: widget.selectedAction == action,
                                  onSelected: (selected) {
                                    widget.onActionChanged
                                        ?.call(selected ? action : null);
                                  },
                                )),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Date range filter
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date Range',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectDate(context, true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: themeProvider.isDarkMode
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade300,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: themeProvider.isDarkMode
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.startDate != null
                                          ? DateFormat('MMM dd, yyyy')
                                              .format(widget.startDate!)
                                          : 'Start Date',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: themeProvider.isDarkMode
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'to',
                          style: TextStyle(
                            color: themeProvider.isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectDate(context, false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: themeProvider.isDarkMode
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade300,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: themeProvider.isDarkMode
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.endDate != null
                                          ? DateFormat('MMM dd, yyyy')
                                              .format(widget.endDate!)
                                          : 'End Date',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: themeProvider.isDarkMode
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
          // Search filter
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search audit logs...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: widget.onSearchChanged,
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? widget.startDate ?? DateTime.now()
          : widget.endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      if (isStartDate) {
        widget.onStartDateChanged?.call(picked);
      } else {
        widget.onEndDateChanged?.call(picked);
      }
    }
  }
}
