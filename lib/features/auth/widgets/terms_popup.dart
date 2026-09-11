import 'package:flutter/material.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:flutter/services.dart';

class TermsPopup extends StatefulWidget {
  final VoidCallback onAccept;

  const TermsPopup({super.key, required this.onAccept});

  static void show(BuildContext context, {required VoidCallback onAccept}) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: TermsPopup(onAccept: onAccept),
      ),
    );
  }

  @override
  State<TermsPopup> createState() => _TermsPopupState();
}

class _TermsPopupState extends State<TermsPopup> {
  bool _isAccepted = false;

  final List<Map<String, dynamic>> _termsParagraphs = [
    {
      "title": "1. Eligibility & Account Integrity",
      "spans": [
        const TextSpan(text: "By accessing the "),
        const TextSpan(text: "Tapasya Vendor Platform", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
        const TextSpan(text: ", you legally bind yourself to this agreement. You must be "),
        const TextSpan(text: "at least 18 years old", style: TextStyle(fontWeight: FontWeight.bold)),
        const TextSpan(text: " and possess all mandated licenses or certifications to offer your services. You authorize Tapasya to conduct "),
        const TextSpan(text: "background checks and identity verifications", style: TextStyle(fontWeight: FontWeight.bold)),
        const TextSpan(text: " to ensure platform safety."),
      ]
    },
    {
      "title": "2. Professional Standards & Punctuality",
      "spans": [
        const TextSpan(text: "Vendors represent the quality of Tapasya. You guarantee to arrive "),
        const TextSpan(text: "on time for all accepted bookings.", style: TextStyle(fontWeight: FontWeight.bold)),
        const TextSpan(text: " Any prolonged or uncommunicated delays, poor service delivery, or unprofessional conduct may incur penalties. You are strictly expected to provide "),
        const TextSpan(text: "your own premium tools and equipment", style: TextStyle(fontWeight: FontWeight.bold)),
        const TextSpan(text: " necessary to fulfill client requests."),
      ]
    },
    {
      "title": "3. Platform Fees & Independent Operations",
      "spans": [
        const TextSpan(text: "You operate as an "),
        const TextSpan(text: "Independent Contractor", style: TextStyle(fontWeight: FontWeight.bold)),
        const TextSpan(text: " and not as an employee of Tapasya. Therefore, you are solely responsible for handling your own taxes and insurance. Tapasya will deduct a transparent "),
        const TextSpan(text: "platform commission fee", style: TextStyle(fontWeight: FontWeight.bold)),
        const TextSpan(text: " clearly stated prior to accepting any job request. Attempting to bypass the platform by charging clients directly is a severe breach of this contract and will lead to an "),
        const TextSpan(text: "immediate lifetime ban", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        const TextSpan(text: "."),
      ]
    },
    {
      "title": "4. Data Privacy & Confidentiality",
      "spans": [
        const TextSpan(text: "While fulfilling services, you may gain access to sensitive client information (such as addresses and phone numbers). You are strictly prohibited from using, storing, or sharing this data outside of the explicit scope of the active booking. Misuse of client information violates our "),
        const TextSpan(text: "strict Data Privacy protocols", style: TextStyle(fontWeight: FontWeight.bold)),
        const TextSpan(text: " and carries legal consequences."),
      ]
    },
    {
      "title": "5. Cancellation & Feedback Mechanisms",
      "spans": [
        const TextSpan(text: "We understand that emergencies occur. However, frequent or unsupported cancellations severely degrade client trust. Excessively late cancellations impact your profile rating. Furthermore, clients will directly "),
        const TextSpan(text: "review and rate your services", style: TextStyle(fontWeight: FontWeight.bold)),
        const TextSpan(text: ". Maintaining a high average rating is crucial to remain active in the Tapasya ecosystem."),
      ]
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      clipBehavior: Clip.antiAlias, // Fixes bottom radius
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 5,
          )
        ],
      ),
      child: Column(
        children: [
          // Close Button
          Padding(
            padding: const EdgeInsets.only(right: 8.0, top: 8.0),
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
              ),
            ),
          ),

          // Clean Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Icon(Icons.shield_outlined, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Vendor Agreement",
                            style: AppTheme.headingStyle.copyWith(
                              fontSize: 24,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Please review all terms to proceed",
                            style: AppTheme.bodyStyle.copyWith(
                              color: AppTheme.greyColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Divider(height: 1, color: Colors.grey.shade100, thickness: 1),

          // Content List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              physics: const BouncingScrollPhysics(),
              itemCount: _termsParagraphs.length + 1,
              separatorBuilder: (context, index) => const SizedBox(height: 32),
              itemBuilder: (context, index) {
                if (index == _termsParagraphs.length) {
                  // The Checkbox at the end of the terms list
                  return Column(
                    children: [
                      const SizedBox(height: 8),
                      Divider(color: Colors.grey.shade200),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _isAccepted = !_isAccepted);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _isAccepted ? AppTheme.primaryColor.withOpacity(0.05) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _isAccepted ? AppTheme.primaryColor.withOpacity(0.3) : Colors.grey.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: _isAccepted ? AppTheme.primaryColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _isAccepted ? AppTheme.primaryColor : Colors.grey.shade400,
                                    width: 2,
                                  ),
                                ),
                                child: _isAccepted
                                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  "I have read, understood, and agree to the vendor terms.",
                                  style: AppTheme.bodyStyle.copyWith(
                                    color: _isAccepted ? AppTheme.blackColor : Colors.black54,
                                    fontWeight: _isAccepted ? FontWeight.w600 : FontWeight.normal,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                // Normal Term Item (Paragraph format)
                final term = _termsParagraphs[index];
                final title = term['title'] as String;
                final spans = term['spans'] as List<TextSpan>;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.headingStyle.copyWith(
                        color: AppTheme.primaryColor,
                        fontSize: 16,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text.rich(
                      TextSpan(
                        style: AppTheme.bodyStyle.copyWith(
                          color: AppTheme.blackColor.withOpacity(0.85),
                          height: 1.6,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        children: spans,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Sticky Footer (Button Only)
          Container(
            padding: EdgeInsets.only(
              left: 24, 
              right: 24, 
              top: 16, 
              bottom: MediaQuery.of(context).padding.bottom + 20
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade100)),
            ),
            child: GestureDetector(
              onTap: _isAccepted
                  ? () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(context);
                      widget.onAccept();
                    }
                  : () {
                     // Add haptic or visual feedback if they try to click while disabled
                     HapticFeedback.vibrate();
                  },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: _isAccepted ? AppTheme.primaryColor : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _isAccepted 
                    ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
                    : [],
                ),
                child: Center(
                  child: Text(
                    "Accept & Continue",
                    style: AppTheme.buttonTextStyle.copyWith(
                      color: _isAccepted ? Colors.white : Colors.grey.shade500,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
