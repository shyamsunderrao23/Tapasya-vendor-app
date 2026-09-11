import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tapasya_vendor_app/core/utils/job_navigation_utils.dart';
import 'package:tapasya_vendor_app/core/utils/job_payload_utils.dart';
import 'package:tapasya_vendor_app/core/utils/native_job_alert.dart';
import 'package:tapasya_vendor_app/core/utils/notification_helper.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';
import 'package:tapasya_vendor_app/main.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tapasya_vendor_app/features/home/vendor_provider.dart';
import 'package:tapasya_vendor_app/services/api_service.dart';

/// Central gate for new-job alerts: only online + logged-in vendors get sound/UI.
class JobAlertHandler {
  /// Set from HomeScreen — shows the Rapido-style overlay popup.
  static void Function(Map<String, dynamic> data)? showJobPopup;

  static bool _processingPending = false;
  static bool _processingLaunchAction = false;

  static String? _bookingId(Map<String, dynamic> data) {
    return JobPayloadUtils.extractBookingId(data);
  }

  static Future<bool> shouldReceiveJobAlert() async {
    return NotificationHelper.canReceiveJobAlerts();
  }

  /// Show popup + loud sound immediately (foreground / socket / pending queue).
  static Future<void> handleIncomingJob(
    BuildContext? context,
    Map<String, dynamic> rawData, {
    VoidCallback? onManualPopup,
    String? eventSource,
    bool showTrayNotification = false,
  }) async {
    if (!await shouldReceiveJobAlert()) {
      debugPrint('🔕 [JOB ALERT] Blocked — vendor offline or logged out');
      return;
    }

    final data = JobPayloadUtils.normalize(rawData, eventSource: eventSource);
    final bookingId = _bookingId(data);
    if (bookingId == null) {
      debugPrint('❌ [JOB ALERT] No booking id in payload: $rawData');
      return;
    }

    if (await NotificationHelper.isJobHandled(bookingId)) {
      debugPrint('🚫 [JOB ALERT] Already handled: $bookingId');
      return;
    }

    final jobStatus = (data['status'] ?? data['booking_status'] ?? data['booking']?['status'] ?? '').toString().toLowerCase();
    if (jobStatus == 'accepted' || jobStatus == 'in_progress' || jobStatus == 'started' || jobStatus == 'completed' || jobStatus == 'cancelled' || jobStatus == 'rejected') {
      await NotificationHelper.markJobHandled(bookingId);
      debugPrint('🚫 [JOB ALERT] Job status is "$jobStatus" — skipping popup for $bookingId');
      return;
    }

    if (NotificationHelper.activeJobPopups.contains(bookingId)) {
      debugPrint('🚫 [JOB ALERT] Duplicate ignored: $bookingId');
      return;
    }

    String vendorJobMode = 'manual';
    if (context != null) {
      try {
        vendorJobMode = context.read<VendorProvider>().profile?.vendor.jobMode ?? 'manual';
      } catch (_) {}
    } else {
      final prefs = await SharedPreferences.getInstance();
      vendorJobMode = prefs.getString(NotificationHelper.prefJobMode) ?? 'manual';
    }

    // V1 REQUIREMENT: STRICTLY MANUAL MODE ONLY
    // final isAuto = JobPayloadUtils.isAutoAssign(data, vendorJobMode: vendorJobMode);
    final isAuto = false; 
    debugPrint('🔔 [JOB ALERT] id=$bookingId auto=$isAuto source=$eventSource (FORCED MANUAL FOR V1)');

    // Manual jobs — always use the unified popup path (works in-app + fallback navigator).
    if (!isAuto) {
      // Play sound and vibrate EXACTLY ONCE for the foreground popup
      await NotificationHelper.playNotificationSound(isAuto: false);
      await NotificationHelper.vibrate(isAuto: false);

      if (onManualPopup != null) {
        NotificationHelper.activeJobPopups.add(bookingId);
        onManualPopup();
        return;
      }
      await presentJobPopup(data);
      return;
    }

    if (showTrayNotification && !isAuto) {
      await NotificationHelper.showJobAlertNotification(
        bookingId: bookingId,
        data: data,
        isAuto: false,
        skipPendingSave: true,
      );
    }

    var shownNow = false;

    if (onManualPopup != null) {
      onManualPopup();
      shownNow = true;
    } else if (showJobPopup != null) {
      showJobPopup!(data);
      shownNow = true;
    } else {
      final nav = context ?? navigatorKey.currentContext;
      if (nav != null && nav.mounted) {
        if (isAuto) {
          nav.push('/auto-job-assigned', extra: data);
        } else {
          nav.push('/job-request', extra: data);
        }
        shownNow = true;
      }
    }

    if (!shownNow) {
      await NotificationHelper.savePendingJobAlert(data, isAuto: isAuto);
      await NotificationHelper.playNotificationSound(isAuto: isAuto);
      await NotificationHelper.vibrate(isAuto: isAuto);
      debugPrint('⏳ [JOB ALERT] Popup deferred — saved pending for $bookingId');
    }
  }

