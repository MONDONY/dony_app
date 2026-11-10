import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Pastille du statut légal du voyageur : « Particulier » (grise) ou
/// « Professionnel » (bleue, suivie du numéro d'immatriculation quand il est
/// fourni).
///
/// Ne rend rien quand [status] est `null` : voyageur qui n'a pas encore
/// répondu, ou back antérieur au statut. Une seule ligne : un numéro trop long
/// est tronqué par une ellipse, jamais coupé sur deux lignes.
///
/// [registrationNumber] n'est lu que pour un professionnel : un particulier
/// n'en a pas, et un champ résiduel ne doit jamais s'afficher.
class TravelerStatusChip extends StatelessWidget {
  const TravelerStatusChip({
    required this.status,
    this.registrationNumber,
    super.key,
  });

  final TravelerStatus? status;
  final String? registrationNumber;

  @override
  Widget build(BuildContext context) {
    final current = status;
    if (current == null) return const SizedBox.shrink();
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final number = registrationNumber?.trim();
    final label = switch (current) {
      TravelerStatus.individual => l.travelerStatusChipIndividual,
      TravelerStatus.professional =>
        number == null || number.isEmpty
            ? l.travelerStatusChipProfessional
            : l.travelerStatusChipProfessionalWithNumber(number),
    };
    final professional = current == TravelerStatus.professional;
    final bg = professional ? cs.primaryContainer : cs.surfaceContainerHighest;
    final fg = professional ? cs.primary : cs.onSurfaceVariant;

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.sm,
          vertical: DonySpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(DonyRadius.full),
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: tt.labelSmall?.copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
