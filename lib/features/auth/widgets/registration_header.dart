import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';

class RegistrationHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final int currentStep;
  final int totalSteps;
  final bool showBackButton;

  const RegistrationHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.currentStep,
    required this.totalSteps,
    this.showBackButton = true,
  });

  final List<String> _stepTitles = const [
    'Mobile',
    'Personal',
    'Services',
    'Docs',
    'Selfie',
    'Available',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.scaffoldBG,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 24,
        right: 24,
        bottom: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showBackButton)
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.black87),
                  ),
                ),
              if (showBackButton) const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.headingStyle.copyWith(
                        color: AppTheme.blackColor,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
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
          const SizedBox(height: 32),
          
          // Timeline Stepper
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(totalSteps, (index) {
              final stepNumber = index + 1;
              final isCompleted = stepNumber < currentStep;
              final isActive = stepNumber == currentStep;
              
              final isLast = index == totalSteps - 1;
              
              return Expanded(
                flex: isLast ? 0 : 1,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step Circle and Label
                    Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCompleted 
                                ? const Color(0xFF2B0E67) // Deep Purple
                                : isActive 
                                    ? Colors.white 
                                    : const Color(0xFFF6F6F6), // Light Grey
                            border: isActive 
                                ? Border.all(color: const Color(0xFF2B0E67), width: 2) 
                                : null,
                          ),
                          child: Center(
                            child: isCompleted
                                ? const Icon(Icons.check, color: Colors.white, size: 24)
                                : Text(
                                    "$stepNumber",
                                    style: TextStyle(
                                      color: isActive ? const Color(0xFF2B0E67) : Colors.grey.shade600,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          index < _stepTitles.length ? _stepTitles[index] : "Step $stepNumber",
                          style: TextStyle(
                            color: isCompleted || isActive ? const Color(0xFF2B0E67) : Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    
                    // Connecting Line
                    if (!isLast)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(top: 20),
                          height: 2,
                          color: isCompleted ? const Color(0xFF2B0E67) : Colors.grey.shade300,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
