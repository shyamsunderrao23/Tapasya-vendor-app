import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tapasya_vendor_app/core/utils/job_payload_utils.dart';

class NotificationHelper {
  static final AudioPlayer _player = AudioPlayer();
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static GoRouter? router;

  /// Set from main.dart to route notification taps (avoids circular imports).
  static void Function(NotificationResponse response)? onJobNotificationResponse;

  /// Action ids for auto-assign notification buttons.
  static const String actionNavigate = 'job_action_navigate';
  static const String actionViewDetails = 'job_action_view_details';

  static const String _jobChannelId = 'new_job_channel_v4';
  static const String prefActiveStatus = 'vendor_active_status';
  static const String prefJobMode = 'vendor_job_mode';
  static const String prefFullScreenGranted = 'fsi_permission_granted';
  static const String prefPendingJobAlert = 'pending_job_alert';
  static const String prefLaunchJobPayload = 'launch_job_payload';
  static const String prefHandledJobs = 'handled_job_booking_ids';

  static final Set<String> activeJobPopups = {};

  static Timer? _alertLoopTimer;
  static Timer? _alertAutoStopTimer;

  /// Repeats alert chime every 3s, auto-stops after [maxDuration] (default 8s).
  static const Duration alertLoopInterval = Duration(seconds: 3);
  static const Duration alertAutoStopDuration = Duration(seconds: 8);
  static const Duration manualAlertAutoStopDuration = Duration(seconds: 10);

