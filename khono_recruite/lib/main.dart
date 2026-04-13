import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// Import screens
import 'screens/landing_page/splash_landing_page.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/candidate/candidate_dashboard.dart';
import 'screens/candidate/saved_application_screen.dart';
import 'screens/candidate/jobs_applied_page.dart';
import 'screens/candidate/assessment_page.dart';
import 'screens/candidate/assessments_results_screen.dart';
import 'screens/candidate/user_profile_page.dart';
import 'screens/candidate/my_interviews_page.dart';
import 'screens/candidate/saved_jobs_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/hr/hr_dashboard.dart';
import 'screens/hiring_manager/hiring_manager_dashboard.dart';
import 'screens/candidate/job_details_page.dart';
import 'screens/candidate/redirect_to_assessment_page.dart';

// Import services
import 'services/auth_service.dart';
import 'providers/theme_provider.dart';

String _dashboardRouteForRole(String? role) {
  switch (role) {
    case 'admin':
      return '/admin-dashboard';
    case 'hr':
      return '/hr-dashboard';
    case 'hiring_manager':
      return '/hiring-manager-dashboard';
    case 'candidate':
      return '/candidate-dashboard';
    default:
      return '/login';
  }
}

/// Single instance so changing theme does not recreate the router or drop navigation.
GoRouter _createAppRouter({required String? initialToken, required String? initialRole}) {
  return GoRouter(
        initialLocation: initialToken != null && initialToken.trim().isNotEmpty
            ? _dashboardRouteForRole(initialRole)
            : '/',
        redirect: (context, state) {
          final token = initialToken;
          final rawPath = state.uri.path;
          final path = rawPath.isEmpty ? '/' : rawPath;
          final tokenFromQuery = state.uri.queryParameters['token'];

          final isAuthed = (token != null && token.trim().isNotEmpty) ||
              (tokenFromQuery != null && tokenFromQuery.trim().isNotEmpty);

          if (!isAuthed) {
            final allowedUnauth = path == '/' ||
                path.startsWith('/login') ||
                path.startsWith('/register') ||
                path.startsWith('/forgot-password') ||
                path.startsWith('/oauth-callback');
            if (!allowedUnauth) {
              return '/';
            }
          }
          return null;
        },
        routes: [
          // Splash (root): first screen before auth; same URL as "Home" from login/register.
          GoRoute(
            path: '/',
            redirect: (context, state) {
              final t = initialToken;
              if (t != null && t.trim().isNotEmpty) {
                return _dashboardRouteForRole(initialRole);
              }
              return null;
            },
            builder: (context, state) => const SplashLandingPage(),
          ),
          // Legacy / direct link compatibility
          GoRoute(
            path: '/landing',
            redirect: (context, state) => '/',
          ),
          // Authentication routes
          GoRoute(
            path: '/login',
            builder: (context, state) => LoginScreen(),
          ),
          GoRoute(
            path: '/register',
            builder: (context, state) => RegisterScreen(),
          ),
          GoRoute(
            path: '/forgot-password',
            builder: (context, state) => ForgotPasswordScreen(),
          ),
          GoRoute(
            path: '/oauth-callback',
            builder: (context, state) => OAuthCallbackPage(
              accessToken: state.uri.queryParameters['access_token'],
              refreshToken: state.uri.queryParameters['refresh_token'],
              role: state.uri.queryParameters['role'],
              dashboard: state.uri.queryParameters['dashboard'],
            ),
          ),
          
          // Candidate routes
          GoRoute(
            path: '/candidate-dashboard',
            builder: (context, state) => CandidateDashboard(
              token: state.uri.queryParameters['token'] ?? '',
            ),
          ),
          GoRoute(
            path: '/saved-applications',
            builder: (context, state) => SavedApplicationsScreen(
              token: state.uri.queryParameters['token'] ?? '',
            ),
          ),
          GoRoute(
            path: '/jobs-applied',
            builder: (context, state) {
              final extra = state.extra;
              final initial = extra is List
                  ? extra
                        .whereType<Map>()
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList()
                  : null;
              return JobsAppliedPage(
                token: state.uri.queryParameters['token'] ?? '',
                initialApplications: initial,
              );
            },
          ),
          GoRoute(
            path: '/assessment',
            builder: (context, state) => AssessmentPage(
              applicationId: int.tryParse(state.uri.queryParameters['applicationId'] ?? '0') ?? 0,
              draftData: state.extra as Map<String, dynamic>?,
            ),
          ),
          GoRoute(
            path: '/assessment-results',
            builder: (context, state) => AssessmentResultsPage(
              token: state.uri.queryParameters['token'] ?? '',
            ),
          ),
          GoRoute(
            path: '/my-interviews',
            builder: (context, state) => MyInterviewsPage(
              token: state.uri.queryParameters['token'] ?? '',
            ),
          ),
          GoRoute(
            path: '/saved-jobs',
            builder: (context, state) => SavedJobsScreen(
              token: state.uri.queryParameters['token'] ?? '',
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => ProfilePage(
              token: state.uri.queryParameters['token'] ?? '',
            ),
          ),
          GoRoute(
            path: '/job-details',
            builder: (context, state) {
              final job = state.extra as Map<String, dynamic>?;
              return JobDetailsPage(
                job: job ?? {},
              );
            },
          ),
          GoRoute(
            path: '/redirect-to-assessment',
            builder: (context, state) => RedirectToAssessmentPage(
              applicationId: int.tryParse(state.uri.queryParameters['applicationId'] ?? '0') ?? 0,
              jobTitle: state.uri.queryParameters['jobTitle'],
            ),
          ),
          
          // Admin routes
          GoRoute(
            path: '/admin-dashboard',
            builder: (context, state) => AdminDashboard(
              token: state.uri.queryParameters['token'] ?? '',
            ),
          ),
          
          // HR routes
          GoRoute(
            path: '/hr-dashboard',
            builder: (context, state) => HRDashboard(
              token: state.uri.queryParameters['token'] ?? '',
            ),
          ),

          // Hiring Manager routes
          GoRoute(
            path: '/hiring-manager-dashboard',
            builder: (context, state) => HMMainDashboard(
              token: state.uri.queryParameters['token'] ?? '',
            ),
          ),
        ],
        errorBuilder: (context, state) => Scaffold(
          body: Center(
            child: Text('Page not found'),
          ),
        ),
      );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final token = await AuthService.getAccessToken();
  final role = await AuthService.getRole();
  final initialThemeDark = await ThemeProvider.loadSavedIsDark();
  final router = _createAppRouter(initialToken: token, initialRole: role);

  runApp(MyApp(
    initialToken: token,
    initialRole: role,
    initialThemeDark: initialThemeDark,
    routerConfig: router,
  ));
}

class MyApp extends StatelessWidget {
  final String? initialToken;
  final String? initialRole;
  final bool initialThemeDark;
  final GoRouter routerConfig;

  const MyApp({
    super.key,
    this.initialToken,
    this.initialRole,
    required this.initialThemeDark,
    required this.routerConfig,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(initialIsDark: initialThemeDark),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            title: 'Khono Recruitment',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.themeData,
            routerConfig: routerConfig,
          );
        },
      ),
    );
  }
}

