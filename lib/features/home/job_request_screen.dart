import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tapasya_vendor_app/services/socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tapasya_vendor_app/services/api_service.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tapasya_vendor_app/features/home/vendor_provider.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/core/utils/job_payload_utils.dart';
import 'package:tapasya_vendor_app/core/utils/notification_helper.dart';
import 'package:tapasya_vendor_app/core/utils/native_job_alert.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';

/// Manual-mode only: Rapido-style Accept / Decline popup.
class JobRequestScreen extends StatefulWidget {
  final dynamic jobData;

  const JobRequestScreen({super.key, required this.jobData});

  static const int manualTimerSeconds = 10;

  @override
  State<JobRequestScreen> createState() => _JobRequestScreenState();
}

class _JobRequestScreenState extends State<JobRequestScreen> {
  late String bookingId;
  int timer = JobRequestScreen.manualTimerSeconds;
  Timer? countdown;
  bool isAcceptLoading = false;
  bool isDeclineLoading = false;
  bool isDetailsLoading = true;
  Map<String, dynamic>? fullJobData;

  @override
  void initState() {
    super.initState();
    final mapData = widget.jobData is Map ? Map<String, dynamic>.from(widget.jobData as Map) : <String, dynamic>{};
    final extracted = JobPayloadUtils.extractBookingId(mapData);
    final rawId = widget.jobData['booking_id'] ?? widget.jobData['id'];
    bookingId = extracted ?? rawId?.toString() ?? '';
    fullJobData = widget.jobData is Map
        ? Map<String, dynamic>.from(widget.jobData as Map)
        : null;

    if (bookingId.isNotEmpty) {
      NotificationHelper.activeJobPopups.add(bookingId);
    }

    debugPrint('📥 [MANUAL POPUP] id=$bookingId');

    // Remove the tray notification banner so only this popup is shown.
    NotificationHelper.cancelJobNotification(bookingId);

    startTimer();
    startContinuousAlert();
    fetchFullDetails();

    SocketService.listenForJobTaken((data) {
      if (isAcceptLoading || isDeclineLoading) return;
      final takenByVendorId = data['vendor_id']?.toString() ?? data['v_id']?.toString();
      final currentVendorId = context.read<VendorProvider>().profile?.vendor.id ?? '';

      if (data['booking_id']?.toString() == bookingId) {
        if (takenByVendorId != null && takenByVendorId == currentVendorId) return;
        if (mounted) {
          Navigator.pop(context);
          AppToast.show(context, '❌ Job already taken', isError: true);
        }
      }
    });
  }

