import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // Runs when user taps Sign Up
  void signup() async {

    // Check if all fields are valid
    if (formKey.currentState!.validate()) {
      try {
        // Create new account with Firebase
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        // Go back to login page after signup
        Navigator.pop(context);

      } catch (e) {
        // Show error if signup fails
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

              // Title
              const Text('Create Account',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1815),
                )),
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
                    icon: Icon(showPassword
                      ? Icons.visibility
                      : Icons.visibility_off),
                    onPressed: () => setState(() => showPassword = !showPassword),
                  ),
                ),
                validator: (value) {
                  if (value!.isEmpty) return 'Please enter your password';
                  if (value.length < 6) return 'Minimum 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Sign up button (full width)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: signup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B4332),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Sign Up'),
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
                    child: const Text('Login',
                      style: TextStyle(color: Color(0xFF1B4332))),
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