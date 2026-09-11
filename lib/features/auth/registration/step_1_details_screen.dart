import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/features/auth/registration/registration_state.dart';
import 'package:tapasya_vendor_app/features/auth/widgets/premium_form_widgets.dart';
import 'package:tapasya_vendor_app/features/auth/widgets/premium_scale_button.dart';
import 'package:tapasya_vendor_app/services/location_service.dart';
import 'package:tapasya_vendor_app/services/file_helper.dart';
import 'package:tapasya_vendor_app/services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';

class Step1DetailsScreen extends StatefulWidget {
  const Step1DetailsScreen({super.key});

  @override
  State<Step1DetailsScreen> createState() => _Step1DetailsScreenState();
}

class _Step1DetailsScreenState extends State<Step1DetailsScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late TextEditingController _fullNameController;
  late TextEditingController _fathersNameController;
  late TextEditingController _dobController;
  late TextEditingController _emailController;
  late TextEditingController _primaryPhoneController;
  late TextEditingController _whatsappController;
  late TextEditingController _secondaryPhoneController;
  late TextEditingController _cityController;
  late TextEditingController _addressController;
  late TextEditingController _referralController;
  
  // Hidden values for location
  late TextEditingController _latController;
  late TextEditingController _lngController;

  String? _selectedGender;
  List<String> _selectedLanguages = [];
  XFile? _profilePic;

  final LocationService _locationService = LocationService();
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _predictions = [];
  final ImagePicker _picker = ImagePicker();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isLoading = false;

  // Language options
  final List<String> _languageOptions = [
    'Hindi', 'English', 'Marathi', 'Bengali', 'Gujarati', 
    'Tamil', 'Telugu', 'Kannada', 'Malayalam', 'Punjabi'
  ];

  @override
  void initState() {
    super.initState();
    debugPrint("📱 [REGISTRATION] Entered Step 1: Personal Details");
    final state = context.read<RegistrationState>();
    
    _fullNameController = TextEditingController(text: state.name);
    _fathersNameController = TextEditingController(text: state.fathersName);
    _dobController = TextEditingController(text: state.dob);
    _emailController = TextEditingController(text: state.email);
    _primaryPhoneController = TextEditingController(text: state.phoneNumber);
    _whatsappController = TextEditingController(text: state.whatsappNumber);
    _secondaryPhoneController = TextEditingController(text: state.secondaryMobileNumber);
    _cityController = TextEditingController(text: state.city);
    _addressController = TextEditingController(text: state.address);
    _referralController = TextEditingController(text: state.referralCode);
    
    _latController = TextEditingController(text: state.lat);
    _lngController = TextEditingController(text: state.lng);
    
    _profilePic = state.profilePic;
    _selectedLanguages = List<String>.from(state.languages);
    if (state.gender.isNotEmpty) _selectedGender = state.gender;
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate() && _selectedGender != null && _profilePic != null) {
      setState(() => _isLoading = true);
      final state = context.read<RegistrationState>();
      
      debugPrint("📝 [STEP 1] Data Validation Passed.");
      debugPrint("📝 [STEP 1] Personal Info: Name=${_fullNameController.text}, City=${_cityController.text}");

      state.updatePersonalDetails(
        name: _fullNameController.text.trim(),
        fathersName: _fathersNameController.text.trim(),
        dob: _dobController.text.trim(),
        gender: _selectedGender!,
        whatsappNumber: _whatsappController.text.trim(),
        secondaryMobileNumber: _secondaryPhoneController.text.trim(),
        city: _cityController.text.trim(),
        address: _addressController.text.trim(),
        languages: _selectedLanguages,
        email: _emailController.text.trim(),
        lat: _latController.text,
        lng: _lngController.text,
      );
      
      state.updateProfilePic(_profilePic!);
      debugPrint("📸 [STEP 1] Profile Picture Updated locally.");
      
      debugPrint("💾 [STEP 1] Local State Saved. Navigating to Step 2...");
      if (mounted) {
        setState(() => _isLoading = false);
        context.push('/register/step2');
      }
    } else {
      if (_profilePic == null) {
        debugPrint("⚠️ [STEP 1] Form validation failed: Profile picture missing");
        AppToast.show(context, "Profile picture is required", isError: true);
      }
      if (_selectedGender == null) {
        debugPrint("⚠️ [STEP 1] Form validation failed: Gender not selected");
        AppToast.show(context, "Please select your gender", isError: true);
      }
      debugPrint("⚠️ [STEP 1] Form validation failed");
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _fathersNameController.dispose();
    _dobController.dispose();
    _emailController.dispose();
    _primaryPhoneController.dispose();
    _whatsappController.dispose();
    _secondaryPhoneController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _referralController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 48,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 85),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            shadowColor: Colors.black26,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _predictions.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (context, index) {
                    final prediction = _predictions[index];
                    return ListTile(
                      leading: const Icon(Icons.location_on_rounded, color: AppTheme.primaryColor, size: 20),
                      title: Text(prediction['description'], style: const TextStyle(fontSize: 14)),
                      onTap: () => _selectPlace(prediction),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  Future<void> _selectPlace(Map<String, dynamic> prediction) async {
    final description = prediction['description'];
    final placeId = prediction['place_id'];
    _addressController.text = description;
    _removeOverlay();
    setState(() => _predictions = []);
    final details = await _locationService.getPlaceDetails(placeId);
    if (details != null) {
      _latController.text = details['lat'].toString();
      _lngController.text = details['lng'].toString();
    }
  }

  Future<void> _onAddressChanged(String query) async {
    if (query.length < 3) {
      setState(() => _predictions = []);
      _removeOverlay();
      return;
    }
    final suggestions = await _locationService.getAutocompleteSuggestions(query);
    setState(() => _predictions = suggestions);
    if (_predictions.isNotEmpty) _showOverlay();
    else _removeOverlay();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 500,
      maxHeight: 500,
      imageQuality: 80,
    );
    if (image != null) {
      final savedFile = await FileHelper.savePermanently(File(image.path));
      setState(() => _profilePic = XFile(savedFile.path));
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
                      Positioned.fill(child: CustomPaint(painter: _PersonalBubblePainter())),
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
                                        onTap: () => context.pushReplacement('/register/verify'),
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
                                        onTap: state.name.isNotEmpty ? () => context.push('/register/step2') : null,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: state.name.isNotEmpty 
                                                ? Colors.white.withOpacity(0.15) 
                                                : Colors.white.withOpacity(0.05),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                                          ),
                                          child: Icon(
                                            Icons.arrow_forward_rounded, 
                                            color: state.name.isNotEmpty ? Colors.white : Colors.white24, 
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
                                      "STEP 2 OF 6",
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                "Personal information",
                                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Enter the details below so we can get to know and serve you better",
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Form Fields
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (state.registrationError != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 24),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    state.registrationError!,
                                    style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                  onPressed: () => state.setRegistrationError(null),
                                ),
                              ],
                            ),
                          ),
                        PremiumTextField(
                          controller: _fullNameController,
                          label: "Full Name",
                          hint: "Enter the name as per aadhar",
                          isRequired: true,
                          validator: (v) => v!.isEmpty ? "Required" : null,
                        ),
                        const SizedBox(height: 20),

                        PremiumTextField(
                          controller: _fathersNameController,
                          label: "Father's Name",
                          hint: "Please enter father's name",
                          isRequired: true,
                          validator: (v) => v!.isEmpty ? "Required" : null,
                        ),
                        const SizedBox(height: 20),

                        PremiumTextField(
                          controller: _emailController,
                          label: "Email ID",
                          hint: "Please enter your email",
                          isRequired: true,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty) return "Required";
                            if (!v.contains('@')) return "Invalid email";
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // DOB & Gender Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: PremiumDatePicker(
                                controller: _dobController,
                                label: "Date of birth",
                                hint: "dd-mm-yyyy",
                                isRequired: true,
                                onDateSelected: (date) {
                                  _dobController.text = DateFormat('dd-MM-yyyy').format(date);
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: PremiumDropdownField(
                                items: const ['Male', 'Female', 'Other'],
                                label: "Gender",
                                value: _selectedGender,
                                isRequired: true,
                                onChanged: (val) => setState(() => _selectedGender = val),
                                validator: (v) => v == null || v.isEmpty ? "Required" : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Mobile Numbers
                        PremiumTextField(
                          controller: _primaryPhoneController,
                          label: "Primary mobile number",
                          hint: "+91 9999999999",
                          readOnly: true,
                          icon: Icons.phone_android_rounded,
                        ),
                        const SizedBox(height: 20),

                        PremiumTextField(
                          controller: _whatsappController,
                          label: "WhatsApp number",
                          hint: "+91 9999999999",
                          keyboardType: TextInputType.phone,
                          icon: Icons.chat_bubble_outline_rounded,
                        ),
                        const SizedBox(height: 20),

                        PremiumTextField(
                          controller: _secondaryPhoneController,
                          label: "Secondary mobile number (Optional)",
                          hint: "e.g. 9999999999",
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 20),

                        // City Selection
                        PremiumTextField(
                          controller: _cityController,
                          label: "City",
                          hint: "e.g. Bangalore",
                          suffixIcon: Icons.keyboard_arrow_right_rounded,
                          isRequired: true,
                          validator: (v) => v!.isEmpty ? "Required" : null,
                        ),
                        const SizedBox(height: 20),

                        // Address Field with Location Search
                        CompositedTransformTarget(
                          link: _layerLink,
                          child: PremiumTextField(
                            controller: _addressController,
                            label: "Enter complete address here",
                            hint: "Search address",
                            maxLines: 2,
                            onChanged: _onAddressChanged,
                            isRequired: true,
                            validator: (v) => v!.isEmpty ? "Required" : null,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Languages Multi-select
                        FormField<List<String>>(
                          initialValue: _selectedLanguages,
                          validator: (v) => (v == null || v.isEmpty) ? "Please select at least one language" : null,
                          builder: (fieldState) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                PremiumMultiSelectField(
                                  selectedItems: _selectedLanguages,
                                  label: "Languages you know",
                                  hint: "Select one or multiple",
                                  options: _languageOptions,
                                  isRequired: true,
                                  onChanged: (list) {
                                    setState(() => _selectedLanguages = list);
                                    fieldState.didChange(list);
                                  },
                                ),
                                if (fieldState.hasError)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 12, top: 8),
                                    child: Text(
                                      fieldState.errorText!,
                                      style: const TextStyle(color: Colors.red, fontSize: 12),
                                    ),
                                  ),
                              ],
                            );
                          }
                        ),
                        const SizedBox(height: 24),

                        // Profile Picture Section
                        FormField<XFile?>(
                          initialValue: _profilePic,
                          validator: (v) => v == null ? "Profile picture is required" : null,
                          builder: (fieldState) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: fieldState.hasError ? Colors.red : const Color(0xFFE5E7EB), 
                                      width: 1.5
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3F4F6),
                                          borderRadius: BorderRadius.circular(12),
                                          image: _profilePic != null 
                                              ? DecorationImage(image: FileImage(File(_profilePic!.path)), fit: BoxFit.cover)
                                              : null,
                                        ),
                                        child: _profilePic == null 
                                            ? const Icon(Icons.person_rounded, size: 40, color: Color(0xFF9CA3AF))
                                            : null,
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "Profile Picture *",
                                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF374151)),
                                            ),
                                            const SizedBox(height: 8),
                                            PremiumScaleButton(
                                              onTap: () async {
                                                await _pickImage();
                                                fieldState.didChange(_profilePic);
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                                decoration: BoxDecoration(
                                                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.photo_camera_rounded, size: 16, color: AppTheme.primaryColor),
                                                    const SizedBox(width: 8),
                                                    const Text("Upload Photo", style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (fieldState.hasError)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 12, top: 8),
                                    child: Text(
                                      fieldState.errorText!,
                                      style: const TextStyle(color: Colors.red, fontSize: 12),
                                    ),
                                  ),
                              ],
                            );
                          }
                        ),
                        const SizedBox(height: 20),

                        PremiumTextField(
                          controller: _referralController,
                          label: "Referral code (Optional)",
                          hint: "Enter referral code",
                        ),

                        const SizedBox(height: 40),

                        // Submit Button
                        PremiumScaleButton(
                          onTap: _isLoading ? null : _submit,
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
                            ),
                            child: Center(
                              child: _isLoading 
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    "Submit",
                                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),
                      ],
                    ),
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

class _PersonalBubblePainter extends CustomPainter {
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