  Future<void> fetchFullDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final data = await ApiService().getBookingDetails(token, bookingId);
    if (mounted && data != null) {
      setState(() {
        fullJobData = data['booking'] ?? data['data'] ?? data;
        isDetailsLoading = false;
      });
    } else if (mounted) {
      setState(() => isDetailsLoading = false);
    }
  }

  void startContinuousAlert() {
    final nativeSound = widget.jobData is Map &&
        widget.jobData['_nativeSoundActive'] == true;
    if (nativeSound) return;
    NotificationHelper.startJobAlertLoop(isAuto: false);
  }

  void startTimer() {
    countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (timer <= 1) {
        t.cancel();
        if (mounted) {
          NotificationHelper.stopJobAlertLoop();
          NativeJobAlert.stopSound();
          Navigator.pop(context);
        }
      } else if (mounted) {
        setState(() => timer--);
      }
    });
  }

  @override
  void dispose() {
    countdown?.cancel();
    NotificationHelper.stopJobAlertLoop();
    NotificationHelper.activeJobPopups.remove(bookingId);
    super.dispose();
  }

  Future<void> acceptJob() async {
    if (isAcceptLoading || isDeclineLoading) return;
    setState(() => isAcceptLoading = true);
    countdown?.cancel();

    // Stop job alert sound/vibration immediately
    NotificationHelper.stopJobAlertLoop();
    await NativeJobAlert.stopSound();
    await NotificationHelper.clearPendingJobAlertOnly();
    NotificationHelper.activeJobPopups.add(bookingId);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    if (!mounted || token.isEmpty) {
      if (mounted) setState(() => isAcceptLoading = false);
      return;
    }

    final vendorId = context.read<VendorProvider>().profile?.vendor.id ?? '';

    // Call POST /vendors/bookings/action with {"booking_id": bookingId, "action": "ACCEPTED"}
    final data = await ApiService().acceptBooking(token, bookingId, vendorId);
    if (!mounted) return;

    if (data['success'] == true) {
      // Success: Show toast, close popup, refresh jobs, redirect to Jobs screen
      await NotificationHelper.markJobHandled(bookingId);
      await context.read<VendorProvider>().refreshJobsAfterAccept();
      if (mounted) {
        AppToast.show(context, '🎉 Congratulations! You got the job.');
      }
      if (mounted && context.canPop()) {
        context.pop();
      }
      if (mounted) {
        context.go('/jobs');
      }
    } else {
      // Failure: DO NOT close popup, DO NOT redirect, show actual backend error message
      NotificationHelper.activeJobPopups.remove(bookingId);
      if (mounted) setState(() => isAcceptLoading = false);
      print("❌ [ACCEPT JOB FAILED] Response data: $data");
      final errorMsg = data['message']?.toString() ?? 'Error accepting job';
      if (mounted) AppToast.show(context, errorMsg, isError: true);
    }
  }

  Future<void> declineJob() async {
    if (isAcceptLoading || isDeclineLoading) return;
    setState(() => isDeclineLoading = true);
    countdown?.cancel();

    // Stop job alert sound/vibration immediately
    NotificationHelper.stopJobAlertLoop();
    await NativeJobAlert.stopSound();
    await NotificationHelper.clearPendingJobAlert();
    NotificationHelper.activeJobPopups.remove(bookingId);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    if (!mounted || token.isEmpty) {
      if (mounted) setState(() => isDeclineLoading = false);
      return;
    }

    final vendorId = context.read<VendorProvider>().profile?.vendor.id ?? '';
    final res = await ApiService().rejectBooking(token, bookingId, vendorId);
    if (!mounted) return;

    if (res['success'] == true) {
      await NotificationHelper.markJobHandled(bookingId);
      await context.read<VendorProvider>().refreshJobsAfterReject();
      if (mounted) {
        AppToast.show(context, 'Job declined');
      }
      if (mounted && context.canPop()) {
        context.pop();
      }
      if (mounted) {
        context.go('/jobs?tab=2');
      }
    } else {
      if (mounted) setState(() => isDeclineLoading = false);
      print("❌ [DECLINE JOB FAILED] Response data: $res");
      final errorMsg = res['message']?.toString() ?? 'Could not decline job';
      if (mounted) AppToast.show(context, errorMsg, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialJob = fullJobData ?? widget.jobData;
    final Map<String, dynamic> job = (initialJob is Map)
        ? (initialJob['booking'] ?? initialJob['data'] ?? initialJob)
        : {};

    dynamic getVal(List<String> keys, {dynamic fallback}) {
      for (final k in keys) {
        if (job[k] != null && job[k].toString().trim().isNotEmpty) return job[k];
        final lowerK = k.toLowerCase();
        for (final realK in job.keys) {
          if (realK.toLowerCase() == lowerK &&
              job[realK] != null &&
              job[realK].toString().trim().isNotEmpty) {
            return job[realK];
          }
        }
      }
      return fallback;
    }

    final customerName = getVal(
      [JobPayloadUtils.fcmUserName, 'customer_name', 'full_name', 'name'],
      fallback: 'New Customer',
    );

    final addressObj = job['address'] ?? job['location'] ?? job['addr'];
    String address = 'Location pending...';
    if (addressObj is Map) {
      address = addressObj['address_line1']?.toString() ??
          addressObj['address']?.toString() ??
          addressObj['formatted_address']?.toString() ??
          'Location pending...';
    } else if (addressObj != null && addressObj.toString().isNotEmpty) {
      address = addressObj.toString();
    } else {
      address = getVal(['formatted_address', 'address_line1'], fallback: 'Location pending...');
    }

    final servicesObj = job['services'] ?? job['services_list'] ?? job['service_details'];
    final services = servicesObj is List ? servicesObj : [];
    final profile = context.read<VendorProvider>().profile;
    final fallbackService = profile?.services.firstOrNull?.serviceName ?? 'Service Request';
    final fallbackSub = profile?.services.firstOrNull?.subServiceName ?? '';

    final mainService = services.isNotEmpty
        ? (services.first['service_name'] ?? services.first['service'] ?? fallbackService).toString()
        : getVal([JobPayloadUtils.fcmServiceName, 'service', 'category'], fallback: fallbackService);

    final subService = services.isNotEmpty
        ? (services.first['sub_service_name'] ?? services.first['sub_service'] ?? fallbackSub).toString()
        : getVal(['sub_service_name', 'sub_service', 'task'], fallback: fallbackSub);

    final amount = getVal(['amount', 'price', 'total_amount', 'service_charge', 'final_amount'], fallback: '');
    final distance =
        getVal([JobPayloadUtils.fcmDistanceKm, 'pickup_distance', 'distance'], fallback: '').toString();
    final timeSlot = getVal(['time_slot', 'slot', 'booking_time'], fallback: '').toString();

    return PopScope(
      canPop: false,
      child: Scaffold(
      backgroundColor: Colors.black54,
      body: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF22C55E), width: 2.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        amount.toString().isNotEmpty ? '₹$amount' : mainService,
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: timer <= 3 ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${timer}s',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: timer <= 3 ? Colors.red : Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (amount.toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subService.isNotEmpty ? subService : mainService,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 18),
                _infoRow(Icons.person_outline_rounded, 'Customer', customerName.toString()),
                const SizedBox(height: 12),
                _infoRow(Icons.location_on_outlined, 'Service Location', address),
                if (distance.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _infoRow(Icons.near_me_outlined, 'Distance', '$distance km away'),
                ],
                if (timeSlot.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _infoRow(Icons.schedule_outlined, 'Time Slot', timeSlot),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            disabledForegroundColor: const Color(0xFFDC2626).withOpacity(0.5),
                            padding: EdgeInsets.zero,
                            alignment: Alignment.center,
                            side: BorderSide(
                              color: isDeclineLoading ? const Color(0xFFDC2626).withOpacity(0.5) : const Color(0xFFDC2626),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          ),
                          onPressed: (isAcceptLoading || isDeclineLoading) ? null : () => declineJob(),
                          child: Center(
                            child: isDeclineLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFDC2626)),
                                  )
                                : const Text(
                                    'Decline',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.85),
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            alignment: Alignment.center,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          ),
                          onPressed: (isAcceptLoading || isDeclineLoading) ? null : () => acceptJob(),
                          child: Center(
                            child: isAcceptLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  )
                                : const Text(
                                    'Accept',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: const Color(0xFF16A34A)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
