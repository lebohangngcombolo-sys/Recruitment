import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/hover_card.dart';

class MetricCard extends StatelessWidget {
  final double? width;
  final String title;
  final String subtitle;
  final String value;
  final IconData? icon;
  final String? imageAsset;

  const MetricCard({
    super.key,
    this.width,
    required this.title,
    this.subtitle = "Additional description information can be included.",
    required this.value,
    this.icon,
    this.imageAsset,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 112,
      child: HoverCard(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.cardTitle),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.small),
                    const Spacer(),
                    Text(value, style: AppTextStyles.metric),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: icon != null
                      ? Icon(icon, color: AppColors.primary, size: 20)
                      : (imageAsset != null
                          ? Image.asset(imageAsset!,
                              width: 20, height: 20, color: AppColors.primary)
                          : const SizedBox.shrink()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
