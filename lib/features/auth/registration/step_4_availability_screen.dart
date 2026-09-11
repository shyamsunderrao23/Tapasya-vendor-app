import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/features/auth/registration/registration_state.dart';
import 'package:tapasya_vendor_app/features/auth/widgets/premium_scale_button.dart';
import 'package:tapasya_vendor_app/services/api_service.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';

class Step4AvailabilityScreen extends StatefulWidget {
  const Step4AvailabilityScreen({super.key});

  @override
  State<Step4AvailabilityScreen> createState() => _Step4AvailabilityScreenState();
}

class _Step4AvailabilityScreenState extends State<Step4AvailabilityScreen> {
  bool _isLoading = false;
  final ApiService _apiService = ApiService();
  
  // All 7 days active by default with full shifts
  List<Map<String, dynamic>> _availability = [
    {"day": "Monday",    "start_time": "09:00:00", "end_time": "18:00:00", "is_available": 1},
    {"day": "Tuesday",   "start_time": "09:00:00", "end_time": "18:00:00", "is_available": 1},
    {"day": "Wednesday", "start_time": "09:00:00", "end_time": "18:00:00", "is_available": 1},
    {"day": "Thursday",  "start_time": "09:00:00", "end_time": "18:00:00", "is_available": 1},
    {"day": "Friday",    "start_time": "09:00:00", "end_time": "18:00:00", "is_available": 1},
    {"day": "Saturday",  "start_time": "09:00:00", "end_time": "18:00:00", "is_available": 1},
    {"day": "Sunday",    "start_time": "09:00:00", "end_time": "18:00:00", "is_available": 1},
  ];

  @override
  void initState() {
    super.initState();
    debugPrint("📱 [REGISTRATION] Entered Step 4: Your Availability");
    _fetchCurrentAvailability();
  }

