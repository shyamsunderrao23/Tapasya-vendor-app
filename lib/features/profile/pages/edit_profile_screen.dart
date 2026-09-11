import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/features/home/vendor_provider.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';
import 'package:tapasya_vendor_app/features/auth/widgets/premium_form_widgets.dart';
import 'package:tapasya_vendor_app/features/auth/widgets/premium_scale_button.dart';
import 'package:tapasya_vendor_app/services/location_service.dart';
import 'dart:convert';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _fathersNameCtrl;
  late TextEditingController _dobCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _whatsappCtrl;
  late TextEditingController _secondaryPhoneCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _addressCtrl;
  
  String? _selectedGender;
  String? _selectedJobMode;
  List<String> _selectedLanguages = [];
  File? _imageFile;
  bool _isLoading = false;

  final LocationService _locationService = LocationService();
  List<Map<String, dynamic>> _predictions = [];
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  
  late TextEditingController _latCtrl;
  late TextEditingController _lngCtrl;

  final List<String> _languageOptions = [
    'Hindi', 'English', 'Marathi', 'Bengali', 'Gujarati', 
    'Tamil', 'Telugu', 'Kannada', 'Malayalam', 'Punjabi'
  ];

  @override
  void initState() {
    super.initState();
    final vendor = context.read<VendorProvider>().profile?.vendor;
    
    _nameCtrl = TextEditingController(text: vendor?.fullName ?? '');
    _fathersNameCtrl = TextEditingController(text: vendor?.fathersName ?? '');
    _dobCtrl = TextEditingController(text: vendor?.dob ?? '');
    _emailCtrl = TextEditingController(text: vendor?.email ?? '');
    _phoneCtrl = TextEditingController(text: vendor?.phone ?? '');
    _whatsappCtrl = TextEditingController(text: vendor?.whatsappNumber ?? '');
    _secondaryPhoneCtrl = TextEditingController(text: vendor?.secondaryMobileNumber ?? '');
    _cityCtrl = TextEditingController(text: vendor?.city ?? '');
    _addressCtrl = TextEditingController(text: vendor?.address ?? '');
    
    if (vendor?.gender != null && vendor!.gender.isNotEmpty) {
      _selectedGender = vendor.gender;
    }
    
    // 🔥 Initialize Job Mode (Internal keys: auto / manual)
    if (vendor?.jobMode != null && vendor!.jobMode.isNotEmpty) {
      final m = vendor.jobMode.toLowerCase().trim();
      _selectedJobMode = (m == 'auto' || m == 'automatic') ? 'auto' : 'manual';
    } else {
      _selectedJobMode = 'manual';
    }
    
    _selectedLanguages = List<String>.from(vendor?.languages ?? []);
    
    _latCtrl = TextEditingController(text: vendor?.lat?.toString() ?? '');
    _lngCtrl = TextEditingController(text: vendor?.lng?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _fathersNameCtrl.dispose();
    _dobCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _secondaryPhoneCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
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
    _addressCtrl.text = description;
    _removeOverlay();
    setState(() => _predictions = []);
    final details = await _locationService.getPlaceDetails(placeId);
    if (details != null) {
      _latCtrl.text = details['lat'].toString();
      _lngCtrl.text = details['lng'].toString();
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
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      HapticFeedback.mediumImpact();

      final provider = context.read<VendorProvider>();
      final res = await provider.updateProfile(
        name: _nameCtrl.text.trim(),
        fathersName: _fathersNameCtrl.text.trim(),
        dob: _dobCtrl.text.trim(),
        gender: _selectedGender ?? '',
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        whatsapp: _whatsappCtrl.text.trim(),
        secondaryPhone: _secondaryPhoneCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        languages: _selectedLanguages,
        jobMode: _selectedJobMode,
        image: _imageFile,
        lat: _latCtrl.text,
        lng: _lngCtrl.text,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (res['success'] == true) {
          AppToast.show(context, res['message'] ?? "Profile updated successfully!");
          Navigator.pop(context);
        } else {
          AppToast.show(context, res['message'] ?? "Error updating profile", isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorProvider = context.watch<VendorProvider>();
    final vendor = vendorProvider.profile?.vendor;
    
    String currentPic = '';
    if (vendor?.profilePic != null && vendor!.profilePic!.isNotEmpty) {
      final p = vendor.profilePic!;
      currentPic = p.startsWith('http') ? p : 'https://tapasyaserver.sreerasthusilvers.co.in${p.startsWith('/') ? '' : '/'}$p';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // 1. PREMIUM BUBBLE HEADER
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(bottom: 40),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(50),
                        bottomRight: Radius.circular(50),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(child: CustomPaint(painter: _BubbleHeaderPainter())),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => Navigator.pop(context),
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
                                    const SizedBox(width: 20),
                                    const Text(
                                      "Personal information",
                                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),
                                // PROFILE PIC SECTION
                                GestureDetector(
                                  onTap: _pickImage,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        width: 110,
                                        height: 110,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
                                          boxShadow: [
                                            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8)),
                                          ],
                                        ),
                                        child: CircleAvatar(
                                          radius: 50,
                                          backgroundColor: Colors.white.withOpacity(0.1),
                                          backgroundImage: _imageFile != null 
                                              ? FileImage(_imageFile!) 
                                              : (currentPic.isNotEmpty ? NetworkImage(currentPic) : null) as ImageProvider?,
                                          child: (_imageFile == null && currentPic.isEmpty) 
                                              ? const Icon(Icons.person_rounded, size: 50, color: Colors.white70)
                                              : null,
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                          child: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryColor, size: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 2. FORM FIELDS
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        PremiumTextField(
                          controller: _nameCtrl,
                          label: "Full Name",
                          hint: "Enter matching your aadhar",
                          isRequired: true,
                          icon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 20),

                        PremiumTextField(
                          controller: _fathersNameCtrl,
                          label: "Father's Name",
                          hint: "Enter father's name",
                          isRequired: true,
                          icon: Icons.person_pin_rounded,
                        ),
                        const SizedBox(height: 20),

                        PremiumTextField(
                          controller: _emailCtrl,
                          label: "Email ID",
                          hint: "Your official email",
                          isRequired: true,
                          readOnly: true,
                          icon: Icons.alternate_email_rounded,
                        ),
                        const SizedBox(height: 20),

                        // DOB & GENDER
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: PremiumDatePicker(
                                controller: _dobCtrl,
                                label: "Date of birth",
                                hint: "dd-mm-yyyy",
                                isRequired: true,
                                onDateSelected: (date) {
                                  _dobCtrl.text = DateFormat('dd-MM-yyyy').format(date);
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: PremiumDropdownField(
                                value: _selectedGender,
                                label: "Gender",
                                hint: "Select",
                                items: const ['Male', 'Female', 'Other'],
                                isRequired: true,
                                onChanged: (val) => setState(() => _selectedGender = val),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // PHONES
                        PremiumTextField(
                          controller: _phoneCtrl,
                          label: "Primary mobile number",
                          hint: "91XXXXXXXX",
                          readOnly: true,
                          icon: Icons.phone_android_rounded,
                        ),
                        const SizedBox(height: 20),

                        PremiumTextField(
                          controller: _whatsappCtrl,
                          label: "WhatsApp number",
                          hint: "91XXXXXXXX",
                          isRequired: true,
                          keyboardType: TextInputType.phone,
                          icon: Icons.chat_bubble_outline_rounded,
                        ),
                        const SizedBox(height: 20),

                        PremiumTextField(
                          controller: _secondaryPhoneCtrl,
                          label: "Secondary contact (Optional)",
                          hint: "Backup phone number",
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 20),

                        PremiumTextField(
                          controller: _cityCtrl,
                          label: "City",
                          hint: "e.g. Bangalore",
                          isRequired: true,
                          icon: Icons.apartment_rounded,
                        ),
                        const SizedBox(height: 20),

                        CompositedTransformTarget(
                          link: _layerLink,
                          child: PremiumTextField(
                            controller: _addressCtrl,
                            label: "Complete Address",
                            hint: "Street, House No, Landmark",
                            isRequired: true,
                            maxLines: 2,
                            icon: Icons.location_on_outlined,
                            onChanged: _onAddressChanged,
                          ),
                        ),
                        const SizedBox(height: 20),

                        PremiumMultiSelectField(
                          selectedItems: _selectedLanguages,
                          label: "Languages known",
                          hint: "Select languages",
                          options: _languageOptions,
                          isRequired: true,
                          onChanged: (list) => setState(() => _selectedLanguages = list),
                        ),
                        const SizedBox(height: 20),

                        PremiumDropdownField(
                          value: 'Manual (Pick & Choose)',
                          label: "Job Assignment Mode",
                          hint: "Select your preference",
                          items: const ['Manual (Pick & Choose)'],
                          isRequired: true,
                          onChanged: (val) {
                            setState(() {
                              _selectedJobMode = 'manual';
                            });
                          },
                        ),

                        const SizedBox(height: 48),

                        // SAVE BUTTON
                        PremiumScaleButton(
                          onTap: _isLoading ? null : _submit,
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5)),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                "Save Changes",
                                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
            ),
        ],
      ),
    );
  }
}

class _BubbleHeaderPainter extends CustomPainter {
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
