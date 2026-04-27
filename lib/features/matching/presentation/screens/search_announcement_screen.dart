import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

const _departureCities = ['Paris · CDG, ORY', 'Lyon · LYS', 'Marseille · MRS'];
const _arrivalCities = ['Dakar · DKR', 'Abidjan · ABJ', 'Bamako · BKO', 'Douala · DLA'];

// Layout constants
const _kRowIndent = 56.0; // left indent for divider under location rows
const _kIconGap = 14.0;   // gap between location dot and city text

class SearchAnnouncementScreen extends StatefulWidget {
  const SearchAnnouncementScreen({super.key});

  @override
  State<SearchAnnouncementScreen> createState() =>
      _SearchAnnouncementScreenState();
}

class _SearchAnnouncementScreenState extends State<SearchAnnouncementScreen> {
  // Form field notifiers — no setState required
  final _departureCityNotifier = ValueNotifier<String>(_departureCities[0]);
  final _arrivalCityNotifier = ValueNotifier<String>(_arrivalCities[0]);
  final _dateNotifier = ValueNotifier<DateTime?>(null);
  final _weightKgNotifier = ValueNotifier<double>(6);
  final _maxPricePerKgNotifier = ValueNotifier<double>(25);
  final _kiloProOnlyNotifier = ValueNotifier<bool>(false);
  final _ratingFilterNotifier = ValueNotifier<bool>(false);
  final _weekendFilterNotifier = ValueNotifier<bool>(false);
  final _priceFilterNotifier = ValueNotifier<bool>(false);
  // showResults flag as a ValueNotifier — toggled without setState
  final _showResultsNotifier = ValueNotifier<bool>(false);

  String get _departureCityShort =>
      _departureCityNotifier.value.split(' ').first;
  String get _arrivalCityShort =>
      _arrivalCityNotifier.value.split(' ').first;

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
    _showResultsNotifier.dispose();
    super.dispose();
  }

  void _search() {
    context.read<AnnouncementBloc>().add(AnnouncementSearchRequested(
      departureCity: _departureCityShort,
      arrivalCity: _arrivalCityShort,
      departureDateFrom: _dateNotifier.value,
      minAvailableKg: _weightKgNotifier.value > 1 ? _weightKgNotifier.value : null,
      sortBy: 'date',
    ));
    _showResultsNotifier.value = true;
  }

  void _resetSearch() {
    _showResultsNotifier.value = false;
  }

  @override
  Widget build(BuildContext context) {
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
        _showResultsNotifier,
      ]),
      builder: (context, _) {
        final showResults = _showResultsNotifier.value;

        if (showResults) {
          return _ResultsView(
            departureCity: _departureCityShort,
            arrivalCity: _arrivalCityShort,
            onBack: _resetSearch,
          );
        }

        return _FilterFormView(
          departureCity: _departureCityNotifier.value,
          arrivalCity: _arrivalCityNotifier.value,
          date: _dateNotifier.value,
          weightKg: _weightKgNotifier.value,
          maxPricePerKg: _maxPricePerKgNotifier.value,
          kiloProOnly: _kiloProOnlyNotifier.value,
          ratingFilter: _ratingFilterNotifier.value,
          weekendFilter: _weekendFilterNotifier.value,
          priceFilter: _priceFilterNotifier.value,
          onDepartureChanged: (v) => _departureCityNotifier.value = v,
          onArrivalChanged: (v) => _arrivalCityNotifier.value = v,
          onDateChanged: (v) => _dateNotifier.value = v,
          onWeightChanged: (v) => _weightKgNotifier.value = v,
          onMaxPriceChanged: (v) => _maxPricePerKgNotifier.value = v,
          onKiloProChanged: (v) => _kiloProOnlyNotifier.value = v,
          onRatingChanged: (v) => _ratingFilterNotifier.value = v,
          onWeekendChanged: (v) => _weekendFilterNotifier.value = v,
          onPriceChanged: (v) => _priceFilterNotifier.value = v,
          onSearch: _search,
        );
      },
    );
  }
}