  Future<void> _fetchCurrentAvailability() async {
    final state = context.read<RegistrationState>();
    if (state.authToken.isEmpty) {
      debugPrint("⚠️ [STEP 4] No auth token found, skipping availability sync");
      return;
    }

    debugPrint("🔄 [STEP 4] Syncing availability from backend DB...");
    try {
      var response = await _apiService.getAvailability(state.authToken);
      
      // 🛡️ RECOVERY: If 401, try to refresh token once
      if (response['success'] == false && (response['message']?.contains('401') == true || response['message']?.contains('Unauthorized') == true)) {
        debugPrint("🔄 [STEP 4] 401 Detected. Attempting token refresh...");
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final idToken = await user.getIdToken(true) ?? "";
          final loginResponse = await _apiService.loginVendor(idToken);
            if (loginResponse != null && loginResponse['success'] == true) {
              final newToken = loginResponse['data']?['jwt_token'] ?? loginResponse['data']?['token'];
              if (newToken != null) {
                await state.updateRegistrationToken(newToken);
                // Retry sync with new token
                response = await _apiService.getAvailability(newToken);
              }
            }
          }
        }

        if (response['success'] == true && response['availability'] != null) {
          final List backendData = response['availability'];
        debugPrint("📥 [STEP 4] Found ${backendData.length} availability slots in DB.");
        if (backendData.isNotEmpty) {
          setState(() {
            _availability = backendData.map((e) => {
              "day": e['day'],
              "start_time": e['start_time'],
              "end_time": e['end_time'],
              "is_available": e['is_available'] is bool 
                  ? (e['is_available'] ? 1 : 0) 
                  : (e['is_available'] ?? 1),
            }).toList();
          });
          debugPrint("✅ [STEP 4] Local state synced with Backend Availability.");
        }
      }
    } catch (e) {
      debugPrint("❌ [STEP 4 SYNC EXCEPTION] $e");
    }
  }

  Future<void> _onFinish() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    
    final state = context.read<RegistrationState>();
    debugPrint("🚀 [STEP 4] Finalizing Availability Settings...");

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("❌ [STEP 4] Auth Session Invalid");
        throw "Authentication session expired.";
      }
      
      debugPrint("🔥 [STEP 4] Refreshing Firebase Token...");
      String? freshToken = await user.getIdToken(true);
      if (freshToken == null) throw "Failed to get token.";

      debugPrint("🔥 [STEP 4] Exchanging Firebase Token for Backend JWT...");
      final loginResponse = await _apiService.loginVendor(freshToken);
      String? backendJwt;
      if (loginResponse != null && loginResponse['success'] == true) {
        final data = loginResponse['data'] ?? {};
        backendJwt = loginResponse['token'] ?? loginResponse['jwt_token'] ?? data['jwt_token'] ?? data['token'];
        if (backendJwt != null) {
          debugPrint("✅ [STEP 4] Received Fresh Backend JWT");
          state.updateRegistrationToken(backendJwt);
        }
      }
      
      final tokenToUse = backendJwt ?? state.authToken;
      if (tokenToUse.isEmpty) throw "Failed to retrieve backend authorization token.";

      debugPrint("📤 [STEP 4] Submitting Availability to Backend: ${_availability.length} days.");
      final response = await _apiService.setAvailability(tokenToUse, _availability);
      
      debugPrint("📥 [STEP 4] API Response Status: ${response != null && response['success'] == true ? 'SUCCESS' : 'FAILURE'}");
      if (response != null) {
        debugPrint("📥 [STEP 4] Full Response Body: $response");
      }

      if (response != null && response['success'] == true) {
        debugPrint("✅ [STEP 4] Availability Saved. Proceeding to Verification...");
        state.completeAvailability();
        if (mounted) context.push('/register/verification');
      } else {
        final errorMsg = response?['message'] ?? "Failed to set availability.";
        debugPrint("❌ [STEP 4] API Error: $errorMsg");
        if (mounted) AppToast.show(context, errorMsg, isError: true);
      }
    } catch (e) {
      debugPrint("❌ [STEP 4 EXCEPTION] $e");
      if (mounted) AppToast.show(context, "Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Premium Bubble Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 30),
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(50),
                bottomRight: Radius.circular(50),
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _AvailabilityBubblePainter())),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                // Back button (<)
                                GestureDetector(
                                  onTap: () => context.canPop() ? context.pop() : context.go('/register/step3'),
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
                                const SizedBox(width: 8),
                                // Next button (>)
                                GestureDetector(
                                  onTap: context.read<RegistrationState>().hasCompletedAvailability 
                                      ? () => context.push('/register/verification') 
                                      : null,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: context.read<RegistrationState>().hasCompletedAvailability 
                                          ? Colors.white.withOpacity(0.15) 
                                          : Colors.white.withOpacity(0.05),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward_rounded, 
                                      color: context.read<RegistrationState>().hasCompletedAvailability ? Colors.white : Colors.white24, 
                                      size: 20
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                "STEP 5 OF 6",
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "Your Availability",
                          style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Set the hours you're available to work each week",
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor, size: 20),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "You are active by default for all days. Change timings or toggle off as needed.",
                            style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _availability.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _availability[index];
                      final isEnabled = item['is_available'] == 1;
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isEnabled ? AppTheme.primaryColor.withOpacity(0.2) : const Color(0xFFE5E7EB),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['day'],
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111827)),
                                  ),
                                  const SizedBox(height: 8),
                                  if (isEnabled)
                                    Row(
                                      children: [
                                        _buildTimePickerPill(_formatTime(item['start_time']), () => _selectTime(item, 'start_time')),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 8),
                                          child: Text("-", style: TextStyle(color: Colors.grey)),
                                        ),
                                        _buildTimePickerPill(_formatTime(item['end_time']), () => _selectTime(item, 'end_time')),
                                      ],
                                    )
                                  else
                                    const Text("Unavailable", style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: isEnabled,
                              activeColor: AppTheme.primaryColor,
                              onChanged: (val) {
                                debugPrint("📅 [STEP 4] Toggling ${item['day']} to ${val ? 'Available' : 'Unavailable'}");
                                setState(() => item['is_available'] = val ? 1 : 0);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 48),

                  PremiumScaleButton(
                    onTap: _isLoading ? null : _onFinish,
                    child: Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "NEXT", 
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                letterSpacing: 1.2,
                              )
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  String _formatTime(String time) {
    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return "$displayHour:${minute.toString().padLeft(2, '0')} $period";
    } catch (e) {
      return time;
    }
  }

  Future<void> _selectTime(Map<String, dynamic> item, String field) async {
    final current = item[field].split(':');
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(current[0]), minute: int.parse(current[1])),
    );

    if (pickedTime != null) {
      final String formatted = "${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}:00";
      debugPrint("⏰ [STEP 4] Updated ${item['day']} $field to: $formatted");
      setState(() {
        item[field] = formatted;
      });
    }
  }

  Widget _buildTimePickerPill(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }
}

class _AvailabilityBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.05)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.2), 40, paint);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.1), 60, paint);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.8), 50, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
