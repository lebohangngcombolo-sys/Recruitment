import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/offer.dart';
import '../../services/offer_service.dart';
import 'offer_detail_screen.dart';

class CandidateOffersScreen extends StatefulWidget {
  const CandidateOffersScreen({super.key});

  @override
  _CandidateOffersScreenState createState() => _CandidateOffersScreenState();
}

class _CandidateOffersScreenState extends State<CandidateOffersScreen> {
  final OfferService _offerService = OfferService();
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
      // Fetch offers for the currently authenticated candidate
      final fetchedOffers = await _offerService.getMyOffers();

      // Filter offers based on selection
      List<Offer> filteredOffers;
      if (_selectedFilter == 'all') {
        filteredOffers = fetchedOffers;
      } else {
        filteredOffers = fetchedOffers
            .where((offer) => offer.status == _selectedFilter)
            .toList();
      }

      setState(() {
        offers = filteredOffers;
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
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background Image
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/dark.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Column(
            children: [
              // Custom Header with Back Button
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  bottom: 16,
                  left: 16,
                  right: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Color(0xFFC10D00), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    SizedBox(width: 16),
                    Text(
                      "My Job Offers",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Color(0xFFC10D00), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(Icons.refresh, color: Colors.white),
                        onPressed: _loadOffers,
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Chips
              _buildFilterChips(),

              // Content Area
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : offers.isEmpty
                        ? _buildEmptyState()
                        : _buildOffersList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color(0xFFF2F2F2).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Color(0xFFC10D00), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFC10D00)),
            SizedBox(height: 16),
            Text(
              "Loading your offers...",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'value': 'all', 'label': 'All'},
      {'value': 'sent', 'label': 'Pending'},
      {'value': 'signed', 'label': 'Signed'},
      {'value': 'expired', 'label': 'Expired'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                filter['label']!,
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = selected ? filter['value']! : 'all';
                });
                _loadOffers();
              },
              backgroundColor: isSelected
                  ? Color(0xFFC10D00)
                  : Color(0xFFF2F2F2).withValues(alpha: 0.3),
              selectedColor: Color(0xFFC10D00),
              checkmarkColor: Colors.white,
              side: BorderSide(
                color: isSelected ? Color(0xFFC10D00) : Color(0xFFC10D00),
                width: 1,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(24),
        margin: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color(0xFFF2F2F2).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Color(0xFFC10D00), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _selectedFilter == 'all' ? Icons.description : Icons.filter_alt,
              size: 64,
              color: Color(0xFFC10D00),
            ),
            SizedBox(height: 16),
            Text(
              _selectedFilter == 'all'
                  ? 'No job offers yet'
                  : 'No ${_selectedFilter} offers',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Keep applying! Offers will appear here when received.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffersList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: offers.length,
      itemBuilder: (context, index) {
        final offer = offers[index];
        return Container(
          margin: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xFFF2F2F2).withValues(alpha: 0.2),
                border: Border.all(
                  color: Color(0xFFC10D00),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color(0xFFC10D00).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.work_outline,
                            color: Color(0xFFC10D00),
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                offer.jobTitle ?? "Job Title Not Available",
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFC10D00),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4),
                              Text(
                                offer.candidateName ??
                                    "Candidate Not Available",
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12),
                        _buildStatusBadge(offer.status),
                      ],
                    ),
                    SizedBox(height: 12),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(0xFFC10D00).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_outlined,
                            size: 16,
                            color: Color(0xFFC10D00),
                          ),
                          SizedBox(width: 6),
                          Text(
                            "Received: ${offer.createdAt != null ? '${offer.createdAt!.year}-${offer.createdAt!.month.toString().padLeft(2, '0')}-${offer.createdAt!.day.toString().padLeft(2, '0')}' : 'N/A'}",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Color(0xFFC10D00),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _viewOfferDetails(offer),
                        icon: Icon(Icons.visibility_outlined, size: 20),
                        label: Text(
                          "View Offer Details",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFC10D00),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          shadowColor: Color(0xFFC10D00).withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'signed':
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'expired':
        backgroundColor = Colors.red.withValues(alpha: 0.1);
        textColor = Colors.red;
        icon = Icons.cancel;
        break;
      case 'sent':
      default:
        backgroundColor = Colors.blue.withValues(alpha: 0.1);
        textColor = Colors.blue;
        icon = Icons.pending;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            status,
            style: GoogleFonts.poppins(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _viewOfferDetails(Offer offer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CandidateOfferDetailScreen(offer: offer),
      ),
    ).then((_) => _loadOffers());
  }
}