  /// FCM background — loud notification + custom sound on arrival.
  static Future<void> handleBackgroundMessage(Map<String, dynamic> rawData) async {
    if (!await shouldReceiveJobAlert()) {
      debugPrint('🔕 [BG JOB] Blocked — vendor offline or logged out');
      return;
    }

    final data = JobPayloadUtils.normalize(
      rawData,
      eventSource: rawData[JobPayloadUtils.fcmType]?.toString(),
    );
    final bookingId = _bookingId(data);
    if (bookingId == null) {
      debugPrint('❌ [BG JOB] No booking id: $rawData');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final vendorJobMode = prefs.getString(NotificationHelper.prefJobMode) ?? 'manual';
    // V1 REQUIREMENT: STRICTLY MANUAL MODE ONLY
    // final isAuto = JobPayloadUtils.isAutoAssign(data, vendorJobMode: vendorJobMode);
    final isAuto = false;

    debugPrint('📬 [BG JOB] Notification + sound on arrival id=$bookingId auto=$isAuto (FORCED MANUAL FOR V1)');

    // Always save + notify — native overlay may also open in parallel on Android.
    await NotificationHelper.savePendingJobAlert(data, isAuto: isAuto);
    await NotificationHelper.showJobAlertNotification(
      bookingId: bookingId,
      data: data,
      isAuto: isAuto,
      skipPendingSave: true,
    );
    if (!isAuto) {
      await NotificationHelper.playNotificationSound(isAuto: false);
      await NotificationHelper.vibrate(isAuto: false);
    }
  }

  /// Show the same Flutter popup used in-app (background FCM / lock screen).
  static Future<void> presentJobPopup(
    Map<String, dynamic> rawData, {
    bool nativeSoundActive = false,
  }) async {
    if (!await shouldReceiveJobAlert()) return;

    final data = JobPayloadUtils.normalize(rawData);
    final bookingId = _bookingId(data);
    if (bookingId == null) return;

    if (await NotificationHelper.isJobHandled(bookingId)) {
      debugPrint('🚫 [PRESENT] Already handled: $bookingId');
      return;
    }

    if (NotificationHelper.activeJobPopups.contains(bookingId)) {
      debugPrint('🚫 [PRESENT] Already showing: $bookingId');
      return;
    }

    if (nativeSoundActive) {
      data['_nativeSoundActive'] = true;
    }

    NotificationHelper.activeJobPopups.add(bookingId);
    await NotificationHelper.clearPendingJobAlert();
    await NotificationHelper.cancelJobNotification(bookingId);

    for (var i = 0; i < 40; i++) {
      if (showJobPopup != null) {
        showJobPopup!(data);
        return;
      }

      final nav = navigatorKey.currentContext;
      if (nav != null && nav.mounted) {
        await nav.push('/job-request', extra: data);
        return;
      }

      await Future.delayed(const Duration(milliseconds: 150));
    }

    debugPrint('⏳ [PRESENT] Navigator not ready — saved pending for $bookingId');
    NotificationHelper.activeJobPopups.remove(bookingId);
    await NotificationHelper.savePendingJobAlert(data, isAuto: false);
  }

  /// Process job saved when notification arrived while app was background/killed.
  static Future<void> processPendingJobAlert() async {
    if (_processingPending || _processingLaunchAction) return;
    if (!await shouldReceiveJobAlert()) return;

    _processingPending = true;
    try {
      final launchPayload = await NotificationHelper.consumeLaunchJobPayload();
      if (launchPayload != null && launchPayload.payload.isNotEmpty) {
        debugPrint('🚀 [PENDING] Processing launch action=${launchPayload.actionId}');
        _processingLaunchAction = true;
        try {
          await handleNotificationTap(
            launchPayload.payload,
            actionId: launchPayload.actionId,
          );
        } finally {
          _processingLaunchAction = false;
        }
        return;
      }

      final pending = await NotificationHelper.consumePendingJobAlert();
      if (pending == null) return;

      final rawData = pending['data'] is Map
          ? Map<String, dynamic>.from(pending['data'] as Map)
          : <String, dynamic>{};
      final data = JobPayloadUtils.normalize(rawData);
      final bookingId = _bookingId(data);
      if (bookingId == null) return;

      if (await NotificationHelper.isJobHandled(bookingId)) {
        debugPrint('🚫 [PENDING] Already handled: $bookingId');
        return;
      }

      final pendingAction = pending['pendingAction']?.toString();
      if (pendingAction != null && pendingAction.isNotEmpty) {
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          final prefs = await SharedPreferences.getInstance();
          final vendorJobMode = prefs.getString(NotificationHelper.prefJobMode) ?? 'manual';
          final isAuto = JobPayloadUtils.isAutoAssign(data, vendorJobMode: vendorJobMode);
          debugPrint('🚀 [PENDING] Running deferred action=$pendingAction for $bookingId');
          await _routeNotificationAction(
            context,
            payloadData: data,
            bookingId: bookingId,
            isAuto: isAuto,
            actionId: pendingAction,
          );
          return;
        }
      }

      if (NotificationHelper.activeJobPopups.contains(bookingId)) {
        debugPrint('🚫 [PENDING] Already showing: $bookingId');
        return;
      }

      debugPrint('🚀 [PENDING] Auto-opening popup for $bookingId');
      await presentJobPopup(data);
    } finally {
      _processingPending = false;
    }
  }

