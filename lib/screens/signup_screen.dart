import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // formKey checks if all fields are filled correctly
  final formKey = GlobalKey<FormState>();

  // These read what the user types
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // Controls show/hide password
  bool showPassword = false;

  // Controls loading state
  bool _isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Runs when user taps Sign Up
  void signup() async {
    // Check if all fields are valid
    if (!formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Create new account with AuthService
      await AuthService.instance.signUp(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (!context.mounted) return;
      // Close signup screen
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;

      String message = 'Failed to create account.';
      switch (e.code) {
        case 'email-already-in-use':
          message = 'An account already exists for that email.';
          break;
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        case 'weak-password':
          message = 'The password provided is too weak.';
          break;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
    // --- Responsive trick: ask, decide, act ---
    double screenWidth = MediaQuery.of(context).size.width;
    bool isBigScreen = screenWidth > 700;
    double formWidth = isBigScreen ? 400 : double.infinity;

    return Scaffold(
      // Cream background to match friend's theme
      backgroundColor: const Color(0xFFFCF9F4),

      // Center + SingleChildScrollView = form stays centered
      // and won't overflow if the keyboard pops up on a small screen
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            width: formWidth, // <-- caps width on big screens, full on mobile
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min, // don't force full height
                children: [
                  // Logo image
                  Image.asset('assets/logo.png', height: 120, width: 120),
                  const SizedBox(height: 16),

                  // Title
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1815),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Name field
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value!.isEmpty) return 'Please enter your name';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

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
                          showPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setState(() => showPassword = !showPassword),
                      ),
                    ),
                    // Stronger rule set from the newer version: length + mixed case + digit
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 8) return 'Minimum 8 characters';
                      if (!value.contains(RegExp(r'[A-Z]'))) {
                        return 'Must contain at least one uppercase letter';
                      }
                      if (!value.contains(RegExp(r'[a-z]'))) {
                        return 'Must contain at least one lowercase letter';
                      }
                      if (!value.contains(RegExp(r'[0-9]'))) {
                        return 'Must contain at least one number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Sign up button (full width)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : signup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B4332),
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
                          : const Text('Sign Up'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Already have account link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account?'),
                      TextButton(
                        // Go back to login screen
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Login',
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
