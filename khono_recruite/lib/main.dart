import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart'; // ΓÜí Web URL strategy
import 'package:flutter_web_plugins/flutter_web_plugins.dart'; // ΓÜí Web URL strategy
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_flutter_web/webview_flutter_web.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/candidate/candidate_dashboard.dart';
import 'screens/candidate/find_talent_page.dart';
import 'screens/candidate/jobs_applied_page.dart';
import 'screens/candidate/intern_stories_page.dart';
import 'screens/candidate/job_details_page.dart';
import 'screens/enrollment/enrollment_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/hiring_manager/hiring_manager_dashboard.dart';
import 'screens/landing_page/landing_page.dart';
import 'screens/about_us_page.dart';
import 'screens/contact_page.dart';
import 'screens/auth/reset_password.dart';
import 'screens/admin/profile_page.dart';
import 'screens/auth/oath_callback_screen.dart';
import 'screens/auth/mfa_verification_screen.dart';
import 'screens/auth/sso_handler_screen.dart';
import 'screens/auth/verification_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/sso_enterprise_screen.dart';
import 'screens/hr/hr_dashboard.dart';
import 'screens/hiring_manager/pipeline_page.dart';
import 'screens/hiring_manager/offer_list_screen.dart';

import 'providers/theme_provider.dart';
import 'utils/theme_utils.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ai/firebase_ai.dart' show FirebaseAI, GenerativeModel;
import 'firebase_options.dart';
import 'services/ai_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase: init only if options are configured (non-empty apiKey). Otherwise app still runs without Firebase/Gemini.
  GenerativeModel? generativeModel;
  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options.apiKey.isNotEmpty && options.projectId.isNotEmpty) {
      await Firebase.initializeApp(options: options);
      generativeModel =
          FirebaseAI.googleAI().generativeModel(model: 'gemini-2.5-flash');
    }
  } catch (e) {
    assert(true, 'Firebase init failed (e.g. invalid-api-key): $e');
    // Continue without Firebase so the app UI still loads
  }
  AIService.initialize(generativeModel);

  // ⚡ Fix Flutter Web initial route handling
  setUrlStrategy(PathUrlStrategy());

  // WebView: set web platform implementation so CV preview works in-app on web
  if (kIsWeb) {
    WebViewPlatform.instance = WebWebViewPlatform();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const KhonoRecruiteApp(),
    ),
  );
}

// Γ£à Persistent router
// Γ£à Persistent router
final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LandingPage(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/sso-enterprise',
      builder: (context, state) => const SsoEnterpriseScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/verify-email',
      builder: (context, state) {
        final email = state.uri.queryParameters['email'] ?? '';
        final code = state.uri.queryParameters['code'] ?? '';
        return VerificationScreen(
            email: email, initialCode: code.isNotEmpty ? code : null);
      },
    ),
    GoRoute(
      path: '/find-talent',
      builder: (context, state) => const FindTalentPage(),
    ),
    GoRoute(
      path: '/intern-stories',
      builder: (context, state) => const InternStoriesPage(),
    ),
    GoRoute(
      path: '/about-us',
      builder: (context, state) => const AboutUsPage(),
    ),
    GoRoute(
      path: '/contact',
      builder: (context, state) => const ContactPage(),
    ),
    GoRoute(
      path: '/job-details',
      builder: (context, state) {
        final job = state.extra as Map<String, dynamic>?;
        if (job == null) {
          return const LandingPage();
        }
        return JobDetailsPage(job: job);
      },
    ),
    GoRoute(
      path: '/mfa-verification',
      builder: (context, state) {
        final mfaSessionToken =
            state.uri.queryParameters['mfa_session_token'] ?? '';
        final userId = state.uri.queryParameters['user_id'] ?? '';
        return MfaVerificationScreen(
          mfaSessionToken: mfaSessionToken,
          userId: userId,
          onVerify: (String token) {},
          onBack: () {
            context.go('/login');
          },
          isLoading: false,
        );
      },
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) {
        final token = state.uri.queryParameters['token'] ?? '';
        return ResetPasswordPage(token: token);
      },
    ),
    GoRoute(
      path: '/candidate-dashboard',
      builder: (context, state) {
        final token = state.uri.queryParameters['token'] ?? '';
        return CandidateDashboard(token: token);
      },
    ),
    GoRoute(
      path: '/jobs-applied',
      builder: (context, state) {
        final token = state.uri.queryParameters['token'] ?? '';
        return JobsAppliedPage(token: token);
      },
    ),
    GoRoute(
      path: '/enrollment',
      builder: (context, state) {
        final token = state.uri.queryParameters['token'] ?? '';
        return EnrollmentScreen(token: token);
      },
    ),
    GoRoute(
      path: '/admin-dashboard',
      builder: (context, state) {
        final token = state.uri.queryParameters['token'] ?? '';
        return AdminDAshboard(token: token);
      },
    ),
    GoRoute(
      path: '/hiring-manager-dashboard',
      builder: (context, state) {
        final token = state.uri.queryParameters['token'] ?? '';
        return HMMainDashboard(token: token);
      },
    ),
    GoRoute(
      path: '/hiring-manager-pipeline',
      builder: (context, state) {
        final token = state.uri.queryParameters['token'] ?? '';
        return RecruitmentPipelinePage(token: token);
      },
    ),
    GoRoute(
      path: '/hiring-manager-offers',
      builder: (context, state) => const AdminOfferListScreen(),
    ),
    // Γ£à Add this new route
    // Γ£à Add this new route
    GoRoute(
      path: '/hr-dashboard',
      builder: (context, state) {
        final token = state.uri.queryParameters['token'] ?? '';
        return HRDashboard(token: token);
      },
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) {
        final token = state.uri.queryParameters['token'] ?? '';
        return ProfilePage(token: token);
      },
    ),
    // ΓÜí OAuth callback screen reads tokens directly from URL
    // ΓÜí OAuth callback screen reads tokens directly from URL
    GoRoute(
      path: '/oauth-callback',
      builder: (context, state) => const OAuthCallbackScreen(),
    ),
    GoRoute(
      path: '/sso-redirect',
      builder: (context, state) => const SsoRedirectHandler(),
    ),
  ],
);

class KhonoRecruiteApp extends StatelessWidget {
  const KhonoRecruiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp.router(
      title: "Khono_Recruite",
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeUtils.lightTheme,
      darkTheme: ThemeUtils.darkTheme,
      routerConfig: _router,
    );
  }
}
