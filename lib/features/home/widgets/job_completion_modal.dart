import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';
import 'package:tapasya_vendor_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CompletionStep { confirm, sendingOtp, enterOtp, processingPayout, success }

class JobCompletionModal extends StatefulWidget {
  final String bookingId;
  final String amount;
  final VoidCallback onComplete;
  final VoidCallback? onVerified;

  const JobCompletionModal({
    super.key,
    required this.bookingId,
    required this.amount,
    required this.onComplete,
    this.onVerified,
  });

  @override
  State<JobCompletionModal> createState() => _JobCompletionModalState();
}

class _JobCompletionModalState extends State<JobCompletionModal> {
  CompletionStep _currentStep = CompletionStep.confirm;
  bool _isLoading = false;
  String _errorMessage = '';
  final TextEditingController _otpController = TextEditingController();

  Future<bool> _onWillPop() async {
    if (_currentStep == CompletionStep.success) return true;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Cancel Completion?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to stop the completion process?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No, Stay")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Yes, Cancel", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _nextStep() {
    setState(() {
      final steps = CompletionStep.values;
      final nextIndex = _currentStep.index + 1;
      if (nextIndex < steps.length) {
        _currentStep = steps[nextIndex];
      }
    });
  }

  Future<void> _sendOtp() async {
    setState(() {
      _isLoading = true;
      _currentStep = CompletionStep.sendingOtp;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      final res = await ApiService().sendCompletionOtp(token, widget.bookingId);
      
      if (res['success'] == true) {
        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          _isLoading = false;
          _currentStep = CompletionStep.enterOtp;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = res['message'] ?? "Failed to send OTP";
          // If it fails, stay on confirm step but show toast
        });
        if (mounted) {
          AppToast.show(context, _errorMessage, isError: true);
          setState(() => _currentStep = CompletionStep.confirm);
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Connection error: $e";
        _currentStep = CompletionStep.confirm;
      });
      if (mounted) AppToast.show(context, _errorMessage, isError: true);
    }
  }

  Future<void> _verifyOtp(String pin) async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      final res = await ApiService().verifyCompletionOtp(token, widget.bookingId, pin);
      
