import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/offer.dart';
import '../../../services/offer_service.dart';

class ApproveOfferScreen extends StatefulWidget {
  final Offer offer;

  const ApproveOfferScreen({super.key, required this.offer});

  @override
  _ApproveOfferScreenState createState() => _ApproveOfferScreenState();
}

class _ApproveOfferScreenState extends State<ApproveOfferScreen> {
  final OfferService _offerService = OfferService();
  bool isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approve & Send Offer'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOfferHeader(),
            const SizedBox(height: 20),
            _buildOfferDetails(),
            const SizedBox(height: 20),
            _buildReviewInfo(),
            const SizedBox(height: 30),
            _buildActionButtons(),
            const SizedBox(height: 20),
            if (widget.offer.pdfUrl != null) _buildPdfSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferHeader() {
    return Card(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.description, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Offer #${widget.offer.id}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    'Status: ${widget.offer.status.toUpperCase()}',
                    style: TextStyle(
                      color: _getStatusColor(widget.offer.status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Offer Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Base Salary',
                '\$${widget.offer.baseSalary?.toStringAsFixed(2) ?? "N/A"}'),
            _buildDetailRow(
                'Contract Type', widget.offer.contractType ?? 'N/A'),
            _buildDetailRow('Start Date',
                widget.offer.startDate?.toLocal().toString() ?? 'N/A'),
            _buildDetailRow(
                'Work Location', widget.offer.workLocation ?? 'N/A'),
            if (widget.offer.notes != null && widget.offer.notes!.isNotEmpty)
              _buildDetailRow('Notes', widget.offer.notes!),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
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

  Widget _buildReviewInfo() {
    if (widget.offer.hiringManagerId == null) {
      return Container();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Review Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Reviewed by: ${widget.offer.hiringManagerId}'),
            if (widget.offer.notes != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Text('Review Comments:'),
                  Text(widget.offer.notes!),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isProcessing ? null : _approveAndSendOffer,
            icon: isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: const Text('Approve & Send to Candidate'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _rejectOffer,
            icon: const Icon(Icons.close),
            label: const Text('Reject'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPdfSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Generated PDF',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.picture_as_pdf, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offer_${widget.offer.id}.pdf',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (widget.offer.pdfGeneratedAt != null)
                        Text(
                          'Generated: ${widget.offer.pdfGeneratedAt!.toLocal()}',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () => _viewPdf(widget.offer.pdfUrl!),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Colors.orange;
      case 'reviewed':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      case 'sent':
        return Colors.purple;
      case 'signed':
        return Colors.teal;
      case 'rejected':
        return Colors.red;
      case 'expired':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  Future<void> _approveAndSendOffer() async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      final updatedOffer = await _offerService.approveOffer(widget.offer.id!);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer approved and sent to candidate')),
      );

      Navigator.pop(context, updatedOffer);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  void _rejectOffer() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const RejectOfferDialog(),
    );

    if (reason != null && reason.isNotEmpty) {
      try {
        await _offerService.rejectOffer(widget.offer.id!, reason);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offer rejected')),
        );

        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _viewPdf(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot open PDF')),
      );
    }
  }
}

/// Dialog to prompt the user to enter a reason for rejecting an offer
class RejectOfferDialog extends StatefulWidget {
  const RejectOfferDialog({super.key});

  @override
  _RejectOfferDialogState createState() => _RejectOfferDialogState();
}

class _RejectOfferDialogState extends State<RejectOfferDialog> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    _reasonController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _reasonController.removeListener(_onTextChanged);
    _reasonController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _isButtonEnabled = _reasonController.text.trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Offer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Please provide a reason for rejecting this offer:'),
          const SizedBox(height: 12),
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
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: _isButtonEnabled
              ? () => Navigator.pop(context, _reasonController.text.trim())
              : null,
          child: const Text('Reject Offer'),
        ),
      ],
    );
  }
}
