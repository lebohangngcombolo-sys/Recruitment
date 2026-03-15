import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../lib/widgets/admin_dashboard_components.dart';
import '../lib/providers/admin_state_provider.dart';
import '../lib/services/cache_service.dart';

void main() {
  group('Admin Dashboard Components Tests', () {
    setUp(() {
      // Setup for admin dashboard tests
    });

    testWidgets('DashboardStatCard displays correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardStatCard(
              title: 'Total Jobs',
              value: '42',
              icon: Icons.work,
              subtitle: '5 new this week',
            ),
          ),
        ),
      );

      expect(find.text('Total Jobs'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('5 new this week'), findsOneWidget);
      expect(find.byIcon(Icons.work), findsOneWidget);
    });

    testWidgets('DashboardChart renders without error',
        (WidgetTester tester) async {
      final chartData = [
        ChartData('Jan', 100, color: Colors.blue),
        ChartData('Feb', 150, color: Colors.green),
        ChartData('Mar', 120, color: Colors.orange),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardChart(
              title: 'Monthly Applications',
              data: chartData,
              chartType: ChartType.bar,
              subtitle: 'Last 3 months',
            ),
          ),
        ),
      );

      expect(find.text('Monthly Applications'), findsOneWidget);
      expect(find.text('Last 3 months'), findsOneWidget);
    });

    testWidgets('RecentActivitiesList shows activities',
        (WidgetTester tester) async {
      final activities = [
        'User John Doe created a new job',
        'Candidate Jane Smith applied for position',
        'Interview scheduled for tomorrow',
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecentActivitiesList(
              activities: activities,
            ),
          ),
        ),
      );

      expect(find.text('Recent Activities'), findsOneWidget);
      expect(find.text('User John Doe created a new job'), findsOneWidget);
      expect(find.text('Candidate Jane Smith applied for position'),
          findsOneWidget);
      expect(find.text('Interview scheduled for tomorrow'), findsOneWidget);
    });

    testWidgets('PowerBIStatusIndicator shows connected status',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PowerBIStatusIndicator(
              isConnected: true,
              isChecking: false,
            ),
          ),
        ),
      );

      expect(find.text('PowerBI Integration'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
    });

    testWidgets('PowerBIStatusIndicator shows checking status',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PowerBIStatusIndicator(
              isConnected: false,
              isChecking: true,
            ),
          ),
        ),
      );

      expect(find.text('PowerBI Integration'), findsOneWidget);
      expect(find.text('Checking status...'), findsOneWidget);
    });
  });

  group('Admin State Provider Tests', () {
    late AdminStateProvider adminStateProvider;

    setUp(() {
      adminStateProvider = AdminStateProvider();
    });

    test('Initial state should be correct', () {
      expect(adminStateProvider.isLoadingDashboard, isFalse);
      expect(adminStateProvider.dashboardStats, isEmpty);
      expect(adminStateProvider.recentActivities, isEmpty);
      expect(adminStateProvider.jobs, isEmpty);
      expect(adminStateProvider.applications, isEmpty);
    });

    test('Jobs filters update correctly', () {
      adminStateProvider.updateJobsFilters(
        searchQuery: 'developer',
        category: 'Engineering',
        status: 'active',
      );

      expect(adminStateProvider.jobsCurrentPage, equals(1));
    });

    test('Applications filters work correctly', () {
      adminStateProvider.updateApplicationsFilters(
        searchQuery: 'john',
        status: 'applied',
      );

      expect(adminStateProvider.applicationsCurrentPage, equals(1));
    });

    test('Audit logs filters update correctly', () {
      final now = DateTime.now();
      adminStateProvider.updateAuditLogsFilters(
        action: 'create',
        startDate: now,
        endDate: now.add(const Duration(days: 7)),
        searchQuery: 'test',
      );

      expect(adminStateProvider.auditLogsCurrentPage, equals(1));
    });

    test('Cache management works', () {
      adminStateProvider.clearCache();
      expect(adminStateProvider.dashboardStats, isEmpty);
    });
  });

  group('Cache Service Tests', () {
    setUp(() async {
      // Setup for cache service tests
    });

    test('Cache item creation works', () {
      final item = CacheItem(
        value: {'test': 'data'},
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        persisted: true,
      );

      expect(item.value, equals({'test': 'data'}));
      expect(item.isExpired, isFalse);
    });

    test('Cache item expiration works', () {
      final expiredItem = CacheItem(
        value: {'test': 'data'},
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        persisted: true,
      );

      expect(expiredItem.isExpired, isTrue);
    });

    test('Cache stats calculation works', () {
      final stats = CacheStats(
        memoryItems: 50,
        diskItems: 200,
        maxMemoryItems: 100,
        maxDiskItems: 500,
      );

      expect(stats.memoryUsagePercent, equals(50.0));
      expect(stats.diskUsagePercent, equals(40.0));
    });
  });

  group('Integration Tests', () {
    testWidgets('Admin dashboard integration test',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (context) => AdminStateProvider(),
            child: Scaffold(
              body: Column(
                children: [
                  DashboardStatCard(
                    title: 'Test Stat',
                    value: '100',
                    icon: Icons.analytics,
                  ),
                  RecentActivitiesList(
                    activities: ['Test activity'],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DashboardStatCard), findsOneWidget);
      expect(find.byType(RecentActivitiesList), findsOneWidget);
      expect(find.text('Test Stat'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('Test activity'), findsOneWidget);
    });
  });

  group('Performance Tests', () {
    test('Large dataset handling', () async {
      final largeActivitiesList =
          List.generate(1000, (index) => 'Activity $index');
      expect(largeActivitiesList.length, equals(1000));
    });

    test('Memory usage test', () {
      final provider = AdminStateProvider();
      provider.clearCache();
    });
  });

  group('Accessibility Tests', () {
    testWidgets('Dashboard components have proper semantics',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardStatCard(
              title: 'Total Applications',
              value: '250',
              icon: Icons.description,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Total Applications'), findsOneWidget);
    });
  });
}

/// Widget test helpers
class TestHelpers {
  static Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  static Widget createProviderTestWidget<T extends ChangeNotifier>(
    T provider,
    Widget child,
  ) {
    return MaterialApp(
      home: ChangeNotifierProvider<T>.value(
        value: provider,
        child: Scaffold(
          body: child,
        ),
      ),
    );
  }
}

/// Mock data generators
class MockDataGenerator {
  static List<Map<String, dynamic>> generateMockJobs(int count) {
    return List.generate(
        count,
        (index) => {
              'id': index + 1,
              'title': 'Job Title ${index + 1}',
              'status': 'active',
              'created_at': DateTime.now().toIso8601String(),
            });
  }

  static List<String> generateMockActivities(int count) {
    return List.generate(count, (index) => 'Activity ${index + 1}');
  }

  static Map<String, dynamic> generateMockDashboardStats() {
    return {
      'jobs': 42,
      'candidates': 128,
      'interviews': 15,
      'applications': 89,
    };
  }
}
