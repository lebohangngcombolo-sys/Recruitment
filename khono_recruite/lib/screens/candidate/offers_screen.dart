import 'package:flutter/material.dart';
import '../../models/offer.dart';
import '../../services/offer_service.dart';
import '../../widgets/offer_card.dart';
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

  // Helper method to get candidate ID (replace with your auth logic)
  Future<int> _getCandidateId() async {
    // This is a placeholder - implement based on your auth system
    return 1; // Example candidate ID
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Job Offers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOffers,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
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
              label: Text(filter['label']!),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = selected ? filter['value']! : 'all';
                });
                _loadOffers();
              },
              backgroundColor: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey[200],
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _selectedFilter == 'all' ? Icons.description : Icons.filter_alt,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 'all'
                ? 'No job offers yet'
                : 'No ${_selectedFilter} offers',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Keep applying! Offers will appear here when received.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOffersList() {
    return RefreshIndicator(
      onRefresh: _loadOffers,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: offers.length,
        itemBuilder: (context, index) {
          final offer = offers[index];
          return OfferCard(
            offer: offer,
            onTap: () => _viewOfferDetails(offer),
          );
        },
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