// ── Formulaire de filtres ────────────────────────────────────────────────────

class _FilterFormView extends StatelessWidget {
  const _FilterFormView({
    required this.departureCity,
    required this.arrivalCity,
    required this.date,
    required this.weightKg,
    required this.maxPricePerKg,
    required this.kiloProOnly,
    required this.ratingFilter,
    required this.weekendFilter,
    required this.priceFilter,
    required this.onDepartureChanged,
    required this.onArrivalChanged,
    required this.onDateChanged,
    required this.onWeightChanged,
    required this.onMaxPriceChanged,
    required this.onKiloProChanged,
    required this.onRatingChanged,
    required this.onWeekendChanged,
    required this.onPriceChanged,
    required this.onSearch,
  });

  final String departureCity;
  final String arrivalCity;
  final DateTime? date;
  final double weightKg;
  final double maxPricePerKg;
  final bool kiloProOnly;
  final bool ratingFilter;
  final bool weekendFilter;
  final bool priceFilter;
  final ValueChanged<String> onDepartureChanged;
  final ValueChanged<String> onArrivalChanged;
  final ValueChanged<DateTime?> onDateChanged;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<double> onMaxPriceChanged;
  final ValueChanged<bool> onKiloProChanged;
  final ValueChanged<bool> onRatingChanged;
  final ValueChanged<bool> onWeekendChanged;
  final ValueChanged<bool> onPriceChanged;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: DonyColors.bg,
      appBar: AppBar(
        title: Text(
          'Rechercher un trajet',
          style: tt.headlineMedium,
        ),
        backgroundColor: DonyColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 20, color: DonyColors.green400),
          onPressed: () => context.pop(),
          tooltip: 'Retour',
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: DonyColors.grey200),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.lg,
          DonySpacing.xl,
          DonySpacing.lg,
          120,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carte départ / arrivée
            Container(
              decoration: BoxDecoration(
                color: DonyColors.white,
                borderRadius: BorderRadius.circular(DonyRadius.card),
                border: Border.all(color: DonyColors.grey200),
              ),
              child: Column(
                children: [
                  _LocationRow(
                    isDeparture: true,
                    value: departureCity,
                    cities: _departureCities,
                    onChanged: onDepartureChanged,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: _kRowIndent),
                    child: Divider(height: 1, color: DonyColors.grey200),
                  ),
                  _LocationRow(
                    isDeparture: false,
                    value: arrivalCity,
                    cities: _arrivalCities,
                    onChanged: onArrivalChanged,
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
                    date: date,
                    onChanged: onDateChanged,
                  ),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: _WeightField(
                    weightKg: weightKg,
                    onChanged: onWeightChanged,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 60.ms),
            const SizedBox(height: DonySpacing.xl),

            // Filtres rapides
            Text(
              'FILTRES RAPIDES',
              style: tt.labelMedium?.copyWith(color: DonyColors.grey400),
            ),
            const SizedBox(height: DonySpacing.md),
            Wrap(
              spacing: DonySpacing.sm,
              runSpacing: DonySpacing.sm,
              children: [
                _QuickChip(
                  label: 'Kilo Pro uniquement',
                  active: kiloProOnly,
                  onChanged: onKiloProChanged,
                ),
                _QuickChip(
                  label: 'Note ≥ 4.5',
                  active: ratingFilter,
                  onChanged: onRatingChanged,
                ),
                _QuickChip(
                  label: 'Arrivée ce week-end',
                  active: weekendFilter,
                  onChanged: onWeekendChanged,
                ),
                _QuickChip(
                  label: 'Prix ≤ ${maxPricePerKg.toStringAsFixed(0)}€/kg',
                  active: priceFilter,
                  onChanged: onPriceChanged,
                ),
              ],
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: DonySpacing.xxl),

            // Slider prix
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Prix max par kg',
                  style: tt.titleMedium,
                ),
                Text(
                  '${maxPricePerKg.toStringAsFixed(0)} €',
                  style: tt.titleMedium?.copyWith(color: DonyColors.green400),
                ),
              ],
            ),
            const SizedBox(height: DonySpacing.sm),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: DonyColors.green400,
                inactiveTrackColor: DonyColors.grey200,
                thumbColor: DonyColors.green400,
                overlayColor: DonyColors.green400.withValues(alpha: 0.1),
                trackHeight: 4,
              ),
              child: Slider(
                value: maxPricePerKg,
                min: 5,
                max: 25,
                divisions: 20,
                onChanged: onMaxPriceChanged,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('5 €', style: tt.bodySmall?.copyWith(color: DonyColors.grey400)),
                Text('25 €', style: tt.bodySmall?.copyWith(color: DonyColors.grey400)),
              ],
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: EdgeInsets.fromLTRB(
          DonySpacing.lg,
          DonySpacing.base,
          DonySpacing.lg,
          MediaQuery.of(context).padding.bottom + DonySpacing.base,
        ),
        decoration: const BoxDecoration(
          color: DonyColors.white,
          border: Border(top: BorderSide(color: DonyColors.grey200)),
        ),
        child: BlocBuilder<AnnouncementBloc, AnnouncementState>(
          builder: (context, state) {
            final isLoading = state is AnnouncementLoading;
            final count = state is AnnouncementSearchLoaded
                ? state.results.length
                : null;
            return DonyButton(
              label: count != null
                  ? 'Voir $count trajet${count > 1 ? 's' : ''}'
                  : 'Rechercher',
              onPressed: isLoading ? null : onSearch,
              isLoading: isLoading,
            );
          },
        ),
      ),
    );
  }
}

