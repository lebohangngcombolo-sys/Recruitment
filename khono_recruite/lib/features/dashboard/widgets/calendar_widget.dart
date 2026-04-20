import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/hover_card.dart';
import '../../../core/widgets/circle_icon.dart';

class CalendarCard extends StatelessWidget {
  final double? width;
  final List<dynamic>? appointments;

  const CalendarCard({super.key, this.width, this.appointments});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      // Tall card spanning the right column
      child: HoverCard(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleIcon(
                      icon: Icons.calendar_today, size: 34, iconSize: 18),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text("Calendar",
                        style: AppTextStyles.cardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(color: AppColors.border, thickness: 1, height: 1),
              const SizedBox(height: 16),
              // Weekly headers
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ["S", "M", "T", "W", "T", "F", "S"]
                    .map((day) => Expanded(
                          child: Center(
                            child: Text(day,
                                style: AppTextStyles.body
                                    .copyWith(fontWeight: FontWeight.bold)),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 42,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1.2,
                ),
                itemBuilder: (context, i) {
                  final isSelected = i == 10; // Dummy active day
                  return Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      color: isSelected ? AppColors.primary : null,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        "${(i % 31) + 1}",
                        style: TextStyle(
                            fontSize: 10,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary),
                      ),
                    ),
                  );
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
