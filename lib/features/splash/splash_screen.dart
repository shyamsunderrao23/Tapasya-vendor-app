import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:tapasya_vendor_app/features/auth/registration/registration_state.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tapasya_vendor_app/firebase_options.dart';
import 'package:tapasya_vendor_app/main.dart'; // To access initFCM
import 'package:tapasya_vendor_app/features/home/vendor_provider.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
    _checkAuth();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    try {
      // 1. Load Registration State
      final registrationState = context.read<RegistrationState>();
      
      // 🔥 FOR TESTING ONLY: RESTART APP FROM BEGINNING
      // If you want to stop the auto-reset, just comment out the line below.
      // debugPrint("🧹 [SPLASH] Triggering Fresh Start (TEMP)...");
      // await registrationState.clearAllData(); 
      // debugPrint("✅ [SPLASH] App State Resetted Successfully.");
      
      // 2. Core Bootstrapping (Non-blocking for UI)
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 3. Load from local to resume progress
      await registrationState.loadFromLocal();
      
      // 3. Init Background Services (Notifications moved to HomeScreen)
      // unawaited(initFCM()); 

      // 4. Subtle delay for animation beauty
      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        final token = registrationState.authToken;
        final hasSeenOnboarding = registrationState.hasSeenOnboarding;
        final hasCompletedRegistration = registrationState.hasCompletedRegistration;
        
        debugPrint("🚀 APP BOOT STATUS:");
        debugPrint("   - TOKEN: ${token.isNotEmpty}");
        debugPrint("   - ONBOARDING: $hasSeenOnboarding");
        debugPrint("   - COMPLETE FLAG: $hasCompletedRegistration");
        debugPrint("   - PAN: ${registrationState.panStatus}, AADHAR: ${registrationState.aadharStatus}, BANK: ${registrationState.bankStatus}");

        if (!hasSeenOnboarding) {
          debugPrint("➡️ [SPLASH] New User -> Onboarding");
          context.go('/onboarding');
        } else if (token.isNotEmpty) {
          // 🔄 Always try to sync if we have a token to restore latest progress
          debugPrint("🔄 [SPLASH] Token found -> Synchronizing all states...");
          await registrationState.syncWithBackend();
          
          // 🔥 ZERO-FLICKER BOOT: Sync the main vendor provider BEFORE navigating home
          if (mounted) {
            await context.read<VendorProvider>().atomicBootSync(token);
          }
          
          final nextPath = registrationState.getNextStepPath();
          debugPrint("➡️ [SPLASH] Routing to: $nextPath");
          
          if (mounted) {
            context.go(nextPath == '/home' ? '/home' : nextPath);
          }
        } else {
          // 🔥 USER REQUIREMENT: Show only the login screen if onboarding seen but no session
          debugPrint("➡️ [SPLASH] No Session -> Login Screen");
          context.go('/login');
        }
      }
    } catch (e) {
      debugPrint("❌ BOOT ERROR: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final registrationState = context.read<RegistrationState>();
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onLongPress: () async {
                  await registrationState.clearAll();
                  if (mounted) {
                    AppToast.show(context, "🧹 App Data Cleared! Restarting...");
                    context.go('/');
                  }
                },
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Image.asset(
                    'assets/images/tapasya_logo.png',
                    width: 150,
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              FadeTransition(
                opacity: _opacityAnimation,
                child: Column(
                  children: [
                    // Removed "Vendor App" text as the logo likely contains branding
                     Text(
                      "Grow Your Service Business",
                      style: AppTheme.subHeadingStyle.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              SizedBox(
                width: 150,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white.withOpacity(0.3),
                  color: Colors.white,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
