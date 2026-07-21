import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'landing_page.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';

import 'presentation/closet/providers/closet_provider.dart';
import 'presentation/closet/screens/closet_screen.dart';
import 'presentation/closet/upload/upload_screen.dart';
import 'presentation/closet/screens/processing_screen.dart';

import 'presentation/closet/screens/item_details_screen.dart';
import 'presentation/closet/screens/metadata_review_screen.dart';
import 'presentation/closet/screens/recommendations_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: "app_config.env");
  } catch (e) {
    print('Warning: .env file could not be loaded: $e');
  }
  
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ClosetProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jewel Vault',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,


      home: const _AuthGate(),

      routes: {
        '/landing': (context) => const LandingPage(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/dashboard': (context) => const _RequireAuth(child: DashboardScreen()),
        '/closet': (context) => const _RequireAuth(child: ClosetScreen()),
        '/upload': (context) => const _RequireAuth(child: UploadScreen()),
      },

      onGenerateRoute: (settings) {
        // These routes carry required arguments, so a direct URL visit without
        // them must fall back to the auth gate rather than crashing on a cast.
        if (settings.name == '/processing') {
          final args = settings.arguments;
          if (args is! Map<String, dynamic>) return _fallbackRoute();
          return MaterialPageRoute(
            builder: (context) => _RequireAuth(
              child: ProcessingScreen(jobId: args['jobId'], itemId: args['itemId']),
            ),
          );

        } else if (settings.name == '/item-details') {
          final itemId = settings.arguments;
          if (itemId is! int) return _fallbackRoute();
          return MaterialPageRoute(
            builder: (context) => _RequireAuth(child: ItemDetailsScreen(itemId: itemId)),
          );
        } else if (settings.name == '/metadata-review') {
          final itemId = settings.arguments;
          if (itemId is! int) return _fallbackRoute();
          return MaterialPageRoute(
            builder: (context) => _RequireAuth(child: MetadataReviewScreen(itemId: itemId)),
          );
        } else if (settings.name == '/recommendations') {
          final itemId = settings.arguments;
          if (itemId is! int) return _fallbackRoute();
          return MaterialPageRoute(
            builder: (context) => _RequireAuth(child: RecommendationsScreen(itemId: itemId)),
          );
        }
        return null;
      },
    );
  }
}

/// Decides the first screen the user sees, based on sign-in state.
/// Flow: LandingPage → Login → Dashboard.
///   - Not signed in  → LandingPage (user clicks "Get Started" to reach Login)
///   - Signed in      → DashboardScreen (skip straight to dashboard)
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFFCF9F4),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF1B4332)),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          // Already signed in: go straight to Dashboard.
          return const DashboardScreen();
        }

        // Not signed in: show the Landing Page first.
        return const LandingPage();
      },
    );
  }
}

/// Route used when a screen is opened without the arguments it requires
/// (typically a direct URL visit on the web build).
MaterialPageRoute _fallbackRoute() =>
    MaterialPageRoute(builder: (context) => const _AuthGate());

/// Wraps a route that requires an authenticated user.
///
/// Navigating straight to a protected URL (for example by typing /closet in the
/// browser) must not expose the screen, so an unauthenticated visitor is shown
/// the login screen instead.
class _RequireAuth extends StatelessWidget {
  final Widget child;

  const _RequireAuth({required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryEmerald),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return child;
        }

        return const LoginScreen();
      },
    );
  }
}
