import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/hover_card.dart';
import '../../../core/widgets/circle_icon.dart';

class ChartCard extends StatelessWidget {
  final double? width;
  final double height;
  final String title;
  final Widget chart;
  final IconData? icon;

  const ChartCard({
    super.key,
    this.width,
    required this.height,
    required this.title,
    required this.chart,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: HoverCard(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleIcon(icon: icon, size: 34, iconSize: 18),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(title,
                        style: AppTextStyles.cardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(color: AppColors.border, thickness: 1, height: 1),
              const SizedBox(height: 16),
              Expanded(
                child: chart,
              )
            ],
          ),
        ),
      ),
    );
  }
}