  /// Persist vendor online/offline so background FCM can respect the toggle.
  static Future<void> persistOnlineStatus(int activeStatus) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefActiveStatus, activeStatus);
    debugPrint('💾 [ALERT] Online status saved: $activeStatus');
  }

  static Future<void> persistJobMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefJobMode, mode.toLowerCase());
  }

  /// Job alerts only when logged in AND toggle is Online (active_status == 1).
  static Future<bool> canReceiveJobAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    if (token.isEmpty) return false;
    return prefs.getInt(prefActiveStatus) == 1;
  }

  /// Call on logout / session expiry — block all future job alerts.
  static Future<void> onLogout() async {
    activeJobPopups.clear();
    stopJobAlertLoop();
    await persistOnlineStatus(0);
    debugPrint('🔕 [ALERT] Logout — job alerts disabled');
  }

  /// Save job so popup + sound fire as soon as the app is active (not only on tap).
  static Future<void> savePendingJobAlert(
    Map<String, dynamic> data, {
    required bool isAuto,
    String? pendingAction,
  }) async {
    final bookingId = data['booking_id']?.toString() ?? data['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefPendingJobAlert,
      jsonEncode({
        'booking_id': bookingId,
        'data': data,
        'isAuto': isAuto,
        'pendingAction': pendingAction,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
    debugPrint('💾 [ALERT] Pending job saved: $bookingId auto=$isAuto action=$pendingAction');
  }

  static Future<Map<String, dynamic>?> consumePendingJobAlert({int maxAgeSeconds = 120}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefPendingJobAlert);
    if (raw == null) return null;

    await prefs.remove(prefPendingJobAlert);

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = decoded['savedAt'] as int? ?? 0;
      final ageMs = DateTime.now().millisecondsSinceEpoch - savedAt;
      if (ageMs > maxAgeSeconds * 1000) {
        debugPrint('⏰ [ALERT] Pending job expired (${ageMs}ms old)');
        return null;
      }
      return decoded;
    } catch (e) {
      debugPrint('⚠️ [ALERT] Bad pending job payload: $e');
      return null;
    }
  }

  static Future<void> clearPendingJobAlert() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefPendingJobAlert);
    await prefs.remove(prefLaunchJobPayload);
  }

  /// Clears queued popup only — keeps native Accept/Decline launch payload intact.
  static Future<void> clearPendingJobAlertOnly() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefPendingJobAlert);
  }

  /// After Accept/Decline the job must not reappear on Home or from pending queue.
  static Future<void> markJobHandled(String bookingId) async {
    if (bookingId.isEmpty) return;
    activeJobPopups.remove(bookingId);
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(prefHandledJobs) ?? [];
    if (!list.contains(bookingId)) {
      list.add(bookingId);
      while (list.length > 50) {
        list.removeAt(0);
      }
      await prefs.setStringList(prefHandledJobs, list);
    }
    await clearPendingJobAlert();
    debugPrint('✅ [ALERT] Job marked handled: $bookingId');
  }

  static Future<bool> isJobHandled(String bookingId) async {
    if (bookingId.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    
    // First try getStringList (standard Flutter format)
    try {
      final list = prefs.getStringList(prefHandledJobs);
      if (list != null && list.contains(bookingId)) return true;
    } catch (_) {}

    // Fallback: Native overlay writes the same key as a JSON array string
    try {
      final raw = prefs.getString(prefHandledJobs);
      if (raw != null && raw.startsWith('[')) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).contains(bookingId);
        }
      }
    } catch (_) {}

    return false;
  }

  /// Cold-start tap saved during [initLocalNotifications].
  static Future<({String payload, String? actionId})?> consumeLaunchJobPayload() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefLaunchJobPayload);
    if (raw == null) return null;
    await prefs.remove(prefLaunchJobPayload);

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final payload = decoded['payload']?.toString() ?? '';
        if (payload.isEmpty) return null;
        return (payload: payload, actionId: decoded['actionId']?.toString());
      }
    } catch (_) {}

    // Legacy: plain payload string.
    if (raw.isNotEmpty) return (payload: raw, actionId: null);
    return null;
  }

  /// Remove the job notification from the tray (e.g. once its popup is shown).
  static Future<void> cancelJobNotification(String bookingId) async {
    if (bookingId.isEmpty) return;
    try {
      await _localNotifications.cancel(id: bookingId.hashCode);
    } catch (e) {
      debugPrint('⚠️ [ALERT] cancelJobNotification failed: $e');
    }
  }

  static Future<void> stopAlertSound() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  static Future<void> stopAllJobAlertAudio() async {
    _alertLoopTimer?.cancel();
    _alertAutoStopTimer?.cancel();
    _alertLoopTimer = null;
    _alertAutoStopTimer = null;
    try {
      await _player.stop();
    } catch (_) {}
  }

  /// Stop looping alert + player (Navigate, View Details, Dismiss, or auto timeout).
  static void stopJobAlertLoop() {
    _alertLoopTimer?.cancel();
    _alertAutoStopTimer?.cancel();
    _alertLoopTimer = null;
    _alertAutoStopTimer = null;
    stopAlertSound();
  }

  /// Loud chime once — used inside the repeat loop.
  static Future<void> playAlertChime() async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(1.0);
      await _player.play(AssetSource('sounds/new_job_alert.wav'), volume: 1.0);
    } catch (e) {
      debugPrint('Error playing alert chime: $e');
    }
  }

  /// Loop alert sound; stops on button tap or after 8s (10s for manual).
  static void startJobAlertLoop({
    required bool isAuto,
    Duration? maxDuration,
  }) {
    stopJobAlertLoop();

    final stopAfter = maxDuration ??
        (isAuto ? alertAutoStopDuration : manualAlertAutoStopDuration);

    void tick() {
      playAlertChime();
      vibrate(isAuto: isAuto);
    }

    tick();
    _alertLoopTimer = Timer.periodic(alertLoopInterval, (_) => tick());
    _alertAutoStopTimer = Timer(stopAfter, () {
      debugPrint('🔇 [ALERT] Auto-stopped after ${stopAfter.inSeconds}s');
      stopJobAlertLoop();
    });
  }

  static Future<void> initLocalNotifications() async {
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    // Do not prompt here — permission is requested on Home screen.
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          onJobNotificationResponse?.call(response);
        }
      },
    );

    // App opened from a job notification (cold start).
    final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final response = launchDetails?.notificationResponse;
      final payload = response?.payload;
      if (payload != null && payload.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          prefLaunchJobPayload,
          jsonEncode({
            'payload': payload,
            'actionId': response?.actionId,
          }),
        );
        debugPrint('🚀 [ALERT] App launched from job notification action=${response?.actionId}');
      }
    }

    // Create high importance channel for Android with the custom job alert sound.
    // NOTE: a new channel id is used because Android caches channel sound settings;
    // changing the sound on an existing channel id would be ignored.
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _jobChannelId,
      'New Job Alerts',
      description: 'Loud alerts for new job requests.',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('new_job_alert'),
      enableVibration: true,
      enableLights: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> showLocalNotification(RemoteMessage message) async {
    if (!await canReceiveJobAlerts()) return;
    final data = JobPayloadUtils.normalize(message);
    if (data.isEmpty) return;

    final bookingId = JobPayloadUtils.extractBookingId(data) ?? '';
    if (bookingId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final vendorJobMode = prefs.getString(prefJobMode) ?? 'manual';
    final isAuto = JobPayloadUtils.isAutoAssign(data, vendorJobMode: vendorJobMode);

    await showJobAlertNotification(bookingId: bookingId, data: data, isAuto: isAuto);
  }

  /// Call from Home screen — shows the system "Allow notifications?" dialog.
  static Future<bool> requestPermissionsOnHome() async {
    debugPrint('🔔 [HOME] Requesting notification permission...');

    if (Platform.isAndroid) {
      final androidStatus = await Permission.notification.request();
      debugPrint('🔔 [ANDROID] Notification permission: $androidStatus');
    }

    final fcmSettings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final granted = fcmSettings.authorizationStatus == AuthorizationStatus.authorized ||
        fcmSettings.authorizationStatus == AuthorizationStatus.provisional;

    debugPrint('🔔 [FCM] Permission after home prompt: ${fcmSettings.authorizationStatus}');

    // Special access (Android 14+) needed for the full-screen popup when the app
    // is closed / the phone is locked. Without it the job alert still shows as a
    // heads-up notification, so it never gets silently dropped.
    await _requestFullScreenIntentPermission();

    // "Display over other apps" — grants the background-activity-launch exemption
    // so the job request opens FULL SCREEN over other apps even when unlocked
    // (Rapido-style). Without it, the alert falls back to a heads-up banner.
    await _requestOverlayPermission();

    return granted;
  }

  /// Request "Display over other apps" (SYSTEM_ALERT_WINDOW). This is what lets a
  /// full-screen-intent notification actually launch the job screen over other
  /// apps while the phone is unlocked. Prompts only once.
  static Future<void> _requestOverlayPermission() async {
    if (!Platform.isAndroid) return;
    try {
      final status = await Permission.systemAlertWindow.status;
      if (!status.isGranted) {
        final result = await Permission.systemAlertWindow.request();
        debugPrint('🪟 [OVERLAY] Display-over-apps request: $result');
      } else {
        debugPrint('🪟 [OVERLAY] Display-over-apps already granted');
      }
    } catch (e) {
      debugPrint('⚠️ [OVERLAY] permission request failed: $e');
    }
  }

  /// Request the Android 14+ full-screen-intent special access and persist the result.
  /// Without it, full-screen notifications are dropped on some OEMs (e.g. Vivo).
  /// Only prompts once so we don't re-open the settings page on every launch;
  /// normal heads-up notifications still work even when this is not granted.
  static Future<bool> _requestFullScreenIntentPermission() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(prefFullScreenGranted) == true) return true;

    bool allowed = true;
    if (Platform.isAndroid) {
      try {
        final result = await _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestFullScreenIntentPermission();
        allowed = result ?? false;
      } catch (e) {
        debugPrint('⚠️ [ALERT] FSI permission request failed: $e');
        allowed = false;
      }
    }
    await prefs.setBool(prefFullScreenGranted, allowed);
    debugPrint('🔔 [FSI] Full-screen intent allowed: $allowed');
    return allowed;
  }

  /// @deprecated Use [requestPermissionsOnHome] from Home screen only.
  static Future<void> ensurePermissions() => requestPermissionsOnHome().then((_) {});

  /// Rich heads-up notification for new jobs (app closed / background).
  static Future<void> showJobAlertNotification({
    required String bookingId,
    required Map<String, dynamic> data,
    required bool isAuto,
    bool force = false,
    bool skipPendingSave = false,
  }) async {
    if (!force && !await canReceiveJobAlerts()) return;

    final amount = data['amount'] ?? data['price'] ?? data['total_amount'] ?? '';
    final service = JobPayloadUtils.serviceName(data);
    final address = data['address'] ??
        data['pickup_address'] ??
        data['formatted_address'] ??
        JobPayloadUtils.locationLabel(data);

    final String title;
    final String body;
    final List<AndroidNotificationAction>? actions;

    if (isAuto) {
      title = 'Job Assigned Successfully';
      body = JobPayloadUtils.autoNotificationBody(data);
      actions = const [
        AndroidNotificationAction(
          actionNavigate,
          'Navigate',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          actionViewDetails,
          'View Details',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ];
    } else {
      title = amount.toString().isNotEmpty ? '₹$amount — New Job' : 'New Job Request';
      body = '$service\n$address\nTap to Accept or Decline';
      actions = null;
    }

    final payload = jsonEncode({
      'type': isAuto ? 'auto' : 'manual',
      'booking_id': bookingId,
      'data': data,
    });

    // Queue popup for when app becomes active (background / killed).
    if (!skipPendingSave) {
      await savePendingJobAlert(data, isAuto: isAuto);
    }

    final platformDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _jobChannelId,
        'New Job Alerts',
        channelDescription: 'Loud alerts for new job requests.',
        importance: Importance.max,
        priority: Priority.max,
        ticker: isAuto ? 'Job Assigned Successfully' : 'New Job Request',
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('new_job_alert'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 800, 200, 800, 200, 800]),
        // fullScreenIntent: true, // REMOVED FOR V1: Standard tray notification only
        // category: AndroidNotificationCategory.call, // REMOVED FOR V1
        visibility: NotificationVisibility.public,
        styleInformation: BigTextStyleInformation(body),
        actions: actions,
        ongoing: false,
        autoCancel: true,
      ),
    );

    await _localNotifications.show(
      id: bookingId.hashCode,
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: payload,
    );
  }

  static Future<void> playNotificationSound({bool isAuto = false}) async {
    await playAlertChime();
    // Initial arrival — play twice for auto-assign urgency (not used in loop).
    if (isAuto) {
      await Future.delayed(const Duration(seconds: 3));
      await playAlertChime();
    }
  }

  static Future<void> vibrate({bool isAuto = false}) async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        if (isAuto) {
          // Intense vibration for auto jobs
          Vibration.vibrate(pattern: [0, 800, 100, 800, 100, 800]);
        } else {
          // Standard single pulse
          Vibration.vibrate(duration: 500);
        }
      }
    } catch (e) {
      print("Error vibrating: $e");
    }
  }

  static Future<void> subscribeToTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      debugPrint("✅ [FCM] Subscribed to topic: $topic");
    } catch (e) {
      debugPrint("❌ [FCM] Subscription failed: $topic - $e");
    }
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      debugPrint("✅ [FCM] Unsubscribed from topic: $topic");
    } catch (e) {
      debugPrint("❌ [FCM] Unsubscription failed: $topic - $e");
    }
  }

  static void dispose() {
    stopJobAlertLoop();
    _player.dispose();
  }
}
