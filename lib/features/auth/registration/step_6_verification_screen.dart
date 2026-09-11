import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/features/auth/registration/registration_state.dart';
import 'package:tapasya_vendor_app/features/auth/widgets/premium_scale_button.dart';
import 'package:tapasya_vendor_app/services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';

class Step6VerificationScreen extends StatefulWidget {
  const Step6VerificationScreen({super.key});

  @override
  State<Step6VerificationScreen> createState() => _Step6VerificationScreenState();
}

class _Step6VerificationScreenState extends State<Step6VerificationScreen> {
  bool _isSubmitting = false;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    debugPrint("📱 [REGISTRATION] Entered Step 6: Verification Hub");
    final state = context.read<RegistrationState>();
    debugPrint("📊 [STEP 6] Initial Document Status: "
               "Aadhar: ${state.aadharStatus}, "
               "PAN: ${state.panStatus}, "
               "Bank: ${state.bankStatus}, "
               "Face: ${state.faceStatus}");
  }

  Future<void> _finalizeRegistration() async {
    setState(() => _isSubmitting = true);
    final state = context.read<RegistrationState>();

    try {
      debugPrint("🚀 [STEP 6] Initiating Final Activation Sequence...");
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("❌ [STEP 6] Auth Session Invalid");
        throw "Authentication session expired.";
      }
      
      debugPrint("🔥 [STEP 6] Fetching fresh Firebase Token...");
      String? freshToken = await user.getIdToken(true);
      if (freshToken == null) throw "Failed to get token.";

      debugPrint("🔥 [STEP 6] Exchanging Firebase Token for Backend JWT...");
      final loginResponse = await _apiService.loginVendor(freshToken);
      String? backendJwt;
      if (loginResponse != null && loginResponse['success'] == true) {
        backendJwt = loginResponse['data']['jwt_token'] ?? loginResponse['data']['token'];
        if (backendJwt != null) {
          debugPrint("✅ [STEP 6] Received Final Backend JWT");
          state.updateRegistrationToken(backendJwt);
        }
      }

      final tokenToUse = backendJwt ?? state.authToken;
      if (tokenToUse.isEmpty) throw "Failed to retrieve backend authorization token.";

      debugPrint("📤 [STEP 6] Calling toggleVendorStatus to ACTIVATE in DB...");
      final res = await _apiService.toggleVendorStatus(tokenToUse);
      bool isActivated = res['success'] == true;
      
      debugPrint("📥 [STEP 6 API RESPONSE] Activation Status: $isActivated, Message: ${res['message']}");

      if (isActivated) {
        debugPrint("✅ [STEP 6] Vendor Account successfully activated in DB.");
        state.completeRegistration(); 

        if (mounted) {
          debugPrint("✨ [STEP 6] Triggering Success UI & Auto-Redirect...");
          _showSuccessDialog(context);
        }
      } else {
        debugPrint("❌ [STEP 6] Activation call returned FALSE");
        throw "Activation failed. Please contact support or try again.";
      }
    } catch (e) {
      debugPrint("❌ [STEP 6 EXCEPTION] $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Activation Failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final state = context.watch<RegistrationState>();
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
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
                  Positioned.fill(child: CustomPaint(painter: _VerificationBubblePainter())),
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
                                  // Back button (<)
                                  GestureDetector(
                                    onTap: () => context.canPop() ? context.pop() : context.go('/register/verify'),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                                      ),
                                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Next button (>) - Hidden for Step 6
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
                                  "STEP 6 OF 6",
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "Document Verification",
                            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Upload focused photos of your documents for faster verification",
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
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Pending Documents",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Please provide valid documents to avoid rejection",
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 32),
                  
                  _buildDocTile(
                    context,
                    title: "Aadhar Card",
                    status: state.aadharStatus,
                    onTap: () {
                      debugPrint("📄 [STEP 6] Aadhar Tile Clicked -> Navigating to Aadhar Upload");
                      context.push('/register/aadhar');
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildDocTile(
                    context,
                    title: "PAN Card",
                    status: state.panStatus,
                    onTap: () {
                      debugPrint("📄 [STEP 6] PAN Tile Clicked -> Navigating to PAN Upload");
                      context.push('/register/pan');
                    },
                  ),
                  const SizedBox(height: 16),
                   _buildDocTile(
                    context,
                    title: "Bank Account Details",
                    status: state.bankStatus,
                    onTap: () {
                      debugPrint("💳 [STEP 6] Bank Tile Clicked -> Navigating to Bank Form");
                      context.push('/register/bank');
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildDocTile(
                    context,
                    title: "Face Verification",
                    status: state.faceStatus,
                    onTap: () => context.push('/register/face'),
                  ),
                  const SizedBox(height: 60),
                  
                  PremiumScaleButton(
                    onTap: (state.aadharStatus == 'approved' && 
                            state.panStatus == 'approved' && 
                            state.bankStatus == 'approved' &&
                            state.faceStatus == 'approved' &&
                            !_isSubmitting)
                        ? _finalizeRegistration
                        : null,
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: (state.aadharStatus == 'approved' && 
                                  state.panStatus == 'approved' && 
                                  state.bankStatus == 'approved' &&
                                  state.faceStatus == 'approved')
                            ? AppTheme.primaryGradient
                            : null,
                        color: (state.aadharStatus == 'approved' && 
                                  state.panStatus == 'approved' && 
                                  state.bankStatus == 'approved' &&
                                  state.faceStatus == 'approved')
                            ? null
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: (state.aadharStatus == 'approved' && 
                                  state.panStatus == 'approved' && 
                                  state.bankStatus == 'approved' &&
                                  state.faceStatus == 'approved')
                            ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]
                            : [],
                      ),
                      child: Center(
                        child: _isSubmitting 
                          ? const SizedBox(
                              height: 24, 
                              width: 24, 
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                            )
                          : const Text(
                              "COMPLETE SIGNUP",
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // 🔥 Need Help? Contact Link
                  Center(
                    child: GestureDetector(
                      onTap: () => _showSupportForm(context),
                      child: RichText(
                        text: TextSpan(
                          text: "Need Help? ",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500),
                          children: const [
                            TextSpan(
                              text: "Contact",
                              style: TextStyle(color: AppTheme.primaryColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocTile(BuildContext context, {
    required String title,
    required String status,
    required VoidCallback onTap,
  }) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'approved':
        statusColor = AppTheme.successColor;
        statusText = "Approved";
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = "Rejected";
        statusIcon = Icons.cancel_rounded;
        break;
      case 'submitted':
        statusColor = Colors.blue;
        statusText = "Verification Pending";
        statusIcon = Icons.info_rounded;
        break;
      default:
        statusColor = Colors.grey;
        statusText = "Pending";
        statusIcon = Icons.radio_button_unchecked_rounded;
    }

    return PremiumScaleButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF374151)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context) {
    final state = context.read<RegistrationState>();
    final String nextPath = state.getNextStepPath();

    // 🔥 Auto-redirect after 5 seconds (User Requirement)
    Timer(const Duration(seconds: 5), () {
      if (Navigator.of(context).canPop()) {
        debugPrint("⏳ [STEP 6] Auto-redirection timer fired. Redirecting to: $nextPath");
        Navigator.of(context).pop();
        context.go(nextPath == '/home' ? '/home' : nextPath);
      }
    });

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Success",
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.successColor.withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Premium Animated Icon
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.successColor.withOpacity(0.1), AppTheme.successColor.withOpacity(0.2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: AppTheme.successColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
                    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                     .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 1000.ms, curve: Curves.easeInOut),
                  ),
                ).animate().scale(delay: 200.ms, duration: 600.ms, curve: Curves.easeOutBack),
                
                const SizedBox(height: 32),
                
                const Text(
                  "Registration Successful!",
                  style: TextStyle(
                    fontSize: 24, 
                    fontWeight: FontWeight.w900, 
                    color: Color(0xFF1B263B), 
                    decoration: TextDecoration.none,
                    letterSpacing: -0.5
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0),
                
                const SizedBox(height: 12),
                
                Text(
                  "Welcome to the Tapasya Family! Your profile is now live. Get ready to receive your first service requests.",
                  style: TextStyle(
                    fontSize: 14, 
                    color: Colors.grey.shade500, 
                    height: 1.5, 
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 700.ms),
                
                const SizedBox(height: 40),
                
                // Explore Button (Manual Redirect)
                PremiumScaleButton(
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go(nextPath == '/home' ? '/home' : nextPath);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1B263B), Color(0xFF415A77)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1B263B).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        "Explore Tapasya",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 900.ms).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
                
                const SizedBox(height: 20),
                
                // Auto-timer indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade300),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Redirecting you in 5 seconds...",
                      style: TextStyle(
                        fontSize: 12, 
                        color: Colors.grey.shade400, 
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 1100.ms),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), curve: Curves.easeOutCubic);
      },
    );
  }

  void _showSupportForm(BuildContext parentContext) {
    final state = parentContext.read<RegistrationState>();
    final TextEditingController messageController = TextEditingController();
    String selectedIssue = 'AADHAAR';
    bool needContact = false;

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header (Fixed)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Contact Support",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1B263B), letterSpacing: -0.5),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF1B263B)),
                    ),
                  ],
                ),
              ),
              
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                    left: 24,
                    right: 24,
                    top: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Having trouble with verification? Let us know.",
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 28),
                      
                      // Issue Type Premium Picker
                      const Text("ISSUE CATEGORY", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF9CA3AF), letterSpacing: 1)),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showIssuePicker(context, selectedIssue, (val) {
                            setModalState(() => selectedIssue = val);
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.help_center_rounded, color: AppTheme.primaryColor, size: 20),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  selectedIssue,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1B263B)),
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Message Field
                      const Text("YOUR MESSAGE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF9CA3AF), letterSpacing: 1)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: messageController,
                        maxLines: 4,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: "Describe your issue here...",
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.w400),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: Color(0xFFF1F5F9)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: Color(0xFFF1F5F9)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Contact Checkbox
                      InkWell(
                         onTap: () {
                           HapticFeedback.selectionClick();
                           setModalState(() => needContact = !needContact);
                         },
                         splashColor: Colors.transparent,
                         child: Row(
                           children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: needContact ? AppTheme.primaryColor : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: needContact ? AppTheme.primaryColor : const Color(0xFFE2E8F0), width: 2),
                                ),
                                child: needContact ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  "Want to talk with our support team?",
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                                ),
                              ),
                           ],
                         ),
                      ),
                      const SizedBox(height: 32),

                      // Submit Button
                      PremiumScaleButton(
                        onTap: () async {
                          if (messageController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Please enter a message")),
                            );
                            return;
                          }

                          // Close form
                          Navigator.pop(context);

                          debugPrint("📞 [SUPPORT] Sending Request: "
                                     "Name: ${state.name}, "
                                     "Mobile: ${state.phoneNumber}, "
                                     "Issue: $selectedIssue, "
                                     "NeedContact: $needContact");

                          final response = await _apiService.submitSupportRequest(
                            vendorName: state.name.isNotEmpty ? state.name : "Vendor",
                            mobileNumber: state.phoneNumber.isNotEmpty ? state.phoneNumber : "0000000000",
                            issueType: selectedIssue,
                            message: messageController.text.trim(),
                            needContact: needContact,
                          );

                          debugPrint("📞 [SUPPORT] API Response: $response");

                          if (response['success'] == true) {
                            if (mounted) {
                              AppToast.show(parentContext, response['message'] ?? "Support request submitted successfully");
                            }
                          } else {
                            if (mounted) {
                              AppToast.show(parentContext, response['message'] ?? "Failed to submit request", isError: true);
                            }
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: 58,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B263B),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF1B263B).withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              "Submit Request", 
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showIssuePicker(BuildContext context, String current, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select Issue Category", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1B263B))),
            const SizedBox(height: 24),
            ...['AADHAAR', 'PAN', 'BANK', 'FACE'].map((val) => _buildSelectionTile(
              val, 
              val == current, 
              () {
                onSelect(val);
                Navigator.pop(context);
              }
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionTile(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppTheme.primaryColor.withOpacity(0.2) : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
              size: 20,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppTheme.primaryColor : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnifiedSubmissionOverlay extends StatelessWidget {
  const _UnifiedSubmissionOverlay();

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            margin: const EdgeInsets.symmetric(horizontal: 48),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppTheme.primaryColor),
                const SizedBox(height: 24),
                const Text(
                  "Finalizing Registration",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  "Uploading documents and creating your profile...",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Please do not close the app",
                  style: TextStyle(color: Colors.black38, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VerificationBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.05)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.2), 40, paint);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.15), 65, paint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.8), 80, paint);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.85), 50, paint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), 30, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
