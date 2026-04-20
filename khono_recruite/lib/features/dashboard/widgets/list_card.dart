import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/hover_card.dart';
import '../../../core/widgets/circle_icon.dart';

class ListCard extends StatelessWidget {
  final double? width;
  final double height;
  final String title;
  final List<dynamic> items; // Will type properly based on usage
  final Widget Function(dynamic item) itemBuilder;
  final IconData? headerIcon;

  const ListCard({
    super.key,
    this.width,
    required this.height,
    required this.title,
    required this.items,
    required this.itemBuilder,
    this.headerIcon,
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
            children: [
              Row(
                children: [
                  CircleIcon(icon: headerIcon, size: 34, iconSize: 18),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(title,
                        style: AppTextStyles.cardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const Spacer(),
                  const CircleIcon(
                      icon: Icons.notifications_none, size: 34, iconSize: 18),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(color: AppColors.border, thickness: 1, height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: items.length > 4 ? 4 : items.length, // Show max 4
                  itemBuilder: (context, i) {
                    return itemBuilder(items[i]);
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
