import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/features/home/vendor_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';
import 'manage_services_screen.dart';

class ActiveServicesScreen extends StatefulWidget {
  const ActiveServicesScreen({super.key});

  @override
  State<ActiveServicesScreen> createState() => _ActiveServicesScreenState();
}

class _ActiveServicesScreenState extends State<ActiveServicesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorProvider>().fetchVendorServices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vendorProvider = context.watch<VendorProvider>();
    final services = vendorProvider.vendorServices;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: vendorProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : SingleChildScrollView(
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
                                       "My Services",
                                       style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                                     ),
                                   ],
                                 ),
                                 const SizedBox(height: 32),
                                // STAT CARD IN HEADER
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(32),
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                                        child: const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "${services.length} Active Services",
                                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "Providing high-quality solutions",
                                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
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
                  
                  const SizedBox(height: 32),

                  // 2. SERVICES LIST
                  services.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: services.length,
                          itemBuilder: (context, index) {
                            final s = services[index];
                            return _buildServiceCard(context, s, index);
                          },
                        ),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ManageServicesScreen()),
          );
        },
        label: const Text("Add New Service", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: AppTheme.primaryColor,
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ).animate().scale(delay: 800.ms, curve: Curves.elasticOut),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        const SizedBox(height: 60),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.handyman_rounded, size: 80, color: AppTheme.primaryColor.withOpacity(0.2)),
        ),
        const SizedBox(height: 24),
        const Text("No Managed Services", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1B263B))),
        const SizedBox(height: 8),
        Text(
          "Add services you want to provide\nto start getting matching jobs.", 
          textAlign: TextAlign.center, 
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildServiceCard(BuildContext context, dynamic s, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
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
            child: const Icon(Icons.bolt_rounded, color: AppTheme.primaryColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s['service_name'] ?? 'Service', 
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1B263B)),
                ),
                const SizedBox(height: 4),
                Text(
                  s['sub_service_name'] ?? 'Detail', 
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  "₹ ${s['price']}", 
                  style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), shape: BoxShape.circle),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
            ),
            onPressed: () => _confirmDelete(context, s['id'].toString()),
          )
        ],
      ),
    ).animate().fadeIn(delay: (300 + (index * 100)).ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }

  void _confirmDelete(BuildContext context, String serviceId) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Remove Service?", style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text("Are you sure you want to remove this service from your profile? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w700))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await context.read<VendorProvider>().deleteVendorService(serviceId);
                if (mounted) {
                  HapticFeedback.lightImpact();
                  final bool success = res['success'] == true;
                  AppToast.show(
                    context, 
                    success ? "Service removed" : (res['message'] ?? "Error removing service"),
                    isError: !success,
                  );
                }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("Delete", style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
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
