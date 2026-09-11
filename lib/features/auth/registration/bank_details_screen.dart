import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/features/auth/registration/registration_state.dart';
import 'package:tapasya_vendor_app/features/auth/widgets/premium_form_widgets.dart';
import 'package:tapasya_vendor_app/features/auth/widgets/premium_scale_button.dart';
import 'package:tapasya_vendor_app/services/api_service.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';

class BankDetailsScreen extends StatefulWidget {
  const BankDetailsScreen({super.key});

  @override
  State<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends State<BankDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _holderNameController;
  late TextEditingController _accountNumberController;
  late TextEditingController _ifscController;
  late TextEditingController _bankNameController;
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    debugPrint("📱 [REGISTRATION] Entered Bank Details Screen");
    final state = context.read<RegistrationState>();
    _holderNameController = TextEditingController(text: state.accountHolderName);
    _accountNumberController = TextEditingController(text: state.accountNumber);
    _ifscController = TextEditingController(text: state.ifscCode);
    _bankNameController = TextEditingController(text: state.bankName);

    // ✅ Listen for IFSC changes to auto-populate Bank Name via API
    _ifscController.addListener(() async {
      final ifsc = _ifscController.text.toUpperCase().trim();
      
      // We only call the API if it's exactly 11 characters (Standard IFSC length)
      if (ifsc.length == 11) {
        debugPrint("🔍 [BANK] IFSC reached 11 chars. Triggering API lookup: $ifsc");
        
        // Temporarily show loading state in the field
        _bankNameController.text = "Fetching bank details...";
        
        final data = await _apiService.getBankDetails(ifsc);
        
        if (mounted && _ifscController.text.toUpperCase().trim() == ifsc) {
          if (data != null) {
            final String bank = data['BANK'] ?? "Unknown Bank";
            final String branch = data['BRANCH'] ?? "";
            _bankNameController.text = branch.isNotEmpty ? "$bank ($branch)" : bank;
            debugPrint("✅ [BANK] Auto-filled: ${_bankNameController.text}");
          } else {
            _bankNameController.text = "Invalid IFSC Code";
            AppToast.show(context, "Please enter a valid IFSC code", isError: true);
          }
        }
      } else if (ifsc.length < 11 && _bankNameController.text.isNotEmpty) {
        // Clear if they start editing again
        _bankNameController.clear();
      }
    });
  }

  @override
  void dispose() {
    _holderNameController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final state = context.read<RegistrationState>();

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      debugPrint("🚀 [BANK] Starting immediate verification via Cashfree...");
      debugPrint("📤 [BANK] Account: ${_accountNumberController.text.trim()}");
      debugPrint("📤 [BANK] IFSC: ${_ifscController.text.toUpperCase().trim()}");
      debugPrint("📤 [BANK] Holder: ${_holderNameController.text.trim()}");

      try {
        final response = await _apiService.verifyBank(
          state.authToken,
          state.vendorId,
          _accountNumberController.text.trim(),
          _ifscController.text.toUpperCase().trim(),
          _holderNameController.text.trim(),
          _bankNameController.text.trim(),
        );

        debugPrint("📥 [BANK API RESPONSE] $response");

        if (response != null && response['success'] == true) {
          final bool isNameMatch = response['name_match'] ?? true;
          debugPrint("🔍 [BANK] Name Match Outcome: $isNameMatch");

          state.updateBankDetails(
            bankName: _bankNameController.text.trim(),
            accountNumber: _accountNumberController.text.trim(),
            ifscCode: _ifscController.text.toUpperCase().trim(),
            accountHolderName: _holderNameController.text.trim(),
            status: 'approved',
          );
          debugPrint("✅ [BANK] Bank details approved in Backend DB");
          
          if (mounted) {
            if (isNameMatch) {
              AppToast.show(context, "Bank Verified Successfully! ✅");
            } else {
              AppToast.show(context, "Bank Verified but Name Mismatch ⚠️", isError: false);
            }
            context.pop();
          }
        } else {
          final errorMsg = response?['message'] ?? "Verification Failed ❌";
          debugPrint("❌ [BANK] API Error: $errorMsg");
          if (mounted) {
            AppToast.show(context, errorMsg, isError: true);
          }
        }
      } catch (e) {
        debugPrint("❌ [BANK EXCEPTION] $e");
        if (mounted) {
          AppToast.show(context, "An error occurred during verification: $e", isError: true);
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RegistrationState>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.blackColor),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          "Bank Account Details",
          style: TextStyle(color: AppTheme.blackColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  PremiumTextField(
                    controller: _holderNameController,
                    label: "Account Holder Name",
                    hint: "As per bank records",
                    readOnly: state.bankStatus == 'approved',
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 16),
                  PremiumTextField(
                    controller: _bankNameController,
                    label: "Bank Name",
                    hint: "Auto-filled from IFSC",
                    readOnly: true, // Always read-only as it's driven by IFSC
                    validator: (v) => v!.isEmpty || v == "Unknown Bank" ? "Enter valid IFSC" : null,
                  ),
                  const SizedBox(height: 16),
                  PremiumTextField(
                    controller: _accountNumberController,
                    label: "Account Number",
                    hint: "Enter account number",
                    keyboardType: TextInputType.number,
                    readOnly: state.bankStatus == 'approved',
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 16),
                  PremiumTextField(
                    controller: _ifscController,
                    label: "IFSC Code",
                    hint: "e.g. HDFC0001234",
                    readOnly: state.bankStatus == 'approved',
                    onChanged: (v) => _ifscController.value = _ifscController.value.copyWith(
                      text: v.toUpperCase(),
                      selection: TextSelection.collapsed(offset: v.length),
                    ),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            
            _isLoading 
              ? const CircularProgressIndicator(color: AppTheme.primaryColor)
              : PremiumScaleButton(
                  onTap: state.bankStatus == 'approved' ? null : _onSave,
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: state.bankStatus == 'approved' ? null : AppTheme.primaryGradient,
                      color: state.bankStatus == 'approved' ? Colors.grey.shade400 : null,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Center(
                      child: Text(
                        state.bankStatus == 'approved' ? "Done ✅" : "Verify Bank Account",
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 16),
            if (state.bankStatus != 'approved')
            Text(
              "Instant verification via Cashfree Pay",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