  /// Notification tap / action button / full-screen intent.
  static Future<void> handleNotificationResponse(NotificationResponse response) async {
    await handleNotificationTap(
      response.payload ?? '',
      actionId: response.actionId,
    );
  }

  /// Notification tap / full-screen intent — route by action or show popup.
  static Future<void> handleNotificationTap(String payload, {String? actionId}) async {
    if (payload.isEmpty) return;
    if (!await shouldReceiveJobAlert()) return;

    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      final rawData = decoded['data'] is Map
          ? Map<String, dynamic>.from(decoded['data'] as Map)
          : <String, dynamic>{};
      final data = JobPayloadUtils.normalize(rawData);
      final bookingId = decoded['booking_id']?.toString() ?? _bookingId(data) ?? '';

      if (bookingId.isEmpty) return;

      if (await NotificationHelper.isJobHandled(bookingId)) {
        debugPrint('🚫 [JOB TAP] Already handled: $bookingId');
        return;
      }

      await NotificationHelper.clearPendingJobAlert();

      final prefs = await SharedPreferences.getInstance();
      final vendorJobMode = prefs.getString(NotificationHelper.prefJobMode) ?? 'manual';
      final isAuto = JobPayloadUtils.isAutoAssign(data, vendorJobMode: vendorJobMode);

      NotificationHelper.stopJobAlertLoop();

      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) {
        await NotificationHelper.savePendingJobAlert(
          data,
          isAuto: isAuto,
          pendingAction: actionId,
        );
        return;
      }

