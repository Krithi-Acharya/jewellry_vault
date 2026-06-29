import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class JewelVaultColors {
  static const Color background = Color(0xFFFCF9F4);
  static const Color primaryEmerald = Color(0xFF1B4332);
  static const Color darkEmerald = Color(0xFF012D1D);
  static const Color whiteCard = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5DDD0);
  static const Color primaryText = Color(0xFF1A1815);
  static const Color secondaryText = Color(0xFF6B6258);
}

class JewelVaultTypography {
  static TextStyle displayMassive = GoogleFonts.fraunces(
    fontSize: 84,
    fontWeight: FontWeight.w400,
    color: JewelVaultColors.primaryText,
    height: 1.1,
    letterSpacing: -0.03,
  );

  static TextStyle displayLarge = GoogleFonts.fraunces(
    fontSize: 56,
    fontWeight: FontWeight.w400,
    color: JewelVaultColors.primaryText,
    height: 1.15,
    letterSpacing: -0.02,
  );

  static TextStyle displayMedium = GoogleFonts.fraunces(
    fontSize: 40,
    fontWeight: FontWeight.w400,
    color: JewelVaultColors.primaryText,
    height: 1.2,
    letterSpacing: -0.01,
  );

  static TextStyle headingLarge = GoogleFonts.fraunces(
    fontSize: 28,
    fontWeight: FontWeight.w500,
    color: JewelVaultColors.primaryText,
    height: 1.4,
  );

  static TextStyle headingMedium = GoogleFonts.fraunces(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    color: JewelVaultColors.primaryText,
  );

  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w300,
    color: JewelVaultColors.secondaryText,
    height: 1.6,
  );

  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: JewelVaultColors.secondaryText,
    height: 1.6,
  );
  
  static TextStyle labelLarge = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JewelVaultColors.background,
      body: Stack(
        children: [
          // Background ambient blurs
          Positioned(
            top: -200,
            right: -100,
            child: Container(
              width: 800,
              height: 800,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: JewelVaultColors.primaryEmerald.withOpacity(0.04),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            top: 600,
            left: -200,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: JewelVaultColors.primaryEmerald.withOpacity(0.03),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          // Main Scroll Content
          const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NavBar(),
                _HeroSection(),
                _FeaturesSection(),
                _HowItWorksSection(),
                _TestimonialSection(),
                _FinalCTASection(),
                _FooterSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar();

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 24,
        vertical: 32,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: JewelVaultColors.primaryEmerald,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.diamond_outlined, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Text(
                'JewelVault',
                style: JewelVaultTypography.headingLarge.copyWith(fontSize: 24, letterSpacing: -0.5),
              ),
            ],
          ),
          if (isDesktop)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white),
              ),
              child: Row(
                children: [
                  _NavTextButton(text: 'Features'),
                  const SizedBox(width: 24),
                  _NavTextButton(text: 'How It Works'),
                  const SizedBox(width: 24),
                  _NavTextButton(text: 'Login'),
                ],
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.menu, color: JewelVaultColors.primaryText),
              onPressed: () {},
            ),
          if (isDesktop)
            const _PrimaryButton(text: 'Get Started'),
        ],
      ),
    );
  }
}

class _NavTextButton extends StatelessWidget {
  final String text;

  const _NavTextButton({required this.text});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {},
      style: TextButton.styleFrom(
        foregroundColor: JewelVaultColors.primaryText,
        textStyle: JewelVaultTypography.labelLarge,
      ),
      child: Text(text),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isDark;

