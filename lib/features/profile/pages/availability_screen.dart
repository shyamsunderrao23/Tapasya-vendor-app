import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:tapasya_vendor_app/features/home/vendor_provider.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  List<dynamic> _localAvailability = [];
  bool _hasSyncedWithBackend = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<VendorProvider>().fetchAvailability();
      if (mounted) {
        setState(() {
          _initializeLocalData(context.read<VendorProvider>().availabilityData);
          _hasSyncedWithBackend = true;
        });
      }
    });
  }

  void _initializeLocalData(List<dynamic> data) {
    if (data.isEmpty) {
      _localAvailability = [
        {"day": "Monday", "start_time": "09:00:00", "end_time": "18:00:00", "is_available": 1},
        {"day": "Tuesday", "start_time": "09:00:00", "end_time": "18:00:00", "is_available": 1},
        {"day": "Wednesday", "start_time": "09:00:00", "end_time": "18:00:00", "is_available": 1},
        {"day": "Thursday", "start_time": "09:00:00", "end_time": "18:00:00", "is_available": 1},
        {"day": "Friday", "start_time": "09:00:00", "end_time": "18:00:00", "is_available": 1},
        {"day": "Saturday", "start_time": null, "end_time": null, "is_available": 0},
        {"day": "Sunday", "start_time": null, "end_time": null, "is_available": 0},
      ];
    } else {
      _localAvailability = data.map((item) => Map<String, dynamic>.from(item)).toList();
    }
  }

  Future<void> _handleSave() async {
    HapticFeedback.heavyImpact();
    final res = await context.read<VendorProvider>().updateAvailability(_localAvailability);
    if (mounted) {
      final bool success = res['success'] == true;
      AppToast.show(
        context, 
        res['message'] ?? (success ? "Schedule saved!" : "Failed to save"),
        isError: !success,
      );
      if (res['success'] == true) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VendorProvider>(
      builder: (context, provider, child) {
        if (!_hasSyncedWithBackend) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // 1. CINEMATIC HEADER
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(60), bottomRight: Radius.circular(60)),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(child: CustomPaint(painter: _BubbleBackgroundPainter())),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 50),
                          child: Column(
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
                                  const SizedBox(width: 20),
                                  const Text(
                                    "Manage Availability",
                                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                                child: const Icon(Icons.event_available_rounded, color: Colors.white, size: 36),
                              ).animate().scale(delay: 200.ms, curve: Curves.elasticOut),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 2. WEEKLY VIEW
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Weekly Schedule",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1B263B), letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 20),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _localAvailability.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _localAvailability[index];
                          final day = item['day'];
                          final isEnabled = item['is_available'] == 1;
                          return _buildDayCard(item, index);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                
                // 3. SAVE BUTTON
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: provider.isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : InkWell(
                        onTap: _handleSave,
                        borderRadius: BorderRadius.circular(28),
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [AppTheme.primaryColor, Color(0xFF6200EE)]),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                          ),
                          child: const Center(
                            child: Text("Save Availability", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        );
      },
    );
  }
  

  String _formatTime(String? timeStr) {
    if (timeStr == null || !timeStr.contains(':')) return "--:--";
    final parts = timeStr.split(':');
    final String hhStr = parts.isNotEmpty ? parts[0] : '00';
    final String mmStr = parts.length > 1 ? parts[1] : '00';
    int h = int.tryParse(hhStr) ?? 0;
    int m = int.tryParse(mmStr) ?? 0;
    
    final int hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final String amPm = h >= 12 ? "PM" : "AM";
    return "${hour12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $amPm";
  }

  Future<void> _selectTime(BuildContext context, Map<String, dynamic> item, String key) async {
    final currentTimeString = item[key] as String?;
    TimeOfDay initialTime = const TimeOfDay(hour: 9, minute: 0);
    
    if (currentTimeString != null && currentTimeString.contains(':')) {
      final parts = currentTimeString.split(':');
      if (parts.length >= 2) {
        initialTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 9,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
         return Theme(
           data: Theme.of(context).copyWith(
             colorScheme: const ColorScheme.light(
               primary: AppTheme.primaryColor,
             ),
           ),
           child: child!,
         );
      },
    );

    if (picked != null) {
      setState(() {
        final hh = picked.hour.toString().padLeft(2, '0');
        final mm = picked.minute.toString().padLeft(2, '0');
        item[key] = "$hh:$mm:00";
      });
    }
  }

  Widget _buildTimePickerPill({required String time, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time_rounded, size: 14, color: AppTheme.primaryColor),
            const SizedBox(width: 4),
            Text(time, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCard(Map<String, dynamic> item, int index) {
    final day = item['day'];
    final isEnabled = item['is_available'] == 1;
    final startTime = item['start_time'] ?? "09:00:00";
    final endTime = item['end_time'] ?? "18:00:00";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 6))],
        border: Border.all(color: isEnabled ? AppTheme.primaryColor.withOpacity(0.2) : Colors.grey.shade50, width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isEnabled ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isEnabled ? Icons.check_circle_rounded : Icons.do_not_disturb_on_rounded, 
              color: isEnabled ? AppTheme.primaryColor : Colors.grey.shade400,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1B263B))),
                const SizedBox(height: 6),
                isEnabled 
                  ? Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTimePickerPill(time: _formatTime(startTime), onTap: () => _selectTime(context, item, 'start_time')),
                        const Text("—", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        _buildTimePickerPill(time: _formatTime(endTime), onTap: () => _selectTime(context, item, 'end_time')),
                      ],
                    )
                  : Text("Closed for the day", style: TextStyle(color: Colors.red.shade300, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Switch.adaptive(
            value: isEnabled, 
            activeColor: AppTheme.primaryColor,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              setState(() {
                item['is_available'] = val ? 1 : 0;
                if (val) {
                  item['start_time'] = item['start_time'] ?? "09:00:00";
                  item['end_time'] = item['end_time'] ?? "18:00:00";
                } else {
                  // Usually best to leave times as they were when disabled so they are remembered if re-enabled.
                  // But following previous logic: you can nullify or keep them.
                  item['start_time'] = null;
                  item['end_time'] = null;
                }
              });
            }
          ),
        ],
      ),
    ).animate().fadeIn(delay: (200 + (index * 80)).ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }
}

class _BubbleBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.05)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.2), 40, paint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.1), 60, paint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.7), 80, paint);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.8), 50, paint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.4), 30, paint);
    final strokePaint = Paint()..color = Colors.white.withOpacity(0.03)..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.5), 90, strokePaint);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.3), 70, strokePaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
