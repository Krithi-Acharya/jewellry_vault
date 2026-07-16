import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
<<<<<<< HEAD
=======

  // Controls loading state
>>>>>>> 3df0e715f29cf1ed06e7d56c88d0cf05d3e543cb
  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  void resetPassword() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AuthService.instance.sendPasswordResetEmail(
        emailController.text.trim(),
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent! Check your inbox.'),
        ),
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;

      String message = 'Failed to send reset email.';
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      }

<<<<<<< HEAD
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
=======
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
>>>>>>> 3df0e715f29cf1ed06e7d56c88d0cf05d3e543cb
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
<<<<<<< HEAD
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
                  const Icon(
                    Icons.lock_reset,
                    size: 70,
                    color: Color(0xFF1B4332),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1815),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter your email and we\'ll send you a link to reset your password',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 32),
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
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : resetPassword,
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
                          : const Text('Send Reset Link'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Back to Login',
                      style: TextStyle(color: Color(0xFF1B4332)),
=======
    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F4),

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

                // Subtitle
                const Text(
                  'Enter your email to receive a reset link',
                  textAlign: TextAlign.center,
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
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Send reset link button (full width)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : resetPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B4332),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
>>>>>>> 3df0e715f29cf1ed06e7d56c88d0cf05d3e543cb
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
    );
  }
}
