import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:tapasya_vendor_app/features/home/vendor_provider.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:tapasya_vendor_app/services/socket_service.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';
import 'package:tapasya_vendor_app/core/utils/notification_helper.dart';
import 'package:tapasya_vendor_app/features/home/widgets/job_completion_modal.dart';

class JobDetailsScreen extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic>? initialData;

  const JobDetailsScreen({super.key, required this.bookingId, this.initialData});

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  bool isLoading = true;
  bool isActionLoading = false;
  Map<String, dynamic> booking = {};

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  Position? _vendorLocation;

  @override
  void initState() {
    super.initState();
    NotificationHelper.markJobHandled(widget.bookingId);
    
    // 1. Initialize with best available data
    if (widget.initialData != null) {
      final Map<String, dynamic> raw = Map<String, dynamic>.from(widget.initialData!);
      booking = raw['booking'] ?? raw['data'] ?? raw;
      isLoading = false;
    } else {
      booking = {'id': widget.bookingId};
    }
    
    // 2. Immediate tasks
    _updateMarkersFromData(); // Add markers immediately from initialData
    _fetchBookingDetails(); // Fetch fresh data

    // 🚀 STEP 4.3 — LISTEN EVENT (REAL-TIME SOCKET)
    SocketService.listenForJobUpdate((data) async {
      print("🔥 SOCKET UPDATE: $data");
      final String incomingBookingId = data['booking_id']?.toString() ?? data['id']?.toString() ?? '';

      if (incomingBookingId == widget.bookingId) {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token') ?? '';
        final res = await ApiService().getSingleBooking(token, widget.bookingId);

        if (mounted && res != null) {
          setState(() {
            booking = res['booking'] ?? res['data'] ?? res;
          });
          _updateMarkersFromData();
        }
      }
    });
  }

  int _getStatusIndex(String status, {bool isAutoFlow = false}) {
    final s = status.toLowerCase().trim();
    if (s == 'requested' || s == 'pending') {
      // Auto-assign skips manual accept — timeline starts at Accepted (green).
      return isAutoFlow ? 1 : 0;
    }
    if (s == 'accepted' || s == 'confirmed' || s == 'assigned' || s == 'auto') return 1;
    if (s == 'started' || s == 'ongoing' || s == 'started_job' || s == 'in_progress' || s == 'in progress') return 2;
    if (s == 'completed' || s == 'finished') return 3;
    return 1;
  }

  // Robust data extraction for unreliable backends (Universal mapper + Case-insensitive)
  dynamic _getVal(List<String> keys, {dynamic fallback}) {
    for (var k in keys) {
      if (booking[k] != null && booking[k].toString().trim().isNotEmpty) {
        return booking[k];
      }
      // Try case-insensitive search
      final lowerK = k.toLowerCase();
      for (var realK in booking.keys) {
        if (realK.toLowerCase() == lowerK && booking[realK] != null && booking[realK].toString().trim().isNotEmpty) {
          return booking[realK];
        }
      }
    }
    return fallback;
  }

  void _updateMarkersFromData() {
    final rawLat = _getVal(['lat', 'latitude', 'latitiude']);
    final rawLng = _getVal(['lng', 'longitude', 'longtiude']);
    
    if (rawLat != null && rawLng != null) {
      try {
        double dLat = double.parse(rawLat.toString());
        double dLng = double.parse(rawLng.toString());
        if (dLat != 0.0 && dLng != 0.0) {
          setState(() {
            _markers.clear();
            _markers.add(Marker(
              markerId: const MarkerId("customer"),
              position: LatLng(dLat, dLng),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
              infoWindow: const InfoWindow(title: "Job Location"),
            ));
          });
          
          if (_mapController != null) {
            _mapController!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(dLat, dLng), 15.5));
          }
        }
      } catch (e) {
        debugPrint("Map Error: $e");
      }
    }
  }

  Future<void> _fetchBookingDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      final data = await ApiService().getBookingDetails(token, widget.bookingId);
      if (mounted && data != null) {
        setState(() {
          final Map<String, dynamic> raw = Map<String, dynamic>.from(data);
          booking = raw['booking'] ?? raw['data'] ?? raw;
          isLoading = false;
        });
        _updateMarkersFromData();
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<bool> updateStatus(String status) async {
    setState(() => isActionLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final vendorId = Provider.of<VendorProvider>(context, listen: false).profile?.vendor.id ?? '';
      
      final res = await ApiService().bookingAction(token, widget.bookingId, vendorId, status);
      print("🔥 FULL RESPONSE: $res");

      if (res['success'] != true) {
        print("❌ FAILED ACTION: ${res['message']}");
        if (mounted) {
          AppToast.show(context, res['message'] ?? "Action failed", isError: true);
        }
        return false;
      }

      HapticFeedback.lightImpact();

      // Refresh data immediately
      final updatedBookingRes = await ApiService().getSingleBooking(token, widget.bookingId);
      print("UPDATED BOOKING: $updatedBookingRes");

      if (mounted && updatedBookingRes != null) {
        setState(() {
          booking = updatedBookingRes['booking'] ?? updatedBookingRes['data'] ?? updatedBookingRes;
        });
      }
      
      // Refresh in background and global dashboard
      if (mounted) {
        final vendor = context.read<VendorProvider>();
        if (status == "COMPLETED") {
          await vendor.refreshJobsAfterComplete(widget.bookingId);
        } else {
          vendor.fetchDashboardData();
          vendor.fetchAllJobs();
          vendor.fetchTransactions();
          vendor.fetchEarnings();
        }
      }
      
      // 🔥 NAVIGATION: If job is completed, go back to Completed Jobs tab
      // NOTE: This part is now handled by the Completion Modal for the "Complete" action
      if (status == "COMPLETED" && mounted) {
        context.go('/jobs?tab=1');
      }
      return true;
    } catch (e) {
      debugPrint("Update Error: $e");
      return false;
    } finally {
      if (mounted) setState(() => isActionLoading = false);
    }
  }

  Future<bool> _showCompletionFlow(String amount) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      isDismissible: false,
      builder: (context) => JobCompletionModal(
        bookingId: widget.bookingId,
        amount: amount,
        onVerified: () {
          if (mounted) {
            context.read<VendorProvider>().refreshJobsAfterComplete(widget.bookingId);
          }
        },
        onComplete: () async {
          if (mounted) {
            await context.read<VendorProvider>().refreshJobsAfterComplete(widget.bookingId);
            context.go('/jobs?tab=1');
          }
        },
      ),
    );
    return result ?? false;
  }

  Widget _buildStaticActionCircle(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey.shade400, size: 22),
        const SizedBox(width: 16),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w600, color: Color(0xFF495057)))),
      ],
    );
  }

  Widget _buildTieredServiceCard(String main, String sub, String price) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor.withOpacity(0.1), AppTheme.primaryColor.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.auto_awesome_mosaic_rounded, color: AppTheme.primaryColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(main, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0D1B2A))),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(sub, style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
            child: Text("₹$price", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Extract mapped values using universal helper
    final status = _getVal(['status', 'booking_status', 'state'], fallback: '').toString().toLowerCase();
    final name = _getVal(['user_name', 'customer_name', 'name', 'full_name'], fallback: 'Customer');
    final phone = _getVal(['user_phone', 'phone', 'mobile'], fallback: '+91 99999 99999');
    final rawAddress = _getVal(['address', 'location', 'address_line1'], fallback: 'Location not specified');
    final String address = status == "completed" && rawAddress.length > 20 
        ? "${rawAddress.substring(0, 15)}... xxxxxxxxxxxx" 
        : rawAddress;
    final date = _getVal(['booking_date', 'date'], fallback: '---');
    final time = _getVal(['time_slot', 'time'], fallback: '---');
    final price = _getVal(['final_amount', 'amount', 'total_amount', 'price', 'payable_amount'], fallback: '0');

    // 2. Logic for Actionable States (Strict Action Guard)
    final bool isCompletedOrCancelled = status == "completed" || status == "cancelled" || status == "rejected";
    final bool needsAccept = status == "pending" ||
        status == "requested" ||
        status == "new" ||
        status == "assigned";
    
    // Check if in auto-mode to override actionability
    final bool isAutoFlow = false;

    bool isActionable = status == "accepted" || 
                        status == "started" || 
                        status == "pending" || 
                        status == "ongoing" || 
                        status == "assigned" || 
                        status == "confirmed" ||
                        status == "auto";
    
    // Force actionable if in auto-flow and not finished
    if (isAutoFlow && !isCompletedOrCancelled) {
      isActionable = true;
    }

    // 3. Service Data: Dynamic top-level extraction
    final dynamicMain = _getVal(['service_name', 'service', 'category']);
    final dynamicSub = _getVal(['sub_service_name', 'sub_service', 'task']);
    final services = (booking['services_list'] ?? booking['services'] as List?) ?? [];

    // Prioritize services_list; if empty, use top-level dynamic names
    final List resolvedServices = services.isNotEmpty 
        ? services 
        : (dynamicMain != null ? [{'service_name': dynamicMain, 'sub_service_name': dynamicSub, 'price': price}] : []);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // 1. Premium Purple Header with Bubble Patterns
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(60),
                      bottomRight: Radius.circular(60),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(child: CustomPaint(painter: _BubbleBackgroundPainter())),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                                    child: IconButton(
                                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "Job #${widget.bookingId.length > 6 ? widget.bookingId.substring(widget.bookingId.length - 6).toUpperCase() : widget.bookingId.toUpperCase()}",
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Padding(
                                padding: EdgeInsets.only(left: 0),
                                child: Text(
                                  "Job Details",
                                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Interactive Status Tracker
                              _StatusTracker(
                                currentIndex: _getStatusIndex(status, isAutoFlow: isAutoFlow),
                                isAutoFlow: isAutoFlow,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // A. MAP SECTION
                Container(
                  height: 260,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: GoogleMap(
                    key: ValueKey("map-${_markers.length}"),
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: false,
                    initialCameraPosition: CameraPosition(
                      target: _markers.isNotEmpty ? _markers.first.position : const LatLng(17.3850, 78.4867),
                      zoom: 15.5,
                    ),
                    onMapCreated: (controller) => _mapController = controller,
                    markers: _markers,
                    myLocationEnabled: true,
                  ),
                ),

                // B. CUSTOMER CARD (PRO-LEVEL)
                Transform.translate(
                  offset: const Offset(0, -30),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 30, offset: const Offset(0, 15)),
                          BoxShadow(color: AppTheme.primaryColor.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5)),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppTheme.primaryColor.withOpacity(0.1), AppTheme.primaryColor.withOpacity(0.05)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1), width: 2),
                                ),
                                child: Center(
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'C',
                                    style: const TextStyle(color: AppTheme.primaryColor, fontSize: 24, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0D1B2A))),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.verified_user_rounded, color: Colors.green.shade400, size: 14),
                                        const SizedBox(width: 4),
                                        Text("Verified Customer", style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => launchUrl(Uri.parse("tel:$phone")),
                                child: _buildStaticActionCircle(Icons.call_rounded, AppTheme.primaryColor),
                              ),
                            ],
                          ),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1, thickness: 1, color: Color(0xFFF8F9FA))),
                          _buildInfoRow(Icons.location_on_rounded, address),
                          const SizedBox(height: 16),
                          _buildInfoRow(Icons.calendar_today_rounded, "${date.split('T')[0]} • $time"),
                          const SizedBox(height: 24),
                          // Premium Inline Action
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.directions_rounded, size: 18),
                                  label: const Text("Get Directions"),
                                  onPressed: isCompletedOrCancelled ? null : () async {
                                    final rawLat = _getVal(['lat', 'latitude']);
                                    final rawLng = _getVal(['lng', 'longitude']);
                                    if (rawLat != null && rawLng != null) {
                                      final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$rawLat,$rawLng");
                                      if (await canLaunchUrl(url)) await launchUrl(url);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isCompletedOrCancelled ? Colors.grey.shade100 : const Color(0xFF0D1B2A),
                                    foregroundColor: isCompletedOrCancelled ? Colors.grey : Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                               if (status != 'completed') ...[
                                 const SizedBox(width: 12),
                                 Container(
                                   decoration: BoxDecoration(
                                     color: Colors.grey.shade100,
                                     borderRadius: BorderRadius.circular(16),
                                   ),
                                   child: IconButton(
                                     icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF0D1B2A), size: 20),
                                     onPressed: () {},
                                   ),
                                 ),
                               ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // C. SERVICE DETAILS (PRO PILLS)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "SERVICE DETAILS",
                        style: TextStyle(color: Color(0xFF1B263B), fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 16),
                      if (resolvedServices.isEmpty)
                        _buildTieredServiceCard("Service Detail", "", price)
                      else
                        ...resolvedServices.map((s) => _buildTieredServiceCard(
                              (s is Map ? s['service_name'] : null)?.toString() ?? "General Service",
                              (s is Map ? s['sub_service_name'] : null)?.toString() ?? '',
                              (s is Map ? (s['price'] ?? s['final_amount'] ?? price) : price).toString(),
                            )),
                      const SizedBox(height: 140), // Extra space for sticky button
                    ],
                  ),
                ),
              ],
            ),
          ),

          // D. PREMIUM STICKY SWIPE ACTION
          if (needsAccept)
            Positioned(
              bottom: 30,
              left: 24,
              right: 24,
              child: isActionLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                  : Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                                side: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              onPressed: isActionLoading
                                  ? null
                                  : () async {
                                      setState(() => isActionLoading = true);
                                      try {
                                        final prefs = await SharedPreferences.getInstance();
                                        final token = prefs.getString('auth_token') ?? '';
                                        final vendorId =
                                            context.read<VendorProvider>().profile?.vendor.id ?? '';
                                        final res = await ApiService()
                                            .rejectBooking(token, widget.bookingId, vendorId);
                                        if (!mounted) return;
                                        if (res['success'] == true) {
                                          AppToast.show(context, 'Job declined');
                                          await context.read<VendorProvider>().refreshJobsAfterReject();
                                          Navigator.pop(context);
                                        } else {
                                          AppToast.show(
                                            context,
                                            res['message']?.toString() ?? 'Could not decline job',
                                            isError: true,
                                          );
                                        }
                                      } finally {
                                        if (mounted) setState(() => isActionLoading = false);
                                      }
                                    },
                              child: const Text(
                                'Decline',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              onPressed: () async {
                                setState(() => isActionLoading = true);
                                final prefs = await SharedPreferences.getInstance();
                                final token = prefs.getString('auth_token') ?? '';
                                final vendorId = context.read<VendorProvider>().profile?.vendor.id ?? '';
                                final res = await ApiService().acceptBooking(token, widget.bookingId, vendorId);
                                if (!mounted) return;
                                if (res['success'] == true) {
                                  await NotificationHelper.markJobHandled(widget.bookingId);
                                  AppToast.show(context, 'Job accepted!');
                                  await _fetchBookingDetails();
                                  await context.read<VendorProvider>().refreshJobsAfterAccept();
                                } else {
                                  AppToast.show(context, res['message'] ?? 'Could not accept job', isError: true);
                                }
                                setState(() => isActionLoading = false);
                              },
                              child: const Text('Accept', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ),
                      ],
                    ),
            )
          else if (isActionable || status == "completed")
            Builder(
              builder: (context) {
                final currentStep = _getStatusIndex(status, isAutoFlow: isAutoFlow);
                String buttonText = (currentStep < 2) ? "Swipe to Start" : "Swipe to Complete";

                return Positioned(
                  bottom: 30, left: 24, right: 24,
                  child: isActionLoading
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                      : (status == "completed") 
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                color: const Color(0xFF43A047), // Solid Green
                                borderRadius: BorderRadius.circular(50),
                                boxShadow: [
                                  BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  "SERVICE COMPLETED",
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                ),
                              ),
                            )
                          : _SwipeButton(
                              text: buttonText,
                              color: (buttonText == "Swipe to Start") ? AppTheme.primaryColor : Colors.green.shade600,
                              onConfirm: () async {
                                 if (currentStep < 2) {
                                   return await updateStatus("STARTED");
                                 } else {
                                   return await _showCompletionFlow(price.toString());
                                 }
                              },
                            ),
                );
              }
            ),
        ],
      ),
    );
  }
}

