import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/features/home/vendor_provider.dart';
import 'package:tapasya_vendor_app/main.dart'; // To access navigatorKey

class MagicFab extends StatefulWidget {
  final bool isNew;
  final VoidCallback? onAddService;
  final VoidCallback? onCompleteProfile;
  final VoidCallback? onWithdraw;
  final VoidCallback? onAvailability;
  final VoidCallback? onUploadWork;

  const MagicFab({
    super.key,
    required this.isNew,
    this.onAddService,
    this.onCompleteProfile,
    this.onWithdraw,
    this.onAvailability,
    this.onUploadWork,
  });

  @override
  State<MagicFab> createState() => _MagicFabState();
}

class _MagicFabState extends State<MagicFab> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotationAnimation;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: 350.ms);
    _expandAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _rotationAnimation = Tween<double>(begin: 0, end: 0.125).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    try {
      if (_overlayEntry != null) {
        // Use a slight delay or SchedulerBinding if needed, but remove() is usually safe in try-catch
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    } catch (e) {
      debugPrint("⚠️ MagicFab Overlay Removal Info (Safe-Caught): $e");
      _overlayEntry = null;
    }
  }

  void _toggle({bool immediate = false}) {
    // 🛡️ ULTRA-ROBUST CONTEXT RECOVERY
    // If the FAB's local context is deactivated (e.g. during a screen swap), 
    // we fall back to the root navigator context to ensure the provider remains accessible.
    final safeContext = mounted ? context : navigatorKey.currentContext;
    if (safeContext == null) return;

    try {
      final vendorProvider = safeContext.read<VendorProvider>();

      if (_isExpanded) {
        // 1. ATOMIC STATE CLOSURE
        if (mounted) setState(() => _isExpanded = false);
        vendorProvider.setMagicFabExpanded(false);

        if (immediate) {
          _controller.value = 0;
          _removeOverlay();
        } else {
          _controller.reverse().then((_) {
            if (mounted || _overlayEntry != null) _removeOverlay();
          });
        }
      } else {
        // 2. ROBUST OPENING
        final overlayState = (navigatorKey.currentState?.overlay);
        if (overlayState == null) return;

        _overlayEntry = _createOverlayEntry();
        overlayState.insert(_overlayEntry!);
        _controller.forward();
        
        if (mounted) setState(() => _isExpanded = true);
        vendorProvider.setMagicFabExpanded(true);
      }
    } catch (e) {
      debugPrint("❌ MagicFab Toggle Error: $e");
    }
  }

  OverlayEntry _createOverlayEntry() {
    final List<Map<String, dynamic>> actions = widget.isNew 
        ? [
            {'label': 'Service', 'icon': Icons.handyman_rounded, 'color': Colors.blue, 'onTap': widget.onAddService},
            {'label': 'Profile', 'icon': Icons.person_add_rounded, 'color': Colors.green, 'onTap': widget.onCompleteProfile},
          ]
        : [
            {'label': 'Withdraw', 'icon': Icons.account_balance_wallet_rounded, 'color': Colors.green, 'onTap': widget.onWithdraw},
            {'label': 'Availability', 'icon': Icons.event_available_rounded, 'color': Colors.orange, 'onTap': widget.onAvailability},
            {'label': 'Work', 'icon': Icons.upload_file_rounded, 'color': Colors.blue, 'onTap': widget.onUploadWork},
          ];

    return OverlayEntry(
      builder: (overlayContext) {
        // 🛡️ REIFIED CONTEXT: Explicitly inherit theme and directionality to prevent 'Red Screen' errors
        return Theme(
          data: Theme.of(context),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  // 1. FULL SCREEN BACKGROUND BLUR
                  GestureDetector(
                    onTap: () {
                      try {
                        _toggle();
                      } catch (e) {
                         _removeOverlay();
                         debugPrint("⚠️ Backdrop toggle fail-safe: $e");
                      }
                    },
                    child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withOpacity(0.35),
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ).animate().fadeIn(duration: 200.ms),

          // 2. RADIAL ACTION BUTTONS (Positioned relative to screen bottom-right)
          ...List.generate(actions.length, (index) {
            return _buildRadialButton(
              index: index,
              count: actions.length,
              label: actions[index]['label'],
              icon: actions[index]['icon'],
              color: actions[index]['color'],
              onTap: actions[index]['onTap'],
            );
          }),

          // 3. CLONE OF MAIN FAB (To handle closing and keep rotation visible)
          Positioned(
            right: 20,
            bottom: 20,
            child: RotationTransition(
              turns: _rotationAnimation,
              child: FloatingActionButton(
                onPressed: () {
                  try {
                    _toggle();
                  } catch (e) {
                    _removeOverlay();
                  }
                },
                backgroundColor: AppTheme.primaryColor,
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.add, color: Colors.white, size: 32),
              ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack),
            ),
          ),
        ],
      ),
    ),
  ),
);
      }
    );
  }

  Widget _buildRadialButton({
    required int index,
    required int count,
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // 🛡️ STAGGERED CLAMP: Ensure the parametric value 't' is ALWAYS within [0.0, 1.0]
        final double start = (index * 0.1).clamp(0.0, 0.4);
        const double end = 1.0;
        final double t = ((_controller.value - start) / (end - start).clamp(0.01, 1.0)).clamp(0.0, 1.0);
        final double animValue = Curves.easeOutBack.transform(t);

        return Positioned(
          right: 24,
          bottom: 100 + (index * 85.0 * animValue),
          child: Opacity(
            opacity: animValue.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.8 + (0.2 * animValue),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Label (To the left of icon)
                  Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10)],
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1B263B), decoration: TextDecoration.none)
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Icon Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // ⚡ IMPORTANT: Force close immediately BEFORE navigation to prevent context/overlay errors
                        _toggle(immediate: true);
                        onTap?.call();
                      },
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5))],
                        ),
                        child: Icon(icon, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only show the base FAB here. The menu and blur are in the Overlay.
    return RotationTransition(
      turns: _rotationAnimation,
      child: FloatingActionButton(
        onPressed: () => _toggle(),
        backgroundColor: AppTheme.primaryColor,
        elevation: _isExpanded ? 0 : 8, // Hide elevation when overlay clone is active
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
    );
  }
}