// ── Vue des résultats ────────────────────────────────────────────────────────

class _ResultsView extends StatefulWidget {
  const _ResultsView({
    required this.departureCity,
    required this.arrivalCity,
    required this.onBack,
  });

  final String departureCity;
  final String arrivalCity;
  final VoidCallback onBack;

  @override
  State<_ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<_ResultsView> {
  // Quick-filter state — ValueNotifier, no setState
  final _ratingActive = ValueNotifier<bool>(false);
  final _priceActive = ValueNotifier<bool>(false);
  final _weekActive = ValueNotifier<bool>(false);
  final _weightActive = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    context.read<AnnouncementBloc>().add(AnnouncementSearchRequested(
      departureCity: widget.departureCity,
      arrivalCity: widget.arrivalCity,
      sortBy: 'date',
    ));
  }

  @override
  void dispose() {
    _ratingActive.dispose();
    _priceActive.dispose();
    _weekActive.dispose();
    _weightActive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: DonyColors.bg,
      appBar: AppBar(
        backgroundColor: DonyColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 20, color: DonyColors.green400),
          onPressed: widget.onBack,
          tooltip: 'Retour',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.departureCity} → ${widget.arrivalCity}',
              style: tt.headlineLarge,
            ),
            Text(
              '23 voyageurs · cette semaine',
              style: tt.bodySmall?.copyWith(color: DonyColors.grey400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: DonyColors.ink900),
            onPressed: () {},
            tooltip: 'Filtres',
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: DonyColors.grey200),
        ),
      ),
      body: Column(
        children: [
          // ── Filter chips row ────────────────────────────────────────
          SizedBox(
            height: 48,
            child: ListenableBuilder(
              listenable: Listenable.merge([
                _ratingActive,
                _priceActive,
                _weekActive,
                _weightActive,
              ]),
              builder: (context, _) => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.lg,
                  vertical: DonySpacing.sm,
                ),
                children: [
                  _FilterChip(
                    label: '★ 4.7+',
                    icon: Icons.star_rounded,
                    active: _ratingActive.value,
                    onTap: () => _ratingActive.value = !_ratingActive.value,
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  _FilterChip(
                    label: '€/kg ↓',
                    active: _priceActive.value,
                    onTap: () => _priceActive.value = !_priceActive.value,
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  _FilterChip(
                    label: 'Cette semaine',
                    active: _weekActive.value,
                    onTap: () => _weekActive.value = !_weekActive.value,
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  _FilterChip(
                    label: '+10 kg',
                    active: _weightActive.value,
                    onTap: () => _weightActive.value = !_weightActive.value,
                  ),
                ],
              ),
            ),
          ),
          // ── Results list ────────────────────────────────────────────
          Expanded(
            child: BlocBuilder<AnnouncementBloc, AnnouncementState>(
              builder: (context, state) {
                if (state is AnnouncementLoading ||
                    state is AnnouncementInitial) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: DonyColors.green400),
                  );
                }

                if (state is AnnouncementError) {
                  return _ErrorView(
                    message: state.message,
                    onRetry: () => context
                        .read<AnnouncementBloc>()
                        .add(AnnouncementSearchRequested(
                          departureCity: widget.departureCity,
                          arrivalCity: widget.arrivalCity,
                          sortBy: 'date',
                        )),
                  );
                }

                if (state is AnnouncementSearchLoaded) {
                  if (state.isEmpty) {
                    return _EmptyView(onBack: widget.onBack);
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      DonySpacing.base,
                      DonySpacing.base,
                      DonySpacing.base,
                      DonySpacing.huge,
                    ),
                    // +1 for skeleton card at the end
                    itemCount: state.results.length + 1,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: DonySpacing.md),
                    itemBuilder: (context, i) {
                      // Last item is skeleton
                      if (i == state.results.length) {
                        return const _SkeletonCard();
                      }

                      final announcement = state.results[i];
                      final authState =
                          context.read<AuthBloc>().state;
                      final currentUserId =
                          authState is AuthAuthenticated
                              ? authState.user.id
                              : null;
                      final isOwn = currentUserId != null &&
                          announcement.travelerId == currentUserId;
                      return _TravelerCard(
                        announcement: announcement,
                        index: i,
                        isOwnAnnouncement: isOwn,
                        onTap: isOwn
                            ? null
                            : () => context.push(
                                  '/search/${announcement.id}',
                                  extra: announcement,
                                ),
                      );
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter chip (results header) ─────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 180.ms,
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.sm,
        ),
        decoration: BoxDecoration(
          color: active ? DonyColors.green50 : DonyColors.white,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          border: Border.all(
            color: active ? DonyColors.green400 : DonyColors.grey200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 14,
                  color: active
                      ? DonyColors.green400
                      : DonyColors.grey400),
              const SizedBox(width: DonySpacing.xs),
            ],
            Text(
              label,
              style: tt.labelMedium?.copyWith(
                color: active
                    ? DonyColors.green400
                    : DonyColors.grey400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Composants partagés ──────────────────────────────────────────────────────

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
                color: isDeparture
                    ? DonyColors.green400
                    : DonyColors.error,
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
                        ?.copyWith(color: DonyColors.grey400),
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
                size: 18, color: DonyColors.grey400),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    showModalBottomSheet<void>(
      context: context,
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
                  color: DonyColors.grey200,
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
                          ? DonyColors.green400
                          : DonyColors.ink900,
                      fontWeight: value == city
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                  trailing: value == city
                      ? const Icon(Icons.check_rounded,
                          color: DonyColors.green400)
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
                primary: DonyColors.green400,
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
          border: Border.all(color: DonyColors.grey200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DATE',
              style: tt.labelSmall?.copyWith(color: DonyColors.grey400),
            ),
            const SizedBox(height: DonySpacing.xs),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 14, color: DonyColors.green400),
                const SizedBox(width: DonySpacing.xs),
                Text(
                  date != null
                      ? DateFormat('d MMM', 'fr').format(date!)
                      : 'Choisir',
                  style: tt.titleSmall?.copyWith(
                    color: date != null
                        ? DonyColors.ink900
                        : DonyColors.grey400,
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
          border: Border.all(color: DonyColors.grey200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'POIDS',
              style: tt.labelSmall?.copyWith(color: DonyColors.grey400),
            ),
            const SizedBox(height: DonySpacing.xs),
            Row(
              children: [
                const Icon(Icons.scale_rounded,
                    size: 14, color: DonyColors.green400),
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
                    color: DonyColors.grey200,
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
                      color: DonyColors.green400,
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(top: DonySpacing.md),
                    child: Text(
                      'kg',
                      style: tt.headlineMedium?.copyWith(
                        color: DonyColors.grey400,
                      ),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(ctx).copyWith(
                  activeTrackColor: DonyColors.green400,
                  inactiveTrackColor: DonyColors.grey200,
                  thumbColor: DonyColors.green400,
                  trackHeight: 4,
                ),
                child: Slider(
                  value: localWeight,
                  min: 1,
                  max: 30,
                  divisions: 29,
                  onChanged: (v) =>
                      setSheetState(() => localWeight = v),
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
          color: active ? DonyColors.green50 : DonyColors.white,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          border: Border.all(
            color: active ? DonyColors.green400 : DonyColors.grey200,
          ),
        ),
        child: Text(
          label,
          style: tt.labelMedium?.copyWith(
            color: active ? DonyColors.green400 : DonyColors.ink900,
          ),
        ),
      ),
    );
  }
}

// ── Traveler card (résultats) ────────────────────────────────────────────────

class _TravelerCard extends StatelessWidget {
  const _TravelerCard({
    required this.announcement,
    required this.index,
    required this.isOwnAnnouncement,
    required this.onTap,
  });

  final AnnouncementModel announcement;
  final VoidCallback? onTap;
  final int index;
  final bool isOwnAnnouncement;

  String get _displayName =>
      announcement.traveler?.resolvedName ?? 'Voyageur';

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final traveler = announcement.traveler;
    final rating = traveler?.averageRating;
    final totalTrips = traveler?.totalTrips;
    final isKiloPro = traveler?.kiloPro ?? false;
    final dateStr =
        DateFormat('EEE d MMM', 'fr').format(announcement.departureDate);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: DonyColors.white,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: DonyColors.grey200),
        ),
        padding: const EdgeInsets.all(DonySpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: avatar + info + price ───────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DonyAvatar(
                  name: _displayName,
                  size: DonyAvatarSize.md,
                  verified: isKiloPro,
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName,
                        style: tt.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: DonySpacing.xxs),
                      Row(
                        children: [
                          if (rating != null) ...[
                            const Icon(Icons.star_rounded,
                                size: 13,
                                color: DonyColors.warning),
                            const SizedBox(width: DonySpacing.xxs),
                            Text(
                              rating.toStringAsFixed(1),
                              style: tt.titleSmall,
                            ),
                          ],
                          if (totalTrips != null && totalTrips > 0)
                            Text(
                              ' · $totalTrips trajet${totalTrips > 1 ? 's' : ''}',
                              style: tt.bodySmall?.copyWith(
                                color: DonyColors.grey400,
                              ),
                            ),
                          if (isKiloPro) ...[
                            const SizedBox(width: DonySpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: DonySpacing.xs,
                                vertical: DonySpacing.xxs,
                              ),
                              decoration: BoxDecoration(
                                color: DonyColors.warningLight,
                                borderRadius: BorderRadius.circular(
                                    DonyRadius.xs),
                              ),
                              child: Text(
                                'KYC',
                                style: tt.labelSmall?.copyWith(
                                  color: DonyColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Price per kg
                Text(
                  '${announcement.pricePerKg.toStringAsFixed(0)} €/kg',
                  style: tt.titleLarge?.copyWith(
                    color: DonyColors.green400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DonySpacing.sm),

            // ── Row 2: date + capacity ──────────────────────────────
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 13, color: DonyColors.grey400),
                const SizedBox(width: DonySpacing.xs),
                Text(
                  dateStr,
                  style: tt.bodySmall
                      ?.copyWith(color: DonyColors.grey400),
                ),
                const SizedBox(width: DonySpacing.md),
                const Icon(Icons.inventory_2_outlined,
                    size: 13, color: DonyColors.grey400),
                const SizedBox(width: DonySpacing.xs),
                Text(
                  '${announcement.availableKg.toStringAsFixed(0)} kg dispo',
                  style: tt.bodySmall
                      ?.copyWith(color: DonyColors.grey400),
                ),
              ],
            ),
            const SizedBox(height: DonySpacing.sm),

            // ── Row 3: content-type chips — shown only when the model
            // exposes an acceptedContentTypes field. AnnouncementModel
            // currently has no such field; nothing is rendered here to
            // avoid displaying hardcoded placeholder content.
            // TODO(matching): wire up announcement.acceptedContentTypes when added.

            // Own announcement label
            if (isOwnAnnouncement) ...[
              const SizedBox(height: DonySpacing.sm),
              Text(
                'Votre trajet',
                style: tt.labelMedium
                    ?.copyWith(color: DonyColors.grey400),
              ),
            ],
          ],
        ),
      ).animate().fadeIn(
            delay: Duration(milliseconds: 60 * index),
          ).slideY(
            begin: 0.04,
            curve: Curves.easeOutCubic,
          ),
    );
  }
}

// ── Skeleton card ────────────────────────────────────────────────────────────

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  // Dimension constants to avoid raw literals
  static const double _kAvatarSize = 44.0;
  static const double _kLineHeight = 12.0;
  static const double _kNameWidth = 120.0;
  static const double _kSubWidth = 80.0;
  static const double _kShortLineWidth = 160.0;
  static const double _kNameHeight = 14.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.grey200),
      ),
      padding: const EdgeInsets.all(DonySpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SkeletonBox(
                width: _kAvatarSize,
                height: _kAvatarSize,
                radius: DonyRadius.full,
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _SkeletonBox(width: _kNameWidth, height: _kNameHeight),
                    SizedBox(height: DonySpacing.xs),
                    _SkeletonBox(width: _kSubWidth, height: _kLineHeight),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.md),
          const _SkeletonBox(width: double.infinity, height: _kLineHeight),
          const SizedBox(height: DonySpacing.xs),
          const _SkeletonBox(width: _kShortLineWidth, height: _kLineHeight),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    this.radius = DonyRadius.sm,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width == double.infinity ? double.infinity : width,
      height: height,
      decoration: BoxDecoration(
        color: DonyColors.grey200,
        borderRadius: BorderRadius.circular(radius),
      ),
    )
        .animate(
          onPlay: (c) => c.repeat(reverse: true),
        )
        .tint(
          color: DonyColors.grey100,
          duration: 900.ms,
          curve: Curves.easeInOut,
        );
  }
}

// ── États vide + erreur ──────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.huge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(DonySpacing.xl),
              decoration: const BoxDecoration(
                color: DonyColors.green50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 48, color: DonyColors.green400),
            ),
            const SizedBox(height: DonySpacing.lg),
            Text(
              'Aucun voyageur disponible',
              style: tt.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              'Essayez avec d\'autres critères de recherche.',
              style: tt.bodyMedium?.copyWith(color: DonyColors.grey400),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.xl),
            DonyButton(
              label: 'Modifier la recherche',
              onPressed: onBack,
              variant: DonyButtonVariant.secondary,
              fullWidth: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.huge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 56, color: DonyColors.grey200),
            const SizedBox(height: DonySpacing.base),
            Text(
              'Connexion impossible',
              style: tt.headlineMedium,
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              message,
              style: tt.bodySmall?.copyWith(color: DonyColors.grey400),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.xl),
            DonyButton(
              label: 'Réessayer',
              onPressed: onRetry,
              icon: Icons.refresh_rounded,
              fullWidth: false,
            ),
          ],
        ),
      ),
    );
  }
}
