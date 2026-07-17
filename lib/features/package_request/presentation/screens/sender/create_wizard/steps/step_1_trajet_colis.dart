import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/urgency/dony_urgency.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/presentation/widgets/city_autocomplete_field.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Étape 1 / 3 — Trajet & colis (Proposal B — Sahel Warmth).
class Step1TrajetColis extends StatefulWidget {
  const Step1TrajetColis({super.key});

  @override
  State<Step1TrajetColis> createState() => Step1TrajetColisState();
}

class Step1TrajetColisState extends State<Step1TrajetColis> {
  final _formKey = GlobalKey<FormState>();
  String? _departureCity;
  String? _arrivalCity;
  DateTime? _date;
  int _tolerance = 2;
  final TransportMode _transportMode = TransportMode.plane;

  @override
  void initState() {
    super.initState();
    // Pré-remplissage (mode édition ou retour à l'étape) depuis l'état du bloc.
    final PackageRequestFormState s =
        context.read<PackageRequestFormBloc>().state;
    _departureCity = s.departureCity;
    _arrivalCity = s.arrivalCity;
    _date = s.desiredDate;
    if (s.dateToleranceDays != null) _tolerance = s.dateToleranceDays!;
  }

  void submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_date == null) {
      DonySnackbar.show(
        context,
        message: 'Choisis une date souhaitée',
        type: DonySnackbarType.warning,
      );
      return;
    }
    if (_departureCity == null || _arrivalCity == null) {
      DonySnackbar.show(
        context,
        message: 'Renseigne les deux villes',
        type: DonySnackbarType.warning,
      );
      return;
    }
    if (_departureCity == _arrivalCity) {
      DonySnackbar.show(
        context,
        message: 'Les villes doivent être différentes',
        type: DonySnackbarType.warning,
      );
      return;
    }
    context.read<PackageRequestFormBloc>().add(
          FormStep1Submitted(
            departureCity: _departureCity!,
            arrivalCity: _arrivalCity!,
            desiredDate: _date!,
            dateToleranceDays: _tolerance,
            transportMode: _transportMode,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.md,
        DonySpacing.lg,
        DonySpacing.huge,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Section label ──────────────────────────────────────────────
            Text(
              'TRAJET & COLIS',
              style: tt.labelMedium?.copyWith(
                color: DonyColors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              "D'où vers où ?",
              style: tt.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: DonyColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: DonySpacing.lg),

            // ── Route card (départ + arrivée) ──────────────────────────────
            _RouteCard(
              departureField: BlocProvider(
                create: (_) => getIt<CitySearchBloc>(),
                child: CityAutocompleteField(
                  label: '',
                  initialValue: _departureCity,
                  onSelected: (city) =>
                      setState(() => _departureCity = city.name),
                ),
              ),
              arrivalField: BlocProvider(
                create: (_) => getIt<CitySearchBloc>(),
                child: CityAutocompleteField(
                  label: '',
                  initialValue: _arrivalCity,
                  onSelected: (city) =>
                      setState(() => _arrivalCity = city.name),
                ),
              ),
            ),
            const SizedBox(height: DonySpacing.base),

            // ── Date + Tolérance row ───────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Date'),
                      const SizedBox(height: DonySpacing.xs),
                      _DatePickerField(
                        date: _date,
                        onChanged: (d) => setState(() => _date = d),
                      ),
                      // ── Feedback informatif « sera signalée urgente » ──
                      // Non-bloquant : n'affecte jamais la soumission.
                      if (_date != null && isUrgentDate(_date!))
                        Padding(
                          padding: const EdgeInsets.only(top: DonySpacing.xs),
                          child: Text(
                            '🔥 Date proche — cette demande sera signalée urgente',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Tolérance'),
                      const SizedBox(height: DonySpacing.xs),
                      _ToleranceField(
                        tolerance: _tolerance,
                        onChanged: (t) => setState(() => _tolerance = t),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DonySpacing.base),

            // ── Mode de transport — Avion verrouillé ───────────────────────
            const _LockedAirplaneBlock(),
          ],
        ),
      ),
    );
  }
}

