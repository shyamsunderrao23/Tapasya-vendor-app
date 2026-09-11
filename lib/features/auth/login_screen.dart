import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/features/auth/registration/registration_state.dart';

import 'package:tapasya_vendor_app/services/auth_service.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  void initState() {
    super.initState();
    debugPrint("📱 [AUTH] Entered Login Screen");
  }

  final TextEditingController _phoneController = TextEditingController();
  bool _isButtonEnabled = false;
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  void _onPhoneChanged(String value) {
    setState(() {
      _isButtonEnabled = value.length == 10;
    });
  }

  void _sendOTP() async {
    setState(() => _isLoading = true);
    debugPrint("🚀 [LOGIN] Sending OTP to: ${_phoneController.text.trim()}");
    
    await _authService.sendOtp(
      phoneNumber: _phoneController.text.trim(),
      onCodeSent: (verificationId) {
        setState(() => _isLoading = false);
        context.push('/otp', extra: {
          'phone': _phoneController.text.trim(),
          'verificationId': verificationId,
        });
      },
      onError: (error) {
        setState(() => _isLoading = false);
        AppToast.show(context, error, isError: true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // 1. Profile-style Premium Header
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
                      // Bubble Pattern
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(60),
                            bottomRight: Radius.circular(60),
                          ),
                          child: CustomPaint(painter: _LoginBubblePainter()),
                        ),
                      ),
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Back Button
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
                              const SizedBox(height: 40),
                              Text(
                                "Welcome Back",
                                style: AppTheme.headingStyle.copyWith(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Login to continue",
                                style: AppTheme.bodyStyle.copyWith(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Enter your registered mobile number to get OTP",
                                style: AppTheme.bodyStyle.copyWith(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
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
                
                // 2. Form Section below the swoop
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      
                      // Input Field (Floating Label Outlined)
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        onChanged: _onPhoneChanged,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: AppTheme.bodyStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1.5),
                        decoration: InputDecoration(
                          labelText: "Mobile Number",
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          labelStyle: AppTheme.bodyStyle.copyWith(color: Colors.grey.shade600, fontWeight: FontWeight.w500, letterSpacing: 0),
                          hintText: "Enter 10 digit number",
                          hintStyle: AppTheme.bodyStyle.copyWith(color: Colors.grey.shade400, fontSize: 16, letterSpacing: 0),
                          counterText: "",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("🇮🇳 +91", style: AppTheme.bodyStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w400)),
                                const SizedBox(width: 12),
                                Container(width: 1, height: 24, color: Colors.grey.shade300),
                                const SizedBox(width: 12),
                              ],
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        ),
                      ),
                      const SizedBox(height: 48),
                      
                      // Send OTP Button (Solid Pill)
                      GestureDetector(
                        onTap: _isButtonEnabled ? _sendOTP : null,
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: _isButtonEnabled ? AppTheme.primaryGradient : null,
                            color: _isButtonEnabled ? null : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [],
                          ),
                          child: Center(
                            child: _isLoading 
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(
                                  "Send OTP",
                                  style: AppTheme.buttonTextStyle.copyWith(
                                    color: _isButtonEnabled ? Colors.white : Colors.grey.shade500,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      // Register Link
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            final nextPath = context.read<RegistrationState>().getNextStepPath();
                            context.push(nextPath);
                          },
                          child: RichText(
                            text: TextSpan(
                              text: "Don't have an account? ",
                              style: AppTheme.bodyStyle.copyWith(color: Colors.grey.shade700, fontSize: 16),
                              children: [
                                TextSpan(
                                  text: "Register",
                                  style: AppTheme.bodyStyle.copyWith(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
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

class _LoginBubblePainter extends CustomPainter {
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
