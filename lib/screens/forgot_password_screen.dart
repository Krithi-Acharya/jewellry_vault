import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // formKey checks if the email field is filled correctly
  final formKey = GlobalKey<FormState>();

  // Reads what the user types
  final emailController = TextEditingController();

  // Shows a loading spinner while Firebase is working
  bool isLoading = false;

  // Runs when user taps "Send Reset Link"
  void resetPassword() async {
    // Check if email field is valid first
    if (formKey.currentState!.validate()) {
      setState(() => isLoading = true);

      try {
        // Ask Firebase to send the reset email
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: emailController.text.trim(),
        );

        // Tell the user it worked
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reset link sent! Check your email.')),
        );

        // Go back to login screen
        Navigator.pop(context);
      } catch (e) {
        // Show error if something went wrong
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
                  // Icon instead of logo, since this isn't the main entry screen
                  const Icon(
                    Icons.lock_reset,
                    size: 70,
                    color: Color(0xFF1B4332),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  const Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1815),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Small helper text
                  const Text(
                    'Enter your email and we\'ll send you a link to reset your password',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
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
                  const SizedBox(height: 24),

                  // Send Reset Link button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      // Disable button while loading so it can't be tapped twice
                      onPressed: isLoading ? null : resetPassword,
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
                          : const Text('Send Reset Link'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Back to login link
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Back to Login',
                      style: TextStyle(color: Color(0xFF1B4332)),
                    ),
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