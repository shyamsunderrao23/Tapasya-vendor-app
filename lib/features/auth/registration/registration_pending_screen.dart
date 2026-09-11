import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/features/auth/registration/registration_state.dart';
import 'package:tapasya_vendor_app/features/auth/widgets/premium_scale_button.dart';

class RegistrationPendingScreen extends StatelessWidget {
  const RegistrationPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RegistrationState>();
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: Colors.white, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      "Registration Complete",
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Your application is under Verification",
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Account will get activated in 48hrs",
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              _buildStatusItem("Personal Information", "Approved", AppTheme.successColor),
              _buildStatusItem("Personal Documents", state.aadharStatus.capitalize(), _getStatusColor(state.aadharStatus)),
              _buildStatusItem("Tax Details (PAN)", state.panStatus.capitalize(), _getStatusColor(state.panStatus)),
              _buildStatusItem("Bank Account Details", state.bankStatus.capitalize(), _getStatusColor(state.bankStatus)),
              
              const Spacer(),
              
              const Text(
                "Need Help? Contact Us",
                style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 24),
              
              PremiumScaleButton(
                onTap: () {
                  // Mark registration as "systemically" complete to allow login to show this pending status
                  state.completeRegistration();
                  context.go('/home');
                },
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.blackColor,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Center(
                    child: Text(
                      "Go to Dashboard",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return AppTheme.successColor;
      case 'rejected': return Colors.red;
      case 'submitted': return Colors.blue;
      default: return Colors.grey;
    }
  }

  Widget _buildStatusItem(String title, String status, Color statusColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151)),
          ),
          Text(
            status,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
