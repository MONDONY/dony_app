import 'dart:ui';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/home/presentation/home_map_focus.dart';
import 'package:flutter/material.dart';

/// Filtre de focus de la carte Home : Tout / Colis / Trajets.
/// Visible uniquement pour les voyageurs (`isTraveler == true`).
/// Widget stateless : l'état est géré par le parent via [focus] + [onChanged].
class HomeFocusFilter extends StatelessWidget {
  const HomeFocusFilter({
    super.key,
    required this.focus,
    required this.onChanged,
  });

  final HomeMapFocus focus;
  final ValueChanged<HomeMapFocus> onChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.full),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(DonyRadius.full),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Segment(
                label: 'Tout',
                isActive: focus == HomeMapFocus.all,
                onTap: () => onChanged(HomeMapFocus.all),
              ),
              _Segment(
                label: 'Colis',
                emoji: '📦',
                isActive: focus == HomeMapFocus.parcels,
                onTap: () => onChanged(HomeMapFocus.parcels),
              ),
              _Segment(
                label: 'Trajets',
                emoji: '✈️',
                isActive: focus == HomeMapFocus.trips,
                onTap: () => onChanged(HomeMapFocus.trips),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.emoji,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isActive ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(DonyRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: DonySpacing.xs),
            ],
            Text(
              label,
              style: tt.labelMedium?.copyWith(
                color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
