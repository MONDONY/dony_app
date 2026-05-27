import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_state.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

const _categoryPresets = [
  'Vêtements',
  'Médicaments',
  'Alim. sèche',
  'Hi-fi',
  'Documents',
  'Téléphone',
  'Cosmétiques',
];

const _capacityUnits = [
  ('SUITCASE_23KG', 'Valise 23 kg'),
  ('SUITCASE_32KG', 'Valise 32 kg'),
  ('KG_FREE', 'Au kilo'),
];

class TripTemplateEditScreen extends StatefulWidget {
  const TripTemplateEditScreen({super.key, this.template});

  final TripTemplate? template;

  @override
  State<TripTemplateEditScreen> createState() => _TripTemplateEditScreenState();
}

class _TripTemplateEditScreenState extends State<TripTemplateEditScreen> {
  final _labelCtrl = TextEditingController();
  final _departureCtrl = TextEditingController();
  final _arrivalCtrl = TextEditingController();
  final _kgCtrl = TextEditingController(text: '23');
  final _priceCtrl = TextEditingController(text: '8');

  TransportMode _transport = TransportMode.plane;
  String _capacityUnit = 'SUITCASE_23KG';
  Set<String> _categories = {'Vêtements', 'Documents'};
  bool _submitted = false;

  bool get _isEditing => widget.template != null;

  bool get _isValid =>
      _labelCtrl.text.trim().isNotEmpty &&
      _departureCtrl.text.trim().isNotEmpty &&
      _arrivalCtrl.text.trim().isNotEmpty &&
      (double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0) > 0 &&
      (int.tryParse(_kgCtrl.text) ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    if (t != null) {
      _labelCtrl.text = t.label;
      _departureCtrl.text = t.departureCity;
      _arrivalCtrl.text = t.arrivalCity;
      _kgCtrl.text = t.availableKg.toString();
      _priceCtrl.text = _trimPrice(t.pricePerKg);
      _transport = transportModeFromWire(t.transportMode) ?? TransportMode.plane;
      _capacityUnit = t.capacityUnit;
      _categories = Set<String>.from(t.acceptedCategories);
    }
  }

  String _trimPrice(double p) =>
      p == p.roundToDouble() ? p.toInt().toString() : p.toString();

