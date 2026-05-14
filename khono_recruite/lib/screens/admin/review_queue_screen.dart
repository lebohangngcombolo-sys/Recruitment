import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/offer.dart';
import '../../services/admin_service.dart';
import '../../providers/theme_provider.dart';
import '../../constants/brand_tokens.dart';
import '../../widgets/offer_card.dart';
import 'review_offer_screen.dart';

class AdminReviewQueueScreen extends StatefulWidget {
  const AdminReviewQueueScreen({super.key});

  @override
  State<AdminReviewQueueScreen> createState() => _AdminReviewQueueScreenState();
}

class _AdminReviewQueueScreenState extends State<AdminReviewQueueScreen> {
  final AdminService _adminService = AdminService();
  List<Offer> offers = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final draftOffersData = await _adminService.getOffersByStatus('draft');
      setState(() {
        offers = draftOffersData
            .map((data) => Offer(
                  id: data['id'],
                  applicationId: data['application_id'] ?? 1,
                  status: data['status'],
                  candidateName: data['candidate_name'],
                  jobTitle: data['position'],
                  baseSalary: double.tryParse(
                      data['salary']?.replaceAll(RegExp(r'[^\d.]'), '') ?? '0'),
                  startDate: DateTime.tryParse(data['start_date'] ?? ''),
                  notes: data['description'],
                ))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading offers: $e'),
          backgroundColor: BrandTokens.primary,
        ),
      );
    }
  }

  Future<void> _refreshOffers() async {
    await _loadOffers();
  }

  List<Offer> _getFilteredOffers() {
    if (_selectedFilter == 'all') return offers;
    return offers.where((offer) => offer.status == _selectedFilter).toList();
  }

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
          'Offers for Review',
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
            icon: const Icon(Icons.refresh),
            onPressed: _refreshOffers,
            color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(BrandTokens.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading offers...',
                    style: GoogleFonts.inter(
                      color: themeProvider.isDarkMode
                          ? Colors.white70
                          : Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : offers.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildFilterBar(),
                    _buildStatsRow(),
                    const SizedBox(height: 16),
                    Expanded(child: _buildOffersList()),
                  ],
                ),
    );
  }

  Widget _buildFilterBar() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode
                    ? BrandTokens.darkSurface
                    : Colors.white,
                borderRadius: BorderRadius.circular(BrandTokens.searchRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search offers...',
                  prefixIcon: Icon(Icons.search, color: BrandTokens.primary),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(BrandTokens.searchRadius),
                    borderSide: BorderSide(
                        color: BrandTokens.primary.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(BrandTokens.searchRadius),
                    borderSide:
                        BorderSide(color: BrandTokens.primary, width: 2),
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
                  setState(() {
                    // Implement search functionality
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: BrandTokens.primary,
              borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFilter,
                icon: Icon(Icons.filter_list, color: Colors.white, size: 20),
                dropdownColor: themeProvider.isDarkMode
                    ? BrandTokens.darkSurface
                    : Colors.white,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Status')),
                  DropdownMenuItem(value: 'draft', child: Text('Draft')),
                  DropdownMenuItem(
                      value: 'pending_review', child: Text('Pending Review')),
                  DropdownMenuItem(value: 'approved', child: Text('Approved')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                ],
                onChanged: (value) {
                  setState(() => _selectedFilter = value!);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final filteredOffers = _getFilteredOffers();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildStatCard(
              'Total Offers', offers.length.toString(), Icons.description),
          const SizedBox(width: 12),
          _buildStatCard(
              'Filtered', filteredOffers.length.toString(), Icons.filter_list),
          const SizedBox(width: 12),
          _buildStatCard(
              'Pending',
              offers
                  .where((o) => o.status == 'pending_review')
                  .length
                  .toString(),
              Icons.pending),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: BrandTokens.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        border: Border.all(color: BrandTokens.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: BrandTokens.primary, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: BrandTokens.primary,
                ),
              ),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: themeProvider.isDarkMode
                      ? Colors.white70
                      : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: themeProvider.isDarkMode
                ? Colors.grey.shade600
                : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No offers to review',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Draft offers will appear here once available',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade500
                  : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _refreshOffers,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandTokens.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffersList() {
    final filteredOffers = _getFilteredOffers();

    return RefreshIndicator(
      onRefresh: _refreshOffers,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: filteredOffers.length,
        itemBuilder: (context, index) {
          final offer = filteredOffers[index];
          return OfferCard(
            offer: offer,
            showActions: true,
            onAction: (offer) => _reviewOffer(offer),
          );
        },
      ),
    );
  }

  void _reviewOffer(Offer offer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminReviewOfferScreen(offer: offer),
      ),
    ).then((_) => _refreshOffers());
  }
}
