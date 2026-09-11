import 'package:flutter/material.dart';

class PremiumScaleButton extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;

  const PremiumScaleButton({super.key, required this.onTap, required this.child});

  @override
  State<PremiumScaleButton> createState() => _PremiumScaleButtonState();
}

class _PremiumScaleButtonState extends State<PremiumScaleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: widget.onTap != null ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: widget.onTap != null ? () => setState(() => _isPressed = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        curve: Curves.easeOutCubic,
        duration: const Duration(milliseconds: 150),
        child: widget.child,
      ),
    );
  }
}
