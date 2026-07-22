import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/presentation/widgets/city_autocomplete_field.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/home/presentation/widgets/search_filter_fields.dart';
import 'package:dony/features/matching/data/models/search_params.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/urgency_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
          final cs = Theme.of(ctx).colorScheme;
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
                        color: Theme.of(ctx).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(DonyRadius.lg),
                        border: Border.all(color: cs.outline),
                      ),
                      child: Center(
                        child: Text(
                          'Réinitialiser',
                          style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                            color: cs.onSurface,
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
                  label: count == 1 ? 'Rechercher · 1 filtre' : count > 1 ? 'Rechercher · $count filtres' : 'Rechercher',
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
  // Catalogue de types de contenu — seedé synchrone avec le catalogue
  // embarqué (fallbackCatalog), puis remplacé par le catalogue live du
  // repository dès qu'il répond (repli automatique hors ligne intégré).
  final _catalogLabelsNotifier = ValueNotifier<List<String>>(
    fallbackCatalog.map((c) => c.label).toList(),
  );
  final _customContentCtrl = TextEditingController();

  Future<void> _loadCatalog() async {
    final categories =
        await getIt<IContentCategoryRepository>().getCategories();
    if (!mounted) return;
    _catalogLabelsNotifier.value = categories.map((c) => c.label).toList();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadCatalog());
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
    _catalogLabelsNotifier.dispose();
    _customContentCtrl.dispose();
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
      transportMode: _transportModeNotifier.value,
      kycVerifiedOnly: _kycVerifiedOnlyNotifier.value,
      contentType: _contentTypeNotifier.value,
      urgencyFilter: _urgencyFilterNotifier.value,
    ));
  }

  void _submitCustomContentType() {
    final value = _customContentCtrl.text.trim();
    if (value.isEmpty) return;
    _contentTypeNotifier.value = value;
    _customContentCtrl.clear();
  }

  void _reset() {
    _departureCityNotifier.value = null;
    _arrivalCityNotifier.value = null;
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
    final cs = Theme.of(context).colorScheme;
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
        _catalogLabelsNotifier,
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
                    prefixIcon: const DonyEmoji.planeTakeoff(size: 20),
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
                    prefixIcon: const DonyEmoji.planeLanding(size: 20),
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
                  child: DateField(
                    date: _dateNotifier.value,
                    onChanged: (v) => _dateNotifier.value = v,
                  ),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: WeightField(
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
                  child: PriceField(
                    maxPrice: _priceFilterNotifier.value
                        ? _maxPricePerKgNotifier.value
                        : null,
                    onTap: () => unawaited(showPricePicker(
                      context,
                      maxPrice: _priceFilterNotifier.value
                          ? _maxPricePerKgNotifier.value
                          : null,
                      onApply: (v) {
                        _priceFilterNotifier.value = v != null;
                        if (v != null) {
                          _maxPricePerKgNotifier.value = v;
                        }
                      },
                    )),
                  ),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: TransportModeField(
                    mode: _transportModeNotifier.value,
                    onTap: () => unawaited(showTransportPicker(
                      context,
                      mode: _transportModeNotifier.value,
                      onApply: (v) => _transportModeNotifier.value = v,
                    )),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 60.ms),
            const SizedBox(height: DonySpacing.xl),

            // ── Filtres rapides ──────────────────────────────────────────
            Text(
              'FILTRES RAPIDES',
              style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.md),
            Wrap(
              spacing: DonySpacing.sm,
              runSpacing: DonySpacing.sm,
              children: [
                QuickChip(
                  label: 'Kilo Pro',
                  iconAsset: 'award',
                  active: _kiloProOnlyNotifier.value,
                  onChanged: (v) => _kiloProOnlyNotifier.value = v,
                ),
                QuickChip(
                  label: 'Note ≥ 4.5',
                  iconAsset: 'star',
                  active: _ratingFilterNotifier.value,
                  onChanged: (v) => _ratingFilterNotifier.value = v,
                ),
                QuickChip(
                  label: 'Week-end',
                  iconAsset: 'sofa',
                  active: _weekendFilterNotifier.value,
                  onChanged: (v) => _weekendFilterNotifier.value = v,
                ),
                QuickChip(
                  label: 'KYC vérifié',
                  iconAsset: 'shield-check',
                  active: _kycVerifiedOnlyNotifier.value,
                  onChanged: (v) => _kycVerifiedOnlyNotifier.value = v,
                ),
              ],
            ).animate().fadeIn(delay: 80.ms),
            const SizedBox(height: DonySpacing.xl),

            // ── Type de contenu ──────────────────────────────────────────
            Text(
              'MON COLIS CONTIENT',
              style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.md),
            Wrap(
              spacing: DonySpacing.sm,
              runSpacing: DonySpacing.sm,
              children: _catalogLabelsNotifier.value.map((type) {
                final isSelected = _contentTypeNotifier.value == type;
                return ContentTypeChip(
                  label: type,
                  emoji: emojiForLabel(type),
                  selected: isSelected,
                  onTap: () {
                    _contentTypeNotifier.value = isSelected ? null : type;
                  },
                );
              }).toList(),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: DonySpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('content-type-free-text'),
                    controller: _customContentCtrl,
                    onSubmitted: (_) => _submitCustomContentType(),
                    decoration: const InputDecoration(
                      hintText: 'Ajouter un autre type…',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('content-type-free-text-add-btn'),
                  icon: const Icon(Icons.add_rounded),
                  onPressed: _submitCustomContentType,
                  tooltip: 'Ajouter',
                ),
              ],
            ),
            const SizedBox(height: DonySpacing.xl),

            // ── Urgence du départ ────────────────────────────────────────
            Text(
              'URGENCE DU DÉPART',
              style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              'Filtrer les trajets selon leur proximité de départ',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.md),
            UrgencyFilterChips(
              selected: _urgencyFilterNotifier.value,
              onChanged: (v) => _urgencyFilterNotifier.value = v,
            ).animate().fadeIn(delay: 120.ms),
            const SizedBox(height: DonySpacing.sm),
          ],
        );
      },
    );
  }
}
