import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {

  // formKey checks if field is filled correctly
  final formKey = GlobalKey<FormState>();

  // Reads what user types
  final emailController = TextEditingController();

  // Runs when user taps Send Reset Link
  void resetPassword() async {

    // Check if field is valid
    if (formKey.currentState!.validate()) {
      try {
        // Send reset email using Firebase
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: emailController.text.trim(),
        );

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent! Check your inbox.')),
        );

      } catch (e) {
        // Show error if it fails
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      // Cream background to match friend's theme
      backgroundColor: const Color(0xFFFCF9F4),

      // App bar with back button
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B4332),
        foregroundColor: Colors.white,
        title: const Text('Forgot Password'),
      ),

      body: Padding(
        padding: const EdgeInsets.all(24.0),

        // Form widget helps validate field
        child: Form(
          key: formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // Logo image
              Image.asset('assets/logo.png', height: 120, width: 120),
              const SizedBox(height: 16),

              // Title
              const Text('Reset Password',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1815),
                )),
              const SizedBox(height: 8),

              // Subtitle
              const Text(
                'Enter your email to receive a reset link',
                style: TextStyle(color: Color(0xFF6B6258)),
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
                validator: (value) {
                  if (value!.isEmpty) return 'Please enter your email';
                  if (!value.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Send reset link button (full width)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B4332),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Send Reset Link'),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}