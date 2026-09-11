import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/features/auth/registration/registration_state.dart';
import 'package:tapasya_vendor_app/features/auth/widgets/premium_scale_button.dart';
import 'package:tapasya_vendor_app/services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';

class Step3JobModeScreen extends StatefulWidget {
  const Step3JobModeScreen({super.key});

  @override
  State<Step3JobModeScreen> createState() => _Step3JobModeScreenState();
}
class _Step3JobModeScreenState extends State<Step3JobModeScreen> {
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    debugPrint("📱 [REGISTRATION] Entered Step 3: Job Mode Preference");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<RegistrationState>().updateJobMode('manual');
      }
    });
  }

  void _submit() {
    final state = context.read<RegistrationState>();
    debugPrint("🚀 [STEP 3] Job Mode Finalized: ${state.jobMode}");
    _register();
  }

  Future<void> _register() async {
    setState(() => _isLoading = true);
    final state = context.read<RegistrationState>();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("❌ [STEP 3] Auth Session Expired");
        throw "Authentication session expired.";
      }
      final token = await user.getIdToken(true) ?? "";

      debugPrint("🚀 [STEP 3] Submitting Full Registration to Backend...");
      final Map<String, dynamic> registrationPayload = {
        'full_name': state.name,
        'email': state.email,
        'job_mode': state.jobMode,
        'services_count': state.selectedServices.length,
        'address': state.address,
      };
      debugPrint("📤 [STEP 3] Payload Overview: $registrationPayload");
      
      final response = await _apiService.registerVendor(
        token: token,
        fullName: state.name,
        fatherName: state.fathersName,
        dob: state.dob,
        gender: state.gender,
        age: state.calculateAge(),
        email: state.email,
        whatsappNumber: state.whatsappNumber,
        secondaryPhone: state.secondaryMobileNumber,
        city: state.city,
        address: state.address,
        lat: double.tryParse(state.lat) ?? 0.0,
        lng: double.tryParse(state.lng) ?? 0.0,
        jobMode: state.jobMode,
        languages: state.languages,
        services: state.selectedServices.map((s) => s.toMap()).toList(),
        profilePic: File(state.profilePic!.path),
        aadharNo: state.aadharNumber,
        panNo: state.panNumber,
      );

      debugPrint("📥 [STEP 3] API Response Status: ${response != null && response['success'] == true ? 'SUCCESS' : 'FAILURE'}");
      if (response != null) {
        debugPrint("📥 [STEP 3] Full Response Body: $response");
      }

      if (response != null && response['success'] == true) {
        debugPrint("✅ [STEP 3] Registration Data Successfully Saved in DB.");
        final data = response['data'] ?? {};
        if (data['vendor_id'] != null) {
          debugPrint("✅ [STEP 3] Assigned Vendor UUID: ${data['vendor_id']}");
          state.updateVendorId(data['vendor_id'].toString());
        }
        
        // Robust Token Extraction
        String? backendToken = response['token'] ?? response['jwt_token'] ?? data['jwt_token'] ?? data['token'];
        if (backendToken != null) {
          debugPrint("✅ [STEP 3] Backend JWT Token Received and Cached.");
          state.updateRegistrationToken(backendToken);
        }

        debugPrint("➡️ [STEP 3] Moving to Step 4 (Availability)...");
        if (mounted) context.push('/register/step4');
      } else {
        final errorMsg = response?['message'] ?? "Registration failed. Please try again.";
        debugPrint("❌ [STEP 3] DB Save Failed: $errorMsg");
        if (mounted) AppToast.show(context, errorMsg, isError: true);
      }
      
    } catch (e) {
      debugPrint("❌ [STEP 3 EXCEPTION] $e");
      if (mounted) {
        AppToast.show(context, "Error: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RegistrationState>();

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
                      Positioned.fill(child: CustomPaint(painter: _JobModeBubblePainter())),
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
                                        onTap: () => context.canPop() ? context.pop() : context.go('/register/step2'),
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
                                      // Next button (>)
                                      GestureDetector(
                                        onTap: state.jobMode.isNotEmpty ? () => context.push('/register/step4') : null,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: state.jobMode.isNotEmpty 
                                                ? Colors.white.withOpacity(0.15) 
                                                : Colors.white.withOpacity(0.05),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                                          ),
                                          child: Icon(
                                            Icons.arrow_forward_rounded, 
                                            color: state.jobMode.isNotEmpty ? Colors.white : Colors.white24, 
                                            size: 20
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      "STEP 4 OF 6",
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                "Account Setup",
                                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Choose your job assignment preference and finish registration",
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
                      const SizedBox(height: 8),
                      const Text(
                        "Job Assignment Mode",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Select how you want to receive new job requests.",
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                      ),
                      const SizedBox(height: 24),

                      // Job Mode Options (Strictly Manual for V1)
                      _buildModeOption(
                        context,
                        title: "Manual Selection (Standard)",
                        subtitle: "Review and accept incoming job alerts with complete details before proceeding.",
                        icon: Icons.touch_app_rounded,
                        mode: "manual",
                        currentMode: "manual",
                        onChanged: (val) => state.updateJobMode("manual"),
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Divider(color: Color(0xFFE5E7EB)),
                      ),

                      // Review Card
                      const Text(
                        "Registration Summary",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          children: [
                            _buildSummaryItem("Full Name", state.name),
                            const Divider(height: 24),
                            _buildSummaryItem("Phone", state.phoneNumber),
                            const Divider(height: 24),
                            _buildSummaryItem("Services", "(${state.selectedServices.length})"),
                            const SizedBox(height: 12),
                            ...List.generate(state.selectedServices.length, (index) {
                              final service = state.selectedServices[index];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          "${service.serviceName} - ${service.subServiceName}",
                                          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151), fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (index < state.selectedServices.length - 1)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Divider(color: Colors.grey.shade200, thickness: 1),
                                    ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),

                      const SizedBox(height: 48),

                      PremiumScaleButton(
                        onTap: _isLoading ? null : _register,
                        child: Container(
                          width: double.infinity,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isLoading 
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  "Next Step",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  )
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
        ],
      ),
    );
  }

  Widget _buildModeOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String mode,
    required String currentMode,
    required Function(String) onChanged,
  }) {
    final bool isSelected = currentMode == mode;
    return GestureDetector(
      onTap: () => onChanged(mode),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? Colors.white : const Color(0xFF6B7280), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isSelected ? AppTheme.primaryColor : const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: const Color(0xFF6B7280), fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1F2937), fontSize: 14)),
      ],
    );
  }
}

class _JobModeBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.05)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.1), 50, paint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.3), 30, paint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.85), 70, paint);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.7), 40, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
