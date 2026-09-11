import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tapasya_vendor_app/core/utils/job_navigation_utils.dart';
import 'package:tapasya_vendor_app/core/utils/job_payload_utils.dart';
import 'package:tapasya_vendor_app/core/utils/notification_helper.dart';
import 'package:tapasya_vendor_app/services/api_service.dart';

/// Auto-mode: informational popup — job is already assigned, no Accept/Reject.
class AutoJobAssignedScreen extends StatefulWidget {
  final Map<String, dynamic> jobData;

  const AutoJobAssignedScreen({super.key, required this.jobData});

  @override
  State<AutoJobAssignedScreen> createState() => _AutoJobAssignedScreenState();
}

class _AutoJobAssignedScreenState extends State<AutoJobAssignedScreen> {
  late String bookingId;
  Map<String, dynamic>? fullJobData;
  bool isLoadingDetails = true;

  @override
  void initState() {
    super.initState();
    bookingId = (widget.jobData['booking_id'] ?? widget.jobData['id'])?.toString() ?? '';
    fullJobData = Map<String, dynamic>.from(widget.jobData);

    // Auto-assign popup is silent — stop any alert sound that may still be playing.
    NotificationHelper.stopJobAlertLoop();
    // Remove the tray notification banner so only this popup is shown.
    NotificationHelper.cancelJobNotification(bookingId);
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    if (bookingId.isEmpty || bookingId.startsWith('preview_auto_')) {
      if (mounted) setState(() => isLoadingDetails = false);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final res = await ApiService().getBookingDetails(token, bookingId);
    if (mounted && res != null) {
      setState(() {
        fullJobData = res['booking'] ?? res['data'] ?? res;
        isLoadingDetails = false;
      });
    } else if (mounted) {
      setState(() => isLoadingDetails = false);
    }
  }

  void _stopAlert() {
    NotificationHelper.stopJobAlertLoop();
    NotificationHelper.activeJobPopups.remove(bookingId);
  }

  void _closePopup() {
    _stopAlert();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _openMaps() async {
    _stopAlert();
    await JobNavigationUtils.openMaps(fullJobData ?? widget.jobData);
  }

  void _viewDetails() {
    _stopAlert();

    if (!mounted) return;
    Navigator.pop(context);
    context.push(
      '/jobs/details/$bookingId',
      extra: fullJobData ?? widget.jobData,
    );
  }

  @override
  void dispose() {
    NotificationHelper.stopJobAlertLoop();
    NotificationHelper.activeJobPopups.remove(bookingId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerName = JobPayloadUtils.customerName(fullJobData ?? widget.jobData);
    final locationLabel = JobPayloadUtils.locationLabel(fullJobData ?? widget.jobData);
    final service = JobPayloadUtils.serviceName(fullJobData ?? widget.jobData);

    return Scaffold(
      backgroundColor: Colors.black54,
      body: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 40),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Job Assigned Successfully',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'This job is already yours — no accept needed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                ),
                const SizedBox(height: 22),
                if (isLoadingDetails)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                else ...[
                  _infoRow(Icons.person_outline_rounded, 'Customer', customerName),
                  const SizedBox(height: 12),
                  _infoRow(Icons.location_on_outlined, 'Location', locationLabel),
                  const SizedBox(height: 12),
                  _infoRow(Icons.build_outlined, 'Service', service),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isLoadingDetails ? null : _openMaps,
                        icon: const Icon(Icons.navigation_rounded, size: 20),
                        label: const Text('Navigate', style: TextStyle(fontWeight: FontWeight.w800)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF111827),
                          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isLoadingDetails ? null : _viewDetails,
                        icon: const Icon(Icons.visibility_outlined, size: 20),
                        label: const Text('View Details', style: TextStyle(fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B47FF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _closePopup,
                  child: Text('Dismiss', style: TextStyle(color: Colors.grey.shade600)),
                ),
              ],
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
        Icon(icon, size: 22, color: const Color(0xFF8B47FF)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
