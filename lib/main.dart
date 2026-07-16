import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'landing_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jewel Vault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B4332)),
        useMaterial3: true,
      ),

      // AuthGate decides the first screen based on login state.
      home: const _AuthGate(),

      // Named routes used by Navigator.pushNamed throughout the app
      routes: {
        '/landing': (context) => const LandingPage(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/dashboard': (context) => const DashboardScreen(),
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
