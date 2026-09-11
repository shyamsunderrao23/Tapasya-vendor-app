import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tapasya_vendor_app/core/utils/job_alert_handler.dart';
import 'package:tapasya_vendor_app/core/utils/notification_helper.dart';

/// Native Android job alert bridge (sound stop + background job popup).
class NativeJobAlert {
  static const MethodChannel _channel =
      MethodChannel('com.tapasya.vendor/native_job_alert');

  static bool _initialized = false;

  static void init() {
    if (_initialized || !Platform.isAndroid) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'stopJobAlertSound') {
        await NotificationHelper.stopAllJobAlertAudio();
        final bookingId = call.arguments?.toString() ?? '';
        if (bookingId.isNotEmpty) {
          await NotificationHelper.cancelJobNotification(bookingId);
        }
        return;
      }

      if (call.method == 'processLaunchJobAction') {
        await JobAlertHandler.processPendingJobAlert();
        return;
      }

      if (call.method == 'presentJobRequest') {
        final args = call.arguments;
        if (args is! Map) return;

        final bookingId = args['booking_id']?.toString() ?? '';
        final rawJson = args['job_data_json']?.toString() ?? '{}';
        final nativeSoundActive = args['native_sound_active'] == true;

        Map<String, dynamic> data = {};
        try {
          final decoded = jsonDecode(rawJson);
          if (decoded is Map) {
            data = Map<String, dynamic>.from(decoded);
          }
        } catch (e) {
          debugPrint('⚠️ [NATIVE JOB] Bad job_data_json: $e');
        }

        if (bookingId.isNotEmpty) {
          data['booking_id'] ??= bookingId;
        }

        await JobAlertHandler.presentJobPopup(
          data,
          nativeSoundActive: nativeSoundActive,
        );
      }
    });
  }

  static Future<void> stopSound() async {
    if (!Platform.isAndroid) return;
    init();
    await NotificationHelper.stopAllJobAlertAudio();
    try {
      await _channel.invokeMethod('stopJobSound');
    } catch (e) {
      debugPrint('⚠️ [NATIVE JOB] stopJobSound failed: $e');
    }
  }
}