      if (res['success'] == true) {
        HapticFeedback.heavyImpact();
        widget.onVerified?.call();
        setState(() {
          _isLoading = false;
          _currentStep = CompletionStep.processingPayout;
        });
      } else {
        setState(() {
          _isLoading = false;
          _otpController.clear();
        });
        if (mounted) {
          AppToast.show(context, res['message'] ?? "Invalid OTP", isError: true);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppToast.show(context, "Verification error: $e", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: animation.drive(Tween(begin: const Offset(0, 0.1), end: Offset.zero)),
              child: child,
            ),
          ),
          child: _buildCurrentStep(),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case CompletionStep.confirm:
        return _buildConfirmStep();
      case CompletionStep.sendingOtp:
        return _buildSendingOtpStep();
      case CompletionStep.enterOtp:
        return _buildOtpEntryStep();
      case CompletionStep.processingPayout:
        return _buildPayoutProcessingStep();
      case CompletionStep.success:
        return _buildSuccessStep();
    }
  }

  Widget _buildConfirmStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.help_outline_rounded, color: Colors.orange, size: 48),
          ),
          const SizedBox(height: 24),
          const Text(
            "Confirm Completion",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0D1B2A)),
          ),
          const SizedBox(height: 12),
          Text(
            "Are you sure the work is completed?\nWe will send an OTP to the customer to verify.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.5, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: _sendOtp,
                  child: const Text("Yes, Complete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSendingOtpStep() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          const CircularProgressIndicator(color: AppTheme.primaryColor),
          const SizedBox(height: 32),
          const Text(
            "Sending OTP...",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0D1B2A)),
          ),
          const SizedBox(height: 12),
          Text(
            "Requesting a secure verification code from the customer.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOtpEntryStep() {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: const TextStyle(fontSize: 22, color: Color(0xFF1B263B), fontWeight: FontWeight.w700),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.lock_person_rounded, color: Colors.green, size: 32),
          ),
          const SizedBox(height: 24),
          const Text(
            "Enter Customer OTP",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0D1B2A)),
          ),
          const SizedBox(height: 8),
          Text(
            "Ask customer for the 6-digit code sent to them",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 32),
          Pinput(
            length: 6,
            controller: _otpController,
            defaultPinTheme: defaultPinTheme,
            focusedPinTheme: defaultPinTheme.copyWith(
              decoration: defaultPinTheme.decoration!.copyWith(border: Border.all(color: AppTheme.primaryColor, width: 2)),
            ),
            hapticFeedbackType: HapticFeedbackType.lightImpact,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: _isLoading
                  ? null
                  : () {
                      final otp = _otpController.text.trim();

                      if (otp.length != 6) {
                        AppToast.show(
                          context,
                          "Please enter the 6-digit OTP",
                          isError: true,
                        );
                        return;
                      }

                      _verifyOtp(otp);
                    },
              child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Verify OTP", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() => _currentStep = CompletionStep.confirm),
            child: Text("Didn't receive OTP? Resend", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutProcessingStep() {
    return _PayoutTimelineStep(
      onFinished: () {
        setState(() => _currentStep = CompletionStep.success);
      },
    );
  }

  Widget _buildSuccessStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.green.shade400, Colors.green.shade700]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
          ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 32),
          const Text(
            "Job Completed Successfully!",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0D1B2A)),
          ),
          const SizedBox(height: 8),
          Text(
            "Payment has been initiated and will reflect shortly",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              children: [
                const Text("TOTAL EARNINGS", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 8),
                Text(
                  "₹${widget.amount}",
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF1B263B)),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_balance_rounded, color: Colors.green.shade700, size: 14),
                      const SizedBox(width: 8),
                      Text("Transferring to Bank", style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D1B2A),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(context, true);
                widget.onComplete();
              },
              child: const Text("Go to Dashboard", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoutTimelineStep extends StatefulWidget {
  final VoidCallback onFinished;
  const _PayoutTimelineStep({required this.onFinished});

  @override
  State<_PayoutTimelineStep> createState() => _PayoutTimelineStepState();
}

class _PayoutTimelineStepState extends State<_PayoutTimelineStep> {
  int _activeStep = 0;
  final List<String> _steps = [
    "OTP Verified",
    "Completing Job",
    "Calculating Earnings",
    "Initiating Payout",
    "Transferring to Bank",
    "Payment Successful"
  ];

  @override
  void initState() {
    super.initState();
    _startTimeline();
  }

  void _startTimeline() async {
    for (int i = 0; i < _steps.length; i++) {
      await Future.delayed(Duration(milliseconds: 800 + (i * 200)));
      if (mounted) {
        setState(() => _activeStep = i + 1);
        HapticFeedback.selectionClick();
      }
    }
    await Future.delayed(const Duration(milliseconds: 1000));
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Finalizing Job",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0D1B2A)),
          ),
          const SizedBox(height: 8),
          Text(
            "Please wait while we process your payout",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
          const SizedBox(height: 40),
          ...List.generate(_steps.length, (index) {
            final isCompleted = index < _activeStep;
            final isCurrent = index == _activeStep;
            final isPending = index > _activeStep;

            return IntrinsicHeight(
              child: Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted ? Colors.green : (isCurrent ? AppTheme.primaryColor : Colors.grey.shade200),
                        ),
                        child: isCompleted
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : (isCurrent
                                ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : null),
                      ),
                      if (index != _steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: isCompleted ? Colors.green : Colors.grey.shade200,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        _steps[index],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                          color: isPending ? Colors.grey.shade400 : (isCompleted ? Colors.green.shade800 : const Color(0xFF0D1B2A)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
