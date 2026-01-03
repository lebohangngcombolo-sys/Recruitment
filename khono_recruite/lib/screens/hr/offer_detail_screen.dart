import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/offer.dart';
import '../../services/offer_service.dart';
import '../../widgets/status_badge.dart';

class HROfferDetailScreen extends StatefulWidget {
  final Offer offer;

  const HROfferDetailScreen({super.key, required this.offer});

  @override
  _HROfferDetailScreenState createState() => _HROfferDetailScreenState();
}

class _HROfferDetailScreenState extends State<HROfferDetailScreen> {
  final OfferService _offerService = OfferService();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Offer #${widget.offer.id}'),
        actions: [
          if (widget.offer.pdfUrl != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () => _viewPDF(widget.offer.pdfUrl!),
            ),
        ],
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderSection(),
                  const SizedBox(height: 20),
                  _buildCandidateInfo(),
                  const SizedBox(height: 20),
                  _buildOfferDetails(),
                  const SizedBox(height: 20),
                  _buildCompensationDetails(),
                  const SizedBox(height: 20),
                  _buildReviewHistory(),
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
                StatusBadge(status: widget.offer.status, size: 18),
                if (widget.offer.baseSalary != null)
                  Chip(
                    label: Text(
                      '\$${widget.offer.baseSalary!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.offer.createdAt != null)
              _buildInfoRow('Created', _formatDate(widget.offer.createdAt!)),
            if (widget.offer.hiringManagerId != null)
              _buildInfoRow('Reviewed By', widget.offer.hiringManagerId!),
            if (widget.offer.approvedBy != null)
              _buildInfoRow('Approved By', widget.offer.approvedBy!),
            if (widget.offer.pdfGeneratedAt != null)
              _buildInfoRow('Sent', _formatDate(widget.offer.pdfGeneratedAt!)),
            if (widget.offer.signedAt != null)
              _buildInfoRow('Signed', _formatDate(widget.offer.signedAt!)),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidateInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Candidate Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (widget.offer.candidateName != null)
              _buildInfoRow('Name', widget.offer.candidateName!),
            if (widget.offer.jobTitle != null)
              _buildInfoRow('Position', widget.offer.jobTitle!),
            _buildInfoRow(
                'Application ID', widget.offer.applicationId.toString()),
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
              'Offer Terms',
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
                  const SizedBox(height: 12),
                  const Text(
                    'Additional Notes:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(widget.offer.notes!),
                  ),
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
              _buildInfoRow('Base Salary',
                  '\$${widget.offer.baseSalary!.toStringAsFixed(2)}'),
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
            if (widget.offer.pdfUrl != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text('Offer Letter PDF'),
                subtitle: Text(
                    'Generated: ${_formatDate(widget.offer.pdfGeneratedAt!)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () => _viewPDF(widget.offer.pdfUrl!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReviewHistory() {
    final List<Map<String, dynamic>> history = [];

    if (widget.offer.draftedBy != null) {
      history.add({
        'action': 'Drafted',
        'by': widget.offer.draftedBy,
        'date': widget.offer.createdAt,
        'icon': Icons.create,
      });
    }

    if (widget.offer.hiringManagerId != null) {
      history.add({
        'action': 'Reviewed',
        'by': widget.offer.hiringManagerId,
        'date': widget.offer.updatedAt,
        'icon': Icons.reviews,
      });
    }

    if (widget.offer.approvedBy != null) {
      history.add({
        'action': 'Approved',
        'by': widget.offer.approvedBy,
        'date': widget.offer.updatedAt,
        'icon': Icons.check_circle,
      });
    }

    if (widget.offer.pdfGeneratedAt != null) {
      history.add({
        'action': 'PDF Generated & Sent',
        'by': 'System',
        'date': widget.offer.pdfGeneratedAt,
        'icon': Icons.send,
      });
    }

    if (history.isEmpty) return Container();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activity History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...history.map((item) => _buildHistoryItem(item)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(item['icon'], size: 20, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['action'],
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  'By: ${item['by']}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (item['date'] != null)
            Text(
              _formatDate(item['date']),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
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
        if (widget.offer.status == 'reviewed')
          _buildActionButton(
            'Approve & Send Offer',
            Icons.send,
            Colors.green,
            _approveAndSendOffer,
          ),
        if (widget.offer.status == 'sent')
          _buildActionButton(
            'Mark as Expired',
            Icons.timelapse,
            Colors.orange,
            _expireOffer,
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
              onPressed: _isProcessing ? null : onPressed,
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
              onPressed: _isProcessing ? null : onPressed,
              icon: Icon(icon, color: Colors.white),
              label: Text(
                text,
                style: const TextStyle(color: Colors.white),
              ),
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
            width: 140,
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
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot open PDF'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _approveAndSendOffer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve & Send Offer'),
        content: const Text('This will:\n'
            '1. Generate a PDF offer letter\n'
            '2. Upload it to cloud storage\n'
            '3. Send email to the candidate\n'
            '4. Update offer status to "sent"\n\n'
            'Continue?'),
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
        successMessage: 'Offer approved and sent to candidate',
      );
    }
  }

  Future<void> _expireOffer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Expire Offer'),
        content: const Text(
            'Mark this offer as expired? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Mark as Expired'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _performAction(
        action: () => _offerService.expireOffer(widget.offer.id!),
        successMessage: 'Offer marked as expired',
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
      _isProcessing = true;
    });

    try {
      await action();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
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
