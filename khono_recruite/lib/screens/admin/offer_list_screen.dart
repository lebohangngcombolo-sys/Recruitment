import 'package:flutter/material.dart';
import '../../models/offer.dart';
import '../../models/application.dart';
import '../../services/offer_service.dart';
import '../../widgets/offer_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/application_picker_dialog.dart';
import 'draft_offer_screen.dart';

class AdminOfferListScreen extends StatefulWidget {
  final String? initialStatus;

  const AdminOfferListScreen({super.key, this.initialStatus});

  @override
  _AdminOfferListScreenState createState() => _AdminOfferListScreenState();
}

class _AdminOfferListScreenState extends State<AdminOfferListScreen> {
  final OfferService _offerService = OfferService();
  List<Offer> offers = [];
  bool _isLoading = true;
  String? _selectedStatus;
  final List<String> _statusOptions = [
    'all',
    'draft',
    'reviewed',
    'approved',
    'sent',
    'signed',
    'rejected',
    'expired',
  ];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus ?? 'all';
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Offer> fetchedOffers;
      if (_selectedStatus == 'all') {
        fetchedOffers = await _offerService.getAllOffers();
      } else {
        fetchedOffers = await _offerService.getOffersByStatus(_selectedStatus!);
      }

      setState(() {
        offers = fetchedOffers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading offers: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Offers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOffers,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : offers.isEmpty
                    ? _buildEmptyState()
                    : _buildOffersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Create Draft Offer Button ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final application = await showDialog<Application>(
                    context: context,
                    builder: (_) => const ApplicationPickerDialog(),
                  );

                  if (application != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DraftOfferScreen(application: application),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text(
                  'Create Draft Offer',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),

            const Text(
              'Filter Offers',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _statusOptions.map((status) {
                final isSelected = _selectedStatus == status;
                return FilterChip(
                  label: Text(
                    status == 'all' ? 'All Offers' : status,
                    style: TextStyle(
                      color: isSelected ? Colors.white : null,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedStatus = selected ? status : 'all';
                    });
                    _loadOffers();
                  },
                  backgroundColor: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey[200],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.description,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _selectedStatus == 'all'
                ? 'No offers found'
                : 'No ${_selectedStatus} offers',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try changing filters or check back later',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildOffersList() {
    return RefreshIndicator(
      onRefresh: _loadOffers,
      child: ListView.builder(
        itemCount: offers.length,
        itemBuilder: (context, index) {
          final offer = offers[index];
          return OfferCard(
            offer: offer,
            showActions: true,
            onAction: (offer) => _viewOfferDetails(offer),
          );
        },
      ),
    );
  }

  void _viewOfferDetails(Offer offer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OfferDetailScreen(offer: offer),
      ),
    );
  }
}

class OfferDetailScreen extends StatefulWidget {
  final Offer offer;

  const OfferDetailScreen({super.key, required this.offer});

  @override
  _OfferDetailScreenState createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends State<OfferDetailScreen> {
  final OfferService _offerService = OfferService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Offer #${widget.offer.id}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 20),
            _buildOfferDetails(),
            const SizedBox(height: 20),
            _buildCompensationDetails(),
            const SizedBox(height: 20),
            _buildTimelineSection(),
            const SizedBox(height: 30),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offer #${widget.offer.id}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      StatusBadge(status: widget.offer.status, size: 16),
                    ],
                  ),
                ),
                if (widget.offer.pdfUrl != null)
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, size: 32),
                    onPressed: () => _viewPDF(widget.offer.pdfUrl!),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.offer.candidateName != null)
              _buildInfoRow('Candidate', widget.offer.candidateName!),
            if (widget.offer.jobTitle != null)
              _buildInfoRow('Position', widget.offer.jobTitle!),
            _buildInfoRow(
                'Application ID', widget.offer.applicationId.toString()),
            if (widget.offer.draftedBy != null)
              _buildInfoRow('Drafted By', widget.offer.draftedBy!),
            if (widget.offer.createdAt != null)
              _buildInfoRow('Created', _formatDate(widget.offer.createdAt!)),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Offer Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (widget.offer.contractType != null)
              _buildInfoRow('Contract Type', widget.offer.contractType!),
            if (widget.offer.startDate != null)
              _buildInfoRow('Start Date', _formatDate(widget.offer.startDate!)),
            if (widget.offer.workLocation != null)
              _buildInfoRow('Work Location', widget.offer.workLocation!),
            if (widget.offer.notes != null && widget.offer.notes!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Notes:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(widget.offer.notes!),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompensationDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Compensation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (widget.offer.baseSalary != null)
              _buildInfoRow(
                'Base Salary',
                '\$${widget.offer.baseSalary!.toStringAsFixed(2)}',
              ),
            if (widget.offer.allowances != null &&
                widget.offer.allowances!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Allowances',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              ...widget.offer.allowances!.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(entry.key)),
                      Text('\$${entry.value.toString()}'),
                    ],
                  ),
                ),
              ),
            ],
            if (widget.offer.bonuses != null &&
                widget.offer.bonuses!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Bonuses',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              ...widget.offer.bonuses!.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(entry.key)),
                      Text('\$${entry.value.toString()}'),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineSection() {
    final timelineItems = <Map<String, dynamic>>[];

    if (widget.offer.createdAt != null) {
      timelineItems.add({
        'title': 'Offer Created',
        'date': widget.offer.createdAt!,
        'icon': Icons.create,
        'color': Colors.blue,
      });
    }

    if (widget.offer.hiringManagerId != null) {
      timelineItems.add({
        'title': 'Reviewed by Hiring Manager',
        'date': widget.offer.updatedAt ?? widget.offer.createdAt!,
        'icon': Icons.reviews,
        'color': Colors.orange,
      });
    }

    if (widget.offer.approvedBy != null) {
      timelineItems.add({
        'title': 'Approved by HR',
        'date': widget.offer.updatedAt ?? widget.offer.createdAt!,
        'icon': Icons.check_circle,
        'color': Colors.green,
      });
    }

    if (widget.offer.pdfGeneratedAt != null) {
      timelineItems.add({
        'title': 'PDF Generated & Sent',
        'date': widget.offer.pdfGeneratedAt!,
        'icon': Icons.send,
        'color': Colors.purple,
      });
    }

    if (widget.offer.signedAt != null) {
      timelineItems.add({
        'title': 'Signed by Candidate',
        'date': widget.offer.signedAt!,
        'icon': Icons.assignment_turned_in,
        'color': Colors.teal,
      });
    }

    if (timelineItems.isEmpty) return Container();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Timeline',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...timelineItems.map((item) => _buildTimelineItem(item)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item['color'].withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: item['color'].withValues(alpha: 0.3)),
            ),
            child: Icon(item['icon'], color: item['color'], size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'],
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(item['date']),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (widget.offer.status == 'signed' ||
        widget.offer.status == 'rejected' ||
        widget.offer.status == 'expired') {
      return Container();
    }

    return Column(
      children: [
        if (widget.offer.status == 'draft')
          _buildActionButton(
            'Send for Review',
            Icons.reviews,
            Colors.orange,
            _sendForReview,
          ),
        if (widget.offer.status == 'reviewed')
          _buildActionButton(
            'Approve & Send',
            Icons.check_circle,
            Colors.green,
            _approveOffer,
          ),
        const SizedBox(height: 12),
        _buildActionButton(
          'Reject Offer',
          Icons.close,
          Colors.red,
          _rejectOffer,
          isOutlined: true,
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed, {
    bool isOutlined = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: isOutlined
          ? OutlinedButton.icon(
              onPressed: _isLoading ? null : onPressed,
              icon: Icon(icon, color: color),
              label: Text(
                text,
                style: TextStyle(color: color),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: color),
              ),
            )
          : ElevatedButton.icon(
              onPressed: _isLoading ? null : onPressed,
              icon: Icon(icon),
              label: Text(text),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: color,
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.toLocal().toString().split(' ')[0]} ${date.toLocal().toString().split(' ')[1].substring(0, 5)}';
  }

  Future<void> _viewPDF(String url) async {
    // Implement PDF viewing logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening PDF...')),
    );
  }

  Future<void> _sendForReview() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send for Review'),
        content:
            const Text('Send this offer to the hiring manager for review?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _performAction(
        action: () => _offerService.reviewOffer(widget.offer.id!, ''),
        successMessage: 'Offer sent for review',
      );
    }
  }

  Future<void> _approveOffer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve & Send Offer'),
        content: const Text('Approve this offer and send it to the candidate?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve & Send'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _performAction(
        action: () => _offerService.approveOffer(widget.offer.id!),
        successMessage: 'Offer approved and sent',
      );
    }
  }

  Future<void> _rejectOffer() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _RejectOfferDialog(),
    );

    if (reason != null && reason.isNotEmpty) {
      await _performAction(
        action: () => _offerService.rejectOffer(widget.offer.id!, reason),
        successMessage: 'Offer rejected',
      );
    }
  }

  Future<void> _performAction({
    required Future<Offer> Function() action,
    required String successMessage,
  }) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final updatedOffer = await action();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back with updated offer
      Navigator.pop(context, updatedOffer);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

class _RejectOfferDialog extends StatefulWidget {
  @override
  __RejectOfferDialogState createState() => __RejectOfferDialogState();
}

class __RejectOfferDialogState extends State<_RejectOfferDialog> {
  final TextEditingController _reasonController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Offer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Please provide a reason for rejecting this offer:'),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Enter reason...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_reasonController.text.isNotEmpty) {
              Navigator.pop(context, _reasonController.text);
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Reject Offer'),
        ),
      ],
    );
  }
}
