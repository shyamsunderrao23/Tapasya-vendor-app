import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/features/auth/widgets/premium_scale_button.dart';
import 'package:tapasya_vendor_app/services/auth_service.dart';
import 'package:tapasya_vendor_app/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:tapasya_vendor_app/features/auth/registration/registration_state.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const OtpScreen({
    super.key, 
    required this.phoneNumber,
    required this.verificationId,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _otpController = TextEditingController();
  int _secondsRemaining = 30;
  Timer? _timer;
  bool _canResend = false;
  bool _isLoading = false;
  final AuthService _authService = AuthService();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    debugPrint("📱 [AUTH] Entered general OTP Screen for: ${widget.phoneNumber}");
    _startTimer();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 30;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        setState(() => _canResend = true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp(String pin) async {
    if (pin.length == 6) {
      if (mounted) setState(() => _isLoading = true);
      debugPrint("🚀 [OTP] Verifying general OTP code: $pin");
      
      final userCredential = await _authService.verifyOtp(
        verificationId: widget.verificationId,
        otp: pin,
      );

      setState(() => _isLoading = false);

      if (userCredential != null) {
        if (!mounted) return;
        showGeneralDialog(
          context: context,
          barrierDismissible: false,
          barrierLabel: "Success",
          barrierColor: Colors.black.withOpacity(0.45),
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, __, ___) => const SizedBox.shrink(),
          transitionBuilder: (_, animation, __, ___) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            );
            return Opacity(
              opacity: animation.value.clamp(0.0, 1.0),
              child: Center(
                child: ScaleTransition(
                  scale: curved,
                  child: _buildVerifiedPopup(),
                ),
              ),
            );
          },
        );

        setState(() => _isLoading = true);
        final idToken = await userCredential.user?.getIdToken() ?? '';
        final vendorResponse = await ApiService().loginVendor(idToken);
        setState(() => _isLoading = false);

        debugPrint("📥 [LOGIN] API Response: $vendorResponse");

        if (vendorResponse != null) {
          final data = vendorResponse['data'] ?? {};
          final bool isSuccess = vendorResponse['success'] == true;
          final String finalToken = (vendorResponse['token'] ?? data['token'] ?? '') as String;
          
          if (context.mounted) {
            final registrationState = context.read<RegistrationState>();
            
            // 🔐 1. Save core session data if available
            registrationState.updatePhone(widget.phoneNumber);
            if (finalToken.isNotEmpty) {
              await registrationState.updateRegistrationToken(finalToken);
              await registrationState.syncWithBackend();
            }
            
            // 🔥 2. Sync full profile from backend data if available
            if (data.isNotEmpty) {
              registrationState.updateFromBackend(vendorResponse);
              
              final backendVendor = data['vendor'] ?? data;
              final vendorId = backendVendor['id'] ??
                               backendVendor['_id'] ??
                               vendorResponse['vendor']?['id'] ??
                               data['vendor']?['id'];
              if (vendorId != null) registrationState.updateVendorId(vendorId.toString());
            }

            // 🛣️ 3. Navigate — HomeScreen auto-reloads its data on arrival.
            final String nextPath = registrationState.getNextStepPath();
            debugPrint("➡️ [LOGIN REDIRECT] Path: $nextPath");

            await Future.delayed(const Duration(milliseconds: 800));
            if (context.mounted) {
              Navigator.of(context, rootNavigator: true).pop(); // close verified dialog
            }

            if (context.mounted) {
              context.go(nextPath == '/home' ? '/home' : nextPath);
            }
          }
        }
      } else {
        if (!mounted) return;
        AppToast.show(context, "Invalid OTP. Please try again.", isError: true);
      }
    }
  }

  /// Success popup shown after a vendor logs in successfully.
  Widget _buildVerifiedPopup() {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 48),
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated green checkmark (rendered on white to blend with the card)
            Image.asset(
              'assets/animations/check_success.gif',
              width: 120,
              height: 120,
              gaplessPlayback: true,
            ),
            const SizedBox(height: 14),
            Text(
              "Verified!",
              style: AppTheme.headingStyle.copyWith(
                fontSize: 23,
                decoration: TextDecoration.none,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1B1B1F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Login successful. Welcome back to Tapasya",
              textAlign: TextAlign.center,
              style: AppTheme.bodyStyle.copyWith(
                color: AppTheme.greyColor,
                decoration: TextDecoration.none,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Premium pin box themes
    final defaultPinTheme = PinTheme(
      width: 52,
      height: 60,
      textStyle: AppTheme.headingStyle.copyWith(fontSize: 24, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.transparent, width: 1.5),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: Colors.white,
        border: Border.all(color: AppTheme.primaryColor, width: 2),
        boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.15), blurRadius: 15, spreadRadius: 2)],
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: AppTheme.primaryColor.withOpacity(0.05),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 1.5),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // Premium Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: 40),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(60),
                      bottomRight: Radius.circular(60),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(60),
                            bottomRight: Radius.circular(60),
                          ),
                          child: CustomPaint(painter: _OtpBubblePainter()),
                        ),
                      ),
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => context.pop(),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                                ),
                              ),
                              const SizedBox(height: 32),
                              ScaleTransition(
                                scale: _pulseAnimation,
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.shield_rounded, color: Colors.white, size: 36),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                "Verify your\nnumber",
                                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.2),
                              ),
                              const SizedBox(height: 10),
                              RichText(
                                text: TextSpan(
                                  text: "Code sent to  ",
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.w400),
                                  children: [
                                    TextSpan(
                                      text: "+91 ${widget.phoneNumber}",
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.4),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 36),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    children: [
                      // Trust Indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline, color: AppTheme.primaryColor.withOpacity(0.8), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            "Secure Verification",
                            style: AppTheme.bodyStyle.copyWith(
                              color: AppTheme.blackColor.withOpacity(0.6),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      const Text(
                        "Enter 6-digit OTP",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 28),

                      // Premium Pinput
                      Pinput(
                        controller: _otpController,
                        length: 6,
                        defaultPinTheme: defaultPinTheme,
                        focusedPinTheme: focusedPinTheme,
                        submittedPinTheme: submittedPinTheme,
                        onCompleted: _verifyOtp,
                        autofocus: true,
                        separatorBuilder: (index) => const SizedBox(width: 8),
                        showCursor: true,
                        cursor: Container(
                          width: 2,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Timer / Resend
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _canResend
                            ? GestureDetector(
                                key: const ValueKey('resend'),
                                onTap: _startTimer,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Text(
                                    "Resend OTP",
                                    style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700, fontSize: 15),
                                  ),
                                ),
                              )
                            : Container(
                                key: const ValueKey('timer'),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5FA),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.timer_outlined, size: 16, color: Colors.grey.shade500),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Resend in  00:${_secondsRemaining.toString().padLeft(2, '0')}",
                                      style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                      ),

                      const SizedBox(height: 56),

                      // Verify Button
                      PremiumScaleButton(
                        onTap: _otpController.text.length == 6 ? () => _verifyOtp(_otpController.text) : null,
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: _otpController.text.length == 6 ? AppTheme.primaryGradient : null,
                            color: _otpController.text.length == 6 ? null : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: _otpController.text.length == 6 
                              ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5))]
                              : [],
                          ),
                          child: Center(
                            child: _isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text(
                                  "Verify & Login",
                                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                                ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      Text(
                        "By verifying, you agree to our Terms & Privacy Policy",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w400),
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

class _OtpBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.05)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.15), 45, paint);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.1), 70, paint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.8), 85, paint);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.85), 55, paint);
    canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.5), 35, paint);
    final strokePaint = Paint()..color = Colors.white.withOpacity(0.04)..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.6), 95, strokePaint);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.35), 75, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
