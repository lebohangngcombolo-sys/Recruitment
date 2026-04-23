import 'package:flutter/material.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/hover_card.dart';

class MetricCard extends StatelessWidget {
  final double? width;
  final String title;
  final String subtitle;
  final String value;
  final String imageAsset;
  final bool isDarkMode;

  const MetricCard({
    super.key,
    this.width,
    required this.title,
    this.subtitle = "Additional description information can be included.",
    required this.value,
    required this.imageAsset,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 112,
      child: HoverCard(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.cardTitle.copyWith(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.small.copyWith(
                        color: isDarkMode
                            ? Colors.white70
                            : Colors.black.withValues(alpha: 0.6),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      value,
                      style: AppTextStyles.metric.copyWith(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Image.asset(
                imageAsset,
                width: 64,
                height: 64,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
