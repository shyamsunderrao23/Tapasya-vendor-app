import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';
import 'package:tapasya_vendor_app/features/home/vendor_provider.dart';
import 'package:tapasya_vendor_app/features/auth/login_screen.dart';
import 'package:tapasya_vendor_app/features/auth/registration/registration_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tapasya_vendor_app/services/api_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:tapasya_vendor_app/services/socket_service.dart';
import 'package:tapasya_vendor_app/features/home/auto_job_assigned_screen.dart';
import 'package:tapasya_vendor_app/features/home/job_request_screen.dart';
import 'package:tapasya_vendor_app/core/utils/notification_helper.dart';
import 'package:tapasya_vendor_app/core/utils/job_alert_handler.dart';
import 'package:tapasya_vendor_app/core/utils/transaction_stats_utils.dart';
import 'package:tapasya_vendor_app/core/utils/job_payload_utils.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:tapasya_vendor_app/features/home/widgets/magic_fab.dart';
import 'package:tapasya_vendor_app/features/profile/pages/manage_services_screen.dart';
import 'package:tapasya_vendor_app/features/profile/pages/edit_profile_screen.dart';
import 'package:tapasya_vendor_app/features/profile/pages/availability_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:tapasya_vendor_app/core/navigation/session_service.dart';
import 'package:tapasya_vendor_app/core/utils/share_app_helper.dart';
import 'package:tapasya_vendor_app/main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String selectedFilter = 'Today';
  Timer? _locationTimer;
  RegistrationState? _registrationState;
  String? _activeToken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _registrationState = context.read<RegistrationState>();
    _registrationState!.addListener(_onSessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onSessionChanged());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    JobAlertHandler.showJobPopup = null;
    _registrationState?.removeListener(_onSessionChanged);
    _locationTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Skip if native Accept/Decline is already being processed.
      JobAlertHandler.processPendingJobAlert();
    }
  }

  void _onSessionChanged() {
    if (!mounted) return;
    final token = _registrationState!.authToken;
    if (token.isEmpty) {
      _activeToken = null;
      _locationTimer?.cancel();
      return;
    }
    if (token == _activeToken) return;
    _activeToken = token;
    _bootstrapHome(token);
  }

  Future<void> _bootstrapHome(String token) async {
    final vProv = context.read<VendorProvider>();

    // 🔄 AUTO-RELOAD ON LOGIN: Always pull fresh data when the vendor lands on Home.
    // Wipe stale data only on a true cold login (no profile yet) so we show a loader;
    // otherwise refresh silently in the background without blanking the screen.
    await vProv.refreshAfterLogin(token, clearFirst: vProv.profile == null);

    if (!mounted) return;
    _setupRealtimeListeners();
    _startLocationUpdates();
    await _initNotifications();
    // Job may have arrived while app was closed — show popup + sound immediately.
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) await JobAlertHandler.processPendingJobAlert();
  }

  void _setupRealtimeListeners() {
    final vendor = context.read<VendorProvider>().profile?.vendor;
    if (vendor == null) return;

    // Wire global popup so FCM / job_assigned use the same UI as manual socket jobs.
    JobAlertHandler.showJobPopup = (data) => showJobPopup(data);

    SocketService.initSocket(vendor.id);
    SocketService.listenForJobs((data) {
      if (!mounted) return;
      JobAlertHandler.handleIncomingJob(
        context,
        Map<String, dynamic>.from(data as Map),
        eventSource: 'new_job',
        onManualPopup: () => showJobPopup(
          JobPayloadUtils.normalize(data, eventSource: 'new_job'),
        ),
      );
    });

    SocketService.listenForJobTaken((data) {
      final normalized = JobPayloadUtils.normalize(data);
      final bookingId = JobPayloadUtils.extractBookingId(normalized) ?? '';
      if (bookingId.isNotEmpty) {
        NotificationHelper.activeJobPopups.remove(bookingId);
        if (mounted) fetchDashboardData();
      }
    });

    SocketService.listenForJobAssigned((data) {
      if (!mounted) return;
      JobAlertHandler.handleIncomingJob(
        context,
        Map<String, dynamic>.from(data as Map),
        eventSource: 'job_assigned',
        onManualPopup: () => showJobPopup(
          JobPayloadUtils.normalize(data, eventSource: 'job_assigned'),
        ),
      );
    });
  }

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token') ?? context.read<RegistrationState>().authToken;
        if (token.isEmpty) return;
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) return;
        }
        Position position = await Geolocator.getCurrentPosition();
        await ApiService().updateLocation(token, position.latitude, position.longitude);
      } catch (e) {
        print("Error updating live location: $e");
      }
    });
  }

  Future<void> _initNotifications() async {
    try {
      // 1. Ask notification permission on Home (not at app launch)
      if (!mounted) return;
      await NotificationHelper.requestPermissionsOnHome();

      if (!mounted) return;
      // 2. Init FCM + save token
      await initFCM();
      
      // 3. Fetch the token from SharedPrefs (where initFCM just saved it)
      final prefs = await SharedPreferences.getInstance();
      final fcmToken = prefs.getString('fcm_token');
      
      String jwtToken = prefs.getString('auth_token') ?? '';
      if (jwtToken.isEmpty && mounted) {
        jwtToken = context.read<RegistrationState>().authToken;
      }

      if (fcmToken != null && jwtToken.isNotEmpty) {
        debugPrint("🚀 [HOME_SCREEN] Syncing FCM Token to backend...");
        await ApiService().saveFcmToken(jwtToken, fcmToken);
      } else {
        debugPrint("⚠️ [HOME_SCREEN] Token sync skipped: FCM($fcmToken), JWT(${jwtToken.isNotEmpty})");
      }
    } catch (e) {
      debugPrint("❌ [HOME_SCREEN] Notification init failed: $e");
    }
  }

  Future<void> fetchDashboardData() async {
    if (!mounted) return;
    final vProv = context.read<VendorProvider>();
    
    // 🔥 AUTOMATIC VERIFICATION ON LAUNCH
    final token = context.read<RegistrationState>().authToken;
    await vProv.fetchVendorProfile(token);
    
    await vProv.fetchDashboardData();
    // 🔥 DIAGNOSTIC: Log raw job data
    debugPrint("🏠 DASHBOARD DATA: ${vProv.dashboardData}");
    await vProv.fetchTransactions();
  }

  void showJobPopup(dynamic data) {
    final normalized = data is Map<String, dynamic>
        ? JobPayloadUtils.normalize(data)
        : JobPayloadUtils.normalize(Map<String, dynamic>.from(data as Map));

    final bookingId = JobPayloadUtils.extractBookingId(normalized) ?? '';
    if (bookingId.isNotEmpty) {
      NotificationHelper.activeJobPopups.add(bookingId);
    }

    final vendorMode =
        context.read<VendorProvider>().profile?.vendor.jobMode.toLowerCase() ?? 'manual';
    final isAuto = JobPayloadUtils.isAutoAssign(normalized, vendorJobMode: vendorMode);

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        barrierDismissible: false,
        pageBuilder: (BuildContext context, _, __) {
          if (isAuto) {
            return AutoJobAssignedScreen(jobData: normalized);
          }
          return JobRequestScreen(jobData: normalized);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RegistrationState>();

    return Consumer<VendorProvider>(
      builder: (context, vendorProvider, child) {
        if (state.authToken.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/login');
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 🔥 RESILIENT LOADING: Only show the full-screen loader on a cold login
        // (no data yet). Once we have a profile, refreshes happen silently in the
        // background so the vendor never sees a blank flicker.
        if ((vendorProvider.isLoading || vendorProvider.isInitializing) &&
            vendorProvider.profile == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
 
        // 🔥 ERROR UI: Only show if loading is complete AND we have zero profile data AND there's a fatal error.
        if (vendorProvider.error != null && vendorProvider.profile == null) {
          final isAuthError = vendorProvider.error!.toLowerCase().contains('token') ||
              vendorProvider.error!.toLowerCase().contains('authentication');

          if (isAuthError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              SessionService.handleSessionExpired();
            });
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      vendorProvider.error!, 
                      style: const TextStyle(color: Color(0xFF1B263B), fontSize: 16, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      vendorProvider.fetchVendorProfile(state.authToken);
                      vendorProvider.fetchProfileFull(); // 🔥 Double-down on getting data!
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text("Retry", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                ],
              ),
            ),
          );
        }

        final vendor = vendorProvider.profile?.vendor;
        final vendorName = vendor?.fullName.split(' ').first ?? "Vendor";
        String profilePic = 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&q=80&w=200';
        if (vendor?.profilePic != null && vendor!.profilePic!.isNotEmpty) {
          final p = vendor.profilePic!;
          profilePic = p.startsWith('http') ? p : '${ApiService.imageBaseUrl}${p.startsWith('/') ? '' : '/'}$p';
        }
        // 🔥 ASSERTIVE STATE: Force 'Offline' if documents are not verified
        // 🔥 FAIL-SAFE STATE: Force 'Offline' if not fully verified
        final isOnline = vendor?.activeStatus == 1 && vendorProvider.isFullyVerified;
        final bool isRestricted = !vendorProvider.isFullyVerified;

        final dashboardData = vendorProvider.dashboardData;
        final List<dynamic> activeJobs = [];
        if (dashboardData?['current_job'] != null) {
          final currentJob = Map<String, dynamic>.from(dashboardData!['current_job']);
          if (TransactionStatsUtils.isInProgressBooking(currentJob)) {
            activeJobs.add(currentJob);
          }
        }

        final List<dynamic> previousJobs = [];
        final jobObj = dashboardData?['last_completed_job'] ?? dashboardData?['data']?['last_completed_job'];
        
        final allTxs = vendorProvider.transactionsData ?? [];
        if (jobObj != null) {
          // 🛡️ MERGE ENGINE: Look for this same ID in transactions to get extra fields (like payment_status)
          final Map<String, dynamic> merged = Map<String, dynamic>.from(jobObj);
          try {
            final matchingTx = allTxs.firstWhere((tx) => tx['id'] == jobObj['id'], orElse: () => null);
            if (matchingTx != null) merged.addAll(Map<String, dynamic>.from(matchingTx));
            // Ensure dashboard keys 'user_name' and 'address' stay prioritized!
            if (jobObj['user_name'] != null) merged['user_name'] = jobObj['user_name'];
            if (jobObj['address'] != null) merged['address'] = jobObj['address'];
          } catch (_) {}
          previousJobs.add(merged);
        } else {
          // Fallback to transaction history if dashboard field is missing 🛡️✅
          previousJobs.addAll(allTxs.where((tx) {
            try {
              final type = tx['type']?.toString().toLowerCase();
              final status = (tx['status'] ?? tx['payment_status'] ?? '').toString().toLowerCase();
              return type != 'payout' && (status == 'completed' || status == 'success' || status == 'paid');
            } catch (_) { return false; }
          }).take(1).toList());
        }
        
        final isJobsLoading = vendorProvider.isDashboardLoading;

        return Scaffold(
          backgroundColor: Colors.white,
          body: RefreshIndicator(
            onRefresh: fetchDashboardData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // 1. Premium Purple Header with Bubble Patterns
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(75),
                        bottomRight: Radius.circular(75),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(child: CustomPaint(painter: _BubbleBackgroundPainter())),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // TOP ROW: Logo and Profile/Notifications
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Image.asset(
                                      'assets/images/tapasya_logo.png',
                                      height: 60,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => const Text(
                                        "TAPASYA", 
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => ShareAppHelper.shareApp(
                                            vendorName: vendor?.fullName,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.12),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        GestureDetector(
                                          onTap: () => context.push('/notifications'),
                                          child: Consumer<VendorProvider>(
                                            builder: (context, vProv, _) {
                                              final count = vProv.totalUnreadNotifications;
                                              return Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 28),
                                                  if (count > 0)
                                                    Positioned(
                                                      right: -2,
                                                      top: -2,
                                                      child: Container(
                                                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                                        decoration: BoxDecoration(
                                                          color: Colors.orangeAccent,
                                                          borderRadius: BorderRadius.circular(10),
                                                          border: Border.all(color: Colors.white, width: 1.5),
                                                        ),
                                                        child: Text(
                                                          count > 99 ? '99+' : '$count',
                                                          textAlign: TextAlign.center,
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.w900,
                                                            height: 1.2,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white30, width: 2)),
                                          child: CircleAvatar(
                                            radius: 24,
                                            backgroundImage: NetworkImage(profilePic),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),
                                
                                // DATE PILL
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, color: Colors.white70, size: 14),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat('EEEE, MMM d').format(DateTime.now()),
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                // GREETING & SUBTITLE
                                 Row(
                                   children: [
                                     Text(
                                       "Hi, $vendorName",
                                       style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                                     ),
                                     const SizedBox(width: 8),
                                     const Text("👋", style: TextStyle(fontSize: 28)),
                                   ],
                                 ),
                                const SizedBox(height: 8),
                                const Text(
                                  "You have approvals and requests\nready to review",
                                  style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500, height: 1.4),
                                ),
                                const SizedBox(height: 24),
                                // ONLINE / OFFLINE TOGGLE BOX
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              "Go online to receive new\njob requests",
                                              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500, height: 1.2),
                                            ),
                                            if (isRestricted)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Text(
                                                  "⚠️ Documents not verified (Found: ${vendorProvider.profile?.documents.length ?? 0} docs)",
                                                  style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ).animate().fadeIn().shake(),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Transform.scale(
                                            scale: 0.8,
                                            child: Switch(
                                              value: isOnline,
                                              onChanged: isRestricted ? null : (val) async {
                                                if (!val) {
                                                  await NotificationHelper.persistOnlineStatus(0);
                                                  await NotificationHelper.stopAlertSound();
                                                }
                                                final vProv = context.read<VendorProvider>();
                                                final res = await vProv.toggleActiveStatus();
                                                
                                                if (context.mounted) {
                                                  if (!isRestricted) {
                                                    if (res['success'] != true) {
                                                      AppToast.show(context, res['message'] ?? "Toggle failed", isError: true);
                                                    } else {
                                                      AppToast.show(context, res['message'] ?? "Status updated!");
                                                    }
                                                  }
                                                }
                                              },
                                              activeColor: Colors.white,
                                              activeTrackColor: Colors.greenAccent.shade400.withOpacity(0.5),
                                              inactiveThumbColor: Colors.white70,
                                              inactiveTrackColor: Colors.white24,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isOnline ? "Online" : "Offline",
                                            style: TextStyle(
                                              color: isRestricted ? Colors.white38 : Colors.white, 
                                              fontWeight: FontWeight.bold, 
                                              fontSize: 14
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Report Row (On White Background)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "This Month", 
                          style: TextStyle(color: Color(0xFF1B263B), fontSize: 18, fontWeight: FontWeight.w700)
                        ),
                        GestureDetector(
                          onTap: () => context.go('/earnings'),
                          child: Row(
                            children: const [
                              Text(
                                "All reports",
                                style: TextStyle(color: Color(0xFF00BFB5), fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.chevron_right_rounded, color: Color(0xFF00BFB5), size: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 🔥 HIGH-VISIBILITY WARNING BANNER
                  if (vendorProvider.statusError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "ACCOUNT RESTRICTION",
                                    style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    vendorProvider.statusError!,
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 3. Stat Card Grid
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Consumer<VendorProvider>(
                      builder: (context, vProv, _) {
                        final txs = vProv.transactionsData;
                        final now = DateTime.now();

                        final records = TransactionStatsUtils.mergeEarningRecords(
                          transactions: txs,
                          completedBookings: vProv.jobsByStatus['completed'] ?? [],
                        );

                        final stats = TransactionStatsUtils.homePeriodStats(records, now);
                        var tWork = stats['todayWork']!.toInt();
                        var tEarn = stats['todayEarn']!.toDouble();
                        final int mWork = stats['monthWork']!.toInt();
                        final double mEarn = stats['monthEarn']!.toDouble();

                        // Fallback to dashboard API when local records are not loaded yet.
                        if (records.isEmpty && dashboardData != null) {
                          tWork = int.tryParse(dashboardData['today_work']?.toString() ?? '') ?? tWork;
                          tEarn = double.tryParse(dashboardData['today_earnings']?.toString() ?? '') ?? tEarn;
                        }

                        String calcProgress(num current, num target) {
                          if (target <= 0) return "0%";
                          int percent = ((current / target) * 100).round();
                          return "+${percent > 100 ? 100 : percent}%";
                        }

                        final workTrend = calcProgress(tWork, 10);
                        final earnTrend = calcProgress(tEarn, 2000);
                        final monthWorkTrend = calcProgress(mWork, 100);
                        final monthEarnTrend = calcProgress(mEarn, 50000);

                        final String todayWorkValue = "$tWork";
                        final String todayEarnValue = "₹${tEarn.toStringAsFixed(0)}";
                        final String monthWorkValue = "$mWork";
                        final String monthEarnValue = "₹${mEarn.toStringAsFixed(0)}";

                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.1,
                          children: [
                            _buildStatCard(
                              title: "Today Work",
                              value: todayWorkValue,
                              icon: Icons.assignment_turned_in_outlined,
                              imagePath: "assets/images/today-work.png",
                              color: Colors.blue,
                              trend: workTrend,
                            ),
                            _buildStatCard(
                              title: "Today Earnings",
                              value: todayEarnValue,
                              icon: Icons.account_balance_wallet_outlined,
                              imagePath: "assets/images/total-monthly-earn.png",
                              color: Colors.green,
                              trend: earnTrend,
                            ),
                            _buildStatCard(
                              title: "Month Work",
                              value: monthWorkValue,
                              icon: Icons.calendar_month_outlined,
                              imagePath: "assets/images/completion.png",
                              color: Colors.purple,
                              trend: monthWorkTrend,
                            ),
                            _buildStatCard(
                              title: "Month Earnings",
                              value: monthEarnValue,
                              icon: Icons.trending_up_rounded,
                              imagePath: "assets/images/ratings.png",
                              color: Colors.orange,
                              trend: monthEarnTrend,
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // 3.5. Invite & Share Partner App Banner
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: InkWell(
                      onTap: () => ShareAppHelper.shareApp(
                        vendorName: vendor?.fullName,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4A00E0).withOpacity(0.25),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    "Invite Partners & Friends",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    "Share Tapasya Partner App to empower more technicians",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 4. Main Content (Current & Previous Jobs)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Active Jobs", style: TextStyle(color: Color(0xFF0D1B2A), fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          if (isJobsLoading)
                            const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()))
                          else if (activeJobs.isEmpty)
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 20),
                                  Image.asset(
                                    'assets/images/no-service-request.png',
                                    width: 240,
                                    height: 240,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    "No Active Jobs Found!",
                                    style: TextStyle(
                                      color: Color(0xFF1B263B),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 32),
                                    child: Text(
                                      "You don't have any active service requests at the moment. Go online to start receiving new jobs!",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: activeJobs.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final job = activeJobs[index];
                                final services = job['services_list'] ?? job['services'] ?? [];
                                debugPrint("🔥 ACTIVE JOB SERVICES ($index): $services");
                                final serviceName = services.isNotEmpty ? (services.first['service_name'] ?? 'Service') : 'Service';
                                final subService = services.isNotEmpty ? (services.first['sub_service_name'] ?? '') : '';

                                return _buildJobCard(
                                  id: job['id']?.toString() ?? '',
                                  name: job['user_name'] ?? 'Customer',
                                  service: subService.isNotEmpty ? "$serviceName - $subService" : serviceName,
                                  status: (job['status'] ?? 'accepted').toString().toUpperCase(),
                                  time: job['time_slot'] ?? 'Pending',
                                  location: job['address'] is Map ? (job['address']['address_line1'] ?? 'Location') : job['address'] ?? 'Location',
                                  lat: job['lat']?.toString(),
                                  lng: job['lng']?.toString(),
                                  icon: Icons.cleaning_services_rounded,
                                  isCompleted: false,
                                  fullJob: job,
                                );
                              },
                            ),
                          
                          const SizedBox(height: 24),
                          
                          const Text("Completed Jobs", style: TextStyle(color: Color(0xFF0D1B2A), fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          if (isJobsLoading)
                            const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()))
                          else if (previousJobs.isEmpty)
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 20),
                                  Image.asset(
                                    'assets/images/no-completed-job.png',
                                    width: 180,
                                    height: 180,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    "No Completed Jobs Yet!",
                                    style: TextStyle(
                                      color: Color(0xFF1B263B),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 32),
                                    child: Text(
                                      "Once you start completing service requests, they will appear here in your job history.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                ],
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: previousJobs.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final job = previousJobs[index];
                                final services = job['services_list'] ?? job['services'] ?? [];
                                
                                // Direct Mapping & Debug 🛡️✅
                                debugPrint("🔥 COMPLETED JOB DATA: $job");
                                final String eName = (job['user_name'] ?? job['customer_name'] ?? job['name'] ?? job['full_name'] ?? 
                                                      job['user']?['name'] ?? job['user']?['full_name'] ?? 'Customer').toString();
                                final String eAddr = (job['address'] ?? job['location'] ?? job['booking_address'] ?? 
                                                      job['address_line1'] ?? 'Location not specified').toString();

                                // Try to find service from history if missing in snippet 🛡️
                                String fService = "Expert Service";
                                if (services.isNotEmpty) {
                                  final s = services.first['service_name'] ?? 'Service';
                                  final sub = services.first['sub_service_name'] ?? '';
                                  fService = sub.isNotEmpty ? "$s - $sub" : s;
                                } else if (job['id'] != null) {
                                  final mTx = (vendorProvider.transactionsData ?? []).firstWhere(
                                    (tx) => tx['id'] == job['id'], orElse: () => null);
                                  if (mTx != null) {
                                    final txS = mTx['services_list'] ?? mTx['services'] ?? [];
                                    if (txS.isNotEmpty) {
                                      final s = txS.first['service_name'] ?? 'Service';
                                      final sub = txS.first['sub_service_name'] ?? '';
                                      fService = sub.isNotEmpty ? "$s - $sub" : s;
                                    }
                                  }
                                }

                                return _buildJobCard(
                                  id: job['id']?.toString() ?? '',
                                  name: eName,
                                  service: fService,
                                  status: (job['status'] ?? 'completed').toString().toUpperCase(),
                                  time: job['time_slot'] ?? 'Completed',
                                  location: eAddr,
                                  lat: job['lat']?.toString(),
                                  lng: job['lng']?.toString(),
                                  icon: Icons.check_circle_rounded,
                                  isCompleted: true,
                                  fullJob: job,
                                );
                              },
                            ),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          floatingActionButton: MagicFab(
            isNew: vendorProvider.profile?.services.isEmpty ?? true,
            onAddService: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManageServicesScreen())),
            onCompleteProfile: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => const EditProfileScreen())),
            onWithdraw: () => context.push('/earnings'), 
            onAvailability: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AvailabilityScreen())), 
            onUploadWork: () => context.push('/jobs'),
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String title, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: valueColor, fontSize: 24, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildFilterPill(String title, {required bool isSelected, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D1B2A) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: isSelected ? null : Border.all(color: Colors.grey.withOpacity(0.2)),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF0D1B2A).withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))] : [],
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildJobCard({
    required String id,
    required String name,
    required String service,
    required String status,
    required String time,
    required String location,
    String? lat,
    String? lng,
    required IconData icon,
    bool isCompleted = false,
    Map<String, dynamic>? fullJob,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08), 
            blurRadius: 30, 
            spreadRadius: 2,
            offset: const Offset(0, 15)
          )
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCompleted ? const Color(0xFFE8F5E9) : const Color(0xFFFFF5E9), 
                        shape: BoxShape.circle
                      ),
                      child: Icon(
                        isCompleted ? Icons.verified_rounded : Icons.auto_awesome_rounded, 
                        color: isCompleted ? const Color(0xFF4CAF50) : const Color(0xFFFF9800), 
                        size: 24
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name, 
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF1B263B), letterSpacing: -0.5)
                          ),
                          const SizedBox(height: 4),
                          Text(
                            service, 
                            style: TextStyle(
                              color: isCompleted ? Colors.deepPurple.shade400 : const Color(0xFFA0A0A0), 
                              fontSize: 14, 
                              fontWeight: FontWeight.w700
                            )
                          ),
                        ],
                      ),
                    ),
                    if (!isCompleted && status.toLowerCase() == 'accepted')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFFFFF5E9), borderRadius: BorderRadius.circular(14)),
                        child: const Text("NEW", style: TextStyle(color: Color(0xFFFF9800), fontWeight: FontWeight.w900, fontSize: 11)),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA), 
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade100)
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.location_on_rounded, color: Color(0xFF4285F4), size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("SERVICE LOCATION", style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                                const SizedBox(height: 2),
                                Text(
                                  isCompleted && location.length > 15 
                                    ? "${location.substring(0, 12)}... xxxxxxx" 
                                    : location, 
                                  style: const TextStyle(color: Color(0xFF1B263B), fontSize: 13, fontWeight: FontWeight.w800),
                                  maxLines: 1, overflow: TextOverflow.ellipsis
                                ),
                              ],
                            ),
                          ),
                          if (isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.shade100)),
                              child: Text(
                                "₹${fullJob?['final_amount'] ?? fullJob?['amount'] ?? '0'}", 
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.green.shade700)
                              ),
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: Colors.grey.shade200),
                      ),
                      // 🟢 MINI STATUS TIMELINE (ONLY FOR COMPLETED)
                      if (isCompleted) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMiniStep("Requested", true),
                              _buildMiniLine(true),
                              _buildMiniStep("Accepted", true),
                              _buildMiniLine(true),
                              _buildMiniStep("Started", true),
                              _buildMiniLine(true),
                              _buildMiniStep("Completed", true),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF673AB7), size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("MISSION WINDOW", style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                                const SizedBox(height: 2),
                                Text(
                                  fullJob?['booking_date'] != null 
                                    ? DateFormat('dd MMM, yyyy').format(DateTime.parse(fullJob!['booking_date'].toString()))
                                    : (fullJob?['created_at'] != null 
                                        ? DateFormat('dd MMM, yyyy').format(DateTime.parse(fullJob!['created_at'].toString()))
                                        : DateFormat('dd MMM, yyyy').format(DateTime.now())), 
                                  style: const TextStyle(color: Color(0xFF1B263B), fontSize: 13, fontWeight: FontWeight.w800)
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: const Color(0xFFEDE7F6), borderRadius: BorderRadius.circular(10)),
                            child: Text(time, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF673AB7))),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // COMPACT ACTION BAR (Only for non-completed)
          if (!isCompleted)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF5E9),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              child: InkWell(
                onTap: () {
                  final Map<String, dynamic> navData = Map<String, dynamic>.from(fullJob ?? {});
                  if (navData['id'] == null) navData['id'] = id;
                  context.push('/jobs/details/$id', extra: navData);
                },
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        status.toLowerCase() == 'accepted' ? "ACCEPT NEW JOB" : "START YOUR JOB",
                        style: const TextStyle(color: Color(0xFFFF9800), fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // GREEN FOOTER FOR COMPLETED (No Button)
          if (isCompleted)
            Container(
              height: 12, width: double.infinity,
              decoration: const BoxDecoration(color: Color(0xFF43A047), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniStep(String label, bool active) {
    return Column(
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: active ? const Color(0xFF43A047) : Colors.grey.shade300),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: active ? const Color(0xFF1B263B) : Colors.grey.shade400)),
      ],
    );
  }

  Widget _buildMiniLine(bool active) {
    return Expanded(
      child: Container(
        height: 2, margin: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
        decoration: BoxDecoration(color: active ? const Color(0xFF43A047).withOpacity(0.5) : Colors.grey.shade200, borderRadius: BorderRadius.circular(1)),
      ),
    );
  }

  Widget _buildFilterPillCompact(String title, {required bool isSelected, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D1B2A) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildCircularStats(int count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Center(
            child: Text(
              "$count",
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDashboardGraph() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Activity Trend", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54)),
            Text(
              selectedFilter,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (index) {
              final active = index == 4 || index == 6;
              return Container(
                width: 30,
                height: (index % 3 + 2) * 10.0,
                decoration: BoxDecoration(
                  color: active ? AppTheme.primaryColor : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    String? imagePath,
    required Color color,
    required String trend,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.zero,
                child: imagePath != null 
                  ? Image.asset(imagePath, width: 60, height: 60, fit: BoxFit.contain)
                  : Icon(icon, color: color, size: 52),
              ),
              Row(
                children: [
                  Text(
                    trend,
                    style: TextStyle(
                      color: trend.startsWith('-') ? Colors.red : Colors.green, 
                      fontSize: 11, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  Icon(
                    trend.startsWith('-') ? Icons.arrow_downward : Icons.arrow_upward, 
                    color: trend.startsWith('-') ? Colors.red : Colors.green, 
                    size: 10
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF1B263B),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BubbleBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.2), 40, paint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.1), 60, paint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.7), 80, paint);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.8), 50, paint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.4), 30, paint);
    final strokePaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.5), 90, strokePaint);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.3), 70, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
