import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Normalizes job payloads from socket / FCM — auto-assign often uses nested or different keys.
class JobPayloadUtils {
  /// Standard keys sent in FCM `message.data` from backend.
  static const String fcmBookingId = 'booking_id';
  static const String fcmType = 'type';
  static const String fcmTypeJobAssigned = 'job_assigned';
  static const String fcmMode = 'mode';
  static const String fcmModeAuto = 'auto';
  static const String fcmUserName = 'user_name';
  static const String fcmDistanceKm = 'distance_km';
  static const String fcmServiceName = 'service_name';
  static const String fcmLat = 'lat';
  static const String fcmLng = 'lng';

  /// Backend auto-assign FCM payload shape:
  /// booking_id, type=job_assigned, mode=auto, user_name, distance_km,
  /// service_name, lat, lng
  static const standardFcmKeys = [
    fcmUserName,
    fcmDistanceKm,
    fcmServiceName,
    fcmLat,
    fcmLng,
  ];

  static const _idKeys = [
    'booking_id',
    'bookingId',
    'bookingID',
    'id',
    'job_id',
    'jobId',
    '_id',
  ];

  static const _nestedKeys = ['booking', 'job', 'data', 'payload', 'details'];

  /// Extract booking id from flat or nested maps / JSON strings.
  static String? extractBookingId(Map<String, dynamic> data) {
    for (final key in _idKeys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    for (final key in _nestedKeys) {
      final nested = data[key];
      if (nested is Map) {
        final id = extractBookingId(Map<String, dynamic>.from(nested));
        if (id != null) return id;
      }
      if (nested is String && nested.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(nested);
          if (decoded is Map) {
            final id = extractBookingId(Map<String, dynamic>.from(decoded));
            if (id != null) return id;
          }
        } catch (_) {}
      }
    }

    return null;
  }

  /// Flatten socket / FCM payloads into one map the alert UI understands.
  static Map<String, dynamic> normalize(
    dynamic raw, {
    String? eventSource,
  }) {
    Map<String, dynamic> data = {};

    if (raw is RemoteMessage) {
      data = Map<String, dynamic>.from(raw.data);
      final notification = raw.notification;
      if (notification != null) {
        data.putIfAbsent('service_name', () => notification.title);
        data.putIfAbsent('address', () => notification.body);
      }
    } else if (raw is Map) {
      data = Map<String, dynamic>.from(raw);
    } else if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        debugPrint('⚠️ [JOB PAYLOAD] Could not decode string payload: $raw');
      }
    }

    // Merge nested booking/job object into top level (auto-assign often sends this).
    for (final key in ['booking', 'job']) {
      final nested = data[key];
      if (nested is Map) {
        final nestedMap = Map<String, dynamic>.from(nested);
        data = {...nestedMap, ...data};
      }
    }

    // Parse stringified JSON blobs inside data fields.
    for (final key in _nestedKeys) {
      final nested = data[key];
      if (nested is String && nested.trim().startsWith('{')) {
        try {
          final decoded = jsonDecode(nested);
          if (decoded is Map) {
            data = {...Map<String, dynamic>.from(decoded), ...data};
          }
        } catch (_) {}
      }
    }

    final bookingId = extractBookingId(data);
    if (bookingId != null) {
      data['booking_id'] = bookingId;
      data['id'] ??= bookingId;
    }

    // Auto-assign: socket event, FCM type, or explicit mode from backend.
    if (eventSource == fcmTypeJobAssigned || _isJobAssignedPayload(data)) {
      data[fcmMode] ??= fcmModeAuto;
      data['job_mode'] ??= fcmModeAuto;
    }

    final mode = (data[fcmMode] ?? data['job_mode'] ?? '').toString().toLowerCase();
    if (mode == fcmModeAuto || mode == 'assigned' || mode == 'automatic') {
      data[fcmMode] = fcmModeAuto;
      data['job_mode'] ??= fcmModeAuto;
    }

    _promoteStandardFcmKeys(data);

    debugPrint('📦 [JOB PAYLOAD] normalized id=$bookingId source=$eventSource keys=${data.keys.toList()}');
    return data;
  }

  /// Ensure standard FCM keys from `message.data` are available at top level.
  static void _promoteStandardFcmKeys(Map<String, dynamic> data) {
    for (final key in standardFcmKeys) {
      final existing = data[key];
      if (existing != null && existing.toString().trim().isNotEmpty) continue;

      for (final nestedKey in _nestedKeys) {
        final nested = data[nestedKey];
        if (nested is! Map) continue;
        final value = nested[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          data[key] = value;
          break;
        }
      }
    }
  }

  static bool _isJobAssignedPayload(Map<String, dynamic> data) {
    final type = (data[fcmType] ?? '').toString().toLowerCase();
    return type == fcmTypeJobAssigned;
  }

  /// Force manual mode across the entire app for V1.
  static bool isAutoAssign(Map<String, dynamic> data, {String? vendorJobMode}) {
    return false;
  }

  static Map<String, dynamic> _jobMap(Map<String, dynamic> data) {
    final inner = data['booking'] ?? data['data'] ?? data;
    return inner is Map ? Map<String, dynamic>.from(inner) : data;
  }

  static dynamic getField(
    Map<String, dynamic> data,
    List<String> keys, {
    dynamic fallback,
  }) {
    final map = _jobMap(data);
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) return value;
    }
    return fallback;
  }

  static String customerName(Map<String, dynamic> data) {
    return getField(data, [fcmUserName, 'customer_name', 'full_name', 'name'], fallback: 'Customer')
        .toString();
  }

  static String locationLabel(Map<String, dynamic> data) {
    final distance =
        getField(data, [fcmDistanceKm, 'pickup_distance', 'distance'], fallback: '').toString();
    if (distance.isNotEmpty) return '$distance km away';

    final address = getField(
      data,
      ['pickup_address', 'address', 'formatted_address', 'address_line1'],
      fallback: '',
    ).toString();
    return address.isNotEmpty ? address : 'Location on file';
  }

  static String serviceName(Map<String, dynamic> data) {
    return getField(data, [fcmServiceName, 'sub_service_name', 'service', 'category'], fallback: 'Service')
        .toString();
  }

  static String latitude(Map<String, dynamic> data) {
    return getField(data, [fcmLat, 'latitude'], fallback: '').toString();
  }

  static String longitude(Map<String, dynamic> data) {
    return getField(data, [fcmLng, 'longitude'], fallback: '').toString();
  }

  /// Rich notification body for auto-assigned jobs (matches in-app info popup).
  static String autoNotificationBody(Map<String, dynamic> data) {
    return 'Customer: ${customerName(data)}\n'
        'Location: ${locationLabel(data)}\n'
        'Service: ${serviceName(data)}';
  }
}
