import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/offer.dart';
import '../../services/admin_service.dart';
import '../../providers/theme_provider.dart';
import '../../constants/brand_tokens.dart';

class AdminReviewOfferScreen extends StatefulWidget {
  final Offer offer;

  const AdminReviewOfferScreen({super.key, required this.offer});

  @override
  State<AdminReviewOfferScreen> createState() => _AdminReviewOfferScreenState();
}

class _AdminReviewOfferScreenState extends State<AdminReviewOfferScreen> {
  final AdminService _adminService = AdminService();
  bool _isLoading = false;
  String _reviewNotes = '';
  String _selectedAction = 'approve'; // approve, reject, request_changes

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor:
            themeProvider.isDarkMode ? BrandTokens.darkSurface : Colors.white,
        elevation: 0,
        title: Text(
          'Review Offer',
          style: GoogleFonts.poppins(
            color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(
          color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(BrandTokens.primary),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOfferDetails(),
                    const SizedBox(height: 24),
                    _buildReviewSection(),
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildOfferDetails() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:
            themeProvider.isDarkMode ? BrandTokens.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Candidate Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: BrandTokens.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                ),
                child: const Icon(
                  Icons.person,
                  color: BrandTokens.primary,
                  size: 40,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.offer.candidateName ?? 'Unknown Candidate',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Application ID: ${widget.offer.applicationId}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: themeProvider.isDarkMode
                            ? Colors.white70
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Offer Details
          _buildDetailRow('Position', widget.offer.jobTitle ?? 'Not specified'),
          _buildDetailRow('Salary',
              widget.offer.baseSalary?.toStringAsFixed(2) ?? 'Not specified'),
          _buildDetailRow(
              'Start Date',
              widget.offer.startDate?.toString().split(' ')[0] ??
                  'Not specified'),
          _buildDetailRow('Status', _getStatusDisplay(widget.offer.status)),

          if (widget.offer.notes != null && widget.offer.notes!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  'Description',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.offer.notes!,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: themeProvider.isDarkMode
                        ? Colors.white70
                        : Colors.black54,
                    height: 1.5,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color:
                    themeProvider.isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusDisplay(String? status) {
    switch (status?.toLowerCase()) {
      case 'draft':
        return 'Draft';
      case 'pending_review':
        return 'Pending Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return status ?? 'Unknown';
    }
  }

  Widget _buildReviewSection() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:
            themeProvider.isDarkMode ? BrandTokens.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Notes',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Add review notes...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
                borderSide: BorderSide(
                    color: BrandTokens.primary.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
                borderSide: BorderSide(color: BrandTokens.primary, width: 2),
              ),
              fillColor: themeProvider.isDarkMode
                  ? BrandTokens.darkSurface
                  : Colors.white,
              filled: true,
              hintStyle: GoogleFonts.inter(
                  color: themeProvider.isDarkMode
                      ? Colors.white70
                      : Colors.black54),
            ),
            onChanged: (value) {
              setState(() => _reviewNotes = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Column(
      children: [
        // Action Selection
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode
                ? BrandTokens.darkSurface
                : Colors.white,
            borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
            border:
                Border.all(color: BrandTokens.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Action',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color:
                      themeProvider.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text(
                        'Approve',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      value: 'approve',
                      groupValue: _selectedAction,
                      onChanged: (value) =>
                          setState(() => _selectedAction = value!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text(
                        'Request Changes',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      value: 'request_changes',
                      groupValue: _selectedAction,
                      onChanged: (value) =>
                          setState(() => _selectedAction = value!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text(
                        'Reject',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      value: 'reject',
                      groupValue: _selectedAction,
                      onChanged: (value) =>
                          setState(() => _selectedAction = value!),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Submit Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitReview,
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandTokens.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Submit Review',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitReview() async {
    setState(() => _isLoading = true);

    try {
      final result = await _adminService.reviewOffer(
        offerId: widget.offer.id ?? 0,
        action: _selectedAction,
        notes: _reviewNotes,
      );

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Offer reviewed successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error reviewing offer: ${result['error']}'),
              backgroundColor: BrandTokens.primary,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reviewing offer: $e'),
            backgroundColor: BrandTokens.primary,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