  const _PrimaryButton({required this.text, this.onPressed, this.isDark = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: JewelVaultColors.primaryEmerald.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed ?? () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? JewelVaultColors.primaryEmerald : Colors.white,
          foregroundColor: isDark ? Colors.white : JewelVaultColors.primaryEmerald,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: JewelVaultTypography.labelLarge,
        ),
        child: Text(text),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final isDesktop = width > 1000;
    
    final textContent = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: JewelVaultColors.primaryEmerald.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(32),
              color: Colors.white.withOpacity(0.5),
            ),
            child: Text(
              'Introducing AI Styling',
              style: JewelVaultTypography.labelLarge.copyWith(color: JewelVaultColors.primaryEmerald),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Your Curated Collection,\nPerfectly Matched.',
            style: isDesktop ? JewelVaultTypography.displayMassive : JewelVaultTypography.displayMedium,
          ),
          const SizedBox(height: 32),
          Text(
            'The ultimate digital vault for your wardrobe and jewelry. AI-powered styling that understands your unique aesthetic and unlocks endless combinations.',
            style: JewelVaultTypography.bodyLarge,
          ),
          const SizedBox(height: 56),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              const _PrimaryButton(text: 'Begin Your Collection'),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: JewelVaultColors.primaryText,
                  side: const BorderSide(color: JewelVaultColors.border, width: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: JewelVaultTypography.labelLarge,
                ),
                child: const Text('Watch Demo'),
              ),
            ],
          ),
        ],
      ),
    );

    final imageContent = Container(
      height: isDesktop ? height * 0.8 : 500,
      constraints: const BoxConstraints(maxHeight: 800, minHeight: 400),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base Dress Card
          Positioned(
            right: isDesktop ? 60 : 20,
            bottom: isDesktop ? 80 : 40,
            child: Container(
              width: isDesktop ? 360 : 280,
              height: isDesktop ? 480 : 380,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: JewelVaultColors.background,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Center(
                        child: Icon(Icons.checkroom_outlined, size: 64, color: JewelVaultColors.border),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Silk Slip Dress', style: JewelVaultTypography.headingMedium),
                        const SizedBox(height: 4),
                        Text('Evening Wear', style: JewelVaultTypography.bodyMedium),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          
          // Floating Jewelry Card
          Positioned(
            left: isDesktop ? 0 : 10,
            top: isDesktop ? 60 : 20,
            child: Container(
              width: isDesktop ? 280 : 220,
              height: isDesktop ? 320 : 260,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: JewelVaultColors.primaryEmerald.withOpacity(0.08),
                    blurRadius: 30,
                    offset: const Offset(-10, 15),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: JewelVaultColors.background.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Icon(Icons.diamond_outlined, size: 48, color: JewelVaultColors.primaryEmerald),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Emerald Pendant', style: JewelVaultTypography.bodyLarge.copyWith(color: JewelVaultColors.primaryText, fontWeight: FontWeight.w500)),
                            Text('Perfect Match', style: JewelVaultTypography.bodyMedium.copyWith(color: JewelVaultColors.primaryEmerald)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),

          // AI Match Score Badge
          Positioned(
            right: isDesktop ? 20 : 0,
            top: isDesktop ? 160 : 100,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: JewelVaultColors.primaryEmerald,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: JewelVaultColors.primaryEmerald.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('98% Match', style: JewelVaultTypography.labelLarge.copyWith(color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 24,
      ),
      constraints: BoxConstraints(minHeight: isDesktop ? height * 0.85 : 800),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 5, child: textContent),
                const SizedBox(width: 60),
                Expanded(flex: 6, child: imageContent),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                textContent,
                const SizedBox(height: 60),
                imageContent,
              ],
            ),
    );
  }
}

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1000;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 24,
        vertical: isDesktop ? 160 : 100,
      ),
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Text(
                  'The Art of Curation',
                  style: isDesktop ? JewelVaultTypography.displayLarge : JewelVaultTypography.displayMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  'Discover how JewelVault transforms your closet into a boutique experience with intelligent tools designed for the modern collector.',
                  style: JewelVaultTypography.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: _FeatureCard(
                    icon: Icons.inventory_2_outlined,
                    title: 'Digital Vault',
                    description: 'Digitize your entire collection with high-fidelity cataloging. Keep immaculate records of every piece you own.',
                  ),
                ),
                const SizedBox(width: 40),
                const Expanded(
                  child: _FeatureCard(
                    icon: Icons.auto_awesome_outlined,
                    title: 'AI Match Engine',
                    description: 'Our proprietary intelligence pairs your jewelry with your garments, unlocking unseen aesthetic combinations.',
                  ),
                ),
                const SizedBox(width: 40),
                const Expanded(
                  child: _FeatureCard(
                    icon: Icons.view_carousel_outlined,
                    title: 'Lookbook Canvas',
                    description: 'Plan your outfits visually. Drag, drop, and design your daily looks on an elegant, infinite digital canvas.',
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FeatureCard(
                  icon: Icons.inventory_2_outlined,
                  title: 'Digital Vault',
                  description: 'Digitize your entire collection with high-fidelity cataloging. Keep immaculate records of every piece you own.',
                ),
                const SizedBox(height: 32),
                const _FeatureCard(
                  icon: Icons.auto_awesome_outlined,
                  title: 'AI Match Engine',
                  description: 'Our proprietary intelligence pairs your jewelry with your garments, unlocking unseen aesthetic combinations.',
                ),
                const SizedBox(height: 32),
                const _FeatureCard(
                  icon: Icons.view_carousel_outlined,
                  title: 'Lookbook Canvas',
                  description: 'Plan your outfits visually. Drag, drop, and design your daily looks on an elegant, infinite digital canvas.',
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(48),
        transform: Matrix4.translationValues(0, _isHovered ? -10 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: _isHovered ? JewelVaultColors.primaryEmerald.withOpacity(0.2) : Colors.white,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered 
                  ? JewelVaultColors.primaryEmerald.withOpacity(0.08)
                  : Colors.black.withOpacity(0.03),
              blurRadius: _isHovered ? 40 : 20,
              offset: Offset(0, _isHovered ? 20 : 10),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isHovered 
                      ? [JewelVaultColors.primaryEmerald, JewelVaultColors.darkEmerald]
                      : [JewelVaultColors.background, JewelVaultColors.background],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                widget.icon,
                color: _isHovered ? Colors.white : JewelVaultColors.primaryEmerald,
                size: 40,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              widget.title,
              style: JewelVaultTypography.headingLarge,
            ),
            const SizedBox(height: 20),
            Text(
              widget.description,
              style: JewelVaultTypography.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1000;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 24,
        vertical: isDesktop ? 160 : 100,
      ),
      child: Column(
        children: [
          Text(
            'The Process',
            style: isDesktop ? JewelVaultTypography.displayLarge : JewelVaultTypography.displayMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 100),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: _TimelineStep(
                    step: '01',
                    title: 'Upload Collection',
                    description: 'Snap photos or sync from your favorite boutiques. We automatically isolate items for a clean catalog look.',
                  ),
                ),
                const SizedBox(width: 80),
                const Expanded(
                  child: _TimelineStep(
                    step: '02',
                    title: 'AI Understands',
                    description: 'Our engine analyzes color palettes, textures, and silhouettes to build your personalized style profile.',
                  ),
                ),
                const SizedBox(width: 80),
                const Expanded(
                  child: _TimelineStep(
                    step: '03',
                    title: 'Perfect Matches',
                    description: 'Get daily curation. See which necklace perfectly complements your new dress before you even put it on.',
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _TimelineStep(
                  step: '01',
                  title: 'Upload Collection',
                  description: 'Snap photos or sync from your favorite boutiques. We automatically isolate items for a clean catalog look.',
                ),
                const SizedBox(height: 48),
                const _TimelineStep(
                  step: '02',
                  title: 'AI Understands',
                  description: 'Our engine analyzes color palettes, textures, and silhouettes to build your personalized style profile.',
                ),
                const SizedBox(height: 48),
                const _TimelineStep(
                  step: '03',
                  title: 'Perfect Matches',
                  description: 'Get daily curation. See which necklace perfectly complements your new dress before you even put it on.',
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String step;
  final String title;
  final String description;

  const _TimelineStep({
    required this.step,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          step,
          style: GoogleFonts.inter(
            fontSize: 64,
            fontWeight: FontWeight.w200,
            color: JewelVaultColors.border,
            height: 1,
          ),
        ),
        const SizedBox(height: 32),
        Container(
          height: 2,
          width: 80,
          color: JewelVaultColors.primaryEmerald,
        ),
        const SizedBox(height: 32),
        Text(
          title,
          style: JewelVaultTypography.headingLarge,
        ),
        const SizedBox(height: 16),
        Text(
          description,
          style: JewelVaultTypography.bodyLarge,
        ),
      ],
    );
  }
}

class _TestimonialSection extends StatelessWidget {
  const _TestimonialSection();

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Container(
      color: JewelVaultColors.darkEmerald,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 24,
        vertical: isDesktop ? 160 : 100,
      ),
      child: Column(
        children: [
          Text(
            'Curated Feedback',
            style: isDesktop 
                ? JewelVaultTypography.displayLarge.copyWith(color: Colors.white) 
                : JewelVaultTypography.displayMedium.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 80),
          Wrap(
            spacing: 32,
            runSpacing: 32,
            alignment: WrapAlignment.center,
            children: const [
              _MockReviewCard(),
              _MockReviewCard(),
              _MockReviewCard(),
            ],
          ),
        ],
      ),
    );
  }
}

class _MockReviewCard extends StatelessWidget {
  const _MockReviewCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              5, 
              (index) => const Icon(Icons.star, color: JewelVaultColors.border, size: 16)
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '"Mock Review"',
            style: JewelVaultTypography.headingMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            'This is a placeholder for a future review from a client or critic.',
            style: JewelVaultTypography.bodyMedium.copyWith(color: Colors.white.withOpacity(0.6)),
          ),
          const SizedBox(height: 48),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100, 
                    height: 12, 
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    )
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 60, 
                    height: 10, 
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    )
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinalCTASection extends StatelessWidget {
  const _FinalCTASection();

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Container(
      color: JewelVaultColors.whiteCard,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 24,
        vertical: isDesktop ? 160 : 100,
      ),
      child: Container(
        padding: EdgeInsets.all(isDesktop ? 100 : 40),
        decoration: BoxDecoration(
          color: JewelVaultColors.background,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: JewelVaultColors.border.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Text(
              'Ready to elevate your collection?',
              style: isDesktop ? JewelVaultTypography.displayLarge : JewelVaultTypography.displayMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            const _PrimaryButton(text: 'Create Your Vault Today'),
          ],
        ),
      ),
    );
  }
}

