import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/search_params.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

const _departureCities = ['Paris · CDG, ORY', 'Lyon · LYS', 'Marseille · MRS'];
const _arrivalCities = ['Dakar · DKR', 'Abidjan · ABJ', 'Bamako · BKO', 'Douala · DLA'];

// Layout constants (same as search_announcement_screen.dart)
const _kRowIndent = 56.0;
const _kIconGap = 14.0;

/// Matches a short city name (e.g. "Paris") to the full label (e.g. "Paris · CDG, ORY").
String _matchCity(String short, List<String> cities) =>
    cities.firstWhere((c) => c.startsWith(short), orElse: () => cities[0]);

class SearchFormBottomSheet {
  static Future<SearchParams?> show(
    BuildContext context, {
    SearchParams? initialParams,
    double? heightFraction,
  }) {
    return DonyBottomSheet.show<SearchParams>(
      context,
      title: 'Rechercher un trajet',
      heightFraction: heightFraction,
      child: _SearchFormContent(initialParams: initialParams),
    );
  }
}

// ── Form content ──────────────────────────────────────────────────────────────

class _SearchFormContent extends StatefulWidget {
  const _SearchFormContent({this.initialParams});

  final SearchParams? initialParams;

  @override
  State<_SearchFormContent> createState() => _SearchFormContentState();
}

class _SearchFormContentState extends State<_SearchFormContent> {
  late final ValueNotifier<String> _departureCityNotifier;
  late final ValueNotifier<String> _arrivalCityNotifier;
  late final ValueNotifier<DateTime?> _dateNotifier;
  late final ValueNotifier<double> _weightKgNotifier;
  late final ValueNotifier<double> _maxPricePerKgNotifier;
  late final ValueNotifier<bool> _kiloProOnlyNotifier;
  late final ValueNotifier<bool> _ratingFilterNotifier;
  late final ValueNotifier<bool> _weekendFilterNotifier;
  late final ValueNotifier<bool> _priceFilterNotifier;

  @override
  void initState() {
    super.initState();
    _departureCityNotifier = ValueNotifier<String>(_departureCities[0]);
    _arrivalCityNotifier = ValueNotifier<String>(_arrivalCities[0]);
    _dateNotifier = ValueNotifier<DateTime?>(null);
    _weightKgNotifier = ValueNotifier<double>(6);
    _maxPricePerKgNotifier = ValueNotifier<double>(25);
    _kiloProOnlyNotifier = ValueNotifier<bool>(false);
    _ratingFilterNotifier = ValueNotifier<bool>(false);
    _weekendFilterNotifier = ValueNotifier<bool>(false);
    _priceFilterNotifier = ValueNotifier<bool>(false);

    if (widget.initialParams != null) {
      final p = widget.initialParams!;
      _departureCityNotifier.value =
          _matchCity(p.departureCity, _departureCities);
      _arrivalCityNotifier.value =
          _matchCity(p.arrivalCity, _arrivalCities);
      _dateNotifier.value = p.date;
      _weightKgNotifier.value = p.weightKg;
      _maxPricePerKgNotifier.value = p.maxPricePerKg;
      _kiloProOnlyNotifier.value = p.kiloProOnly;
      _ratingFilterNotifier.value = p.ratingFilter;
      _weekendFilterNotifier.value = p.weekendFilter;
      _priceFilterNotifier.value = p.priceFilter;
    }
  }

  @override
  void dispose() {
    _departureCityNotifier.dispose();
    _arrivalCityNotifier.dispose();
    _dateNotifier.dispose();
    _weightKgNotifier.dispose();
    _maxPricePerKgNotifier.dispose();
    _kiloProOnlyNotifier.dispose();
    _ratingFilterNotifier.dispose();
    _weekendFilterNotifier.dispose();
    _priceFilterNotifier.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context, rootNavigator: true).pop(SearchParams(
      departureCity: _departureCityNotifier.value,
      arrivalCity: _arrivalCityNotifier.value,
      date: _dateNotifier.value,
      weightKg: _weightKgNotifier.value,
      maxPricePerKg: _maxPricePerKgNotifier.value,
      kiloProOnly: _kiloProOnlyNotifier.value,
      ratingFilter: _ratingFilterNotifier.value,
      weekendFilter: _weekendFilterNotifier.value,
      priceFilter: _priceFilterNotifier.value,
    ));
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
      ]),
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carte départ / arrivée
            Container(
              decoration: BoxDecoration(
                color: DonyColors.white,
                borderRadius: BorderRadius.circular(DonyRadius.card),
                border: Border.all(color: DonyColors.neutral200),
              ),
              child: Column(
                children: [
                  _LocationRow(
                    isDeparture: true,
                    value: _departureCityNotifier.value,
                    cities: _departureCities,
                    onChanged: (v) => _departureCityNotifier.value = v,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: _kRowIndent),
                    child: Divider(height: 1, color: DonyColors.neutral200),
                  ),
                  _LocationRow(
                    isDeparture: false,
                    value: _arrivalCityNotifier.value,
                    cities: _arrivalCities,
                    onChanged: (v) => _arrivalCityNotifier.value = v,
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 250.ms),
            const SizedBox(height: DonySpacing.base),

            // Date + Poids
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
            ).animate().fadeIn(delay: 60.ms),
            const SizedBox(height: DonySpacing.xl),

            // Filtres rapides
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
                  label: 'Kilo Pro uniquement',
                  active: _kiloProOnlyNotifier.value,
                  onChanged: (v) => _kiloProOnlyNotifier.value = v,
                ),
                _QuickChip(
                  label: 'Note ≥ 4.5',
                  active: _ratingFilterNotifier.value,
                  onChanged: (v) => _ratingFilterNotifier.value = v,
                ),
                _QuickChip(
                  label: 'Arrivée ce week-end',
                  active: _weekendFilterNotifier.value,
                  onChanged: (v) => _weekendFilterNotifier.value = v,
                ),
                _QuickChip(
                  label:
                      'Prix ≤ ${_maxPricePerKgNotifier.value.toStringAsFixed(0)}€/kg',
                  active: _priceFilterNotifier.value,
                  onChanged: (v) => _priceFilterNotifier.value = v,
                ),
              ],
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: DonySpacing.xl),

            // Bouton rechercher
            DonyButton(label: 'Rechercher', onPressed: _submit),
            const SizedBox(height: DonySpacing.base),
          ],
        );
      },
    );
  }
}

