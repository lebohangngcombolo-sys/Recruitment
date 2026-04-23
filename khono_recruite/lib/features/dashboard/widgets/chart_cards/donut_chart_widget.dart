import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class JobsDonutChart extends StatelessWidget {
  const JobsDonutChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                  sections: [
                    _section(27, AppColors.green),
                    _section(32, AppColors.yellow),
                    _section(10, AppColors.purple),
                    _section(15, AppColors.blue),
                    _section(12, AppColors.orange),
                  ],
                ),
              ),
              Image.asset('assets/icons/Dashboard/total_jobs.png',
                  width: 56, height: 56, color: AppColors.white)
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Key Guide:",
                  style: AppTextStyles.small.copyWith(
                      fontWeight: FontWeight.bold, color: AppColors.white)),
              const SizedBox(height: 8),
              _legendItem(AppColors.yellow, "32%", "Software Eng"),
              _legendItem(AppColors.green, "27%", "Data Analyst"),
              _legendItem(AppColors.blue, "15%", "Fin Analyst"),
              _legendItem(AppColors.orange, "12%", "HR Spec"),
              _legendItem(AppColors.purple, "10%", "Marketing"),
            ],
          ),
        )
      ],
    );
  }

  PieChartSectionData _section(double value, Color color) {
    return PieChartSectionData(
      value: value,
      color: color,
      radius: 40,
      title: "${value.toInt()}%",
      titleStyle: AppTextStyles.small
          .copyWith(color: Colors.white, fontWeight: FontWeight.bold),
    );
  }

  Widget _legendItem(Color color, String percentage, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(width: 8, height: 8, color: color),
          const SizedBox(width: 8),
          Text(percentage,
              style: AppTextStyles.small.copyWith(
                  color: AppColors.white, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  style: AppTextStyles.small,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
