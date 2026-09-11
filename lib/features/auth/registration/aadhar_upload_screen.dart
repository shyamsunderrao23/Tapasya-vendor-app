import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/features/auth/registration/registration_state.dart';
import 'package:tapasya_vendor_app/features/auth/widgets/premium_form_widgets.dart';
import 'package:tapasya_vendor_app/features/auth/widgets/premium_scale_button.dart';

import 'package:tapasya_vendor_app/services/api_service.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';

class AadharUploadScreen extends StatefulWidget {
  const AadharUploadScreen({super.key});

  @override
  State<AadharUploadScreen> createState() => _AadharUploadScreenState();
}

class _AadharUploadScreenState extends State<AadharUploadScreen> {
  final TextEditingController _aadharController = TextEditingController();
  XFile? _frontImage;
  XFile? _backImage;
  final ImagePicker _picker = ImagePicker();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    debugPrint("📱 [REGISTRATION] Entered Aadhar Upload Screen");
    final state = context.read<RegistrationState>();
    _aadharController.text = state.aadharNumber;
    _frontImage = state.aadharFrontImage;
    _backImage = state.aadharBackImage;
  }

  Future<void> _pickImage(bool isFront) async {
    final state = context.read<RegistrationState>();
    if (state.aadharStatus == 'approved') {
      debugPrint("⚠️ [AADHAR] Image pick ignored: Already approved");
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Select Image Source", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryColor),
              title: const Text("Camera (Recommended for OCR)"),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppTheme.primaryColor),
              title: const Text("Gallery"),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source != null) {
      debugPrint("📸 [AADHAR] Picking ${isFront ? 'FRONT' : 'BACK'} image from ${source.name}...");
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 100,
        maxWidth: 2000,
        maxHeight: 2000,
      );
      if (image != null) {
        debugPrint("✅ [AADHAR] Image picked: ${image.path}");
        if (isFront) {
          setState(() => _frontImage = image);
        } else {
          setState(() => _backImage = image);
        }
      }
    }
  }

  Future<void> _onSave() async {
    final state = context.read<RegistrationState>();

    if (_frontImage == null || _backImage == null) {
      debugPrint("⚠️ [AADHAR] Submission failed: Images missing");
      AppToast.show(context, "Please upload both front and back images", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    debugPrint("🚀 [AADHAR] Requesting OCR & Verification in DB...");
    debugPrint("📤 [AADHAR] Front: ${_frontImage!.path}");
    debugPrint("📤 [AADHAR] Back: ${_backImage!.path}");

    try {
      final response = await _apiService.uploadAadhar(
        state.authToken,
        File(_frontImage!.path),
        File(_backImage!.path),
        state.vendorId,
      );

      debugPrint("📥 [AADHAR API RESPONSE] $response");

      if (response != null && response['success'] == true) {
        // 1. Extract Name & Check Match
        final String extractedName = (response['full_name'] ?? response['name'] ?? "").toString().trim();
        final String extractedAadhar = (response['aadhaar'] ?? response['aadhar_number'] ?? _aadharController.text).toString();
        
        state.updateAadharExtractedName(extractedName);
        debugPrint("🔍 [AADHAR OCR] Extracted Name: '$extractedName'");
        debugPrint("🔍 [AADHAR OCR] Extracted Number: '$extractedAadhar'");
        debugPrint("👥 [AADHAR] Profile Name: '${state.name}' vs OCR Name: '$extractedName'");

        // 
        bool isMatch = extractedName.isNotEmpty &&
    (state.name.toLowerCase().contains(extractedName.toLowerCase()) ||
     extractedName.toLowerCase().contains(state.name.toLowerCase()));

if (!isMatch) {
  debugPrint("⚠️ [AADHAR] Name mismatch (but allowing)");
  if (mounted) {
    AppToast.show(context, "Name mismatch detected, please check once", isError: true);
  }
}

        // 2. Success - Update State
        debugPrint("✅ [AADHAR] Aadhar approved in Backend DB");
        state.updateAadhar(
          frontImage: _frontImage,
          backImage: _backImage,
          number: extractedAadhar,
          status: 'approved',
        );

        if (mounted) {
          AppToast.show(context, "Aadhar Verified Successfully! ✅");
          context.pop();
        }
      } else {
        final errorMsg = response?['message'] ?? "Failed to verify Aadhar.";
        debugPrint("❌ [AADHAR] API Error: $errorMsg");
        if (mounted) {
          AppToast.show(context, errorMsg, isError: true);
        }
      }
    } catch (e) {
      debugPrint("❌ [AADHAR EXCEPTION] $e");
      if (mounted) {
        AppToast.show(context, "Error: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTipRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor.withOpacity(0.7)),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RegistrationState>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.blackColor),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          "Aadhar Card Details",
          style: TextStyle(color: AppTheme.blackColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            PremiumTextField(
              controller: _aadharController,
              label: "Aadhar Number",
              hint: "Extracted after upload",
              keyboardType: TextInputType.number,
              maxLength: 12,
              readOnly: state.aadharStatus == 'approved',
              suffix: state.aadharStatus == 'approved' 
                ? const Padding(
                    padding: EdgeInsets.only(right: 14),
                    child: Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 22),
                  )
                : null,
            ),
            const SizedBox(height: 32),
            _buildUploadCard(
              "Front side photo", 
              "Upload front side of your Aadhar card", 
              _frontImage, 
              () => _pickImage(true)
            ),
            const SizedBox(height: 24),
            _buildUploadCard(
              "Back side photo", 
              "Upload back side of your Aadhar card", 
              _backImage, 
              () => _pickImage(false)
            ),
            const SizedBox(height: 24),
            // Scanning Tips Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tips_and_updates_rounded, color: AppTheme.primaryColor, size: 20),
                      const SizedBox(width: 8),
                      const Text("Smart Scanning Tips", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTipRow(Icons.light_mode_rounded, "Avoid reflections and glare from lights"),
                  const SizedBox(height: 8),
                  _buildTipRow(Icons.crop_free_rounded, "Ensure all 4 corners are clearly visible"),
                  const SizedBox(height: 8),
                  _buildTipRow(Icons.center_focus_strong_rounded, "Hold the camera steady for a sharp image"),
                ],
              ),
            ),
            const SizedBox(height: 32),
            PremiumScaleButton(
              onTap: state.aadharStatus == 'approved' ? null : _onSave,
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: state.aadharStatus == 'approved' ? null : AppTheme.primaryGradient,
                  color: state.aadharStatus == 'approved' ? Colors.grey.shade400 : null,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Center(
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        state.aadharStatus == 'approved' ? "Done" : "Verify Aadhar",
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard(String title, String subtitle, XFile? image, VoidCallback onTap) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          if (image != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(image.path), height: 140, width: double.infinity, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 8, right: 8,
                  child: GestureDetector(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.edit_rounded, size: 16, color: AppTheme.primaryColor),
                    ),
                  ),
                ),
              ],
            )
          else
            PremiumScaleButton(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_camera_rounded, size: 20, color: AppTheme.primaryColor),
                    SizedBox(width: 10),
                    Text("Upload Photo", style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