// ── Composants partagés (copied from search_announcement_screen.dart) ─────────

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.isDeparture,
    required this.value,
    required this.cities,
    required this.onChanged,
  });

  final bool isDeparture;
  final String value;
  final List<String> cities;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => _showPicker(context),
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDeparture ? DonyColors.primary : DonyColors.error,
              ),
            ),
            const SizedBox(width: _kIconGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDeparture ? 'DÉPART' : 'ARRIVÉE',
                    style: tt.labelSmall
                        ?.copyWith(color: DonyColors.neutral400),
                  ),
                  const SizedBox(height: DonySpacing.xxs),
                  Text(
                    value,
                    style: tt.titleLarge,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: DonyColors.neutral400),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: DonyColors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DonyRadius.sheet),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.lg,
          0,
          DonySpacing.lg,
          DonySpacing.xxl,
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
            Text(
              isDeparture ? 'Ville de départ' : 'Ville d\'arrivée',
              style: tt.headlineMedium,
            ),
            const SizedBox(height: DonySpacing.base),
            ...cities.map((city) => ListTile(
                  title: Text(
                    city,
                    style: tt.bodyMedium?.copyWith(
                      color: value == city
                          ? DonyColors.primary
                          : DonyColors.ink900,
                      fontWeight: value == city
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                  trailing: value == city
                      ? const Icon(Icons.check_rounded,
                          color: DonyColors.primary)
                      : null,
                  onTap: () {
                    onChanged(city);
                    context.pop();
                  },
                )),
          ],
        ),
      ),
    );
  }
}

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
              colorScheme: const ColorScheme.light(
                primary: DonyColors.primary,
              ),
            ),
            child: child!,
          ),
        );
        onChanged(d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.md,
        ),
        decoration: BoxDecoration(
          color: DonyColors.white,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(color: DonyColors.neutral200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DATE',
              style: tt.labelSmall?.copyWith(color: DonyColors.neutral400),
            ),
            const SizedBox(height: DonySpacing.xs),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 14, color: DonyColors.primary),
                const SizedBox(width: DonySpacing.xs),
                Text(
                  date != null
                      ? DateFormat('d MMM', 'fr').format(date!)
                      : 'Choisir',
                  style: tt.titleSmall?.copyWith(
                    color: date != null
                        ? DonyColors.ink900
                        : DonyColors.neutral400,
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

class _WeightField extends StatelessWidget {
  const _WeightField({required this.weightKg, required this.onChanged});

  final double weightKg;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () => _showWeightPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.md,
        ),
        decoration: BoxDecoration(
          color: DonyColors.white,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(color: DonyColors.neutral200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'POIDS',
              style: tt.labelSmall?.copyWith(color: DonyColors.neutral400),
            ),
            const SizedBox(height: DonySpacing.xs),
            Row(
              children: [
                const Icon(Icons.scale_rounded,
                    size: 14, color: DonyColors.primary),
                const SizedBox(width: DonySpacing.xs),
                Text(
                  '${weightKg.toStringAsFixed(0)} kg',
                  style: tt.titleSmall,
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
    double localWeight = weightKg;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: DonyColors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(DonyRadius.sheet),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg,
            0,
            DonySpacing.lg,
            DonySpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: DonySpacing.md,
                  ),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DonyColors.neutral200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Poids du colis', style: tt.headlineMedium),
              const SizedBox(height: DonySpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    localWeight.toStringAsFixed(0),
                    style: tt.displayLarge?.copyWith(
                      color: DonyColors.primary,
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(top: DonySpacing.md),
                    child: Text(
                      'kg',
                      style: tt.headlineMedium?.copyWith(
                        color: DonyColors.neutral400,
                      ),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(ctx).copyWith(
                  activeTrackColor: DonyColors.primary,
                  inactiveTrackColor: DonyColors.neutral200,
                  thumbColor: DonyColors.primary,
                  trackHeight: 4,
                ),
                child: Slider(
                  value: localWeight,
                  min: 1,
                  max: 30,
                  divisions: 29,
                  onChanged: (v) => setSheetState(() => localWeight = v),
                ),
              ),
              const SizedBox(height: DonySpacing.md),
              DonyButton(
                label: 'Confirmer',
                onPressed: () {
                  onChanged(localWeight);
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

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.active,
    required this.onChanged,
  });

  final String label;
  final bool active;
  final ValueChanged<bool> onChanged;

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
        child: Text(
          label,
          style: tt.labelMedium?.copyWith(
            color: active ? DonyColors.primary : DonyColors.ink900,
          ),
        ),
      ),
    );
  }
}
