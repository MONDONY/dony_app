import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/presentation/widgets/city_autocomplete_field.dart';
import 'package:dony/features/matching/data/models/search_params.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/urgency_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// Content types mirroring what travelers can declare in CreateAnnouncement
const _contentTypes = [
  'Vêtements',
  'Médicaments',
  'Alim. sèche',
  'Hi-fi',
  'Documents',
  'Téléphone',
  'Cosmétiques',
];

const _contentTypeIcons = <String, IconData>{
  'Vêtements': Icons.checkroom_rounded,
  'Médicaments': Icons.medication_rounded,
  'Alim. sèche': Icons.kitchen_rounded,
  'Hi-fi': Icons.speaker_rounded,
  'Documents': Icons.description_rounded,
  'Téléphone': Icons.smartphone_rounded,
  'Cosmétiques': Icons.face_retouching_natural_rounded,
};

class SearchFormBottomSheet {
  static Future<SearchParams?> show(
    BuildContext context, {
    SearchParams? initialParams,
    double? heightFraction,
  }) async {
    VoidCallback? submitFn;
    VoidCallback? resetFn;
    final filterCount = ValueNotifier<int>(0);

    final result = await DonyBottomSheet.show<SearchParams>(
      context,
      title: 'Filtrer les trajets',
      heightFraction: heightFraction,
      stickyBottom: ValueListenableBuilder<int>(
        valueListenable: filterCount,
        builder: (ctx, count, _) {
          return Row(
            children: [
              if (count > 0) ...[
                Expanded(
                  flex: 1,
                  child: GestureDetector(
                    onTap: () => resetFn?.call(),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: DonyColors.bgApp,
                        borderRadius: BorderRadius.circular(DonyRadius.lg),
                        border: Border.all(color: DonyColors.neutral200),
                      ),
                      child: Center(
                        child: Text(
                          'Réinitialiser',
                          style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                            color: DonyColors.ink900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
              ],
              Expanded(
                flex: 2,
                child: DonyButton(
                  label: count > 0 ? 'Rechercher · $count filtres' : 'Rechercher',
                  onPressed: () => submitFn?.call(),
                ),
              ),
            ],
          );
        },
      ),
      child: _SearchFormContent(
        initialParams: initialParams,
        filterCountNotifier: filterCount,
        onCallbacksReady: (submit, reset) {
          submitFn = submit;
          resetFn = reset;
        },
      ),
    );

    filterCount.dispose();
    return result;
  }
}

// ── Form content ──────────────────────────────────────────────────────────────

class _SearchFormContent extends StatefulWidget {
  const _SearchFormContent({
    this.initialParams,
    this.filterCountNotifier,
    this.onCallbacksReady,
  });

  final SearchParams? initialParams;
  final ValueNotifier<int>? filterCountNotifier;
  final void Function(VoidCallback submit, VoidCallback reset)? onCallbacksReady;

  @override
  State<_SearchFormContent> createState() => _SearchFormContentState();
}

class _SearchFormContentState extends State<_SearchFormContent> {
  late final ValueNotifier<String?> _departureCityNotifier;
  late final ValueNotifier<String?> _arrivalCityNotifier;
  late final ValueNotifier<DateTime?> _dateNotifier;
  late final ValueNotifier<double> _weightKgNotifier;
  late final ValueNotifier<double> _maxPricePerKgNotifier;
  late final ValueNotifier<bool> _kiloProOnlyNotifier;
  late final ValueNotifier<bool> _ratingFilterNotifier;
  late final ValueNotifier<bool> _weekendFilterNotifier;
  late final ValueNotifier<bool> _priceFilterNotifier;
  late final ValueNotifier<TransportMode?> _transportModeNotifier;
  late final ValueNotifier<bool> _kycVerifiedOnlyNotifier;
  late final ValueNotifier<String?> _contentTypeNotifier;
  late final ValueNotifier<UrgencyFilter?> _urgencyFilterNotifier;

  @override
  void initState() {
    super.initState();
    final p = widget.initialParams;
    _departureCityNotifier = ValueNotifier<String?>(p?.departureCity);
    _arrivalCityNotifier = ValueNotifier<String?>(p?.arrivalCity);
    _dateNotifier = ValueNotifier<DateTime?>(p?.date);
    _weightKgNotifier = ValueNotifier<double>(p?.weightKg ?? 6);
    _maxPricePerKgNotifier = ValueNotifier<double>(p?.maxPricePerKg ?? 25);
    _kiloProOnlyNotifier = ValueNotifier<bool>(p?.kiloProOnly ?? false);
    _ratingFilterNotifier = ValueNotifier<bool>(p?.ratingFilter ?? false);
    _weekendFilterNotifier = ValueNotifier<bool>(p?.weekendFilter ?? false);
    _priceFilterNotifier = ValueNotifier<bool>(p?.priceFilter ?? false);
    _transportModeNotifier = ValueNotifier<TransportMode?>(p?.transportMode);
    _kycVerifiedOnlyNotifier = ValueNotifier<bool>(p?.kycVerifiedOnly ?? false);
    _contentTypeNotifier = ValueNotifier<String?>(p?.contentType);
    _urgencyFilterNotifier = ValueNotifier<UrgencyFilter?>(p?.urgencyFilter);

    widget.onCallbacksReady?.call(_submit, _reset);
    widget.filterCountNotifier?.value = _activeFilterCount;

    for (final n in _allNotifiers) {
      n.addListener(_syncFilterCount);
    }
  }

  List<Listenable> get _allNotifiers => [
    _departureCityNotifier,
    _arrivalCityNotifier,
    _dateNotifier,
    _weightKgNotifier,
    _maxPricePerKgNotifier,
    _kiloProOnlyNotifier,
    _ratingFilterNotifier,
    _weekendFilterNotifier,
    _priceFilterNotifier,
    _transportModeNotifier,
    _kycVerifiedOnlyNotifier,
    _contentTypeNotifier,
    _urgencyFilterNotifier,
  ];

  void _syncFilterCount() {
    widget.filterCountNotifier?.value = _activeFilterCount;
  }

  @override
  void dispose() {
    for (final n in _allNotifiers) {
      n.removeListener(_syncFilterCount);
    }
    _departureCityNotifier.dispose();
    _arrivalCityNotifier.dispose();
    _dateNotifier.dispose();
    _weightKgNotifier.dispose();
    _maxPricePerKgNotifier.dispose();
    _kiloProOnlyNotifier.dispose();
    _ratingFilterNotifier.dispose();
    _weekendFilterNotifier.dispose();
    _priceFilterNotifier.dispose();
    _transportModeNotifier.dispose();
    _kycVerifiedOnlyNotifier.dispose();
    _contentTypeNotifier.dispose();
    _urgencyFilterNotifier.dispose();
    super.dispose();
  }

  void _submit() {
    final departureCity = _departureCityNotifier.value;
    final arrivalCity = _arrivalCityNotifier.value;
    if (departureCity == null || arrivalCity == null) return;
    Navigator.of(context, rootNavigator: true).pop(SearchParams(
      departureCity: departureCity,
      arrivalCity: arrivalCity,
      date: _dateNotifier.value,
      weightKg: _weightKgNotifier.value,
      maxPricePerKg: _maxPricePerKgNotifier.value,
      kiloProOnly: _kiloProOnlyNotifier.value,
      ratingFilter: _ratingFilterNotifier.value,
      weekendFilter: _weekendFilterNotifier.value,
      priceFilter: _priceFilterNotifier.value,
      transportMode: _transportModeNotifier.value,
      kycVerifiedOnly: _kycVerifiedOnlyNotifier.value,
      contentType: _contentTypeNotifier.value,
      urgencyFilter: _urgencyFilterNotifier.value,
    ));
  }

  void _reset() {
    _dateNotifier.value = null;
    _weightKgNotifier.value = 6;
    _maxPricePerKgNotifier.value = 25;
    _kiloProOnlyNotifier.value = false;
    _ratingFilterNotifier.value = false;
    _weekendFilterNotifier.value = false;
    _priceFilterNotifier.value = false;
    _transportModeNotifier.value = null;
    _kycVerifiedOnlyNotifier.value = false;
    _contentTypeNotifier.value = null;
    _urgencyFilterNotifier.value = null;
  }

  int get _activeFilterCount {
    int count = 0;
    if (_dateNotifier.value != null) count++;
    if (_weightKgNotifier.value != 6) count++;
    if (_priceFilterNotifier.value) count++;
    if (_kiloProOnlyNotifier.value) count++;
    if (_ratingFilterNotifier.value) count++;
    if (_weekendFilterNotifier.value) count++;
    if (_transportModeNotifier.value != null) count++;
    if (_kycVerifiedOnlyNotifier.value) count++;
    if (_contentTypeNotifier.value != null) count++;
    if (_urgencyFilterNotifier.value != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: Listenable.merge([
        _departureCityNotifier,
        _arrivalCityNotifier,
        _dateNotifier,
        _weightKgNotifier,
        _maxPricePerKgNotifier,
        _kiloProOnlyNotifier,
        _ratingFilterNotifier,
        _weekendFilterNotifier,
        _priceFilterNotifier,
        _transportModeNotifier,
        _kycVerifiedOnlyNotifier,
        _contentTypeNotifier,
        _urgencyFilterNotifier,
      ]),
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Corridor ────────────────────────────────────────────────────
            Column(
              children: [
                BlocProvider(
                  create: (_) => getIt<CitySearchBloc>(),
                  child: CityAutocompleteField(
                    label: 'Ville de départ',
                    initialValue: _departureCityNotifier.value,
                    prefixIcon: const Icon(Icons.flight_takeoff_rounded,
                        color: DonyColors.primary, size: 20),
                    onSelected: (CityModel city) {
                      _departureCityNotifier.value = city.name;
                    },
                  ),
                ),
                const SizedBox(height: DonySpacing.sm),
                BlocProvider(
                  create: (_) => getIt<CitySearchBloc>(),
                  child: CityAutocompleteField(
                    label: 'Ville d\'arrivée',
                    initialValue: _arrivalCityNotifier.value,
                    prefixIcon: const Icon(Icons.flight_land_rounded,
                        color: DonyColors.accent, size: 20),
                    onSelected: (CityModel city) {
                      _arrivalCityNotifier.value = city.name;
                    },
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 250.ms),
            const SizedBox(height: DonySpacing.base),

            // ── Date + Poids ─────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    date: _dateNotifier.value,
                    onChanged: (v) => _dateNotifier.value = v,
                  ),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: _WeightField(
                    weightKg: _weightKgNotifier.value,
                    onChanged: (v) => _weightKgNotifier.value = v,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 40.ms),
            const SizedBox(height: DonySpacing.base),

            // ── Prix max + Mode transport ────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _PriceField(
                    maxPrice: _priceFilterNotifier.value
                        ? _maxPricePerKgNotifier.value
                        : null,
                    onTap: () => _showPricePicker(context),
                  ),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: _TransportModeField(
                    mode: _transportModeNotifier.value,
                    onTap: () => _showTransportPicker(context),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 60.ms),
            const SizedBox(height: DonySpacing.xl),

            // ── Filtres rapides ──────────────────────────────────────────
            Text(
              'FILTRES RAPIDES',
              style: tt.labelMedium?.copyWith(color: DonyColors.neutral400),
            ),
            const SizedBox(height: DonySpacing.md),
            Wrap(
              spacing: DonySpacing.sm,
              runSpacing: DonySpacing.sm,
              children: [
                _QuickChip(
                  label: 'Kilo Pro',
                  icon: Icons.workspace_premium_rounded,
                  active: _kiloProOnlyNotifier.value,
                  onChanged: (v) => _kiloProOnlyNotifier.value = v,
                ),
                _QuickChip(
                  label: 'Note ≥ 4.5',
                  icon: Icons.star_rounded,
                  active: _ratingFilterNotifier.value,
                  onChanged: (v) => _ratingFilterNotifier.value = v,
                ),
                _QuickChip(
                  label: 'Week-end',
                  icon: Icons.weekend_rounded,
                  active: _weekendFilterNotifier.value,
                  onChanged: (v) => _weekendFilterNotifier.value = v,
                ),
                _QuickChip(
                  label: 'KYC vérifié',
                  icon: Icons.verified_user_rounded,
                  active: _kycVerifiedOnlyNotifier.value,
                  onChanged: (v) => _kycVerifiedOnlyNotifier.value = v,
                ),
              ],
            ).animate().fadeIn(delay: 80.ms),
            const SizedBox(height: DonySpacing.xl),

            // ── Type de contenu ──────────────────────────────────────────
            Text(
              'MON COLIS CONTIENT',
              style: tt.labelMedium?.copyWith(color: DonyColors.neutral400),
            ),
            const SizedBox(height: DonySpacing.md),
            Wrap(
              spacing: DonySpacing.sm,
              runSpacing: DonySpacing.sm,
              children: _contentTypes.map((type) {
                final isSelected = _contentTypeNotifier.value == type;
                return _ContentTypeChip(
                  label: type,
                  icon: _contentTypeIcons[type] ?? Icons.inventory_2_rounded,
                  selected: isSelected,
                  onTap: () {
                    _contentTypeNotifier.value = isSelected ? null : type;
                  },
                );
              }).toList(),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: DonySpacing.xl),

            // ── Urgence du départ ────────────────────────────────────────
            Text(
              'URGENCE DU DÉPART',
              style: tt.labelMedium?.copyWith(color: DonyColors.neutral400),
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              'Filtrer les trajets selon leur proximité de départ',
              style: tt.bodySmall?.copyWith(color: DonyColors.textMuted),
            ),
            const SizedBox(height: DonySpacing.md),
            Wrap(
              spacing: DonySpacing.sm,
              runSpacing: DonySpacing.sm,
              children: UrgencyFilter.values.map((f) {
                final isSelected = _urgencyFilterNotifier.value == f;
                return GestureDetector(
                  onTap: () {
                    _urgencyFilterNotifier.value = isSelected ? null : f;
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.base,
                      vertical: DonySpacing.xs + 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? f.color.withValues(alpha: 0.12)
                          : DonyColors.bgApp,
                      borderRadius: BorderRadius.circular(DonyRadius.full),
                      border: Border.all(
                        color: isSelected ? f.color : DonyColors.neutral200,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: f.color,
                            shape: BoxShape.circle,
                            boxShadow: isSelected
                                ? [BoxShadow(color: f.color.withValues(alpha: 0.45), blurRadius: 4)]
                                : null,
                          ),
                        ),
                        const SizedBox(width: DonySpacing.xs),
                        Text(
                          f.label,
                          style: tt.labelSmall?.copyWith(
                            color: isSelected ? f.color : DonyColors.ink900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ).animate().fadeIn(delay: 120.ms),
            const SizedBox(height: DonySpacing.sm),
          ],
        );
      },
    );
  }

  Future<void> _showPricePicker(BuildContext context) async {
    final tt = Theme.of(context).textTheme;
    const double kMin = 3;
    const double kMax = 25;
    double local = _priceFilterNotifier.value ? _maxPricePerKgNotifier.value : kMax;
    bool localEnabled = _priceFilterNotifier.value;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => _SimpleSheet(
          title: 'Prix maximum',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Text(
                  localEnabled ? '≤ ${local.toInt()} €/kg' : 'Tous les prix',
                  style: tt.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: localEnabled ? DonyColors.primary : DonyColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: DonySpacing.sm),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: DonyColors.primary,
                  thumbColor: DonyColors.primary,
                  overlayColor: DonyColors.primarySoft,
                  inactiveTrackColor: DonyColors.neutral200,
                ),
                child: Slider(
                  value: local,
                  min: kMin,
                  max: kMax,
                  divisions: (kMax - kMin).toInt(),
                  onChanged: (v) => setS(() {
                    local = v;
                    localEnabled = v < kMax;
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('3 €/kg', style: tt.bodySmall?.copyWith(color: DonyColors.textMuted)),
                    Text('25 €/kg', style: tt.bodySmall?.copyWith(color: DonyColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(height: DonySpacing.lg),
              DonyButton(
                label: 'Appliquer',
                onPressed: () {
                  _priceFilterNotifier.value = localEnabled;
                  if (localEnabled) _maxPricePerKgNotifier.value = local;
                  ctx.pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTransportPicker(BuildContext context) async {
    TransportMode? local = _transportModeNotifier.value;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final tt = Theme.of(ctx).textTheme;
          return _SimpleSheet(
            title: 'Mode de transport',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...TransportMode.values.map((mode) {
                  final selected = local == mode;
                  return GestureDetector(
                    onTap: () => setS(() => local = selected ? null : mode),
                    child: AnimatedContainer(
                      duration: 180.ms,
                      margin: const EdgeInsets.only(bottom: DonySpacing.xs),
                      padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.base,
                        vertical: DonySpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? DonyColors.primarySoft : DonyColors.bgApp,
                        borderRadius: BorderRadius.circular(DonyRadius.card),
                        border: Border.all(
                          color: selected ? DonyColors.primary : DonyColors.neutral200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(mode.icon,
                              size: 18,
                              color: selected ? DonyColors.primary : DonyColors.textMuted),
                          const SizedBox(width: DonySpacing.md),
                          Expanded(
                            child: Text(
                              mode.label,
                              style: tt.bodyMedium?.copyWith(
                                color: selected ? DonyColors.primary : DonyColors.ink900,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle_rounded,
                                size: 18, color: DonyColors.primary),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: DonySpacing.md),
                DonyButton(
                  label: 'Appliquer',
                  onPressed: () {
                    _transportModeNotifier.value = local;
                    ctx.pop();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Shared sub-components ─────────────────────────────────────────────────────

class _SimpleSheet extends StatelessWidget {
  const _SimpleSheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(DonyRadius.sheet)),
      ),
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg, 0, DonySpacing.lg, bottomPad + DonySpacing.base,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: DonySpacing.md),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DonyColors.neutral200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(title, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: DonySpacing.base),
          child,
        ],
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({required this.maxPrice, required this.onTap});

  final double? maxPrice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final active = maxPrice != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md, vertical: DonySpacing.md),
        decoration: BoxDecoration(
          color: active ? DonyColors.primarySoft : DonyColors.white,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(color: active ? DonyColors.primary : DonyColors.neutral200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PRIX MAX', style: tt.labelSmall?.copyWith(color: DonyColors.neutral400)),
            const SizedBox(height: DonySpacing.xs),
            Row(
              children: [
                Icon(Icons.euro_rounded,
                    size: 14, color: active ? DonyColors.primary : DonyColors.primary),
                const SizedBox(width: DonySpacing.xs),
                Text(
                  active ? '≤ ${maxPrice!.toInt()} €/kg' : 'Tous',
                  style: tt.titleSmall?.copyWith(
                    color: active ? DonyColors.primary : DonyColors.neutral400,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TransportModeField extends StatelessWidget {
  const _TransportModeField({required this.mode, required this.onTap});

  final TransportMode? mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final active = mode != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md, vertical: DonySpacing.md),
        decoration: BoxDecoration(
          color: active ? DonyColors.primarySoft : DonyColors.white,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(color: active ? DonyColors.primary : DonyColors.neutral200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TRANSPORT', style: tt.labelSmall?.copyWith(color: DonyColors.neutral400)),
            const SizedBox(height: DonySpacing.xs),
            Row(
              children: [
                Icon(
                  active ? mode!.icon : Icons.commute_rounded,
                  size: 14,
                  color: active ? DonyColors.primary : DonyColors.neutral400,
                ),
                const SizedBox(width: DonySpacing.xs),
                Expanded(
                  child: Text(
                    active ? mode!.label : 'Tous',
                    style: tt.titleSmall?.copyWith(
                      color: active ? DonyColors.primary : DonyColors.neutral400,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 16, color: DonyColors.neutral400),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentTypeChip extends StatelessWidget {
  const _ContentTypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 180.ms,
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md, vertical: DonySpacing.sm),
        decoration: BoxDecoration(
          color: selected ? DonyColors.primarySoft : DonyColors.bgApp,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          border: Border.all(
            color: selected ? DonyColors.primary : DonyColors.neutral200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected ? DonyColors.primary : DonyColors.textMuted),
            const SizedBox(width: DonySpacing.xs),
            Text(
              label,
              style: tt.labelMedium?.copyWith(
                color: selected ? DonyColors.primary : DonyColors.ink900,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.active,
    required this.onChanged,
    this.icon,
  });

  final String label;
  final bool active;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () => onChanged(!active),
      child: AnimatedContainer(
        duration: 180.ms,
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.sm,
        ),
        decoration: BoxDecoration(
          color: active ? DonyColors.primarySoft : DonyColors.white,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          border: Border.all(
            color: active ? DonyColors.primary : DonyColors.neutral200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: active ? DonyColors.primary : DonyColors.textMuted),
              const SizedBox(width: DonySpacing.xs),
            ],
            Text(
              label,
              style: tt.labelMedium?.copyWith(
                color: active ? DonyColors.primary : DonyColors.ink900,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Date field ────────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onChanged});

  final DateTime? date;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (c, child) => Theme(
            data: Theme.of(c).copyWith(
              colorScheme: const ColorScheme.light(primary: DonyColors.primary),
            ),
            child: child!,
          ),
        );
        onChanged(d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md, vertical: DonySpacing.md),
        decoration: BoxDecoration(
          color: date != null ? DonyColors.primarySoft : DonyColors.white,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(color: date != null ? DonyColors.primary : DonyColors.neutral200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DATE', style: tt.labelSmall?.copyWith(color: DonyColors.neutral400)),
            const SizedBox(height: DonySpacing.xs),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 14, color: DonyColors.primary),
                const SizedBox(width: DonySpacing.xs),
                Text(
                  date != null ? DateFormat('d MMM', 'fr').format(date!) : 'Choisir',
                  style: tt.titleSmall?.copyWith(
                    color: date != null ? DonyColors.primary : DonyColors.neutral400,
                    fontWeight: date != null ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Weight field ──────────────────────────────────────────────────────────────

class _WeightField extends StatelessWidget {
  const _WeightField({required this.weightKg, required this.onChanged});

  final double weightKg;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final active = weightKg != 6;
    return GestureDetector(
      onTap: () => _showWeightPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md, vertical: DonySpacing.md),
        decoration: BoxDecoration(
          color: active ? DonyColors.primarySoft : DonyColors.white,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(color: active ? DonyColors.primary : DonyColors.neutral200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('POIDS MIN', style: tt.labelSmall?.copyWith(color: DonyColors.neutral400)),
            const SizedBox(height: DonySpacing.xs),
            Row(
              children: [
                Icon(Icons.scale_rounded,
                    size: 14, color: active ? DonyColors.primary : DonyColors.primary),
                const SizedBox(width: DonySpacing.xs),
                Text(
                  '${weightKg.toStringAsFixed(0)} kg',
                  style: tt.titleSmall?.copyWith(
                    color: active ? DonyColors.primary : DonyColors.ink900,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showWeightPicker(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    double local = weightKg;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => _SimpleSheet(
          title: 'Poids minimum du trajet',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      local.toStringAsFixed(0),
                      style: tt.displayLarge?.copyWith(color: DonyColors.primary),
                    ),
                    const SizedBox(width: DonySpacing.sm),
                    Padding(
                      padding: const EdgeInsets.only(top: DonySpacing.md),
                      child: Text('kg',
                          style: tt.headlineMedium?.copyWith(color: DonyColors.neutral400)),
                    ),
                  ],
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: DonyColors.primary,
                  inactiveTrackColor: DonyColors.neutral200,
                  thumbColor: DonyColors.primary,
                  trackHeight: 4,
                ),
                child: Slider(
                  value: local,
                  min: 1,
                  max: 30,
                  divisions: 29,
                  onChanged: (v) => setS(() => local = v),
                ),
              ),
              const SizedBox(height: DonySpacing.md),
              DonyButton(
                label: 'Confirmer',
                onPressed: () {
                  onChanged(local);
                  ctx.pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