class _FooterSection extends StatelessWidget {
  const _FooterSection();

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    
    return Container(
      color: JewelVaultColors.whiteCard,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 24,
        vertical: 64,
      ),
      child: Column(
        children: [
          Container(
            height: 1,
            color: JewelVaultColors.border,
            margin: const EdgeInsets.only(bottom: 64),
          ),
          Flex(
            direction: isDesktop ? Axis.horizontal : Axis.vertical,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: isDesktop ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.diamond_outlined, color: JewelVaultColors.primaryEmerald, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'JewelVault',
                    style: JewelVaultTypography.headingMedium,
                  ),
                ],
              ),
              if (!isDesktop) const SizedBox(height: 48),
              Row(
                mainAxisAlignment: isDesktop ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  _FooterLink(text: 'The Closet'),
                  const SizedBox(width: 40),
                  _FooterLink(text: 'AI Matching'),
                  const SizedBox(width: 40),
                  _FooterLink(text: 'Privacy'),
                ],
              ),
              if (!isDesktop) const SizedBox(height: 48),
              Text(
                '© ${DateTime.now().year} JewelVault. All rights reserved.',
                style: JewelVaultTypography.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String text;

  const _FooterLink({required this.text});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Text(
        text,
        style: JewelVaultTypography.bodyMedium.copyWith(
          color: JewelVaultColors.primaryText,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
