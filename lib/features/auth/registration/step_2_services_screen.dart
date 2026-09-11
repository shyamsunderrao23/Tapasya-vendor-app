import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/features/auth/registration/registration_state.dart';
import 'package:tapasya_vendor_app/features/auth/widgets/premium_scale_button.dart';
import 'package:tapasya_vendor_app/services/api_service.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';

class Step2ServicesScreen extends StatefulWidget {
  const Step2ServicesScreen({super.key});

  @override
  State<Step2ServicesScreen> createState() => _Step2ServicesScreenState();
}

class _Step2ServicesScreenState extends State<Step2ServicesScreen> {
  List<dynamic> _services = [];
  List<dynamic> _subServices = [];
  bool _isLoadingServices = false;
  bool _isLoadingSubServices = false;
  final ApiService _apiService = ApiService();
  final TextEditingController _experienceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    debugPrint("📱 [REGISTRATION] Entered Step 2: Services Offered");
    _fetchServices();
    
    final state = context.read<RegistrationState>();
    if (state.currentServiceId != null) {
      _fetchSubServices(state.currentServiceId!);
    }
    _experienceController.text = state.currentExperience;
  }

  @override
  void dispose() {
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _fetchServices() async {
    setState(() => _isLoadingServices = true);
    final services = await _apiService.getServices();
    setState(() {
      _services = services;
      _isLoadingServices = false;
    });
  }

  Future<void> _fetchSubServices(String serviceId) async {
    debugPrint("🔍 [STEP 2] Fetching sub-services for serviceId: $serviceId");
    setState(() => _isLoadingSubServices = true);
    final subServices = await _apiService.getSubServices(serviceId);
    setState(() {
      _subServices = subServices;
      _isLoadingSubServices = false;
    });
    debugPrint("📥 [STEP 2] Received ${subServices?.length ?? 0} sub-services.");
  }

  Future<void> _submit() async {
    final state = context.read<RegistrationState>();
    if (state.selectedServices.isEmpty) {
      AppToast.show(context, "Please add at least one service", isError: true);
      return;
    }
    if (mounted) context.push('/register/step3');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RegistrationState>();
    final bool canAdd = state.currentServiceId != null && 
                       state.currentSubServiceId != null && 
                       _experienceController.text.isNotEmpty;
    final bool canProceed = state.selectedServices.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // PREMIUM PURPLE HEADER (Matches Profile Style)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(60),
                  bottomRight: Radius.circular(60),
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _BubbleBackgroundPainter())),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                      child: Column(
                        children: [
                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               Row(
                                 children: [
                                   GestureDetector(
                                     onTap: () => context.canPop() ? context.pop() : context.go('/register/step1'),
                                     child: Container(
                                       padding: const EdgeInsets.all(10),
                                       decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                                       child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                                     ),
                                   ),
                                   const SizedBox(width: 20),
                                   const Text(
                                     "Service Expertise",
                                     style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                                   ),
                                 ],
                               ),
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                 decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                                 child: const Text("Step 2/6", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                               ),
                             ],
                           ),
                           const SizedBox(height: 32),
                           // MODERN PROMPT CARD
                           Container(
                             padding: const EdgeInsets.all(24),
                             decoration: BoxDecoration(
                               color: Colors.white.withOpacity(0.1),
                               borderRadius: BorderRadius.circular(32),
                               border: Border.all(color: Colors.white.withOpacity(0.1)),
                             ),
                             child: Column(
                               children: [
                                   Container(
                                     padding: const EdgeInsets.all(16),
                                     decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                                     child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 28),
                                   ),
                                   const SizedBox(height: 16),
                                   const Text("Add Your Skills", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                                   const SizedBox(height: 8),
                                   Text(
                                     "Select the jobs you excel at. You can add multiple services before continuing.",
                                     textAlign: TextAlign.center,
                                     style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w500),
                                   ),
                               ],
                             ),
                           ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
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
                    "Service Categorization",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1B263B), letterSpacing: 0.5),
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 24),

                  // 🔥 PREMIUM CATEGORY PICKERS (Ported from Profile)
                  _buildPremiumPicker(
                    label: "Main Category",
                    subtitle: state.currentServiceName ?? "Choose a service",
                    icon: Icons.grid_view_rounded,
                    onTap: () => _showMainCategoryPicker(state),
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),
                  
                  const SizedBox(height: 20),

                  _buildPremiumPicker(
                    label: "Sub Category",
                    subtitle: state.currentSubServiceName ?? "Choose specific skill",
                    icon: Icons.layers_rounded,
                    isEnabled: state.currentServiceId != null,
                    onTap: () => _showSubCategoryPicker(state),
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0),
                  
                  const SizedBox(height: 32),

                  const Text(
                    "Professional Experience",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1B263B), letterSpacing: 0.5),
                  ).animate().fadeIn(delay: 600.ms),
                  const SizedBox(height: 24),

                  _buildModernTextField(
                    controller: _experienceController,
                    label: "Years of Experience",
                    icon: Icons.history_edu_rounded,
                    onChanged: (val) => state.setCurrentExperience(val),
                  ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 32),

                  // Add Service Button
                  PremiumScaleButton(
                    onTap: canAdd ? () {
                      HapticFeedback.mediumImpact();
                      debugPrint("➕ [STEP 2] Adding Service: ${state.currentSubServiceName} (${state.currentExperience} years)");
                      state.addSelectedService();
                      _experienceController.clear();
                      FocusScope.of(context).unfocus();
                      AppToast.show(context, "Added to list! ✅");
                      debugPrint("✅ [STEP 2] Service added. Total services: ${state.selectedServices.length}");
                    } : null,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: canAdd ? const Color(0xFF1B263B).withOpacity(0.05) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: canAdd ? const Color(0xFF1B263B).withOpacity(0.1) : Colors.transparent),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline_rounded, color: canAdd ? const Color(0xFF1B263B) : Colors.grey, size: 24),
                          const SizedBox(width: 12),
                          Text(
                            "Add This Service", 
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: canAdd ? const Color(0xFF1B263B) : Colors.grey)
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Divider
                  if (state.selectedServices.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Divider(color: Color(0xFFF1F3F5), thickness: 2),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Selected Services",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1B263B)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Text("${state.selectedServices.length}", style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w900, fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // LIST OF ADDED SERVICES
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.selectedServices.length,
                      itemBuilder: (context, index) {
                        final service = state.selectedServices[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))],
                            border: Border.all(color: Colors.grey.shade50),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                                child: const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor, size: 20),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(service.serviceName, style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w900, fontSize: 11)),
                                    const SizedBox(height: 2),
                                    Text(service.subServiceName, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1B263B), fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text("${service.experienceYears} Years Experience", style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 22),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  debugPrint("🗑️ [STEP 2] Removing Service at index $index: ${service.subServiceName}");
                                  state.removeSelectedService(index);
                                  debugPrint("✅ [STEP 2] Service removed. Remaining: ${state.selectedServices.length}");
                                },
                              ),
                            ],
                          ),
                        ).animate().scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
                      },
                    ),
                  ],

                  const SizedBox(height: 48),

                  // Next Step Button
                  PremiumScaleButton(
                    onTap: canProceed ? _submit : null,
                    child: Container(
                      width: double.infinity,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: canProceed ? const LinearGradient(colors: [Color(0xFF1B263B), Color(0xFF415A77)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                        color: canProceed ? null : const Color(0xFFF1F3F5),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: canProceed ? [BoxShadow(color: const Color(0xFF1B263B).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))] : [],
                      ),
                      child: Center(
                        child: Text(
                          "Continue Registration", 
                          style: TextStyle(color: canProceed ? Colors.white : Colors.grey.shade400, fontWeight: FontWeight.w900, fontSize: 16)
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumPicker({
    required String label,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(24),
      child: Opacity(
        opacity: isEnabled ? 1 : 0.4,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShape.circle != null ? BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8)) : const BoxShadow()],
            border: Border.all(color: Colors.grey.shade50),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: AppTheme.primaryColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1B263B))),
                  ],
                ),
              ),
              Icon(Icons.keyboard_arrow_right_rounded, color: Colors.grey.shade300, size: 28),
            ],
          ),
        ),
      ),
    );
  }

  void _showMainCategoryPicker(RegistrationState state) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Select Category", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1B263B))),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: _services.length,
                  itemBuilder: (context, index) {
                    final s = _services[index];
                    return _buildSelectionTile(
                      s['service_name'],
                      s['id'].toString() == state.currentServiceId,
                      () {
                        state.setCurrentService(id: s['id'].toString(), name: s['service_name']);
                        _fetchSubServices(s['id'].toString());
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSubCategoryPicker(RegistrationState state) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Skills for ${state.currentServiceName}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1B263B))),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: _subServices.length,
                  itemBuilder: (context, index) {
                    final s = _subServices[index];
                    return _buildSelectionTile(
                      s['sub_service_name'],
                      s['id'].toString() == state.currentSubServiceId,
                      () {
                        state.setCurrentSubService(id: s['id'].toString(), name: s['sub_service_name']);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionTile(String title, bool isSelected, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.grey.shade100, width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: isSelected ? AppTheme.primaryColor : const Color(0xFF1B263B))),
              if (isSelected) const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1B263B)),
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13, fontWeight: FontWeight.w700),
          prefixIcon: Icon(icon, color: AppTheme.primaryColor.withOpacity(0.4), size: 22),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        ),
      ),
    );
  }
}

class _BubbleBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.05)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.2), 40, paint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.1), 60, paint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.7), 80, paint);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.8), 50, paint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.4), 30, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