// ─── Locked Airplane Block ────────────────────────────────────────────────────

class _LockedAirplaneBlock extends StatelessWidget {
  const _LockedAirplaneBlock();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.md,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          DonyIcon(
            'plane',
            size: 22,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Avion',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  'seul mode disponible',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          DonyIcon(
            'lock',
            size: 16,
            color: cs.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

// ─── Route Card ──────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.departureField,
    required this.arrivalField,
  });

  final Widget departureField;
  final Widget arrivalField;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.neutral200),
        boxShadow: [
          BoxShadow(
            color: DonyColors.sand400.withValues(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // Column simple — pas de Row+stretch, pas de hauteur infinie
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: DonyColors.primary, width: 4),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.md, DonySpacing.md, DonySpacing.md, DonySpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CityHeader(
                  label: 'DÉPART',
                  iconAsset: 'locate-fixed',
                ),
                const SizedBox(height: DonySpacing.xs),
                departureField,
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: DonyColors.neutral200),
          Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  width: 4,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.md, DonySpacing.sm, DonySpacing.md, DonySpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CityHeader(
                  label: 'ARRIVÉE',
                  iconAsset: 'map-pin',
                ),
                const SizedBox(height: DonySpacing.xs),
                arrivalField,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CityHeader extends StatelessWidget {
  const _CityHeader({required this.label, required this.iconAsset});

  final String label;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(DonyRadius.sm),
          ),
          child: Center(
            child: DonyIcon(iconAsset, size: 14, color: cs.primary),
          ),
        ),
        const SizedBox(width: DonySpacing.sm),
        Text(
          label,
          style: tt.labelSmall?.copyWith(
            color: DonyColors.textMuted,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ─── Atoms ──────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: DonyColors.textPrimary,
            fontSize: 14,
          ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({required this.date, required this.onChanged});
  final DateTime? date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final dateText = date == null
        ? 'Date'
        : DateFormat('d MMM. y', 'fr_FR').format(date!);
    return InkWell(
      borderRadius: BorderRadius.circular(DonyRadius.md),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now().add(const Duration(days: 7)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 90)),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.md + 2,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          children: [
            const Text('📆', style: TextStyle(fontSize: 14)),
            const SizedBox(width: DonySpacing.xs),
            Flexible(
              child: Text(
                dateText,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyMedium?.copyWith(
                  color: date == null
                      ? DonyColors.textSubtle
                      : DonyColors.textPrimary,
                  fontWeight: date == null ? FontWeight.w500 : FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToleranceField extends StatelessWidget {
  const _ToleranceField({required this.tolerance, required this.onChanged});
  final int tolerance;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(DonyRadius.md),
      onTap: () => _openSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.md + 2,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(color: cs.outline),
        ),
        child: Text(
          '± $tolerance j',
          style: tt.bodyMedium?.copyWith(
            color: DonyColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final t in [0, 1, 2, 3, 5, 7])
                ListTile(
                  title: Text(t == 0
                      ? 'Date exacte'
                      : '± $t ${t > 1 ? "jours" : "jour"}'),
                  trailing: t == tolerance
                      ? const DonyIcon('check',
                          color: DonyColors.primary)
                      : null,
                  onTap: () {
                    onChanged(t);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Bouton sélectionnable pill — emoji/icône + label.
/// Sélectionné : bg terracotta + texte blanc. Repos : blanc + bord neutral.
class OptionButton extends StatelessWidget {
  const OptionButton({
    super.key,
    required this.label,
    this.icon,
    this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final String? emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final fg = selected ? Colors.white : cs.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DonyRadius.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base - 2,
          vertical: DonySpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.lg),
          border: Border.all(
            color: selected ? cs.primary : cs.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null)
              Text(emoji!, style: const TextStyle(fontSize: 14))
            else if (icon != null)
              Icon(icon, size: 16, color: fg),
            const SizedBox(width: DonySpacing.xs + 2),
            Text(
              label,
              style: tt.labelLarge?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
