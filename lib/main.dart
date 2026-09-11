import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'package:go_router/go_router.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/features/splash/splash_screen.dart';
import 'package:tapasya_vendor_app/features/onboarding/onboarding_screen.dart';
import 'package:tapasya_vendor_app/features/auth/login_screen.dart';
import 'package:tapasya_vendor_app/features/auth/otp_screen.dart';
import 'package:tapasya_vendor_app/features/home/main_wrapper.dart';
import 'package:tapasya_vendor_app/features/home/home_screen.dart';
import 'package:tapasya_vendor_app/features/jobs/jobs_screen.dart';
import 'package:tapasya_vendor_app/features/home/job_details_screen.dart';
import 'package:tapasya_vendor_app/features/earnings/earnings_screen.dart';
import 'package:tapasya_vendor_app/features/profile/profile_screen.dart';
import 'package:tapasya_vendor_app/features/notifications/notifications_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:tapasya_vendor_app/core/utils/notification_helper.dart';
import 'package:tapasya_vendor_app/core/utils/job_alert_handler.dart';
import 'package:tapasya_vendor_app/core/utils/job_payload_utils.dart';
import 'package:tapasya_vendor_app/core/utils/native_job_alert.dart';

import 'package:flutter_inappwebview_android/flutter_inappwebview_android.dart'
    hide AndroidWebViewFeature, AndroidServiceWorkerController;

import 'package:tapasya_vendor_app/features/auth/registration/step_1_details_screen.dart';
import 'package:tapasya_vendor_app/features/auth/registration/step_2_services_screen.dart';
import 'package:tapasya_vendor_app/features/auth/registration/step_3_job_mode_screen.dart';
import 'package:tapasya_vendor_app/features/auth/registration/step_4_availability_screen.dart';
import 'package:tapasya_vendor_app/features/auth/registration/step_5_mobile_screen.dart';
import 'package:tapasya_vendor_app/features/auth/registration/registration_otp_screen.dart';
import 'package:tapasya_vendor_app/features/auth/registration/registration_state.dart';
import 'package:tapasya_vendor_app/features/auth/registration/step_6_verification_screen.dart';
import 'package:tapasya_vendor_app/features/auth/registration/aadhar_upload_screen.dart';
import 'package:tapasya_vendor_app/features/auth/registration/pan_upload_screen.dart';
import 'package:tapasya_vendor_app/features/auth/registration/bank_details_screen.dart';
import 'package:tapasya_vendor_app/features/auth/registration/face_verification_screen.dart';
import 'package:tapasya_vendor_app/features/auth/registration/registration_pending_screen.dart';
import 'package:tapasya_vendor_app/features/home/job_request_screen.dart';
import 'package:tapasya_vendor_app/features/home/auto_job_assigned_screen.dart';
import 'package:tapasya_vendor_app/features/home/vendor_provider.dart';
import 'package:tapasya_vendor_app/services/api_service.dart';
import 'package:provider/provider.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationHelper.initLocalNotifications();
  final data = JobPayloadUtils.normalize(
    message,
    eventSource: message.data[JobPayloadUtils.fcmType]?.toString(),
  );
  if (data.isEmpty) {
    debugPrint('⚠️ [BG FCM] Empty payload: notification=${message.notification?.title}');
    return;
  }
  await JobAlertHandler.handleBackgroundMessage(data);
}
void main() async {
  // ⚡ IMMEDIATE INIT: Keep main() lean to prevent white/black screen delay
  WidgetsFlutterBinding.ensureInitialized();
  NativeJobAlert.init();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  ));

  final prefs = await SharedPreferences.getInstance();
  // Persistence is now handled by SplashScreen and individual states

  // Initialize Background Notifications
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationHelper.initLocalNotifications();
  NotificationHelper.onJobNotificationResponse = JobAlertHandler.handleNotificationResponse;
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // We create the state but don't 'await' the heavy local load here
  final registrationState = RegistrationState();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: registrationState),
        ChangeNotifierProvider(create: (_) => VendorProvider()),
      ],
      child: const MyApp(),
    ),
  );

  // Note: Firebase and local state are now initialized inside the SplashScreen
  // to ensure the UI renders as fast as possible.
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Tapasya Partner',
      theme: AppTheme.lightTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

////////////////////////////////////////////////////////////
/// ✅ FIXED FUNCTION (Moved outside)
////////////////////////////////////////////////////////////
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _saveFcmToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('fcm_token', token);
  debugPrint("✅ FCM TOKEN SAVED IN SHARED PREFS");
}

