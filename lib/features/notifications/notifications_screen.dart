import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/features/home/vendor_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Jobs', 'Payments', 'System'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorProvider>().fetchNotifications();
    });
  }

  List<Map<String, dynamic>> _itemsForCategory(VendorProvider provider) {
    switch (_selectedCategory) {
      case 'Jobs':
        return provider.notificationsJobs;
      case 'Payments':
        return provider.notificationsPayments;
      case 'System':
        return provider.notificationsSystem;
      default:
        return provider.notificationsAll;
    }
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
      if (diff.inHours < 24) return '${diff.inHours} hours ago';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  bool _isUnread(Map<String, dynamic> item) {
    final read = item['is_read'];
    return read == 0 || read == '0' || read == false;
  }

  IconData _iconFor(Map<String, dynamic> item, String fallbackCategory) {
    final type = (item['type'] ?? fallbackCategory).toString().toLowerCase();
    if (fallbackCategory == 'Payments' || type.contains('payment')) {
      return Icons.account_balance_wallet_rounded;
    }
    if (fallbackCategory == 'System' || type.contains('system')) {
      return Icons.bolt_rounded;
    }
    return Icons.work_outline_rounded;
  }

  Color _colorFor(Map<String, dynamic> item, String fallbackCategory) {
    final type = (item['type'] ?? fallbackCategory).toString().toLowerCase();
    if (fallbackCategory == 'Payments' || type.contains('payment')) {
      return Colors.green;
    }
    if (fallbackCategory == 'System' || type.contains('system')) {
      return AppTheme.primaryColor;
    }
    return Colors.orange;
  }

  Map<String, dynamic> _toDisplayItem(Map<String, dynamic> raw, String category) {
    return {
      ...raw,
      'title': raw['title']?.toString() ?? 'Notification',
      'message': raw['message']?.toString() ?? '',
      'time': _formatTime(raw['created_at']?.toString()),
      'isUnread': _isUnread(raw),
      'icon': _iconFor(raw, category),
      'color': _colorFor(raw, category),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VendorProvider>(
      builder: (context, provider, _) {
        final items = _itemsForCategory(provider)
            .map((e) => _toDisplayItem(e, _selectedCategory))
            .toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: Column(
            children: [
              _buildPremiumHeader(provider),
              const SizedBox(height: 12),
              _buildCategorySelector(provider),
              const SizedBox(height: 12),
              Expanded(
                child: provider.notificationsLoading && items.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : items.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: () => provider.fetchNotifications(),
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                              itemCount: items.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) => _buildNotificationCard(items[index]),
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPremiumHeader(VendorProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 40),
      decoration: const BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(50), bottomRight: Radius.circular(50)),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _BubbleBackgroundPainter())),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
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
                      const SizedBox(width: 20),
                      const Text(
                        "Notifications",
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      ),
                      const Spacer(),
                      if (provider.totalUnreadNotifications > 0)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${provider.totalUnreadNotifications} new',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      Container(
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.done_all_rounded, color: Colors.white, size: 20),
                          onPressed: provider.totalUnreadNotifications == 0
                              ? null
                              : () {
                                  HapticFeedback.mediumImpact();
                                  provider.markAllNotificationsRead();
                                },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildCategorySelector(VendorProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          final badge = provider.notificationUnreadFor(cat);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: AnimatedContainer(
                  duration: 250.ms,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200),
                    boxShadow: isSelected
                        ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]
                        : [],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey.shade600,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      if (badge > 0)
                        Positioned(
                          right: -2,
                          top: -8,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.redAccent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Text(
                              badge > 99 ? '99+' : '$badge',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected ? AppTheme.primaryColor : Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildNotificationCard(Map<String, dynamic> n) {
    final icon = n['icon'] as IconData;
    final color = n['color'] as Color;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: color.withOpacity(0.08), shape: BoxShape.circle),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    if (n['isUnread'] == true)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A00E0),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              n['title'] as String,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1B263B)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            n['time'] as String,
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        n['message'] as String,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
                      ),
                      if (n['customer_name'] != null && n['customer_name'].toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Customer: ${n['customer_name']}',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                      if (n['final_amount'] != null && n['final_amount'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Amount: ₹${n['final_amount']}',
                          style: const TextStyle(color: Color(0xFF1B263B), fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/no-service-request.png', width: 250, height: 250)
              .animate()
              .scale(duration: 500.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 24),
          const Text("All Caught Up!", style: TextStyle(color: Color(0xFF1B263B), fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50),
            child: Text(
              "You don't have any notifications at the moment. We'll alert you when something important happens!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14, height: 1.5, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _BubbleBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.05)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.2), 30, paint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.15), 50, paint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.7), 60, paint);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.8), 40, paint);
    final strokePaint = Paint()..color = Colors.white.withOpacity(0.03)..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.5), 70, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
