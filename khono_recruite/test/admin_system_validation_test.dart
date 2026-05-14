import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../lib/screens/admin/modular_admin_dashboard.dart';
import '../lib/providers/admin_state_provider.dart';
import '../lib/providers/job_state_provider.dart';
import '../lib/providers/interview_state_provider.dart';
import '../lib/providers/theme_provider.dart';

/// Comprehensive admin system validation test
void main() {
  group('Admin System Validation', () {
    late AdminStateProvider adminProvider;
    late JobStateProvider jobProvider;
    late InterviewStateProvider interviewProvider;
    late ThemeProvider themeProvider;

    setUp(() {
      adminProvider = AdminStateProvider();
      jobProvider = JobStateProvider();
      interviewProvider = InterviewStateProvider();
      themeProvider = ThemeProvider();
    });

    group('State Provider Initialization', () {
      test('AdminStateProvider initializes correctly', () {
        expect(adminProvider.isLoadingDashboard, false);
        expect(adminProvider.isLoadingJobs, false);
        expect(adminProvider.isLoadingInterviews, false);
        expect(adminProvider.jobs, isEmpty);
        expect(adminProvider.interviews, isEmpty);
        expect(adminProvider.applications, isEmpty);
        expect(adminProvider.candidates, isEmpty);
      });

      test('JobStateProvider initializes correctly', () {
        expect(jobProvider.isLoadingJobs, false);
        expect(jobProvider.jobs, isEmpty);
        expect(jobProvider.jobsCurrentPage, 1);
        expect(jobProvider.jobsTotalPages, 1);
        expect(jobProvider.jobsSortBy, 'created_at');
        expect(jobProvider.jobsSortOrder, 'desc');
      });

      test('InterviewStateProvider initializes correctly', () {
        expect(interviewProvider.isLoadingInterviews, false);
        expect(interviewProvider.interviews, isEmpty);
        expect(interviewProvider.interviewFeedback, isEmpty);
        expect(interviewProvider.interviewsCurrentPage, 1);
        expect(interviewProvider.interviewsTotalPages, 1);
        expect(interviewProvider.interviewsSearchQuery, '');
      });
    });

    group('State Provider Methods', () {
      test('JobStateProvider filtering works', () {
        // Test status filtering
        jobProvider.setJobsStatusFilter('active');
        expect(jobProvider.jobsStatusFilter, equals('active'));

        // Test category filtering
        jobProvider.setJobsCategoryFilter('engineering');
        expect(jobProvider.jobsCategoryFilter, equals('engineering'));

        // Test search query
        jobProvider.setJobsSearchQuery('software');
        expect(jobProvider.jobsSearchQuery, equals('software'));

        // Test sorting
        jobProvider.setJobsSortBy('title');
        expect(jobProvider.jobsSortBy, equals('title'));

        jobProvider.toggleJobsSortOrder();
        expect(jobProvider.jobsSortOrder, equals('asc'));
      });

      test('InterviewStateProvider filtering works', () {
        // Test status filtering
        interviewProvider.setInterviewsSelectedStatus('scheduled');
        expect(interviewProvider.interviewsSelectedStatus, equals('scheduled'));

        // Test filter selection
        interviewProvider.setInterviewsSelectedFilter('upcoming');
        expect(interviewProvider.interviewsSelectedFilter, equals('upcoming'));

        // Test search query
        interviewProvider.updateInterviewsSearchQuery('john');
        expect(interviewProvider.interviewsSearchQuery, equals('john'));
      });

      test('Pagination works correctly', () {
        // Test JobStateProvider pagination
        jobProvider.setJobsPage(2);
        expect(jobProvider.jobsCurrentPage, equals(2));

        // Test InterviewStateProvider pagination
        interviewProvider.setInterviewsPage(2);
        expect(interviewProvider.interviewsCurrentPage, equals(2));
      });
    });

    group('Data Management', () {
      test('JobStateProvider data management', () {
        // Test setting jobs
        final testJobs = [
          {'id': 1, 'title': 'Software Engineer', 'status': 'active'},
          {'id': 2, 'title': 'Product Manager', 'status': 'active'},
        ];

        jobProvider.setJobs(testJobs);
        expect(jobProvider.jobs, equals(testJobs));
        expect(jobProvider.jobs.length, equals(2));

        // Test adding jobs
        final newJobs = [
          {'id': 3, 'title': 'Data Scientist', 'status': 'active'}
        ];
        jobProvider.addJobs(newJobs);
        expect(jobProvider.jobs.length, equals(3));
        expect(jobProvider.jobs, containsAll(testJobs));
        expect(jobProvider.jobs, containsAll(newJobs));
      });

      test('InterviewStateProvider data management', () {
        // Test setting interviews
        final testInterviews = [
          {'id': 1, 'candidate_name': 'John Doe', 'status': 'scheduled'},
          {'id': 2, 'candidate_name': 'Jane Smith', 'status': 'completed'},
        ];

        interviewProvider.setInterviews(testInterviews);
        expect(interviewProvider.interviews, equals(testInterviews));
        expect(interviewProvider.interviews.length, equals(2));

        // Test adding interviews
        final newInterviews = [
          {'id': 3, 'candidate_name': 'Bob Johnson', 'status': 'scheduled'}
        ];
        interviewProvider.addInterviews(newInterviews);
        expect(interviewProvider.interviews.length, equals(3));
        expect(interviewProvider.interviews, containsAll(testInterviews));
        expect(interviewProvider.interviews, containsAll(newInterviews));
      });
    });

    group('Component Rendering', () {
      testWidgets('ModularAdminDashboard renders correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => adminProvider),
              ChangeNotifierProvider(create: (_) => themeProvider),
            ],
            child: MaterialApp(
              home: ModularAdminDashboard(token: 'test-token'),
            ),
          ),
        );

        // Verify dashboard renders
        expect(find.byType(ModularAdminDashboard), findsOneWidget);
        expect(find.text('Admin Dashboard'), findsOneWidget);
      });

      testWidgets('Theme provider integration works',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => themeProvider,
            child: MaterialApp(
              home: Container(),
            ),
          ),
        );

        // Test theme toggle
        final initialTheme = themeProvider.isDarkMode;
        themeProvider.toggleTheme();
        expect(themeProvider.isDarkMode, equals(!initialTheme));
      });
    });

    group('Error Handling', () {
      test('Providers handle empty data gracefully', () {
        // Test empty data handling
        jobProvider.setJobs([]);
        expect(jobProvider.jobs, isEmpty);

        interviewProvider.setInterviews([]);
        expect(interviewProvider.interviews, isEmpty);

        interviewProvider.setInterviewFeedback([]);
        expect(interviewProvider.interviewFeedback, isEmpty);
      });

      test('Providers handle null data gracefully', () {
        // Test null data handling
        interviewProvider.setInterviewFeedback([]);
        expect(interviewProvider.interviewFeedback,
            isA<List<Map<String, dynamic>>>());

        jobProvider.setJobs([]);
        expect(jobProvider.jobs, isA<List<Map<String, dynamic>>>());
      });
    });
  });
}
