import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/features/auth/registration/registration_state.dart';
import 'package:tapasya_vendor_app/features/auth/widgets/custom_text_field.dart';
import 'package:tapasya_vendor_app/features/auth/widgets/premium_scale_button.dart';
import 'package:tapasya_vendor_app/features/auth/widgets/terms_popup.dart';
import 'package:tapasya_vendor_app/services/auth_service.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';

class Step5MobileScreen extends StatefulWidget {
  const Step5MobileScreen({super.key});

  @override
  State<Step5MobileScreen> createState() => _Step5MobileScreenState();
}

class _Step5MobileScreenState extends State<Step5MobileScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  bool _isButtonEnabled = false;
  bool _isLoading = false;
  bool _isTermsAccepted = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    debugPrint("📱 [REGISTRATION] Entered Step 5: Mobile Verification");
    final state = context.read<RegistrationState>();
    _phoneController.text = state.phoneNumber;
    if (state.authToken.isNotEmpty && state.phoneNumber.isNotEmpty) {
      _isTermsAccepted = true;
    }
    _phoneFocusNode.addListener(() => setState(() {}));
    _isButtonEnabled = state.phoneNumber.length == 10 && _isTermsAccepted;
  }

  @override
  void dispose() {
    _phoneFocusNode.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onPhoneChanged(String value) {
    setState(() {
      _isButtonEnabled = value.length == 10 && _isTermsAccepted;
    });
  }

  void _onTermsChanged(bool? value) {
    setState(() {
      _isTermsAccepted = value ?? false;
      _isButtonEnabled = _phoneController.text.length == 10 && _isTermsAccepted;
    });
  }

  void _showTerms() {
    TermsPopup.show(
      context,
      onAccept: () {
        _onTermsChanged(true);
      },
    );
  }

  void _sendOTP() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    debugPrint("🚀 [REGISTRATION] Sending OTP to: ${_phoneController.text.trim()}");
    
    context.read<RegistrationState>().updatePhone(_phoneController.text.trim());

    await _authService.sendOtp(
      phoneNumber: _phoneController.text.trim(),
      onCodeSent: (verificationId) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        debugPrint("🚀 [REGISTRATION] OTP Sent successfully to: ${_phoneController.text.trim()}");
        debugPrint("🚀 [REGISTRATION] Verification ID: $verificationId");
        context.push('/register/otp', extra: verificationId);
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        AppToast.show(context, error, isError: true);
      },
    );
  }

  // Dynamic Validation Border Logic
  Color _getInputBorderColor() {
    final text = _phoneController.text;
    if (text.isEmpty) return Colors.grey.shade300;
    if (text.length == 10) return AppTheme.successColor;
    return Colors.red.shade400; // Invalid number visual feedback
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RegistrationState>();
    final isVerified = state.authToken.isNotEmpty && 
                       state.phoneNumber.isNotEmpty && 
                       _phoneController.text == state.phoneNumber;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // Premium Bubble Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: 30),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(50),
                      bottomRight: Radius.circular(50),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(child: CustomPaint(painter: _RegisterBubblePainter())),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      // Back button icon for Step 1 (Back to login/previous)
                                      GestureDetector(
                                        onTap: () => context.pop(), // Usually back to login or onboarding
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.15),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                                          ),
                                          child: const Icon(
                                            Icons.arrow_back_rounded, 
                                            color: Colors.white, 
                                            size: 20
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Empty placeholder for symmetry if needed, or just let it be
                                      const SizedBox(width: 36),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      "STEP 1 OF 6",
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                "Mobile Verification",
                                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Enter your mobile number to get an OTP for verification",
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),

                      // Trust Indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline, color: AppTheme.primaryColor.withOpacity(0.8), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            "Secure Mobile Verification",
                            style: AppTheme.bodyStyle.copyWith(
                              color: AppTheme.blackColor.withOpacity(0.6),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Premium Input Field
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F5FF), // Premium background hue
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _phoneFocusNode.hasFocus
                            ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.15), blurRadius: 15, spreadRadius: 2)]
                            : [const BoxShadow(color: Color(0x0C000000), blurRadius: 10, offset: Offset(0, 4))],
                        ),
                        child: TextField(
                          controller: _phoneController,
                          focusNode: _phoneFocusNode,
                          readOnly: isVerified,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          onChanged: _onPhoneChanged,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: AppTheme.bodyStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1.5),
                          decoration: InputDecoration(
                            labelText: "Mobile Number",
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            labelStyle: AppTheme.bodyStyle.copyWith(
                              color: _phoneFocusNode.hasFocus ? AppTheme.primaryColor : Colors.grey.shade600, 
                              fontWeight: FontWeight.w500, 
                              letterSpacing: 0
                            ),
                            hintText: "Enter 10 digit number",
                            hintStyle: AppTheme.bodyStyle.copyWith(color: Colors.grey.shade400, fontSize: 16, letterSpacing: 0),
                            counterText: "",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: _getInputBorderColor(), width: 1.5),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: _getInputBorderColor(), width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: _getInputBorderColor(), width: 2),
                            ),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 14, right: 10),
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
                            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          ),
                        ),
                      ),
                      if (isVerified)
                        Padding(
                          padding: const EdgeInsets.only(top: 12, left: 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: AppTheme.successColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: Colors.white, size: 12),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Phone number is verified",
                                style: AppTheme.bodyStyle.copyWith(
                                  color: AppTheme.successColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      
                      // Checkbox aligned properly
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 2), // Fixes the label-checkbox top alignment issue
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: _isTermsAccepted,
                              onChanged: _onTermsChanged,
                              activeColor: AppTheme.primaryColor,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Removes implicit big padding
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: _showTerms,
                              behavior: HitTestBehavior.opaque,
                              child: Text.rich(
                                TextSpan(
                                  text: "By signing up I agree to the ",
                                  style: AppTheme.bodyStyle.copyWith(color: AppTheme.blackColor, fontWeight: FontWeight.w400, fontSize: 13, height: 1.4),
                                  children: [
                                    TextSpan(
                                      text: "Terms of use",
                                      style: AppTheme.bodyStyle.copyWith(color: AppTheme.primaryColor, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                    const TextSpan(text: " and "),
                                    TextSpan(
                                      text: "Privacy Policy.",
                                      style: AppTheme.bodyStyle.copyWith(color: AppTheme.primaryColor, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 36),
                      
                      if (!isVerified)
                        PremiumScaleButton(
                          onTap: (_isButtonEnabled && !_isLoading) ? _sendOTP : null,
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: (_isButtonEnabled && !_isLoading) ? AppTheme.primaryGradient : null,
                              color: (_isButtonEnabled && !_isLoading) ? null : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: (_isButtonEnabled && !_isLoading)
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
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already have an account? ",
                            style: AppTheme.bodyStyle.copyWith(color: AppTheme.greyColor, fontSize: 13),
                          ),
                          GestureDetector(
                            onTap: () => context.push('/login'),
                            child: Text(
                              "Log In",
                              style: AppTheme.bodyStyle.copyWith(
                                color: AppTheme.primaryColor, 
                                fontWeight: FontWeight.bold, 
                                fontSize: 13
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
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

class _RegisterBubblePainter extends CustomPainter {
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