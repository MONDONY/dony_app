import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Carte récap à l'étape 3 — fond beige clair (style maquette).
class WizardSummaryCard extends StatelessWidget {
  const WizardSummaryCard({super.key, required this.state});

  final PackageRequestFormState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Fond chaud subtil — utilise DonyColors.surfaceWarm si dispo, sinon
    // tombe sur primary à très faible alpha sur surface (theme-aware).
    final bg = Color.lerp(cs.primary, cs.surface, 0.92)!;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _line(context, 'Trajet', _corridorText(state)),
          _line(context, 'Date', _dateText(state)),
          _line(context, 'Colis', _packageText(state)),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: tt.bodySmall?.copyWith(
                color: DonyColors.textMuted,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: tt.bodyMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: DonyColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _corridorText(PackageRequestFormState s) {
    final dep = s.departureCity ?? '—';
    final arr = s.arrivalCity ?? '—';
    return '$dep → $arr';
  }

  String _dateText(PackageRequestFormState s) {
    if (s.desiredDate == null) return '—';
    final f = DateFormat('d MMM. y', 'fr_FR').format(s.desiredDate!);
    final tol = s.dateToleranceDays ?? 0;
    return tol == 0 ? f : '$f ±${tol}j';
  }

  String _packageText(PackageRequestFormState s) {
    final size = s.parcelSize?.wireName ?? '—';
    final w = s.weightKg;
    final wStr = w == null
        ? ''
        : ' · ${w.toStringAsFixed(w.truncateToDouble() == w ? 0 : 1)} kg';
    final cat = s.contentCategory?.label != null
        ? ' · ${s.contentCategory!.label.split(' ').first}.'
        : '';
    return '$size$wStr$cat';
  }
}
