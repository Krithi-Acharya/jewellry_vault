import 'package:flutter/material.dart';
import 'dashboard_screen.dart'; // reuses your existing color/text styles

class PromptScreen extends StatefulWidget {
  const PromptScreen({super.key});

  @override
  State<PromptScreen> createState() => _PromptScreenState();
}

class _PromptScreenState extends State<PromptScreen> {
  final TextEditingController _promptController = TextEditingController();

  bool _isLoading = false;
  String? _resultText;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _submitPrompt() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isLoading = true;
      _resultText = null;
    });

    try {
      // ── STUBBED FOR NOW ──────────────────────────────────────
      // This fakes what the real backend will eventually return,
      // so the screen works end-to-end today. Swap this whole
      // try block for the real API call once AN's backend is live
      // (see the note below the class for exactly what to change).
      await Future.delayed(const Duration(seconds: 1)); // pretend it's "thinking"
      final fakeResponse =
          'Based on "$prompt", I\'d suggest your Silk Slip Dress paired with the Emerald Pendant — a refined, effortless look perfect for the occasion.';

      setState(() {
        _resultText = fakeResponse;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _resultText = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JewelVaultColors.background,
      appBar: AppBar(
        backgroundColor: JewelVaultColors.background,
        elevation: 0,
        title: Text('Ask JewelVault', style: JewelVaultTypography.headingMedium),
        iconTheme: const IconThemeData(color: JewelVaultColors.primaryText),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What are you dressing for?',
              style: JewelVaultTypography.headingSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'e.g. "I want a dress for a wedding" — we\'ll find the perfect match from your closet.',
              style: JewelVaultTypography.bodyMedium,
            ),
            const SizedBox(height: 20),

            // The prompt input box
            TextField(
              controller: _promptController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Type what you need an outfit for...',
                filled: true,
                fillColor: JewelVaultColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: JewelVaultColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: JewelVaultColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: JewelVaultColors.primaryEmerald, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),

            // Submit button — shows a spinner while "loading"
            ElevatedButton(
              onPressed: _isLoading ? null : _submitPrompt,
              style: ElevatedButton.styleFrom(
                backgroundColor: JewelVaultColors.primaryEmerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Get Suggestion'),
            ),
            const SizedBox(height: 24),

            // The result area — only shows once we have an answer
            if (_resultText != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _resultText!,
                        style: JewelVaultTypography.bodyMedium.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}