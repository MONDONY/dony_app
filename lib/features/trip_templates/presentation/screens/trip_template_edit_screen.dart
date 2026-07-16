import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/presentation/widgets/city_autocomplete_field.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_state.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

const _priceOptions = [5.0, 6.0, 7.0, 8.0];

const _capacityOptions = [
  ('SUITCASE_23KG', '1 valise 23 kg', 'Format standard cabine'),
  ('SUITCASE_32KG', '1 valise 32 kg', 'Grande valise'),
  ('KG_FREE', 'Kg libre', 'Au kilo, sans contrainte'),
];

class TripTemplateEditScreen extends StatefulWidget {
  const TripTemplateEditScreen({super.key, this.template});

  final TripTemplate? template;

  @override
  State<TripTemplateEditScreen> createState() => _TripTemplateEditScreenState();
}

class _TripTemplateEditScreenState extends State<TripTemplateEditScreen> {
  final _labelCtrl = TextEditingController();

  String? _departureCity;
  String? _arrivalCity;
  TransportMode _transport = TransportMode.plane;
  String _capacityUnit = 'SUITCASE_23KG';
  double _availableKg = 23;
  int _priceIdx = 3; // 8€ par défaut
  Set<String> _categories = {'Vêtements & tissus', 'Documents & administratif'};
  bool _cashAccepted = false;
  TimeOfDay? _arrivalTime;
  bool _submitted = false;
  final _customCategoryCtrl = TextEditingController();
  // Catalogue de types de contenu — seedé synchrone avec le catalogue
  // embarqué (fallbackCatalog), puis remplacé par le catalogue live du
  // repository dès qu'il répond (repli automatique hors ligne intégré).
  List<String> _catalogLabels = fallbackCatalog.map((c) => c.label).toList();

  String? get _arrivalWire => _arrivalTime == null
      ? null
      : '${_arrivalTime!.hour.toString().padLeft(2, '0')}:${_arrivalTime!.minute.toString().padLeft(2, '0')}';

  bool get _isEditing => widget.template != null;

