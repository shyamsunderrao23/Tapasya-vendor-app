import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';

import 'package:provider/provider.dart';
import 'package:tapasya_vendor_app/features/home/vendor_provider.dart';

class MainWrapper extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainWrapper({
    super.key,
    required this.navigationShell,
  });

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded = context.watch<VendorProvider>().isMagicFabExpanded;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: navigationShell,
      bottomNavigationBar: AnimatedOpacity(
        duration: 300.ms,
        opacity: isExpanded ? 0 : 1,
        child: IgnorePointer(
          ignoring: isExpanded,
          child: ColoredBox(
            // White fills the full bottom area, including the system gesture bar strip.
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.grid_view_rounded, 'Home'),
                    _buildNavItem(1, Icons.assignment_rounded, 'Jobs'),
                    _buildNavItem(2, Icons.account_balance_wallet_rounded, 'Earnings'),
                    _buildNavItem(3, Icons.person_rounded, 'Profile'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = navigationShell.currentIndex == index;
    
    return InkWell(
      onTap: () => _goBranch(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: 300.ms,
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated Icon Container
            AnimatedContainer(
              duration: 300.ms,
              padding: const EdgeInsets.all(10), // Reduced size as requested
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isSelected 
                  ? const LinearGradient(
                      colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)], 
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ) 
                  : null,
                boxShadow: isSelected 
                  ? [BoxShadow(color: const Color(0xFF4A00E0).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
                  : [],
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade400,
                size: 22, // Slightly smaller icon
              ),
            ).animate(target: isSelected ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
            
            const SizedBox(height: 6),
            
            // Label with smooth color transition
            AnimatedDefaultTextStyle(
              duration: 300.ms,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryColor : Colors.grey.shade400,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
