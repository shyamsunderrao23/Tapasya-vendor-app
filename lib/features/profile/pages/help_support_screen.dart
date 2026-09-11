import 'package:flutter/material.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';
import 'package:tapasya_vendor_app/features/auth/widgets/premium_form_widgets.dart';
import 'package:tapasya_vendor_app/features/auth/widgets/premium_scale_button.dart';
import 'package:tapasya_vendor_app/services/api_service.dart';
import 'package:tapasya_vendor_app/core/utils/share_app_helper.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectCtrl = TextEditingController();
  final TextEditingController _messageCtrl = TextEditingController();
  String? _selectedCategory;
  bool _isSubmitting = false;

  Map<String, dynamic>? _contactData;
  bool _isLoadingContact = true;

  final List<String> _categories = [
    'Payout & Billing',
    'Technical App Issue',
    'Job / Booking Related',
    'Account & Documents',
    'Other Inquiries'
  ];

  @override
  void initState() {
    super.initState();
    _fetchContactInfo();
  }

  Future<void> _fetchContactInfo() async {
    try {
      final res = await ApiService().getContactInfo();
      if (res['success'] == true && res['contacts'] != null && (res['contacts'] as List).isNotEmpty) {
        setState(() {
          _contactData = res['contacts'][0];
          _isLoadingContact = false;
        });
      } else {
        setState(() => _isLoadingContact = false);
      }
    } catch (e) {
      debugPrint("Error fetching contact info: $e");
      setState(() => _isLoadingContact = false);
    }
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      HapticFeedback.mediumImpact();

      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() => _isSubmitting = false);
        AppToast.show(context, "Support ticket submitted successfully!");
        _subjectCtrl.clear();
        _messageCtrl.clear();
        setState(() => _selectedCategory = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
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
                              "Help Center",
                              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                          // SUPPORT ICON HUB
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
                                  child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 40),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  "How can we help?",
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Our expert team is available 24/7\nto resolve any challenges you face.",
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
            
            const SizedBox(height: 48),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CONTACT CARDS SECTION
                  const Text(
                    "Direct Support Channels",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1B263B), letterSpacing: 0.5),
                  ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1, end: 0),
                  const SizedBox(height: 24),
                  
                  _buildPremiumContactCard(
                    context,
                    Icons.phone_in_talk_rounded,
                    "Priority Call Support",
                    _contactData?['phone_number'] ?? "88888 88888",
                    const Color(0xFF4CAF50),
                    0,
                    onTap: () => _launchUrl("tel:${_contactData?['phone_number']}"),
                  ),
                  const SizedBox(height: 16),
                  _buildPremiumContactCard(
                    context,
                    Icons.email_rounded,
                    "Official Email Channel",
                    _contactData?['gmail'] ?? "support@tapasya.com",
                    const Color(0xFF2196F3),
                    1,
                    onTap: () => _launchUrl("mailto:${_contactData?['gmail']}?subject=Support Request - Tapasya"),
                  ),
                  const SizedBox(height: 16),
                  _buildPremiumContactCard(
                    context,
                    Icons.chat_rounded,
                    "Professional WhatsApp",
                    _contactData?['whats_number'] ?? "99999 99999",
                    const Color(0xFF25D366),
                    2,
                    onTap: () => _launchUrl("https://wa.me/91${_contactData?['whats_number']}"),
                  ),
                  const SizedBox(height: 16),
                  _buildPremiumContactCard(
                    context,
                    Icons.share_rounded,
                    "Share Partner App",
                    "Recommend Tapasya to friends & service experts",
                    const Color(0xFF8E2DE2),
                    3,
                    onTap: () => ShareAppHelper.shareApp(),
                  ),
                  
                  const SizedBox(height: 56),

                  // 🔥 NEW SECTION: CONTACT FORM
                  const Text(
                    "Send us a Message",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1B263B), letterSpacing: 0.5),
                  ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.1, end: 0),
                  const SizedBox(height: 24),
                  
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          PremiumDropdownField(
                            value: _selectedCategory,
                            label: "Select Category",
                            hint: "What is this about?",
                            items: _categories,
                            isRequired: true,
                            onChanged: (val) => setState(() => _selectedCategory = val),
                          ),
                          const SizedBox(height: 20),
                          PremiumTextField(
                            controller: _subjectCtrl,
                            label: "Subject",
                            hint: "Brief topic of your issue",
                            isRequired: true,
                            icon: Icons.topic_outlined,
                          ),
                          const SizedBox(height: 20),
                          PremiumTextField(
                            controller: _messageCtrl,
                            label: "Detailed Message",
                            hint: "Please describe your challenge in detail...",
                            isRequired: true,
                            maxLines: 4,
                            icon: Icons.message_outlined,
                          ),
                          const SizedBox(height: 32),
                          PremiumScaleButton(
                            onTap: _isSubmitting ? null : _submitForm,
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
                              child: Center(
                                child: _isSubmitting 
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text(
                                      "Submit Ticket",
                                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 700.ms),

                  const SizedBox(height: 48),
                  
                  _buildFAQSection(),
                ],
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQSection() {
    final faqs = [
      {
        "q": "How do I maximize my earnings?",
        "a": "Maintain a high rating (above 4.5) and ensure your 'Acceptance Rate' remains over 90%. Being 'Online' during peak morning and evening hours also increases job density."
      },
      {
        "q": "When are payments processed?",
        "a": "Earnings are verified upon customer confirmation. Verified funds are settled every Monday directly to your registered bank account."
      },
      {
        "q": "What if a customer cancels late?",
        "a": "If a customer cancels within 2 hours of the scheduled time, a 'Cancellation Fee' is credited to your wallet to compensate for your time and travel."
      },
      {
        "q": "How do I add new service categories?",
        "a": "Navigate to Profile > Services & Offerings. You can add new expertise there, which our verification team will audit within 24-48 hours."
      },
      {
        "q": "Customer is not at the location, what now?",
        "a": "Wait for 15 minutes and attempt to call the customer twice. if no response, use the 'Mark No-Show' button in Job Details to protect your arrival rating."
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          "Frequently Asked Questions",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1B263B), letterSpacing: 0.5),
        ).animate().fadeIn(delay: 900.ms).slideX(begin: -0.1, end: 0),
        const SizedBox(height: 24),
        ...faqs.asMap().entries.map((entry) {
          int idx = entry.key;
          var faq = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: Theme(
                data: ThemeData().copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(
                    faq['q']!,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1B263B)),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  iconColor: AppTheme.primaryColor,
                  collapsedIconColor: Colors.grey.shade300,
                  children: [
                    Text(
                      faq['a']!,
                      style: TextStyle(height: 1.6, fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(delay: (1000 + (idx * 50)).ms).slideY(begin: 0.1, end: 0);
        }),
      ],
    );
  }

  Widget _buildPremiumContactCard(BuildContext context, IconData icon, String title, String subtitle, Color color, int index, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {
        HapticFeedback.lightImpact();
        AppToast.show(context, "Opening $title...");
      },
      borderRadius: BorderRadius.circular(24),
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
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1B263B))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade400, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_right_rounded, color: Colors.grey.shade300, size: 24),
          ],
        ),
      ).animate().fadeIn(delay: (400 + (index * 100)).ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) AppToast.show(context, "Could not launch $urlString", isError: true);
      }
    } catch (e) {
      if (mounted) AppToast.show(context, "Error: $e", isError: true);
    }
  }
}

class _BubbleBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.05)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.2), 40, paint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.1), 60, paint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.8), 80, paint);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.85), 50, paint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), 30, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
