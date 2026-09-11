import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/features/home/vendor_provider.dart';
import 'package:tapasya_vendor_app/services/api_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';

class ManageServicesScreen extends StatefulWidget {
  const ManageServicesScreen({super.key});

  @override
  State<ManageServicesScreen> createState() => _ManageServicesScreenState();
}

class _ManageServicesScreenState extends State<ManageServicesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _expCtrl = TextEditingController();
  
  List<dynamic> _mainServices = [];
  List<dynamic> _subServices = [];
  
  String? _selectedMainId;
  String? _selectedMainName;
  String? _selectedSubId;
  String? _selectedSubName;
  bool _isLoadingData = false;

  @override
  void initState() {
    super.initState();
    _fetchMainServices();
  }

  Future<void> _fetchMainServices() async {
    setState(() => _isLoadingData = true);
    final services = await ApiService().getServices();
    setState(() {
      _mainServices = services;
      _isLoadingData = false;
    });
  }

  Future<void> _fetchSubServices(String id) async {
    setState(() {
      _isLoadingData = true;
      _subServices = [];
      _selectedSubId = null;
      _selectedSubName = null;
    });
    final subs = await ApiService().getSubServices(id);
    setState(() {
      _subServices = subs;
      _isLoadingData = false;
    });
  }

  @override
  void dispose() {
    _expCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vendorProvider = context.watch<VendorProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: (_isLoadingData || vendorProvider.isLoading)
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // 1. PREMIUM PURPLE HEADER
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
                                     children: [
                                       Container(
                                         decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                                         child: IconButton(
                                           icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                                           onPressed: () => Navigator.pop(context),
                                         ),
                                       ),
                                       const SizedBox(width: 20),
                                       const Text(
                                         "Add New Service",
                                         style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                                       ),
                                     ],
                                   ),
                                   const SizedBox(height: 32),
                                  // MODERN ONBOARDING CARD
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
                                            child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 28),
                                          ),
                                          const SizedBox(height: 16),
                                          const Text(
                                            "Showcase Your Skills",
                                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            "Select your expertise and specify your years of experience to attract high-value clients.",
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
                    const SizedBox(height: 40),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Service Categorization",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1B263B), letterSpacing: 0.5),
                          ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1, end: 0),
                          const SizedBox(height: 24),

                          // CUSTOM CATEGORY PICKER
                          _buildPremiumPicker(
                            label: "Main Category",
                            subtitle: _selectedMainName ?? "Choose a category",
                            icon: Icons.grid_view_rounded,
                            onTap: _showMainCategoryPicker,
                          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),
                          const SizedBox(height: 20),
                          
                          _buildPremiumPicker(
                            label: "Sub Category",
                            subtitle: _selectedSubName ?? "Choose specific skill",
                            icon: Icons.layers_rounded,
                            isEnabled: _selectedMainId != null,
                            onTap: _showSubCategoryPicker,
                          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0),
                          const SizedBox(height: 32),

                          const Text(
                            "Professional Experience",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1B263B), letterSpacing: 0.5),
                          ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.1, end: 0),
                          const SizedBox(height: 24),
    
                          _buildModernTextField(
                            controller: _expCtrl,
                            label: "Years of Experience",
                            icon: Icons.history_edu_rounded,
                            keyboardType: TextInputType.number,
                            validator: (v) {
                               if (v == null || v.isEmpty) return "Required";
                               if (int.tryParse(v) == null) return "Invalid number";
                               return null;
                            },
                          ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.1, end: 0),
                          
                          const SizedBox(height: 48),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (_formKey.currentState!.validate() && _selectedSubId != null) {
                                  HapticFeedback.mediumImpact();
                                  final res = await vendorProvider.addVendorService(
                                    _selectedMainId!,
                                    _selectedSubId!,
                                    _expCtrl.text,
                                  );

                                  if (mounted) {
                                      if (res['success'] == true) {
                                        HapticFeedback.lightImpact();
                                        AppToast.show(context, "Service added successfully!");
                                        Navigator.pop(context);
                                      } else {
                                        AppToast.show(context, res['message'] ?? "Error adding service", isError: true);
                                      }
                                  }
                                } else if (_selectedSubId == null) {
                                  AppToast.show(context, "Please select category and sub-category", isError: true);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                padding: EdgeInsets.zero,
                              ),
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppTheme.primaryColor, Color(0xFF4A00E0)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: const Center(
                                  child: Text(
                                    "Save Service",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
                                  ),
                                ),
                              ),
                            ),
                          ).animate().fadeIn(delay: 900.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
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
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
            border: Border.all(color: Colors.grey.shade50),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
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

  void _showMainCategoryPicker() {
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
                  itemCount: _mainServices.length,
                  itemBuilder: (context, index) {
                    final s = _mainServices[index];
                    return _buildSelectionTile(
                      s['service_name'],
                      s['id'].toString() == _selectedMainId,
                      () {
                        setState(() {
                          _selectedMainId = s['id'].toString();
                          _selectedMainName = s['service_name'];
                        });
                        _fetchSubServices(_selectedMainId!);
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

  void _showSubCategoryPicker() {
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
              Text("Skills for $_selectedMainName", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1B263B))),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: _subServices.length,
                  itemBuilder: (context, index) {
                    final s = _subServices[index];
                    return _buildSelectionTile(
                      s['sub_service_name'],
                      s['id'].toString() == _selectedSubId,
                      () {
                        setState(() {
                          _selectedSubId = s['id'].toString();
                          _selectedSubName = s['sub_service_name'];
                        });
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
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1B263B)),
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13, fontWeight: FontWeight.w600),
          prefixIcon: Icon(icon, color: AppTheme.primaryColor.withOpacity(0.4), size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
    final strokePaint = Paint()..color = Colors.white.withOpacity(0.03)..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.5), 90, strokePaint);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.3), 70, strokePaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