  bool get _isValid =>
      _labelCtrl.text.trim().isNotEmpty &&
      (_departureCity?.trim().isNotEmpty ?? false) &&
      (_arrivalCity?.trim().isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    if (t != null) {
      _labelCtrl.text = t.label;
      _departureCity = t.departureCity;
      _arrivalCity = t.arrivalCity;
      _transport = transportModeFromWire(t.transportMode) ?? TransportMode.plane;
      _capacityUnit = t.capacityUnit;
      _availableKg = t.availableKg.toDouble().clamp(1.0, 23.0);
      _categories = Set<String>.from(t.acceptedCategories);
      _cashAccepted = t.cashAccepted;
      if (t.arrivalTime != null && t.arrivalTime!.contains(':')) {
        final parts = t.arrivalTime!.split(':');
        _arrivalTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      int closest = 0;
      double minDiff = double.infinity;
      for (int i = 0; i < _priceOptions.length; i++) {
        final diff = (t.pricePerKg - _priceOptions[i]).abs();
        if (diff < minDiff) {
          minDiff = diff;
          closest = i;
        }
      }
      _priceIdx = closest;
    }
    unawaited(_loadCatalog());
  }

  Future<void> _loadCatalog() async {
    final categories =
        await getIt<IContentCategoryRepository>().getCategories();
    if (!mounted) return;
    setState(() {
      _catalogLabels = categories.map((c) => c.label).toList();
    });
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _customCategoryCtrl.dispose();
    super.dispose();
  }

  void _addCustomCategory() {
    final value = _customCategoryCtrl.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _categories = {..._categories, value};
      _customCategoryCtrl.clear();
    });
  }

  void _submit(BuildContext context) {
    if (!_isValid) {
      return;
    }
    _submitted = true;
    final data = <String, dynamic>{
      'label': _labelCtrl.text.trim(),
      'departureCity': _departureCity!.trim(),
      'arrivalCity': _arrivalCity!.trim(),
      'transportMode': transportModeToWire(_transport),
      'capacityUnit': _capacityUnit,
      'availableKg': _availableKg.round(),
      'pricePerKg': _priceOptions[_priceIdx],
      'acceptedCategories': _categories.toList(),
      'cashAccepted': _cashAccepted,
      'arrivalTime': _arrivalWire,
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

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
              // ── NOM DU MODÈLE ───────────────────────────────────────────
              const _SectionLabel(label: 'NOM DU MODÈLE', iconAsset: 'bookmark'),
              const SizedBox(height: DonySpacing.sm),
              DonyTextField(
                controller: _labelCtrl,
                label: 'Nom',
                hint: 'Ex : Mon Paris → Dakar',
                prefixWidget: DonyIcon('tag', size: 20, color: cs.onSurfaceVariant),
                onChanged: (_) => setState(() {}),
              ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.03),
              const SizedBox(height: DonySpacing.xxl),

              // ── TRAJET ──────────────────────────────────────────────────
              const _SectionLabel(label: 'TRAJET', iconAsset: 'plane-takeoff'),
              const SizedBox(height: DonySpacing.sm),
              BlocProvider(
                create: (_) => getIt<CitySearchBloc>(),
                child: CityAutocompleteField(
                  label: 'Ville de départ',
                  requiredLabel: true,
                  prefixIcon: const DonyEmoji.planeTakeoff(size: 20),
                  initialValue: _departureCity,
                  onSelected: (CityModel city) =>
                      setState(() => _departureCity = city.name),
                ),
              ),
              const SizedBox(height: DonySpacing.sm),
              BlocProvider(
                create: (_) => getIt<CitySearchBloc>(),
                child: CityAutocompleteField(
                  label: "Ville d'arrivée",
                  requiredLabel: true,
                  prefixIcon: const DonyEmoji.planeLanding(size: 20),
                  initialValue: _arrivalCity,
                  onSelected: (CityModel city) =>
                      setState(() => _arrivalCity = city.name),
                ),
              ),
              const SizedBox(height: DonySpacing.xxl),

              // ── TYPE DE CAPACITÉ ────────────────────────────────────────
              const _SectionLabel(label: 'TYPE DE CAPACITÉ', iconAsset: 'luggage'),
              const SizedBox(height: DonySpacing.sm),
              Column(
                children: _capacityOptions.map((opt) {
                  final selected = _capacityUnit == opt.$1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: DonySpacing.sm),
                    child: GestureDetector(
                      onTap: () => setState(() => _capacityUnit = opt.$1),
                      child: AnimatedContainer(
                        duration: 160.ms,
                        padding: const EdgeInsets.all(DonySpacing.base),
                        decoration: BoxDecoration(
                          color: selected ? cs.primaryContainer : cs.surface,
                          borderRadius: BorderRadius.circular(DonyRadius.lg),
                          border: Border.all(
                            color: selected ? cs.primary : cs.outline,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(opt.$2,
                                      style: tt.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: selected ? cs.primary : cs.onSurface)),
                                  Text(opt.$3,
                                      style: tt.bodySmall
                                          ?.copyWith(color: cs.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            DonyIcon(
                              selected ? 'circle-dot' : 'circle',
                              color: selected ? cs.primary : cs.outline,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: DonySpacing.lg),

              // ── POIDS DISPONIBLE ────────────────────────────────────────
              const _SectionLabel(label: 'POIDS DISPONIBLE', iconAsset: 'scale'),
              const SizedBox(height: DonySpacing.base),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _availableKg.toStringAsFixed(0),
                    style: tt.displayLarge?.copyWith(
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(' kg', style: tt.headlineMedium?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: DonySpacing.xs),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: cs.primary,
                  inactiveTrackColor: cs.outline,
                  thumbColor: cs.primary,
                  overlayColor: cs.primary.withValues(alpha: 0.1),
                  trackHeight: 5,
                ),
                child: Slider(
                  value: _availableKg,
                  min: 1,
                  max: 23,
                  divisions: 22,
                  onChanged: (v) => setState(() => _availableKg = v),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('1 kg', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  Text('max 23 kg', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: DonySpacing.xxl),

              // ── PRIX PAR KG ─────────────────────────────────────────────
              const _SectionLabel(label: 'PRIX PAR KG', iconAsset: 'tag'),
              const SizedBox(height: DonySpacing.md),
              Row(
                children: List.generate(_priceOptions.length, (i) {
                  final selected = _priceIdx == i;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: i == 0 ? 0 : DonySpacing.xs,
                        right: i == _priceOptions.length - 1 ? 0 : DonySpacing.xs,
                      ),
                      child: GestureDetector(
                        onTap: () => setState(() => _priceIdx = i),
                        child: AnimatedContainer(
                          duration: 180.ms,
                          padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
                          decoration: BoxDecoration(
                            color: selected ? cs.successLight : cs.surface,
                            borderRadius: BorderRadius.circular(DonyRadius.lg),
                            border: Border.all(
                              color: selected ? cs.success : cs.outline,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_priceOptions[i].toStringAsFixed(0)}€',
                                style: tt.titleMedium?.copyWith(
                                  color: selected ? cs.success : cs.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${formatKgPrice(netToSenderPrice(_priceOptions[i]))}€ exp.',
                                style: tt.labelSmall?.copyWith(
                                  color: selected ? cs.success : cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: DonySpacing.sm),
              Text(
                'Vous touchez ${formatKgPrice(_priceOptions[_priceIdx])}€/kg · l\'expéditeur paie ${formatKgPrice(netToSenderPrice(_priceOptions[_priceIdx]))}€/kg (commission Dony $donyCommissionPercentLabel% incluse)',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: DonySpacing.xxl),

              // ── MODE DE TRANSPORT ───────────────────────────────────────
              const _SectionLabel(label: 'MODE DE TRANSPORT', iconAsset: 'route'),
              const SizedBox(height: DonySpacing.sm),
              Wrap(
                spacing: DonySpacing.sm,
                runSpacing: DonySpacing.sm,
                children: [
                  for (final mode in TransportMode.values)
                    DonyChip(
                      label: mode.label,
                      icon: mode.icon,
                      selected: _transport == mode,
                      onTap: () => setState(() => _transport = mode),
                    ),
                ],
              ),
              const SizedBox(height: DonySpacing.xxl),

              // ── CE QUE J'ACCEPTE ────────────────────────────────────────
              const _SectionLabel(
                  label: "CE QUE J'ACCEPTE", iconAsset: 'circle-check'),
              const SizedBox(height: DonySpacing.sm),
              Wrap(
                spacing: DonySpacing.xs,
                runSpacing: DonySpacing.xs,
                children: [
                  for (final type in _catalogLabels)
                    _AcceptedCategoryChip(
                      label: type,
                      selected: _categories.contains(type),
                      onTap: () => setState(() {
                        if (_categories.contains(type)) {
                          _categories.remove(type);
                        } else {
                          _categories = {..._categories, type};
                        }
                      }),
                    ),
                  for (final type in _categories.where(
                    (c) => !_catalogLabels.contains(c),
                  ))
                    _AcceptedCategoryChip(
                      label: type,
                      selected: true,
                      onTap: () => setState(() => _categories.remove(type)),
                    ),
                ],
              ),
              const SizedBox(height: DonySpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('custom-category-input'),
                      controller: _customCategoryCtrl,
                      onSubmitted: (_) => _addCustomCategory(),
                      decoration: const InputDecoration(
                        hintText: 'Ajouter un autre type…',
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('add-custom-category-btn'),
                    icon: const Icon(Icons.add_rounded),
                    onPressed: _addCustomCategory,
                    tooltip: 'Ajouter',
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.xxl),

              // ── HEURE D'ARRIVÉE ─────────────────────────────────────────
              const _SectionLabel(label: "HEURE D'ARRIVÉE", iconAsset: 'plane-landing'),
              const SizedBox(height: DonySpacing.sm),
              GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _arrivalTime ?? const TimeOfDay(hour: 12, minute: 0),
                  );
                  if (picked != null) setState(() => _arrivalTime = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.base, vertical: DonySpacing.md),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    border: Border.all(color: cs.outline),
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                  ),
                  child: Row(
                    children: [
                      DonyIcon('clock', color: cs.primary, size: 20),
                      const SizedBox(width: DonySpacing.md),
                      Expanded(
                        child: Text(
                          _arrivalTime == null ? 'Optionnel : choisir une heure' : _arrivalWire!,
                          style: tt.bodyMedium?.copyWith(
                            color: _arrivalTime == null ? cs.onSurfaceVariant : cs.onSurface,
                          ),
                        ),
                      ),
                      if (_arrivalTime != null)
                        GestureDetector(
                          onTap: () => setState(() => _arrivalTime = null),
                          child: DonyIcon('x', size: 18, color: cs.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: DonySpacing.xxl),

              // ── PAIEMENT ────────────────────────────────────────────────
              const _SectionLabel(label: 'PAIEMENT', iconAsset: 'banknote'),
              const SizedBox(height: DonySpacing.sm),
              GestureDetector(
                onTap: () => setState(() => _cashAccepted = !_cashAccepted),
                child: Container(
                  padding: const EdgeInsets.all(DonySpacing.base),
                  decoration: BoxDecoration(
                    color: _cashAccepted ? cs.primary.withValues(alpha: 0.08) : cs.surface,
                    borderRadius: BorderRadius.circular(DonyRadius.card),
                    border: Border.all(
                        color: _cashAccepted ? cs.primary.withValues(alpha: 0.4) : cs.outline),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Accepter le paiement en espèces',
                                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                            Text('La carte Stripe reste toujours activée',
                                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Switch(value: _cashAccepted, onChanged: (v) => setState(() => _cashAccepted = v)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: DonySpacing.md),
            ],
          ),
        );
      },
    );
  }
}

class _AcceptedCategoryChip extends StatelessWidget {
  const _AcceptedCategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 160.ms,
        padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.md, vertical: DonySpacing.xs),
        decoration: BoxDecoration(
          color: selected ? cs.success : cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          border: Border.all(color: selected ? cs.success : cs.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const DonyIcon('check', size: 12, color: Colors.white),
              const SizedBox(width: DonySpacing.xs),
            ],
            Text(
              label,
              style: tt.bodySmall?.copyWith(
                color: selected ? Colors.white : cs.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.iconAsset});

  final String label;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        DonyIcon(iconAsset, size: 18, color: cs.primary),
        const SizedBox(width: DonySpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
        ),
      ],
    );
  }
}
