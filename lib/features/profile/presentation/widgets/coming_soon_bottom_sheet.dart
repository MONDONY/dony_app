import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bottom sheet "Bientôt disponible" réutilisable pour les entrées profil
/// qui n'ont pas encore d'écran dédié (parrainage, factures, voyageurs
/// favoris, etc.).
///
/// L'objectif est d'éviter les `onTap: () {}` muets qui laissent l'utilisateur
/// sans feedback, tout en communiquant clairement la roadmap.
class ComingSoonBottomSheet extends StatelessWidget {
  const ComingSoonBottomSheet({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.auto_awesome_rounded,
  });

  final String title;
  final String description;
  final IconData icon;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String description,
    IconData icon = Icons.auto_awesome_rounded,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ComingSoonBottomSheet(
        title: title,
        description: description,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.lg,
          DonySpacing.sm,
          DonySpacing.lg,
          DonySpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: DonySpacing.lg),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: cs.primary, size: 28),
            ),
            const SizedBox(height: DonySpacing.md),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              description,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: DonySpacing.lg),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.md,
                vertical: DonySpacing.sm,
              ),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      color: cs.onSurfaceVariant, size: 18),
                  const SizedBox(width: DonySpacing.sm),
                  Expanded(
                    child: Text(
                      'Bientôt disponible',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DonySpacing.md),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Compris',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