class _SwipeButton extends StatefulWidget {
  final Future<bool> Function() onConfirm;
  final String text;
  final Color color;
  const _SwipeButton({required this.onConfirm, required this.text, required this.color});

  @override
  State<_SwipeButton> createState() => _SwipeButtonState();
}

class _SwipeButtonState extends State<_SwipeButton> {
  double position = 0;
  bool confirmed = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = constraints.maxWidth - 64;
        return Container(
          height: 64,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Color.lerp(widget.color, Colors.black, 0.4), // Strong, vibrant colored background
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: widget.color.withOpacity(0.5), width: 1.5),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  widget.text.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                ),
              ),
              Positioned(
                left: position,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (confirmed) return;
                    setState(() {
                      position += details.delta.dx;
                      if (position < 0) position = 0;
                      if (position > maxDrag) position = maxDrag;
                    });
                  },
                  onHorizontalDragEnd: (details) async {
                    if (confirmed) return;
                    if (position > maxDrag * 0.8) {
                      HapticFeedback.heavyImpact();
                      final bool success = await widget.onConfirm();
                      if (!success && mounted) {
                        setState(() {
                          position = 0;
                          confirmed = false;
                        });
                      }
                    } else {
                      setState(() { position = 0; });
                      HapticFeedback.mediumImpact();
                    }
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [widget.color, widget.color.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: widget.color.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.double_arrow_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusTracker extends StatelessWidget {
  final int currentIndex;
  final bool isAutoFlow;

  const _StatusTracker({required this.currentIndex, this.isAutoFlow = false});

  @override
  Widget build(BuildContext context) {
    final steps = ['requested', 'accepted', 'started', 'completed'];

    return Row(
      children: List.generate(steps.length, (index) {
        final isActive = index <= currentIndex;
        final isLast = index == steps.length - 1;
        final isAcceptedStep = steps[index] == 'accepted';
        return Expanded(
          child: Row(
            children: [
              _StatusItem(
                label: steps[index][0].toUpperCase() + steps[index].substring(1),
                isActive: isActive,
                isCurrent: index == currentIndex,
                // Auto-assign: Accepted is already done — show green, not white pulse.
                forceGreen: isAutoFlow && isAcceptedStep && currentIndex >= 1,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: index < currentIndex ? Colors.greenAccent : Colors.white24,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _StatusItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isCurrent;
  final bool forceGreen;

  const _StatusItem({
    required this.label,
    required this.isActive,
    required this.isCurrent,
    this.forceGreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final showGreen = isActive &&
        (forceGreen || !isCurrent || label.toLowerCase() == 'completed');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isCurrent ? 14 : 10,
          height: isCurrent ? 14 : 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: showGreen ? Colors.greenAccent : (isActive ? Colors.white : Colors.white24),
            boxShadow: isCurrent && !forceGreen
                ? [BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 8)]
                : forceGreen
                    ? [BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 8)]
                    : [],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white54,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
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
