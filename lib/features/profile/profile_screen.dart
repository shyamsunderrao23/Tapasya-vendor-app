import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/features/home/vendor_provider.dart';
import 'package:tapasya_vendor_app/features/auth/registration/registration_state.dart';
import 'package:tapasya_vendor_app/services/api_service.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';
import 'package:tapasya_vendor_app/features/profile/pages/edit_profile_screen.dart';
import 'package:tapasya_vendor_app/features/profile/pages/bank_details_screen.dart';
import 'package:tapasya_vendor_app/features/profile/pages/manage_services_screen.dart';
import 'package:tapasya_vendor_app/features/profile/pages/legal_document_screen.dart';
import 'package:tapasya_vendor_app/features/profile/pages/help_support_screen.dart';
import 'package:tapasya_vendor_app/features/profile/pages/availability_screen.dart';
import 'package:tapasya_vendor_app/features/profile/pages/vendor_reviews_screen.dart';
import 'package:tapasya_vendor_app/features/notifications/notifications_screen.dart';
import 'package:tapasya_vendor_app/core/utils/share_app_helper.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isOnline = true; // Local state for toggle

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<VendorProvider>();
      provider.fetchVendorServices();
      provider.fetchProfileFull();
      provider.fetchPerformance();
      provider.fetchReviewsFull();
      provider.fetchTransactions();
      provider.fetchAllJobs();
    });
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<RegistrationState>().logout();
    context.read<VendorProvider>().clearSession();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VendorProvider>(
      builder: (context, vendorProvider, child) {
        final vendor = vendorProvider.profile?.vendor;
        String profilePic = 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&q=80&w=200';
        if (vendor?.profilePic != null && vendor!.profilePic!.isNotEmpty) {
          final p = vendor.profilePic!;
          profilePic = p.startsWith('http') ? p : 'https://tapasyaserver.sreerasthusilvers.co.in${p.startsWith('/') ? '' : '/'}$p';
        }
        
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA), // Slightly off-white for depth
          body: SingleChildScrollView(
            child: Column(
              children: [
                // 1. REFACTORED PREMIUM HEADER (GLASS EFFECT + GRADIENT)
                _buildUpgradedHeader(context, vendor?.fullName ?? "Vendor", profilePic, vendorProvider),

                const SizedBox(height: 12),

                // 2. MINI STAT CARDS (Rating, Jobs, Earnings)
                _buildMiniStatCards(vendorProvider),

                const SizedBox(height: 32),

                // 4. PERFORMANCE SECTION
                _buildSectionHeader("PERFORMANCE"),
                _buildPerformanceSection(vendorProvider),

                const SizedBox(height: 32),

                // 4. MY SERVICES SECTION
                _buildSectionHeader("MY SERVICES"),
                _buildServicesSection(vendorProvider),

                const SizedBox(height: 32),

                // 4. TRUST & VERIFICATION SECTION
                _buildSectionHeader("TRUST & VERIFICATION"),
                _buildTrustSection(vendorProvider),

                const SizedBox(height: 32),

                // 5. INVITE & SHARE BANNER
                _buildInviteBanner(context, vendor?.fullName),

                const SizedBox(height: 32),

                // 6. QUICK ACTIONS
                _buildSectionHeader("QUICK ACTIONS"),
                _buildQuickActions(),

                const SizedBox(height: 32),

                // 7. ACCOUNT MANAGEMENT
                _buildSectionHeader("ACCOUNT"),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildPremiumActionCard(context, "Services & Offerings", "Manage your work categories", Icons.handyman_rounded, const Color(0xFF4A90E2), 
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageServicesScreen()))),
                      const SizedBox(height: 12),
                      _buildPremiumActionCard(context, "Payments & Banking", "Bank accounts and payout history", Icons.account_balance_wallet_rounded, const Color(0xFF50E3C2), 
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BankDetailsScreen()))),
                      const SizedBox(height: 12),
                      _buildPremiumActionCard(context, "Assignment Mode", "Manual Accept Mode Active", Icons.touch_app_rounded, const Color(0xFFF5A623), 
                        () => AppToast.show(context, "Manual Accept Mode is active for all service requests.")),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 8. SUPPORT SECTION
                _buildSectionHeader("SUPPORT & NETWORK"),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildPremiumActionCard(context, "Share App with Others", "Invite service professionals to join Tapasya", Icons.share_rounded, const Color(0xFF6C63FF), 
                        () => ShareAppHelper.shareApp(vendorName: vendor?.fullName)),
                      const SizedBox(height: 12),
                      _buildPremiumActionCard(context, "Help Center", "Get assistance and FAQs", Icons.forum_rounded, const Color(0xFFD0021B), 
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()))),
                      const SizedBox(height: 12),
                      _buildPremiumActionCard(context, "Terms & Conditions", "View our vendor agreement", Icons.article_rounded, Colors.grey.shade600, 
                        () => _navigateToLegal(context, "Terms & Conditions")),
                      const SizedBox(height: 12),
                      _buildPremiumActionCard(context, "Privacy Policy", "How we protect your data", Icons.privacy_tip_rounded, Colors.grey.shade600, 
                        () => _navigateToLegal(context, "Privacy Policy")),
                    ],
                  ),
                ),
                
                const SizedBox(height: 56),
                
                // 9. UPGRADED LOGOUT BUTTON
                _buildLogoutButton(context),
                const SizedBox(height: 60),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUpgradedHeader(BuildContext context, String name, String image, VendorProvider provider) {
    final fullProfile = provider.profileFullData;
    final reviews = provider.reviewsFullData;
    
    final String ratingStr = reviews?['average_rating']?.toString() ?? 
                            fullProfile?['vendor']?['rating']?.toString() ?? "N/A";

    final totalJobs = provider.unifiedEarningsStats['totalJobs']!.toInt();

    // 🔥 DYNAMIC STATUS: Check real server state
    // 🔥 FAIL-SAFE STATE: Force 'Offline' if not fully verified
    final bool isRestricted = !provider.isFullyVerified;
    final bool isOnline = (provider.profile?.vendor.activeStatus == 1) && !isRestricted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 40),
      decoration: const BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(60), bottomRight: Radius.circular(60)),
      ),
      child: Stack(
        children: [
          // Glass bubble pattern
          Positioned.fill(child: CustomPaint(painter: _BubbleBackgroundPainter())),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                children: [
                  // Profile Identity Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.2)),
                              child: CircleAvatar(
                                radius: 42,
                                backgroundColor: Colors.white.withOpacity(0.1),
                                child: CircleAvatar(radius: 38, backgroundImage: NetworkImage(image)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        "Hi, ${name.split(' ').first}", 
                                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                                        softWrap: true,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text("👋", style: TextStyle(fontSize: 22)),
                                    ],
                                  ),
                                  if (isRestricted)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: const Text(
                                        "⚠️ Documents not verified",
                                        style: TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                    ).animate().fadeIn().shake(),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                      const SizedBox(width: 4),
                                      Text(ratingStr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(width: 8),
                                      Container(width: 1, height: 10, color: Colors.white24),
                                      const SizedBox(width: 8),
                                      Text("$totalJobs Jobs", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => ShareAppHelper.shareApp(vendorName: name),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
                              child: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 24),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),

                  // Toggle & Edit Profile Row
                  Row(
                    children: [
                      // Online Toggle
                      Expanded(
                        child: Column(
                          children: [
                            InkWell(
                              onTap: isRestricted ? null : () async {
                                HapticFeedback.mediumImpact();
                                final res = await provider.toggleActiveStatus();
                                if (context.mounted) {
                                  // 🔥 NO TOASTS AT ALL if restricted
                                  if (!isRestricted) {
                                    if (res['success'] == true) {
                                      AppToast.show(context, res['message'] ?? "Status updated!");
                                    } else {
                                      AppToast.show(context, res['message'] ?? "Toggle failed", isError: true);
                                    }
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: provider.hasDocumentError 
                                    ? Colors.white.withOpacity(0.05) 
                                    : Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.circle, color: isOnline ? Colors.greenAccent : Colors.grey, size: 12),
                                    const SizedBox(width: 8),
                                    Text(
                                      isOnline ? "Online" : "Offline", 
                                      style: TextStyle(
                                        color: isRestricted ? Colors.white38 : Colors.white, 
                                        fontWeight: FontWeight.w700, 
                                        fontSize: 14
                                      )
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Edit Profile
                      Expanded(
                        child: InkWell(
                          onTap: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text("Edit Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                                const SizedBox(width: 8),
                                const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                  
                  // Monthly Earnings Summary (Glass Row)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Consumer<VendorProvider>(
                          builder: (context, vProv, _) {
                            final monthEarn = vProv.unifiedEarningsStats['monthEarnings']!.toDouble();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Monthly Earnings", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 4),
                                Text("₹ ${monthEarn.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                              ],
                            );
                          },
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: const Text("This Month", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatCards(VendorProvider provider) {
    final fullProfile = provider.profileFullData;
    final reviews = provider.reviewsFullData;
    
    final rating = reviews?['average_rating']?.toString() ?? 
                   fullProfile?['vendor']?['rating']?.toString() ?? "0.0";

    final stats = provider.unifiedEarningsStats;
    final totalJobs = stats['totalJobs']!.toInt();
    final totalEarnings = stats['totalEarnings']!.toInt();

    return Transform.translate(
      offset: const Offset(0, -30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            _buildStatCard("⭐ $rating", "Rating", const Color(0xFFF5A623)),
            const SizedBox(width: 12),
            _buildStatCard("💼 $totalJobs", "Jobs", const Color(0xFF4A90E2)),
            const SizedBox(width: 12),
            _buildStatCard("₹ $totalEarnings", "Earnings", const Color(0xFF50E3C2)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String val, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
          border: Border.all(color: Colors.white),
        ),
        child: Column(
          children: [
            Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1B263B))),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Text(
          title, 
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 1.5)
        ),
      ),
    );
  }


  Widget _buildPerformanceSection(VendorProvider provider) {
    final perf = provider.performanceData;
    final completion = perf?['completion_rate']?.toString() ?? "0";
    final acceptance = perf?['acceptance_rate']?.toString() ?? "0";
    final arrival = perf?['on_time_arrival']?.toString() ?? "0";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          children: [
            _buildPerformanceRow("Completion Rate", "$completion%", Colors.green),
            const Divider(height: 32, color: Color(0xFFF1F3F5)),
            _buildPerformanceRow("Acceptance Rate", "$acceptance%", Colors.blue),
            const Divider(height: 32, color: Color(0xFFF1F3F5)),
            _buildPerformanceRow("On-time Arrival", "$arrival%", Colors.orange),
          ],
        ),
      ),
    );
  }


  Widget _buildPerformanceRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1B263B), fontSize: 14)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
        ),
      ],
    );
  }

  Widget _buildServicesSection(VendorProvider provider) {
    if (provider.vendorServices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.grey.shade400, size: 20),
              const SizedBox(width: 12),
              Text("No active services added yet.", style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 140,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: provider.vendorServices.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final service = provider.vendorServices[index];
          final categoryName = service['service_name'] ?? 'Service';
          final subServiceName = service['sub_service_name'] ?? 'Expert Service';
          
          return Container(
            width: 240,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              // Entirely removed border and shadow to achieve 'Zero-Line' minimalist look
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Stack(
                children: [
                  // Subtle Back Decor
                  Positioned(
                    top: -20,
                    right: -20,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.03),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Overline
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                categoryName.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 9, 
                                  fontWeight: FontWeight.w900, 
                                  color: AppTheme.primaryColor,
                                  letterSpacing: 0.8
                                ),
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.verified_user_rounded, color: AppTheme.primaryColor, size: 18),
                          ],
                        ),
                        const Spacer(),
                        // Sub-Service (Hero Text)
                        Text(
                          subServiceName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900, 
                            fontSize: 18, 
                            color: Color(0xFF1B263B), 
                            letterSpacing: -0.5,
                            height: 1.1
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Verified Expert",
                          style: TextStyle(
                            fontSize: 10, 
                            fontWeight: FontWeight.w600, 
                            color: Colors.grey.shade400
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: (index * 150).ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), curve: Curves.easeOutBack);
        },
      ),
    );
  }

  /// Returns the verification status for a document type, defaulting to PENDING
  /// when the document hasn't been submitted yet (so it always shows up).
  String _docStatusFor(List documents, List<String> keys) {
    for (final d in documents) {
      final type = d.documentType.toUpperCase();
      if (keys.any((k) => type.contains(k))) {
        return d.verificationStatus.toUpperCase();
      }
    }
    return 'PENDING';
  }

  Widget _buildTrustSection(VendorProvider provider) {
    final documents = provider.profile?.documents ?? [];

    final String aadharStatus = _docStatusFor(documents, ['AADHAR', 'AADHAAR', 'ADHAR']);
    final String panStatus = _docStatusFor(documents, ['PAN']);
    final bool fullyVerified = provider.isFullyVerified;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: const Color(0xFF2575FC).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: Icon(
                    fullyVerified ? Icons.verified_rounded : Icons.shield_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullyVerified ? "Verified Partner" : "Verification Pending",
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fullyVerified
                            ? "Your account is fully verified and secure."
                            : "Complete your KYC to start receiving jobs.",
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(height: 1, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 20),
            _buildDocStatusRow("Aadhaar Card", aadharStatus),
            const SizedBox(height: 14),
            _buildDocStatusRow("PAN Card", panStatus),
          ],
        ),
      ),
    );
  }

  Widget _buildDocStatusRow(String label, String status) {
    final String s = status.toUpperCase();
    final bool isApproved = s == 'APPROVED' || s == 'VERIFIED';
    final bool isRejected = s == 'REJECTED';
    final bool isSubmitted = s == 'SUBMITTED' || s == 'UNDER_REVIEW' || s == 'PROCESSING' || s == 'IN_REVIEW';

    Color statusColor = Colors.orangeAccent;
    IconData statusIcon = Icons.pending_rounded;
    String statusText = "Pending";

    if (isApproved) {
      statusColor = Colors.greenAccent;
      statusIcon = Icons.check_circle_rounded;
      statusText = "Verified";
    } else if (isRejected) {
      statusColor = Colors.redAccent;
      statusIcon = Icons.cancel_rounded;
      statusText = "Rejected";
    } else if (isSubmitted) {
      statusColor = Colors.lightBlueAccent;
      statusIcon = Icons.hourglass_top_rounded;
      statusText = "Under Review";
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.article_rounded, color: Colors.white.withOpacity(0.9), size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 13),
              const SizedBox(width: 4),
              Text(
                statusText,
                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInviteBanner(BuildContext context, String? vendorName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A00E0).withOpacity(0.28),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.share_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Invite & Share App",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    "Share Tapasya with fellow technicians & partners",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => ShareAppHelper.shareApp(vendorName: vendorName),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF4A00E0),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                "Share",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildQuickCard(
            Icons.add_circle_outline_rounded, 
            "Add Service", 
            Colors.indigo,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageServicesScreen()))
          ),
          const SizedBox(width: 12),
          _buildQuickCard(
            Icons.event_available_rounded, 
            "Availability", 
            Colors.teal,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AvailabilityScreen()))
          ),
          const SizedBox(width: 12),
          _buildQuickCard(
            Icons.rate_review_rounded, 
            "Reviews", 
            Colors.amber,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorReviewsScreen()))
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCard(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 10),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1B263B))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumActionCard(BuildContext context, String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
          border: Border.all(color: Colors.grey.shade100, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color.withOpacity(0.6), color], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1B263B))),
                  const SizedBox(height: 2),
                  Text(sub, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300, size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: InkWell(
        onTap: () => _logout(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.power_settings_new_rounded, color: Colors.red, size: 22),
              SizedBox(width: 12),
              Text("Logout", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToLegal(BuildContext context, String type) {
    String content = "";
    
    if (type == "Terms & Conditions") {
      content = """1. ACCEPTANCE OF TERMS
By registering as a Vendor on Tapasya, you agree to be bound by these professional standards and operational guidelines.

2. SERVICE STANDARDS
- High-Quality Execution: You must provide services with professional competence and diligence.
- Proper Equipment: Use only high-quality tools and materials for all repair or maintenance tasks.
- On-Time Arrival: Punctuality is critical. Late arrivals affect your performance rating and job eligibility.

3. PAYMENTS & EARNINGS
- Verified Completion: Earnings are released only after the customer confirms successful job completion.
- Payout Schedule: Settlements are processed according to the standard weekly cycle.
- Deductions: A platform service fee is deducted from each booking as per the current fee structure.

4. CANCELLATION POLICY
- Late Cancellations: Repeated cancellations within 2 hours of scheduled time will result in professional penalties.
- Suspension: High cancellation rates or poor feedback may lead to temporary account suspension.

5. PROFESSIONAL CONDUCT
- Decency: Maintain respectful and professional behavior at customer locations at all times.
- Safety: Adhere to all safety protocols; any accidental damage must be reported immediately.
- Platform Integrity: Strict prohibition against bypassing the platform for personal bypass leads.""";
    } else {
      content = """1. DATA COLLECTION
We collect your personal identity (Name, Phone), professional credentials (ID, Certificates), and historical performance metrics to maintain a high-quality marketplace.

2. GEOLOCATION TRACKING
- Active Tracking: We track your real-time location while you are 'Online' to assign nearby jobs and calculate accurate arrival times.
- Background Usage: Location access is required for job monitoring and route optimization.

3. DATA SHARING
- Customer Access: Your name, rating, and expertise are visible to customers. Your phone number is shared only during an active booking.
- Security: We never sell your personal data to third parties. Information is shared only with banking partners for payouts.

4. SECURITY PROTOCOLS
We use enterprise-grade encryption to store your sensitive documents and financial records securely.

5. YOUR RIGHTS
You can request a summary of your stored data or update your professional details via the 'Edit Profile' section at any time.

6. POLICY UPDATES
We may update this policy to reflect platform improvements; significant changes will be notified via the App Notification Center.""";
    }

    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => LegalDocumentScreen(
          title: type, 
          content: content,
        ),
      ),
    );
  }

  void _showJobModePicker(BuildContext context, VendorProvider provider, String currentMode) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Job Assignment Mode", 
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1B263B), letterSpacing: -0.5)
            ),
            const SizedBox(height: 8),
            Text(
              "Choose how you'd like to receive new service requests.",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 32),
            _buildPremiumModeOption(
              context, 
              provider, 
              'auto', 
              'Auto Assign', 
              'Jobs are instantly assigned to you. Perfect for maximum efficiency.', 
              Icons.bolt_rounded,
              const Color(0xFF6200EE),
              currentMode == 'auto'
            ),
            const SizedBox(height: 16),
            _buildPremiumModeOption(
              context, 
              provider, 
              'manual', 
              'Manual Accept', 
              'Review every request before accepting. Gives you total control.', 
              Icons.touch_app_rounded,
              const Color(0xFF00BFB5),
              currentMode == 'manual'
            ),
          ],
        ).animate().fadeIn(delay: 1000.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
      ),
    );
  }

  Widget _buildPremiumModeOption(
    BuildContext context, 
    VendorProvider provider, 
    String mode, 
    String title, 
    String sub, 
    IconData icon, 
    Color color,
    bool isSelected
  ) {
    return InkWell(
      onTap: () async {
        HapticFeedback.mediumImpact();
        final prefs = await SharedPreferences.getInstance();
        String token = prefs.getString('auth_token') ?? context.read<RegistrationState>().authToken;
        await ApiService().updateJobMode(token, mode);
        provider.fetchVendorProfile(token);
        if (context.mounted) Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade100, 
            width: 2
          ),
          boxShadow: isSelected 
            ? [BoxShadow(color: color.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))]
            : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? color : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : color, size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title, 
                    style: TextStyle(
                      fontWeight: FontWeight.w900, 
                      fontSize: 16, 
                      color: isSelected ? color : const Color(0xFF1B263B)
                    )
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sub, 
                    style: TextStyle(
                      color: isSelected ? color.withOpacity(0.6) : Colors.grey.shade500, 
                      fontSize: 12, 
                      fontWeight: FontWeight.w500,
                      height: 1.3
                    )
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 24)
            else
              Icon(Icons.radio_button_off_rounded, color: Colors.grey.shade300, size: 24),
          ],
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
