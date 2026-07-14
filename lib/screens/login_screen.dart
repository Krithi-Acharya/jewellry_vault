import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // formKey checks if all fields are filled correctly
  final formKey = GlobalKey<FormState>();

  // These read what the user types
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // Controls show/hide password
  bool showPassword = false;

  // Shows a loading spinner while Firebase is working
  bool isLoading = false;

  // Runs when user taps Login
  void login() async {
    // Check if all fields are valid first
    if (formKey.currentState!.validate()) {
      setState(() => isLoading = true);

      try {
        // Sign in with Firebase
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        // Go to Dashboard after successful login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      } catch (e) {
        // Show error if login fails
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- Responsive trick: ask, decide, act ---
    double screenWidth = MediaQuery.of(context).size.width;
    bool isBigScreen = screenWidth > 700;
    double formWidth = isBigScreen ? 400 : double.infinity;

    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F4),

      // Back button in the top-left, takes you back to Landing Page
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCF9F4),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1B4332)),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            width: formWidth,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo image
                  Image.asset('assets/logo.png', height: 120, width: 120),
                  const SizedBox(height: 16),

                  // Title
                  const Text(
                    'Jewel Vault',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1815),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Email field
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value!.isEmpty) return 'Please enter your email';
                      if (!value.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password field with show/hide eye icon
                  TextFormField(
                    controller: passwordController,
                    obscureText: !showPassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          showPassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setState(() => showPassword = !showPassword),
                      ),
                    ),
                    validator: (value) {
                      if (value!.isEmpty) return 'Please enter your password';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Forgot Password link
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(color: Color(0xFF1B4332)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Login button (full width)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      // Disable button while loading so it can't be tapped twice
                      onPressed: isLoading ? null : login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B4332),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Login'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Don't have an account link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignupScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(color: Color(0xFF1B4332)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}