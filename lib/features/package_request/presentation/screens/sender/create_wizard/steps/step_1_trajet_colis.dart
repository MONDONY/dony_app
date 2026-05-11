import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/presentation/widgets/city_autocomplete_field.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Étape 1 / 3 — Trajet & colis (match maquette `v3/expéditeur_publie`).
///
/// Layout : label section "TRAJET & COLIS" (accent) · titre "D'où vers où ?"
/// · 2 inputs villes · Date + Tolérance row · Mode de transport en boutons.
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
  TransportMode _transportMode = TransportMode.plane;

  void submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis une date souhaitée')),
      );
      return;
    }
    if (_departureCity == null || _arrivalCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Renseigne les deux villes')),
      );
      return;
    }
    if (_departureCity == _arrivalCity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les villes doivent être différentes')),
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
                color: DonyColors.accent,
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

            // ── Départ ─────────────────────────────────────────────────────
            _FieldLabel('Départ'),
            const SizedBox(height: DonySpacing.xs),
            BlocProvider(
              create: (_) => getIt<CitySearchBloc>(),
              child: CityAutocompleteField(
                label: '',
                initialValue: _departureCity,
                prefixIcon: const Text('📍', style: TextStyle(fontSize: 16)),
                onSelected: (city) =>
                    setState(() => _departureCity = city.name),
              ),
            ),
            const SizedBox(height: DonySpacing.base),

            // ── Arrivée ────────────────────────────────────────────────────
            _FieldLabel('Arrivée'),
            const SizedBox(height: DonySpacing.xs),
            BlocProvider(
              create: (_) => getIt<CitySearchBloc>(),
              child: CityAutocompleteField(
                label: '',
                initialValue: _arrivalCity,
                prefixIcon: const Text('📍', style: TextStyle(fontSize: 16)),
                onSelected: (city) =>
                    setState(() => _arrivalCity = city.name),
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
                      _FieldLabel('Date'),
                      const SizedBox(height: DonySpacing.xs),
                      _DatePickerField(
                        date: _date,
                        onChanged: (d) => setState(() => _date = d),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel('Tolérance'),
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

            // ── Mode de transport ──────────────────────────────────────────
            _FieldLabel('Mode de transport'),
            const SizedBox(height: DonySpacing.sm),
            Wrap(
              spacing: DonySpacing.sm,
              runSpacing: DonySpacing.sm,
              children: TransportMode.values.map((m) {
                return OptionButton(
                  label: m.label,
                  icon: m.icon,
                  selected: m == _transportMode,
                  onTap: () => setState(() => _transportMode = m),
                );
              }).toList(),
            ),
          ],
        ),
      ),
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
  const _ToleranceField(
      {required this.tolerance, required this.onChanged});
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
                      ? const Icon(Icons.check_rounded,
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

/// Bouton sélectionnable rond rectangulaire — emoji/icône + label.
/// Selected: bg primary blue + white text. Idle: surface + outline + textPrimary.
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fg = selected ? Colors.white : DonyColors.textPrimary;
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
          color: selected ? DonyColors.primary : cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.lg),
          border: Border.all(
            color: selected ? DonyColors.primary : cs.outline,
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
