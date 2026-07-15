import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import '../landing_page.dart';

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
  
  // Controls loading state
  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Runs when user taps Login
  void login() async {
    // Check if all fields are valid
    if (!formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      // Login with AuthService
      await AuthService.instance.signIn(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (!context.mounted) return;
      // Close the login screen and let AuthGate reveal the Dashboard
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      
      String message = 'Authentication failed.';
      switch (e.code) {
        case 'invalid-credential':
        case 'user-not-found':
        case 'wrong-password':
          message = 'Invalid email or password.';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred.')),
      );
    } finally {
      if (context.mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Cream background to match friend's theme
      backgroundColor: const Color(0xFFFCF9F4),

      body: Padding(
        padding: const EdgeInsets.all(24.0),

        // Form widget helps validate all fields together
        child: Form(
          key: formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo image
              Image.asset('assets/logo.png', height: 120, width: 120),
              const SizedBox(height: 16),

              // App title
              const Text(
                'JewelVault',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1815), // dark color
                ),
              ),
              const SizedBox(height: 32),

              // Email field with validation
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                // validator shows error if field is wrong
                validator: (value) {
                  if (value!.isEmpty) return 'Please enter your email';
                  if (!value.contains('@')) return 'Enter a valid email';
                  return null; // null means no error
                },
              ),
              const SizedBox(height: 16),

              // Password field with show/hide eye icon
              TextFormField(
                controller: passwordController,
                obscureText: !showPassword, // hides password with dots
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  // Eye icon button
                  suffixIcon: IconButton(
                    icon: Icon(
                      showPassword
                          ? Icons
                                .visibility // eye open = password visible
                          : Icons.visibility_off,
                    ), // eye closed = password hidden
                    onPressed: () =>
                        setState(() => showPassword = !showPassword),
                  ),
                ),
                validator: (value) {
                  if (value!.isEmpty) return 'Please enter your password';
                  if (value.length < 6) return 'Minimum 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // Forgot password link (pushed to right side)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ForgotPasswordScreen(),
                    ),
                  ),
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
                  onPressed: _isLoading ? null : login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B4332), // dark green
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading 
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

              // Sign up link at bottom
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?"),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignupScreen(),
                      ),
                    ),
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
    );
  }
}
