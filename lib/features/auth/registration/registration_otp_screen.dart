import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/features/auth/registration/registration_state.dart';
import 'package:tapasya_vendor_app/features/auth/widgets/premium_scale_button.dart';
import 'package:tapasya_vendor_app/services/auth_service.dart';
import 'package:tapasya_vendor_app/services/api_service.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';

class RegistrationOtpScreen extends StatefulWidget {
  final String verificationId;
  const RegistrationOtpScreen({super.key, required this.verificationId});

  @override
  State<RegistrationOtpScreen> createState() => _RegistrationOtpScreenState();
}

class _RegistrationOtpScreenState extends State<RegistrationOtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  int _secondsRemaining = 30;
  Timer? _timer;
  bool _canResend = false;
  bool _isLoading = false;
  late String _currentVerificationId;
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    debugPrint("📱 [REGISTRATION] Entered OTP Verification Screen");
    _currentVerificationId = widget.verificationId;
    _startTimer();
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 30;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
        setState(() {
          _canResend = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp(String pin) async {
    if (pin.length == 6) {
      if (mounted) setState(() => _isLoading = true);
      debugPrint("🚀 [OTP] Verifying code: $pin");
      
      try {
        final userCredential = await _authService.verifyOtp(
          verificationId: _currentVerificationId,
          otp: pin,
        );

        if (userCredential != null) {
          debugPrint("✅ [OTP] Firebase Verification Successful!");
          final state = context.read<RegistrationState>();
          final idToken = await userCredential.user?.getIdToken() ?? "";
          
          await state.updateRegistrationToken(idToken);

          debugPrint("🔥 [OTP] Exchanging Firebase Token for Backend JWT...");
          final loginResponse = await _apiService.loginVendor(idToken);
          debugPrint("📥 [REG_OTP] Login Response: $loginResponse");

          if (mounted) setState(() => _isLoading = false);

          if (loginResponse != null) {
            final data = loginResponse['data'] ?? {};
            final String jwtToken = (loginResponse['token'] ?? data['token'] ?? '') as String;
            
            if (jwtToken.isNotEmpty) {
              debugPrint("✅ [REG_OTP] Backend JWT RECEIVED: $jwtToken");
              // 🔐 Save core session data immediately
              state.updatePhone(state.phoneNumber); 
              await state.updateRegistrationToken(jwtToken);
              debugPrint("🔄 [REG_OTP] Initiating state sync with backend...");
              await state.syncWithBackend();
              debugPrint("✅ [REG_OTP] Sync complete.");
            } else {
              debugPrint("⚠️ [REG_OTP] Login successful but no JWT token found in response.");
            }

            if (data.isNotEmpty) {
              final String vId = data['vendor_id']?.toString() ?? 
                                 data['id']?.toString() ?? '';
              if (vId.isNotEmpty) {
                debugPrint("✅ [OTP] VENDOR ID RECEIVED: $vId");
                state.updateVendorId(vId);
              }

              debugPrint("🔄 [OTP] Syncing Profile from Backend...");
              state.updateFromBackend(data);
            }

            final String nextPath = state.getNextStepPath();
            debugPrint("➡️ [OTP] Navigation Decision: $nextPath");

            // HomeScreen auto-reloads its data on arrival — just navigate.
            if (mounted) {
              if (nextPath == '/home' || nextPath == '/dashboard') {
                context.go('/home');
              } else {
                context.replace(nextPath);
              }
            }
          } else {
            debugPrint("❌ [OTP] No response from backend.");
            if (mounted) context.replace('/register/step1');
          }
        } else {
          debugPrint("❌ [OTP] Firebase verification came back null");
          if (mounted) {
            setState(() => _isLoading = false);
            AppToast.show(context, "Invalid OTP. Please try again.", isError: true);
          }
        }
      } catch (e) {
        debugPrint("❌ [OTP EXCEPTION] $e");
        if (mounted) {
          setState(() => _isLoading = false);
          AppToast.show(context, "Verification error: $e", isError: true);
        }
      }
    }
  }

  Future<void> _resendOtp() async {
    final phoneNumber = context.read<RegistrationState>().phoneNumber;
    setState(() => _isLoading = true);
    
    await _authService.sendOtp(
      phoneNumber: phoneNumber,
      onCodeSent: (newVerificationId) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _currentVerificationId = newVerificationId;
          _otpController.clear();
          _startTimer();
        });
        if (mounted) {
          debugPrint("🔄 [OTP] OTP Resent successfully. New VerificationID: $newVerificationId");
          AppToast.show(context, "OTP Resent Successfully");
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        AppToast.show(context, error, isError: true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final phoneNumber = context.watch<RegistrationState>().phoneNumber;

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
                          child: CustomPaint(painter: _RegistrationOtpBubblePainter()),
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
                              const SizedBox(height: 24),
                              
                              // Minimal Stepper Progress Feel
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
                                    const SizedBox(width: 8),
                                    Text(
                                      "STEP 1 OF 5",
                                      style: AppTheme.bodyStyle.copyWith(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              Text(
                                "Verification",
                                style: AppTheme.headingStyle.copyWith(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Enter the code sent to your mobile",
                                style: AppTheme.bodyStyle.copyWith(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 18,
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
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Trust Indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.security_outlined, color: AppTheme.primaryColor.withOpacity(0.8), size: 18),
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
                      const SizedBox(height: 24),

                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          text: "A 6-digit code has been sent to\n",
                          style: AppTheme.bodyStyle.copyWith(color: AppTheme.greyColor, fontWeight: FontWeight.normal, height: 1.5),
                          children: [
                            TextSpan(
                              text: "+91 $phoneNumber",
                              style: AppTheme.subHeadingStyle.copyWith(color: AppTheme.blackColor, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Premium Pinput
                      Pinput(
                        controller: _otpController,
                        length: 6,
                        defaultPinTheme: defaultPinTheme,
                        focusedPinTheme: focusedPinTheme,
                        submittedPinTheme: submittedPinTheme,
                        separatorBuilder: (index) => const SizedBox(width: 8),
                        onCompleted: _verifyOtp,
                        autofocus: true,
                        pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
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
                                onTap: _isLoading ? null : _resendOtp,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Text(
                                    "Resend Code",
                                    style: AppTheme.bodyStyle.copyWith(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.timer_outlined, size: 18, color: Colors.grey.shade400),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Resend in 00:${_secondsRemaining.toString().padLeft(2, '0')}",
                                    style: AppTheme.bodyStyle.copyWith(color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                      ),
                      
                      const SizedBox(height: 48),
                       
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
                              ? const SizedBox(
                                  height: 20, 
                                  width: 20, 
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                )
                              : Text(
                                  "Verify",
                                  style: AppTheme.buttonTextStyle.copyWith(
                                    color: _otpController.text.length == 6 ? Colors.white : Colors.grey.shade500,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
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

class _RegistrationOtpBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.05)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.2), 40, paint);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.1), 65, paint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.75), 80, paint);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.85), 50, paint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.45), 30, paint);
    final strokePaint = Paint()..color = Colors.white.withOpacity(0.04)..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.55), 90, strokePaint);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.3), 70, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
