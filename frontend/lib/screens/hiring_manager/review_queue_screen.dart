import 'package:flutter/material.dart';
import '../../models/offer.dart';
import '../../services/offer_service.dart';
import '../../widgets/offer_card.dart';
import 'review_offer_screen.dart';

class HiringManagerReviewQueueScreen extends StatefulWidget {
  const HiringManagerReviewQueueScreen({super.key});

  @override
  _HiringManagerReviewQueueScreenState createState() =>
      _HiringManagerReviewQueueScreenState();
}

class _HiringManagerReviewQueueScreenState
    extends State<HiringManagerReviewQueueScreen> {
  final OfferService _offerService = OfferService();
  List<Offer> offers = [];
  bool _isLoading = true;

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
      final draftOffers = await _offerService.getOffersByStatus('draft');
      setState(() {
        offers = draftOffers;
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
        title: const Text('Offers for Review'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOffers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : offers.isEmpty
              ? _buildEmptyState()
              : _buildOffersList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          const Text(
            'No offers to review',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'All draft offers have been reviewed',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadOffers,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
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
        builder: (context) => ReviewOfferScreen(offer: offer),
      ),
    ).then((_) => _loadOffers());
  }
}
