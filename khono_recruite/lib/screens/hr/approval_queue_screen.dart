import 'package:flutter/material.dart';
import '../../models/offer.dart';
import '../../services/offer_service.dart';
import '../hr/offer_detail_screen.dart';

class HRApprovalQueueScreen extends StatefulWidget {
  const HRApprovalQueueScreen({super.key});

  @override
  _HRApprovalQueueScreenState createState() => _HRApprovalQueueScreenState();
}

class _HRApprovalQueueScreenState extends State<HRApprovalQueueScreen> {
  final OfferService _offerService = OfferService();
  late Future<List<Offer>> _offersFuture;

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  void _loadOffers() {
    setState(() {
      _offersFuture = _offerService.getOffersByStatus('reviewed');
    });
  }

  Future<void> _refreshOffers() async {
    _loadOffers();
    await _offersFuture;
  }

  bool _isRecentlyReviewed(Offer offer) {
    if (offer.updatedAt == null) return false;
    final now = DateTime.now();
    return now.difference(offer.updatedAt!).inHours <= 24;
  }

  bool _isUrgent(Offer offer) {
    // Example: if offer has a "priority" field set to "high"
    return offer.priority?.toLowerCase() == 'high';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HR Approval Queue'),
      ),
      body: FutureBuilder<List<Offer>>(
        future: _offersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshOffers,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text('No offers pending HR approval')),
                ],
              ),
            );
          }

          final offers = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refreshOffers,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: offers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final offer = offers[index];

                final recentlyReviewed = _isRecentlyReviewed(offer);
                final urgent = _isUrgent(offer);

                return Card(
                  child: ListTile(
                    title: Text(offer.candidateName ?? 'Unknown Candidate'),
                    subtitle: Text(offer.jobTitle ?? 'No job title'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (recentlyReviewed)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Recent',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (urgent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Urgent',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(width: 4),
                        Text(
                          offer.status.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    onTap: () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HROfferDetailScreen(offer: offer),
                        ),
                      );

                      if (updated == true) {
                        _refreshOffers();
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