class OAuthCallbackPage extends StatefulWidget {
  final String? accessToken;
  final String? refreshToken;
  final String? role;
  final String? dashboard;

  const OAuthCallbackPage({
    super.key,
    this.accessToken,
    this.refreshToken,
    this.role,
    this.dashboard,
  });

  @override
  State<OAuthCallbackPage> createState() => _OAuthCallbackPageState();
}

class _OAuthCallbackPageState extends State<OAuthCallbackPage> {
  @override
  void initState() {
    super.initState();
    _handleOAuthRedirect();
  }

  Future<void> _handleOAuthRedirect() async {
    final access = widget.accessToken?.trim();
    final refresh = widget.refreshToken?.trim();
    final role = (widget.role ?? 'candidate').trim();
    final dashboard = widget.dashboard?.trim();

    if (access == null || access.isEmpty) {
      if (!mounted) return;
      context.go('/login');
      return;
    }

    await AuthService.clearAuthState();
    await AuthService.storeTokens(access, refresh, role);

    if (!mounted) return;
    final encodedToken = Uri.encodeComponent(access);
    final nextPath = switch (role) {
      'admin' => '/admin-dashboard?token=$encodedToken',
      'hiring_manager' => '/hiring-manager-dashboard?token=$encodedToken',
      'hr' => '/hr-dashboard?token=$encodedToken',
      'candidate' when dashboard == '/enrollment' => '/enrollment?token=$encodedToken',
      _ => '/candidate-dashboard?token=$encodedToken',
    };
    context.go(nextPath);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
