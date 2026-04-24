import 'package:dony/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onBranchTapped(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      floatingActionButton: _DonyFab(
        onPressed: () => context.push('/announcements/create'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _DonyBottomBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _onBranchTapped,
      ),
    );
  }
}

// ─── FAB central ────────────────────────────────────────────────────────────

class _DonyFab extends StatelessWidget {
  const _DonyFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: kGreenPrimary.withValues(alpha: 0.45),
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

// ─── Bottom App Bar ──────────────────────────────────────────────────────────

class _DonyBottomBar extends StatelessWidget {
  const _DonyBottomBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 72,
      padding: EdgeInsets.zero,
      notchMargin: 10,
      shape: const CircularNotchedRectangle(),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      color: kSurface,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kBorder, width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              outlinedIcon: Icons.home_outlined,
              label: 'Accueil',
              index: 0,
              currentIndex: currentIndex,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: Icons.flight_takeoff_rounded,
              outlinedIcon: Icons.flight_takeoff_outlined,
              label: 'Trajets',
              index: 1,
              currentIndex: currentIndex,
              onTap: () => onTap(1),
            ),
            const SizedBox(width: 60), // espace pour le FAB
            _NavItem(
              icon: Icons.qr_code_scanner_rounded,
              outlinedIcon: Icons.qr_code_rounded,
              label: 'Suivi',
              index: 2,
              currentIndex: currentIndex,
              onTap: () => onTap(2),
            ),
            _NavItem(
              icon: Icons.person_rounded,
              outlinedIcon: Icons.person_outline_rounded,
              label: 'Profil',
              index: 3,
              currentIndex: currentIndex,
              onTap: () => onTap(3),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Item de navigation ──────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.outlinedIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  final IconData icon;
  final IconData outlinedIcon;
  final String label;
  final int index;
  final int currentIndex;
  final VoidCallback onTap;

  bool get _active => index == currentIndex;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: _active ? kGreenLight : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _active ? icon : outlinedIcon,
                size: 22,
                color: _active ? kGreenPrimary : kTextSecondary,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: _active ? FontWeight.w700 : FontWeight.w500,
                color: _active ? kGreenPrimary : kTextSecondary,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}