import 'package:flutter/material.dart';
import '../models/offer.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool showIcon;
  final double? size;

  const StatusBadge({
    super.key,
    required this.status,
    this.showIcon = true,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final offer = Offer(status: status, applicationId: 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: offer.statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: offer.statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon)
            Icon(
              offer.statusIcon,
              color: offer.statusColor,
              size: size ?? 16,
            ),
          if (showIcon) const SizedBox(width: 6),
          Text(
            offer.statusDisplay,
            style: TextStyle(
              color: offer.statusColor,
              fontWeight: FontWeight.w600,
              fontSize: size ?? 14,
            ),
          ),
        ],
      ),
    );
  }
}
