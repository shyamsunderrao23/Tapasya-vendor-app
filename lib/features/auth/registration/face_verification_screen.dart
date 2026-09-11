import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/features/auth/registration/registration_state.dart';
import 'package:tapasya_vendor_app/features/auth/widgets/premium_scale_button.dart';
import 'package:tapasya_vendor_app/services/api_service.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';

class FaceVerificationScreen extends StatefulWidget {
  const FaceVerificationScreen({super.key});

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  XFile? _selfieImage;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    debugPrint("📱 [REGISTRATION] Entered Face Verification Screen");
  }

  Future<void> _takeSelfie() async {
    debugPrint("📸 [FACE] Opening camera for front selfie...");
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 1000,
      maxHeight: 1000,
      imageQuality: 85,
    );
    if (image != null) {
      debugPrint("✅ [FACE] Selfie captured: ${image.path}");
      setState(() => _selfieImage = image);
    }
  }

  Future<void> _verifyFace() async {
    if (_selfieImage == null) {
      debugPrint("⚠️ [FACE] Verification ignored: No image captured");
      return;
    }
    
    final state = context.read<RegistrationState>();
    if (state.aadharFrontImage == null) {
      debugPrint("⚠️ [FACE] Verification failed: Aadhar image missing in state");
      AppToast.show(context, "Aadhar front image missing. Please upload Aadhar first.", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    debugPrint("🚀 [FACE] Starting face match verification...");
    debugPrint("📤 [FACE] Selfie: ${_selfieImage!.path}");
    debugPrint("📤 [FACE] Aadhar Source: ${state.aadharFrontImage!.path}");
    
    try {
      final result = await ApiService().faceMatch(
        File(_selfieImage!.path),
        File(state.aadharFrontImage!.path),
        state.vendorId,
      );

      debugPrint("📥 [FACE API RESPONSE] $result");

      if (result != null && result['success'] == true) {
        debugPrint("✅ [FACE] Verification successful in Backend DB");
        state.updateFaceStatus('approved');
        state.updateSelfie(_selfieImage);
        
        if (mounted) {
          AppToast.show(context, "Face Verified Successfully! ✅");
          Navigator.pop(context);
        }
      } else {
        final message = result?['message'] ?? "Face verification failed. Please try again.";
        debugPrint("❌ [FACE] API Error: $message");
        if (mounted) {
          AppToast.show(context, message, isError: true);
        }
      }
    } catch (e) {
      debugPrint("❌ [FACE EXCEPTION] $e");
      if (mounted) {
        AppToast.show(context, "An error occurred during face verification.", isError: true);
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
      appBar: AppBar(
        title: const Text("Face Verification", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                   Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
                    child: const Icon(Icons.face_retouching_natural_rounded, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Selfie Verification",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Please take a clear selfie of your face. We will compare it with your Aadhar card image to verify your identity.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 48),

            // Selfie Display / Placeholder
            GestureDetector(
              onTap: _isLoading ? null : _takeSelfie,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _selfieImage != null ? AppTheme.primaryColor : Colors.grey.shade300,
                    width: 3,
                  ),
                  image: _selfieImage != null
                      ? DecorationImage(image: FileImage(File(_selfieImage!.path)), fit: BoxFit.cover)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: _selfieImage == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_rounded, color: Colors.grey.shade400, size: 50),
                          const SizedBox(height: 12),
                          Text("Tap to capture", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                        ],
                      )
                    : null,
              ),
            ),

            const SizedBox(height: 60),

            // Tips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildTipRow(Icons.light_mode_rounded, "Ensure good lighting on your face"),
                  const SizedBox(height: 12),
                  _buildTipRow(Icons.no_photography_rounded, "Don't wear hats, sunglasses or masks"),
                  const SizedBox(height: 12),
                  _buildTipRow(Icons.portrait_rounded, "Keep your face inside the circle"),
                ],
              ),
            ),

            const SizedBox(height: 80),

            // Action Button
            if (_isLoading)
              const CircularProgressIndicator()
            else if (state.faceStatus == 'approved')
              PremiumScaleButton(
                onTap: null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      "DONE ✅",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                  ),
                ),
              )
            else if (_selfieImage != null)
              PremiumScaleButton(
                onTap: _verifyFace,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      "VERIFY FACE",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                  ),
                ),
              )
            else
              PremiumScaleButton(
                onTap: _takeSelfie,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.primaryColor, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      "TAKE SELFIE",
                      style: TextStyle(color: AppTheme.primaryColor, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor.withOpacity(0.7)),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w400)),
      ],
    );
  }
}
