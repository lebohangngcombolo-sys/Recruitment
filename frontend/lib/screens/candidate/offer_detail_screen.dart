import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/offer.dart';
import '../../services/offer_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/status_badge.dart';

class CandidateOfferDetailScreen extends StatefulWidget {
  final Offer offer;

  const CandidateOfferDetailScreen({super.key, required this.offer});

  @override
  _CandidateOfferDetailScreenState createState() =>
      _CandidateOfferDetailScreenState();
}

class _CandidateOfferDetailScreenState
    extends State<CandidateOfferDetailScreen> {
  final OfferService _offerService = OfferService();
  bool _isProcessing = false;
  late Offer _offer;

  @override
  void initState() {
    super.initState();
    _offer = widget.offer; // Use local copy for mutable state
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Offer'),
        actions: [
          if (_offer.pdfUrl != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () => _viewPDF(_offer.pdfUrl!),
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
                  _buildOfferDetails(),
                  const SizedBox(height: 20),
                  _buildCompensationDetails(),
                  const SizedBox(height: 20),
                  _buildNextSteps(),
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
                        _offer.jobTitle ?? 'Job Offer',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_offer.candidateName != null)
                        Text(
                          'For: ${_offer.candidateName!}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                StatusBadge(status: _offer.status, size: 16),
              ],
            ),
            const SizedBox(height: 16),
            if (_offer.pdfGeneratedAt != null)
              _buildInfoRow('Offer Sent', _formatDate(_offer.pdfGeneratedAt!)),
            if (_offer.signedAt != null)
              _buildInfoRow('Signed On', _formatDate(_offer.signedAt!)),
            if (_offer.expiresAt != null)
              _buildInfoRow('Expires On', _formatDate(_offer.expiresAt!)),
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
              'Position Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_offer.contractType != null)
              _buildDetailItem('Contract Type', _offer.contractType!),
            if (_offer.startDate != null)
              _buildDetailItem('Start Date', _formatDate(_offer.startDate!)),
            if (_offer.workLocation != null)
              _buildDetailItem('Work Location', _offer.workLocation!),
            if (_offer.notes != null && _offer.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Additional Information:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_offer.notes!),
              ),
            ],
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
            if (_offer.baseSalary != null)
              _buildCompensationItem(
                'Annual Base Salary',
                '\$${_offer.baseSalary!.toStringAsFixed(2)}',
                Icons.attach_money,
              ),
            if (_offer.allowances != null && _offer.allowances!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Allowances (Annual)',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              ..._offer.allowances!.entries.map(
                (entry) => _buildCompensationItem(
                  entry.key,
                  '\$${entry.value.toString()}',
                  Icons.account_balance_wallet,
                ),
              ),
            ],
            if (_offer.bonuses != null && _offer.bonuses!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Bonuses',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              ..._offer.bonuses!.entries.map(
                (entry) => _buildCompensationItem(
                  entry.key,
                  '\$${entry.value.toString()}',
                  Icons.celebration,
                ),
              ),
            ],
            if (_offer.baseSalary != null ||
                _offer.allowances != null ||
                _offer.bonuses != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              _buildTotalCompensation(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNextSteps() {
    List<Widget> steps = [];

    switch (_offer.status.toLowerCase()) {
      case 'sent':
        steps.addAll([
          _buildStep(
            'Review the offer letter',
            'Carefully read through all terms and conditions',
            Icons.description,
          ),
          _buildStep(
            'Sign the offer',
            'Click "Sign Offer" below to accept the position',
            Icons.assignment_turned_in,
          ),
          _buildStep(
            'Contact HR with questions',
            'Email hr@company.com for any clarifications',
            Icons.email,
          ),
        ]);
        break;
      case 'signed':
        steps.addAll([
          _buildStep(
            'Offer Accepted!',
            'Welcome to the team!',
            Icons.check_circle,
            color: Colors.green,
          ),
          _buildStep(
            'Next Steps',
            'HR will contact you with onboarding details',
            Icons.arrow_forward,
          ),
          _buildStep(
            'Prepare for Start Date',
            'Complete any pre-employment requirements',
            Icons.calendar_today,
          ),
        ]);
        break;
      case 'expired':
        steps.addAll([
          _buildStep(
            'Offer Expired',
            'This offer is no longer valid',
            Icons.timelapse,
            color: Colors.orange,
          ),
          _buildStep(
            'Contact HR',
            'If you still wish to proceed, contact HR immediately',
            Icons.phone,
          ),
        ]);
        break;
    }

    if (steps.isEmpty) return Container();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Next Steps',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...steps,
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_offer.status.toLowerCase() != 'sent') return Container();

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _signOffer,
            icon: const Icon(Icons.check_circle),
            label: const Text(
              'Sign Offer',
              style: TextStyle(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _declineOffer,
            icon: const Icon(Icons.close),
            label: const Text('Decline Offer'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_offer.pdfUrl != null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _viewPDF(_offer.pdfUrl!),
              icon: const Icon(Icons.download),
              label: const Text('Download Offer Letter'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
      ],
    );
  }

  // ------------------ HELPER WIDGETS ------------------

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
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

  Widget _buildCompensationItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCompensation() {
    double total = 0;

    if (_offer.baseSalary != null) total += _offer.baseSalary!;
    if (_offer.allowances != null) {
      for (var value in _offer.allowances!.values) {
        if (value is num) total += value.toDouble();
      }
    }
    if (_offer.bonuses != null) {
      for (var value in _offer.bonuses!.values) {
        if (value is num) total += value.toDouble();
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[100]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.calculate, size: 24, color: Colors.green),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Total Estimated Annual Compensation',
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
              fontSize: 20,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String title, String description, IconData icon,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (color ?? Theme.of(context).primaryColor).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                color: color ?? Theme.of(context).primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
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

  Future<void> _signOffer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Offer'),
        content: const Text(
            'By signing this offer, you agree to all terms, compensation, start date, and work location. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Sign Offer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      try {
        final token = await AuthService.getAccessToken();
        if (token == null) throw Exception('User not authenticated');

        final signedOffer =
            await _offerService.signOffer(_offer.id!, token: token);

        setState(() {
          _offer = signedOffer; // update local offer with signed version
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offer signed successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing offer: $e')),
        );
      } finally {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _declineOffer() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _DeclineOfferDialog(),
    );

    if (reason != null && reason.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Decline functionality coming soon'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}

class _DeclineOfferDialog extends StatefulWidget {
  @override
  __DeclineOfferDialogState createState() => __DeclineOfferDialogState();
}

class __DeclineOfferDialogState extends State<_DeclineOfferDialog> {
  final TextEditingController _reasonController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Decline Offer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Please provide a reason for declining this offer:'),
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
          child: const Text('Decline Offer'),
        ),
      ],
    );
  }
}
