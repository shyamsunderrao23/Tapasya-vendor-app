import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tapasya_vendor_app/features/auth/registration/registration_state.dart';
import 'package:tapasya_vendor_app/features/home/vendor_provider.dart';
import 'package:tapasya_vendor_app/main.dart';
import 'package:tapasya_vendor_app/services/socket_service.dart';

/// Clears an expired or invalid session and sends the vendor to login.
class SessionService {
  static bool _isHandling = false;

  static bool get isHandling => _isHandling;

  static Future<void> handleSessionExpired() async {
    if (_isHandling) return;
    _isHandling = true;

    try {
      final context = navigatorKey.currentContext;
      if (context == null) return;

      debugPrint('🚪 [SESSION] Token expired or session invalid — redirecting to login');

      SocketService.disconnect();
      await context.read<RegistrationState>().logout();
      context.read<VendorProvider>().clearSession();

      if (context.mounted) {
        context.go('/login');
      }
    } finally {
      _isHandling = false;
    }
  }
}