////////////////////////////////////////////////////////////
/// ✅ FCM INIT FUNCTION
////////////////////////////////////////////////////////////
Future<void> initFCM() async {
  try {
    NotificationHelper.router = _router;
    final FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.getNotificationSettings();
    debugPrint("🔔 [FCM] Permission status: ${settings.authorizationStatus}");

    // ⏳ Short delay to ensure Firebase is ready
    await Future.delayed(const Duration(milliseconds: 500));

    // 📲 Get initial token
    String? token = await messaging.getToken();

    if (token != null) {
      debugPrint("🔥 [FCM] TOKEN RETRIEVED: $token");
      await _saveFcmToken(token);
    } else {
      debugPrint("⚠️ [FCM] Token null on first attempt, retrying in 2s...");
      await Future.delayed(const Duration(seconds: 2));
      token = await messaging.getToken();
      if (token != null) {
        debugPrint("🔥 [FCM] TOKEN RETRIEVED (Retry): $token");
        await _saveFcmToken(token);
      } else {
        debugPrint("❌ [FCM] TOKEN STILL NULL after retry");
      }
    }

    // 🔄 Token refresh listener
    messaging.onTokenRefresh.listen((newToken) async {
      debugPrint("🔄 [FCM] TOKEN REFRESHED: $newToken");
      await _saveFcmToken(newToken);
      
      // 🔥 AUTO-UPLOAD on refresh if logged in
      final prefs = await SharedPreferences.getInstance();
      final jwtToken = prefs.getString('auth_token') ?? '';
      if (jwtToken.isNotEmpty) {
        debugPrint("📤 [FCM] Auto-uploading refreshed token to backend...");
        await ApiService().saveFcmToken(jwtToken, newToken);
      }
    });

    // 📩 Handle Background/Terminated clicks
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationClick);
    
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleNotificationClick(message);
    });

    // 🔔 Foreground — popup + loud sound (no tray banner; popup is the alert)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint("🔔 Foreground FCM: data=${message.data}");
      final data = JobPayloadUtils.normalize(
        message,
        eventSource: message.data[JobPayloadUtils.fcmType]?.toString(),
      );
      await JobAlertHandler.handleIncomingJob(
        navigatorKey.currentContext,
        data,
        eventSource: 'fcm_foreground',
        showTrayNotification: false,
      );
    });

  } catch (e) {
    debugPrint("❌ FCM INIT ERROR: $e");
  }
}

void _handleNotificationClick(RemoteMessage message) async {
  debugPrint("📩 Notification Clicked: ${message.data}");
  final data = JobPayloadUtils.normalize(message);
  final prefs = await SharedPreferences.getInstance();
  final vendorJobMode = prefs.getString(NotificationHelper.prefJobMode) ?? 'manual';
  // V1 REQUIREMENT: STRICTLY MANUAL MODE ONLY
  // final isAuto = JobPayloadUtils.isAutoAssign(data, vendorJobMode: vendorJobMode);
  final isAuto = false;
  final bookingId = JobPayloadUtils.extractBookingId(data) ?? '';

  JobAlertHandler.handleNotificationTap(jsonEncode({
    'type': isAuto ? 'auto' : 'manual',
    'booking_id': bookingId,
    'data': data,
  }));
}

////////////////////////////////////////////////////////////
/// ✅ ROUTER
////////////////////////////////////////////////////////////
final GoRouter _router = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/',
  redirect: (context, state) {
    final registrationState = context.read<RegistrationState>();
    final path = state.uri.path;
    final isAuthFlow = path.startsWith('/register') ||
                        path == '/onboarding' ||
                        path == '/login' ||
                        path == '/otp' ||
                        path == '/';

    // No active session on protected routes → login
    if (registrationState.authToken.isEmpty && !isAuthFlow) {
      debugPrint("🛡️ [ROUTER GUARD] Session missing — redirecting to login");
      return '/login';
    }

    final isLoggingIn = isAuthFlow;
    
    // If logged in (has token), always allow home
    if (registrationState.authToken.isNotEmpty && !isLoggingIn) {
      return null; 
    }
    
    // If trying to access home/dashboard but registration is NOT complete
    if (!isLoggingIn && !registrationState.hasCompletedRegistration) {
      debugPrint("🛡️ [ROUTER GUARD] Access denied to ${state.uri.path}. Registration not complete.");
      return '/'; // Kick back to Splash (which handles routing to the correct step)
    }
    
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/otp',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final phone = extra['phone'] as String? ?? "";
        final verificationId = extra['verificationId'] as String? ?? "";
        return OtpScreen(
          phoneNumber: phone,
          verificationId: verificationId,
        );
      },
    ),
    GoRoute(
      path: '/register/verify',
      builder: (context, state) => const Step5MobileScreen(),
    ),
    GoRoute(
      path: '/register/step1',
      builder: (context, state) => const Step1DetailsScreen(),
    ),
    GoRoute(
      path: '/register/step2',
      builder: (context, state) => const Step2ServicesScreen(),
    ),
    GoRoute(
      path: '/register/step3',
      builder: (context, state) => const Step3JobModeScreen(),
    ),
    GoRoute(
      path: '/register/step4',
      builder: (context, state) => const Step4AvailabilityScreen(),
    ),
    GoRoute(
      path: '/register/otp',
      builder: (context, state) {
        final verificationId = state.extra as String? ?? "";
        return RegistrationOtpScreen(verificationId: verificationId);
      },
    ),
    GoRoute(
      path: '/register/verification',
      builder: (context, state) => const Step6VerificationScreen(),
    ),
    GoRoute(
      path: '/register/aadhar',
      builder: (context, state) => const AadharUploadScreen(),
    ),
    GoRoute(
      path: '/register/pan',
      builder: (context, state) => const PanUploadScreen(),
    ),
    GoRoute(
      path: '/register/bank',
      builder: (context, state) => const BankDetailsScreen(),
    ),
    GoRoute(
      path: '/register/face',
      builder: (context, state) => const FaceVerificationScreen(),
    ),
    GoRoute(
      path: '/register/pending',
      builder: (context, state) => const RegistrationPendingScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainWrapper(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/jobs',
              builder: (context, state) {
                final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
                return JobsScreen(initialIndex: tab);
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/earnings',
              builder: (context, state) => const EarningsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/jobs/details/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? "";
        final extra = state.extra as Map<String, dynamic>?;
        return JobDetailsScreen(bookingId: id, initialData: extra);
      },
    ),
    GoRoute(
      path: '/job-request',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>? ?? {};
        return JobRequestScreen(jobData: data);
      },
    ),
    GoRoute(
      path: '/auto-job-assigned',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>? ?? {};
        return AutoJobAssignedScreen(jobData: data);
      },
    ),
    GoRoute(
      path: '/all-reports',
      redirect: (context, state) => '/earnings',
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
  ],
);