  @override
  void dispose() {
    _labelCtrl.dispose();
    _departureCtrl.dispose();
    _arrivalCtrl.dispose();
    _kgCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (!_isValid) {
      return;
    }
    _submitted = true;
    final data = <String, dynamic>{
      'label': _labelCtrl.text.trim(),
      'departureCity': _departureCtrl.text.trim(),
      'arrivalCity': _arrivalCtrl.text.trim(),
      'transportMode': transportModeToWire(_transport),
      'capacityUnit': _capacityUnit,
      'availableKg': int.parse(_kgCtrl.text),
      'pricePerKg': double.parse(_priceCtrl.text.replaceAll(',', '.')),
      'acceptedCategories': _categories.toList(),
    };
    final bloc = context.read<TripTemplateBloc>();
    if (_isEditing) {
      bloc.add(TripTemplateUpdated(widget.template!.id, data));
    } else {
      bloc.add(TripTemplateCreated(data));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TripTemplateBloc, TripTemplateState>(
      listener: (context, state) {
        if (_submitted && state.status == TripTemplateStatus.success) {
          DonySnackbar.show(
            context,
            message: _isEditing ? 'Modèle mis à jour' : 'Modèle enregistré',
            type: DonySnackbarType.success,
          );
          context.pop(true);
        }
        if (state.status == TripTemplateStatus.error && state.error != null) {
          _submitted = false;
          DonySnackbar.show(context, message: state.error!, type: DonySnackbarType.error);
        }
      },
      builder: (context, state) {
        final isLoading = state.status == TripTemplateStatus.loading;
        return DonyPageScaffold(
          title: _isEditing ? 'Modifier le modèle' : 'Nouveau modèle',
          stickyBottom: DonyButton(
            label: 'Enregistrer le modèle',
            onPressed: (_isValid && !isLoading) ? () => _submit(context) : null,
            isLoading: isLoading,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel('Nom du modèle'),
              DonyTextField(
                controller: _labelCtrl,
                label: 'Nom',
                hint: 'Ex : Mon Paris → Dakar',
                prefixIcon: Icons.sell_outlined,
                onChanged: (_) => setState(() {}),
              ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.03),
              const SizedBox(height: DonySpacing.xl),
              const _SectionLabel('Trajet'),
              DonyTextField(
                controller: _departureCtrl,
                label: 'Ville de départ',
                hint: 'Ex : Paris',
                prefixIcon: Icons.flight_takeoff_rounded,
                onChanged: (_) => setState(() {}),
              ).animate().fadeIn(delay: 40.ms, duration: 280.ms).slideY(begin: 0.03),
              const SizedBox(height: DonySpacing.md),
              DonyTextField(
                controller: _arrivalCtrl,
                label: "Ville d'arrivée",
                hint: 'Ex : Dakar',
                prefixIcon: Icons.flight_land_rounded,
                onChanged: (_) => setState(() {}),
              ).animate().fadeIn(delay: 80.ms, duration: 280.ms).slideY(begin: 0.03),
              const SizedBox(height: DonySpacing.xl),
              const _SectionLabel('Transport'),
              Wrap(
                spacing: DonySpacing.sm,
                runSpacing: DonySpacing.sm,
                children: TransportMode.values.map((m) {
                  final selected = m == _transport;
                  return _ChoiceChip(
                    label: m.label,
                    icon: m.icon,
                    selected: selected,
                    onTap: () => setState(() => _transport = m),
                  );
                }).toList(),
              ).animate().fadeIn(delay: 120.ms, duration: 280.ms),
              const SizedBox(height: DonySpacing.xl),
              const _SectionLabel('Capacité'),
              Wrap(
                spacing: DonySpacing.sm,
                runSpacing: DonySpacing.sm,
                children: _capacityUnits.map((c) {
                  return _ChoiceChip(
                    label: c.$2,
                    selected: c.$1 == _capacityUnit,
                    onTap: () => setState(() => _capacityUnit = c.$1),
                  );
                }).toList(),
              ).animate().fadeIn(delay: 160.ms, duration: 280.ms),
              const SizedBox(height: DonySpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionLabel('Poids dispo.'),
                        _NumberField(
                          controller: _kgCtrl,
                          suffix: 'kg',
                          onChanged: () => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: DonySpacing.base),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionLabel('Prix'),
                        _NumberField(
                          controller: _priceCtrl,
                          suffix: '€/kg',
                          allowDecimal: true,
                          onChanged: () => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 200.ms, duration: 280.ms),
              const SizedBox(height: DonySpacing.xl),
              const _SectionLabel('Contenu accepté'),
              Wrap(
                spacing: DonySpacing.sm,
                runSpacing: DonySpacing.sm,
                children: _categoryPresets.map((c) {
                  final selected = _categories.contains(c);
                  return _ChoiceChip(
                    label: c,
                    selected: selected,
                    onTap: () => setState(() {
                      if (selected) {
                        _categories.remove(c);
                      } else {
                        _categories = {..._categories, c};
                      }
                    }),
                  );
                }).toList(),
              ).animate().fadeIn(delay: 240.ms, duration: 280.ms),
              const SizedBox(height: DonySpacing.md),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.sm, left: DonySpacing.xs),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base, vertical: DonySpacing.sm),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withValues(alpha: 0.1) : cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          border: Border.all(
            color: selected ? cs.primary : cs.outline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: selected ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(width: DonySpacing.xs),
            ],
            Text(
              label,
              style: tt.bodySmall?.copyWith(
                color: selected ? cs.primary : cs.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.suffix,
    required this.onChanged,
    this.allowDecimal = false,
  });

  final TextEditingController controller;
  final String suffix;
  final VoidCallback onChanged;
  final bool allowDecimal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
            allowDecimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]')),
      ],
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        suffixText: suffix,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base, vertical: DonySpacing.md),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide(color: cs.outline),
        ),
      ),
    );
  }
}
