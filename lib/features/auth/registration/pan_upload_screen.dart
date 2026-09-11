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

class PanUploadScreen extends StatefulWidget {
  const PanUploadScreen({super.key});

  @override
  State<PanUploadScreen> createState() => _PanUploadScreenState();
}

class _PanUploadScreenState extends State<PanUploadScreen> {
  final TextEditingController _panController = TextEditingController();
  XFile? _panImage;
  final ImagePicker _picker = ImagePicker();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    debugPrint("📱 [REGISTRATION] Entered PAN Upload Screen");
    final state = context.read<RegistrationState>();
    _panController.text = state.panNumber;
    _panImage = state.panImage;
  }

  Future<void> _pickImage() async {
    final state = context.read<RegistrationState>();
    if (state.panStatus == 'approved') {
      debugPrint("⚠️ [PAN] Image pick ignored: Already approved");
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
      debugPrint("📸 [PAN] Picking PAN image from ${source.name}...");
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 100,
        maxWidth: 2000,
        maxHeight: 2000,
      );
      if (image != null) {
        debugPrint("✅ [PAN] Image picked: ${image.path}");
        setState(() => _panImage = image);
      }
    }
  }

  Future<void> _onSave() async {
    final state = context.read<RegistrationState>();
    
    final panNum = _panController.text.toUpperCase().trim();
    if (_panImage == null) {
      debugPrint("⚠️ [PAN] Submission failed: Image missing");
      AppToast.show(context, "Please upload your PAN card photo", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    debugPrint("🚀 [PAN] Requesting Verification in Backend DB...");
    debugPrint("📤 [PAN] Image: ${_panImage!.path}");

    try {
      final response = await _apiService.verifyPan(
        state.authToken,
        File(_panImage!.path),
        state.vendorId,
      );

      debugPrint("📥 [PAN API RESPONSE] $response");

      if (response != null && response['success'] == true) {
        final String extractedPan = (response['pan'] ?? response['pan_number'] ?? panNum).toString().toUpperCase();
        debugPrint("🔍 [PAN OCR] Extracted Number: '$extractedPan'");
        
        state.updatePan(
          image: _panImage,
          number: extractedPan,
          status: 'approved',
        );
        debugPrint("✅ [PAN] PAN approved in Backend DB");

        if (mounted) {
          AppToast.show(context, "PAN Verified Successfully! ✅");
          context.pop();
        }
      } else {
        final errorMsg = response?['message'] ?? "Failed to verify PAN.";
        debugPrint("❌ [PAN] API Error: $errorMsg");
        if (mounted) {
          AppToast.show(context, errorMsg, isError: true);
        }
      }
    } catch (e) {
      debugPrint("❌ [PAN EXCEPTION] $e");
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.blackColor),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          "PAN Card Details",
          style: TextStyle(color: AppTheme.blackColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            PremiumTextField(
              controller: _panController,
              label: "PAN Number",
              hint: "Extracted after upload",
              maxLength: 10,
              readOnly: state.panStatus == 'approved',
              keyboardType: TextInputType.text,
              suffix: state.panStatus == 'approved' 
                ? const Padding(
                    padding: EdgeInsets.only(right: 14),
                    child: Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 22),
                  )
                : null,
              onChanged: (v) => _panController.value = _panController.value.copyWith(
                text: v.toUpperCase(),
                selection: TextSelection.collapsed(offset: v.length),
              ),
            ),
            const SizedBox(height: 32),
            _buildUploadCard(
              "PAN Card photo", 
              "Upload focused photo of your PAN card", 
              _panImage, 
              _pickImage
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
              onTap: state.panStatus == 'approved' ? null : _onSave,
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: state.panStatus == 'approved' ? null : AppTheme.primaryGradient,
                  color: state.panStatus == 'approved' ? Colors.grey.shade400 : null,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Center(
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        state.panStatus == 'approved' ? "Done" : "Verify PAN",
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

  Widget _buildTipRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor.withOpacity(0.7)),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)))),
      ],
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
                  child: Image.file(File(image.path), height: 180, width: double.infinity, fit: BoxFit.cover),
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
