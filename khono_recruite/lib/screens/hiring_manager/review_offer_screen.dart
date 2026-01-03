import 'package:flutter/material.dart';
import '../../models/offer.dart';
import '../../services/offer_service.dart';
import '../../widgets/status_badge.dart';

class ReviewOfferScreen extends StatefulWidget {
  final Offer offer;

  const ReviewOfferScreen({super.key, required this.offer});

  @override
  _ReviewOfferScreenState createState() => _ReviewOfferScreenState();
}

class _ReviewOfferScreenState extends State<ReviewOfferScreen> {
  final OfferService _offerService = OfferService();
  final TextEditingController _reviewCommentsController =
      TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Offer'),
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOfferHeader(),
                  const SizedBox(height: 20),
                  _buildOfferDetails(),
                  const SizedBox(height: 20),
                  _buildCompensationDetails(),
                  const SizedBox(height: 20),
                  _buildReviewSection(),
                  const SizedBox(height: 30),
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildOfferHeader() {
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
            if (widget.offer.candidateName != null)
              _buildInfoRow('Candidate', widget.offer.candidateName!),
            if (widget.offer.jobTitle != null)
              _buildInfoRow('Position', widget.offer.jobTitle!),
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
                    'Notes from Drafter:',
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
              'Compensation Package',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            if (widget.offer.baseSalary != null)
              _buildCompensationItem(
                'Base Salary',
                '\$${widget.offer.baseSalary!.toStringAsFixed(2)}/year',
                Icons.attach_money,
              ),

            if (widget.offer.allowances != null &&
                widget.offer.allowances!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Allowances',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              ...widget.offer.allowances!.entries.map(
                (entry) => _buildCompensationItem(
                  entry.key,
                  '\$${entry.value.toString()}',
                  Icons.account_balance_wallet,
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
                (entry) => _buildCompensationItem(
                  entry.key,
                  '\$${entry.value.toString()}',
                  Icons.celebration,
                ),
              ),
            ],

            // Calculate total compensation
            if (widget.offer.baseSalary != null ||
                widget.offer.allowances != null ||
                widget.offer.bonuses != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              _buildTotalCompensation(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompensationItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCompensation() {
    double total = 0;

    if (widget.offer.baseSalary != null) {
      total += widget.offer.baseSalary!;
    }

    if (widget.offer.allowances != null) {
      for (var value in widget.offer.allowances!.values) {
        if (value is num) total += value.toDouble();
      }
    }

    if (widget.offer.bonuses != null) {
      for (var value in widget.offer.bonuses!.values) {
        if (value is num) total += value.toDouble();
      }
    }

    return Row(
      children: [
        const Icon(Icons.calculate, size: 24, color: Colors.green),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Estimated Annual Total',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        Text(
          '\$${total.toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Review',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please provide your feedback on this offer:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reviewCommentsController,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Review Comments',
                hintText: 'Enter your comments, suggestions, or feedback...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Note: Your comments will be visible to HR when they review this offer.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
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
            onPressed: _isSubmitting ? null : _approveForHR,
            icon: const Icon(Icons.check_circle),
            label: const Text('Approve for HR'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _rejectOffer,
            icon: const Icon(Icons.close),
            label: const Text('Reject'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
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

  Future<void> _approveForHR() async {
    if (_reviewCommentsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide review comments'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve for HR Review'),
        content: const Text(
            'Submit your review and send this offer to HR for final approval?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit Review'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _performAction(
        action: () => _offerService.reviewOffer(
          widget.offer.id!,
          _reviewCommentsController.text,
        ),
        successMessage: 'Review submitted successfully',
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
      _isSubmitting = true;
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
        _isSubmitting = false;
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