      final payloadData = data.isNotEmpty ? data : {'booking_id': bookingId};
      await _routeNotificationAction(
        context,
        payloadData: payloadData,
        bookingId: bookingId,
        isAuto: isAuto,
        actionId: actionId,
      );
    } catch (e) {
      debugPrint('⚠️ [JOB TAP] Invalid payload: $payload — $e');
    }
  }

  static Future<void> _routeNotificationAction(
    BuildContext context, {
    required Map<String, dynamic> payloadData,
    required String bookingId,
    required bool isAuto,
    String? actionId,
  }) async {
    final jobStatus = (payloadData['status'] ?? payloadData['booking_status'] ?? payloadData['booking']?['status'] ?? '').toString().toLowerCase();
    final bool isAlreadyAccepted = jobStatus == 'accepted' || jobStatus == 'in_progress' || jobStatus == 'started';

    if (isAuto || isAlreadyAccepted) {
      if (actionId == NotificationHelper.actionNavigate) {
        NotificationHelper.stopJobAlertLoop();
        NotificationHelper.activeJobPopups.remove(bookingId);
        await JobNavigationUtils.openMaps(payloadData);
        return;
      }

      // Auto job or already accepted job — navigate directly to Job Details Screen
      NotificationHelper.stopJobAlertLoop();
      await NativeJobAlert.stopSound();
      await NotificationHelper.markJobHandled(bookingId);
      await NotificationHelper.clearPendingJobAlert();
      await NotificationHelper.cancelJobNotification(bookingId);
      if (context.mounted) {
        context.push('/jobs/details/$bookingId', extra: payloadData);
      }
      return;
    }

    // Manual — Accept/Decline from native popup, or show in-app popup.
    if (actionId == 'accept') {
      await _acceptManualJobAndNavigate(
        context,
        bookingId: bookingId,
        payloadData: payloadData,
      );
      return;
    }

    if (actionId == 'decline') {
      await _declineManualJob(context, bookingId: bookingId);
      return;
    }

    if (!NotificationHelper.activeJobPopups.contains(bookingId)) {
      NotificationHelper.activeJobPopups.add(bookingId);
    }

    if (showJobPopup != null) {
      showJobPopup!(payloadData);
    } else {
      context.push('/job-request', extra: payloadData);
    }
  }

  static Future<void> _acceptManualJobAndNavigate(
    BuildContext context, {
    required String bookingId,
    required Map<String, dynamic> payloadData,
  }) async {
    // 4. Stop job alert sound/vibration immediately
    NotificationHelper.stopJobAlertLoop();
    await NativeJobAlert.stopSound();
    NotificationHelper.activeJobPopups.add(bookingId);
    await NotificationHelper.clearPendingJobAlertOnly();
    await NotificationHelper.cancelJobNotification(bookingId);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    if (token.isEmpty || !context.mounted) return;

    final vendorId = context.read<VendorProvider>().profile?.vendor.id ?? '';

    // 5. & 6. Call POST /vendors/bookings/action with {"booking_id": bookingId, "action": "ACCEPTED"} and JWT header
    final result = await ApiService().acceptBooking(token, bookingId, vendorId);
    if (!context.mounted) return;

    if (result['success'] == true) {
      // 8. Success: Show toast, close popup overlay if open, refresh jobs, redirect to Jobs screen
      await NotificationHelper.markJobHandled(bookingId);
      if (context.mounted) {
        await context.read<VendorProvider>().refreshJobsAfterAccept();
      }
      if (context.mounted) {
        AppToast.show(context, '🎉 Congratulations! You got the job.');
      }
      if (context.canPop()) {
        context.pop();
      }
      if (context.mounted) {
        context.go('/jobs');
      }
    } else {
      // 9. Failure: DO NOT close popup, DO NOT redirect, show actual backend error message
      NotificationHelper.activeJobPopups.remove(bookingId);
      print("❌ [ACCEPT MANUAL JOB FAILED] Response: $result");
      AppToast.show(
        context,
        result['message']?.toString() ?? 'Error accepting job',
        isError: true,
      );
    }
  }

  static Future<void> _declineManualJob(
    BuildContext context, {
    required String bookingId,
  }) async {
    NotificationHelper.stopJobAlertLoop();
    await NativeJobAlert.stopSound();
    NotificationHelper.activeJobPopups.remove(bookingId);
    await NotificationHelper.clearPendingJobAlert();
    await NotificationHelper.cancelJobNotification(bookingId);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    if (token.isEmpty || !context.mounted) return;

    final vendorId = context.read<VendorProvider>().profile?.vendor.id ?? '';
    final result = await ApiService().rejectBooking(token, bookingId, vendorId);
    if (!context.mounted) return;

    if (result['success'] == true) {
      await NotificationHelper.markJobHandled(bookingId);
      if (context.mounted) {
        await context.read<VendorProvider>().refreshJobsAfterReject();
      }
      if (context.mounted && context.canPop()) {
        context.pop();
      }
      AppToast.show(context, 'Job declined');
    } else {
      AppToast.show(
        context,
        result['message']?.toString() ?? 'Could not decline job',
        isError: true,
      );
    }
  }
}
