import 'package:flutter/material.dart';
import '../models/offer.dart';

class OfferCard extends StatelessWidget {
  final Offer offer;
  final VoidCallback? onTap;
  final bool showActions;
  final Function(Offer)? onAction;

  const OfferCard({
    super.key,
    required this.offer,
    this.onTap,
    this.showActions = false,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: InkWell(
        onTap: onTap,
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
                          'Offer #${offer.id}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (offer.candidateName != null)
                          Text(
                            'Candidate: ${offer.candidateName}',
                            style: TextStyle(
                              color: Colors.grey[700],
                            ),
                          ),
                        if (offer.jobTitle != null)
                          Text(
                            'Position: ${offer.jobTitle}',
                            style: TextStyle(
                              color: Colors.grey[700],
                            ),
                          ),
                      ],
                    ),
                  ),
                  _buildStatusChip(),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (offer.baseSalary != null)
                    _buildInfoItem(
                      Icons.attach_money,
                      '\$${offer.baseSalary!.toStringAsFixed(2)}',
                    ),
                  if (offer.contractType != null)
                    _buildInfoItem(
                      Icons.work,
                      offer.contractType!,
                    ),
                  if (offer.startDate != null)
                    _buildInfoItem(
                      Icons.calendar_today,
                      'Starts ${offer.startDate!.toLocal().toString().split(' ')[0]}',
                    ),
                ],
              ),
              if (showActions && onAction != null) ...[
                const SizedBox(height: 12),
                _buildActionButtons(),
              ],
              if (offer.createdAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Created: ${offer.createdAt!.toLocal().toString().split(' ')[0]}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    return Chip(
      label: Text(
        offer.statusDisplay,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
      backgroundColor: offer.statusColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => onAction?.call(offer),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: const Text('View Details'),
          ),
        ),
      ],
    );
  }
}
