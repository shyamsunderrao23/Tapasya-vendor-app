import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/features/auth/registration/registration_state.dart';
import 'package:tapasya_vendor_app/features/auth/widgets/terms_popup.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _slides = [
    {
      "heading": "Offer Your\nExpertise 🛠️",
      "label": "Become a skilled vendor and provide top-notch services to homeowners.",
      "image": "assets/images/onboarding_expertise.png",
    },
    {
      "heading": "Find Local\nJobs Quickly 📍",
      "label": "Get instant notifications about new job requests in your area near you.",
      "image": "assets/images/onboarding_jobs.png",
    },
    {
      "heading": "Grow Your\nEarnings 💰",
      "label": "Track your progress and multiply your income with our transparent system.",
      "image": "assets/images/onboarding_earnings.png",
    },
    {
      "heading": "Secure and\nFast Payments 💳",
      "label": "Get paid instantly via UPI and bank transfer — safe, transparent, and directly to your account after every job.",
      "image": "assets/images/onboarding_payments.png",
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _skipOnboarding() {
    _pageController.animateToPage(
      _slides.length - 1,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  void _goToLogin() {
    if (mounted) {
      context.read<RegistrationState>().setHasSeenOnboarding(true);
      context.push('/login');
    }
  }

  void _goToRegister() {
    if (mounted) {
      final state = context.read<RegistrationState>();
      state.setHasSeenOnboarding(true);
      final nextPath = state.getNextStepPath();
      context.push(nextPath);
    }
  }

  double halfGradient(double height) {
    return 0.6;
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Sliding Image Area (Centered in top portion)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: height * 0.65, // Dedicated space for image
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _slides.length,
              itemBuilder: (context, index) {
                return SizedBox(
                  width: double.infinity,
                  height: height * 0.65,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        _slides[index]['image']!,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/images/tapasya_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      // Soft fade into black bottom section
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.35),
                              Colors.black.withOpacity(0.85),
                            ],
                            stops: const [0.45, 0.75, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 2. Black Gradient Overlay to blend the image down seamlessly
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: height * halfGradient(height), // Cover about 60% with gradient
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.6),
                      Colors.black.withOpacity(0.9),
                      Colors.black,
                    ],
                    stops: const [0.0, 0.4, 0.7, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 3. Static Bottom Elements (Indicators -> AnimatedText -> Buttons)
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Indicators (Carousel dots on top of title)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 6,
                      width: _currentPage == index ? 24 : 6,
                      decoration: BoxDecoration(
                        color: _currentPage == index ? AppTheme.primaryColor : Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 24), // Reduced extra space

                // Animated Text Content
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    key: ValueKey<int>(_currentPage),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _slides[_currentPage]['heading']!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          _slides[_currentPage]['label']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.7),
                            height: 1.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32), // Tighter spacing before buttons

                // Action Buttons
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _currentPage == _slides.length - 1
                      ? Column(
                          key: const ValueKey('last_screen_buttons'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Create An Account
                            GestureDetector(
                              onTap: _goToRegister,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B47FF), // Bright purple
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: const Center(
                                  child: Text(
                                    "Create An Account",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Log In
                            GestureDetector(
                              onTap: _goToLogin,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                decoration: BoxDecoration(
                                    color: const Color(0xFF8B47FF),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: const Center(
                                  child: Text(
                                    "Log in",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : // Navigation Controls Row matching reference 1
                        Row(
                          key: const ValueKey('nav_buttons'),
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Left Side: Back & Next
                            Row(
                              children: [
                                // Back Button
                                GestureDetector(
                                  onTap: _currentPage > 0
                                      ? () {
                                          _pageController.previousPage(
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.ease,
                                          );
                                        }
                                      : null,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: _currentPage > 0 
                                          ? const Color(0xFF8B47FF) 
                                          : const Color(0xFF8B47FF).withOpacity(0.3), // Purple
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.arrow_back, 
                                      color: _currentPage > 0 ? Colors.white : Colors.white54,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Next Button
                                GestureDetector(
                                  onTap: () {
                                    _pageController.nextPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.ease,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF8B47FF), // Purple
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.arrow_forward, color: Colors.white, size: 24),
                                  ),
                                ),
                              ],
                            ),
                            
                            // Right Side: Skip text / pill
                            GestureDetector(
                              onTap: _skipOnboarding,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: const Text(
                                  "SKIP",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
