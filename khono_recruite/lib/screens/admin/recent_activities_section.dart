import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/themed_surface_card.dart';
import '../../widgets/admin_dashboard_components.dart';

/// Recent activities section component
class RecentActivitiesSection extends StatelessWidget {
  final List<String> activities;
  final bool isLoading;
  final VoidCallback onViewAll;

  const RecentActivitiesSection({
    super.key,
    required this.activities,
    required this.isLoading,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return ThemedSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activities',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color:
                      themeProvider.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFC10D00),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (activities.isEmpty)
            SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_outlined,
                      size: 64,
                      color: themeProvider.isDarkMode
                          ? Colors.grey.shade600
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Recent Activities',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No recent activities to display.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            RecentActivitiesList(
              activities: activities.take(5).toList(),
            ),
        ],
      ),
    );
  }
}
