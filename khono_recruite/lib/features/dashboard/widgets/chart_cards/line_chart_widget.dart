import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class ReviewTrendChart extends StatelessWidget {
  const ReviewTrendChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _legendItem(AppColors.primary, "Completed"),
            const SizedBox(width: 16),
            _legendItem(AppColors.yellow, "Pending"),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) =>
                    const FlLine(color: AppColors.border, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: AppTextStyles.small,
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, _) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text("Week ${value.toInt() + 1}",
                            style: AppTextStyles.small),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: const [
                    FlSpot(0, 20),
                    FlSpot(1, 35),
                    FlSpot(2, 28),
                    FlSpot(3, 40),
                    FlSpot(4, 50),
                  ],
                  isCurved: false,
                  color: AppColors.yellow,
                  barWidth: 2,
                  dotData: const FlDotData(show: true),
                ),
                LineChartBarData(
                  spots: const [
                    FlSpot(0, 15),
                    FlSpot(1, 20),
                    FlSpot(2, 25),
                    FlSpot(3, 30),
                    FlSpot(4, 45),
                  ],
                  isCurved: false,
                  color: AppColors.primary,
                  barWidth: 6, // Make it look like thin bars below the line
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: AppTextStyles.small,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
