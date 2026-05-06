import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_map_view.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

const _departureCities = ['Paris · CDG, ORY', 'Lyon · LYS', 'Marseille · MRS'];
const _arrivalCities = ['Dakar · DKR', 'Abidjan · ABJ', 'Bamako · BKO', 'Douala · DLA'];

/// Retourne un label "CODE · X km" si userPos est connue et pickupAddress non-null.
/// Retourne null sinon.
String? buildDistanceBadge(
  AnnouncementModel announcement,
  ({double lat, double lng})? userPos,
) {
  if (userPos == null) {
    return null;
  }
  final pickup = announcement.pickupAddress;
  if (pickup == null) {
    return null;
  }

  final distanceM = Geolocator.distanceBetween(
    userPos.lat,
    userPos.lng,
    pickup.lat,
    pickup.lng,
  );
  final distanceKm = (distanceM / 1000).round();

  // Extrait le code IATA (3 lettres majuscules) depuis le label si présent
  // Ex: "Paris CDG" → "CDG", "Roissy" → "Roissy"
  final allMatches = RegExp(r'\b([A-Z]{3})\b').allMatches(pickup.label);
  final locationCode = allMatches.isNotEmpty
      ? allMatches.last.group(1)!
      : pickup.label.split(' ').first;

  final distanceLabel = distanceKm == 0 ? '< 1 km' : '$distanceKm km';
  return '$locationCode · $distanceLabel';
}

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

  // Result-filter notifiers — hoisted to parent so they survive form↔results navigation
  final _ratingActive = ValueNotifier<bool>(false);
  final _priceActive = ValueNotifier<bool>(false);
  final _weekActive = ValueNotifier<bool>(false);
  final _weightActive = ValueNotifier<bool>(false);

  // Dirty flag — true until _search() is called
  final _searchDirtyNotifier = ValueNotifier<bool>(true);

  // Near-me filter state — shared between map FAB and filter sheet
  final _isNearMeActiveNotifier = ValueNotifier<bool>(false);
  final _radiusKmNotifier = ValueNotifier<double>(25.0);
  final _userPositionNotifier = ValueNotifier<({double lat, double lng})?>(null);

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
    _ratingActive.dispose();
    _priceActive.dispose();
    _weekActive.dispose();
    _weightActive.dispose();
    _searchDirtyNotifier.dispose();
    _isNearMeActiveNotifier.dispose();
    _radiusKmNotifier.dispose();
    _userPositionNotifier.dispose();
    super.dispose();
  }

  void _search() {
    context.read<AnnouncementBloc>().add(AnnouncementSearchRequested(
      departureCity: _departureCityShort,
      arrivalCity: _arrivalCityShort,
      departureDateFrom: _dateNotifier.value,
      minAvailableKg:
          _weightKgNotifier.value > 1 ? _weightKgNotifier.value : null,
      maxPricePerKg:
          _priceFilterNotifier.value ? _maxPricePerKgNotifier.value : null,
      kiloProOnly: _kiloProOnlyNotifier.value,
      minRating: _ratingFilterNotifier.value ? 4.5 : null,
      weekendOnly: _weekendFilterNotifier.value,
      sortBy: _priceFilterNotifier.value ? 'price' : 'date',
      sortDir: 'asc',
      // Near me: only set when active and we have a known position
      userLat: _isNearMeActiveNotifier.value ? _userPositionNotifier.value?.lat : null,
      userLng: _isNearMeActiveNotifier.value ? _userPositionNotifier.value?.lng : null,
      radiusKm: _isNearMeActiveNotifier.value ? _radiusKmNotifier.value : null,
    ));
    _searchDirtyNotifier.value = false;
    _showResultsNotifier.value = true;
  }

  void _resetSearch() {
    _showResultsNotifier.value = false;
    _searchDirtyNotifier.value = true;
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
        _ratingActive,
        _priceActive,
        _weekActive,
        _weightActive,
        _searchDirtyNotifier,
      ]),
      builder: (context, _) {
        final showResults = _showResultsNotifier.value;

        if (showResults) {
          return _ResultsView(
            departureCity: _departureCityShort,
            arrivalCity: _arrivalCityShort,
            onBack: _resetSearch,
            ratingActive: _ratingActive,
            priceActive: _priceActive,
            weekActive: _weekActive,
            weightActive: _weightActive,
            date: _dateNotifier.value,
            weightKg: _weightKgNotifier.value,
            maxPricePerKg: _maxPricePerKgNotifier.value,
            kiloProOnly: _kiloProOnlyNotifier.value,
            ratingFilter: _ratingFilterNotifier.value,
            weekendFilter: _weekendFilterNotifier.value,
            priceFilter: _priceFilterNotifier.value,
            isNearMeActive: _isNearMeActiveNotifier,
            radiusKm: _radiusKmNotifier,
            userPosition: _userPositionNotifier,
            onApply: ({
              required departureCity,
              required arrivalCity,
              date,
              required weightKg,
              required maxPricePerKg,
              required kiloProOnly,
              required ratingFilter,
              required weekendFilter,
              required priceFilter,
            }) {
              _departureCityNotifier.value = departureCity;
              _arrivalCityNotifier.value = arrivalCity;
              _dateNotifier.value = date;
              _weightKgNotifier.value = weightKg;
              _maxPricePerKgNotifier.value = maxPricePerKg;
              _kiloProOnlyNotifier.value = kiloProOnly;
              _ratingFilterNotifier.value = ratingFilter;
              _weekendFilterNotifier.value = weekendFilter;
              _priceFilterNotifier.value = priceFilter;
              _search();
            },
            onNearMeChanged: ({required bool isActive, double? lat, double? lng, required double radius}) {
              if (lat != null && lng != null) {
                _userPositionNotifier.value = (lat: lat, lng: lng);
              }
              _radiusKmNotifier.value = radius;
              _isNearMeActiveNotifier.value = isActive;
              // Always re-run the search — when disabling, this returns all
              // results matching the other filters (without the radius filter).
              _search();
            },
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
          searchDirty: _searchDirtyNotifier.value,
          onDepartureChanged: (v) {
            _departureCityNotifier.value = v;
            _search();
          },
          onArrivalChanged: (v) {
            _arrivalCityNotifier.value = v;
            _search();
          },
          onDateChanged: (v) {
            _dateNotifier.value = v;
            _searchDirtyNotifier.value = true;
          },
          onWeightChanged: (v) {
            _weightKgNotifier.value = v;
            _searchDirtyNotifier.value = true;
          },
          onMaxPriceChanged: (v) => _maxPricePerKgNotifier.value = v,
          onMaxPriceChangeEnd: () => _searchDirtyNotifier.value = true,
          onKiloProChanged: (v) {
            _kiloProOnlyNotifier.value = v;
            _search();
          },
          onRatingChanged: (v) {
            _ratingFilterNotifier.value = v;
            _search();
          },
          onWeekendChanged: (v) {
            _weekendFilterNotifier.value = v;
            _search();
          },
          onPriceChanged: (v) {
            _priceFilterNotifier.value = v;
            _search();
          },
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
    required this.searchDirty,
    required this.onDepartureChanged,
    required this.onArrivalChanged,
    required this.onDateChanged,
    required this.onWeightChanged,
    required this.onMaxPriceChanged,
    required this.onMaxPriceChangeEnd,
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
  final bool searchDirty;
  final ValueChanged<String> onDepartureChanged;
  final ValueChanged<String> onArrivalChanged;
  final ValueChanged<DateTime?> onDateChanged;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<double> onMaxPriceChanged;
  final VoidCallback onMaxPriceChangeEnd;
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
              size: 20, color: DonyColors.primary),
          onPressed: () => context.pop(),
          tooltip: 'Retour',
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: DonyColors.neutral200),
        ),
      ),
      body: Builder(builder: (context) {
        final h = DonyLayout.hPadding(context);
        return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(h, DonySpacing.xl, h, 120),
        child: Column(
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
                    value: departureCity,
                    cities: _departureCities,
                    onChanged: onDepartureChanged,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: _kRowIndent),
                    child: Divider(height: 1, color: DonyColors.neutral200),
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
              style: tt.labelMedium?.copyWith(color: DonyColors.neutral400),
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
                  style: tt.titleMedium?.copyWith(color: DonyColors.primary),
                ),
              ],
            ),
            const SizedBox(height: DonySpacing.sm),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: DonyColors.primary,
                inactiveTrackColor: DonyColors.neutral200,
                thumbColor: DonyColors.primary,
                overlayColor: DonyColors.primary.withValues(alpha: 0.1),
                trackHeight: 4,
              ),
              child: Slider(
                value: maxPricePerKg,
                min: 5,
                max: 25,
                divisions: 20,
                onChanged: onMaxPriceChanged,
                onChangeEnd: (_) => onMaxPriceChangeEnd(),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('5 €', style: tt.bodySmall?.copyWith(color: DonyColors.neutral400)),
                Text('25 €', style: tt.bodySmall?.copyWith(color: DonyColors.neutral400)),
              ],
            ),
          ],
        ),
        );
      }),
      bottomSheet: Container(
        padding: EdgeInsets.fromLTRB(
          DonyLayout.hPadding(context),
          DonySpacing.base,
          DonyLayout.hPadding(context),
          MediaQuery.of(context).padding.bottom + DonySpacing.base,
        ),
        decoration: const BoxDecoration(
          color: DonyColors.white,
          border: Border(top: BorderSide(color: DonyColors.neutral200)),
        ),
        child: BlocBuilder<AnnouncementBloc, AnnouncementState>(
          builder: (context, state) {
            final isLoading = state is AnnouncementLoading;
            final count = state is AnnouncementSearchLoaded
                ? state.results.length
                : null;
            return DonyButton(
              label: count != null && !searchDirty
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
    required this.ratingActive,
    required this.priceActive,
    required this.weekActive,
    required this.weightActive,
    required this.date,
    required this.weightKg,
    required this.maxPricePerKg,
    required this.kiloProOnly,
    required this.ratingFilter,
    required this.weekendFilter,
    required this.priceFilter,
    required this.isNearMeActive,
    required this.radiusKm,
    required this.userPosition,
    required this.onApply,
    required this.onNearMeChanged,
  });

  final String departureCity;
  final String arrivalCity;
  final VoidCallback onBack;
  final ValueNotifier<bool> ratingActive;
  final ValueNotifier<bool> priceActive;
  final ValueNotifier<bool> weekActive;
  final ValueNotifier<bool> weightActive;
  final DateTime? date;
  final double weightKg;
  final double maxPricePerKg;
  final bool kiloProOnly;
  final bool ratingFilter;
  final bool weekendFilter;
  final bool priceFilter;
  final ValueNotifier<bool> isNearMeActive;
  final ValueNotifier<double> radiusKm;
  final ValueNotifier<({double lat, double lng})?> userPosition;
  final void Function({
    required String departureCity,
    required String arrivalCity,
    DateTime? date,
    required double weightKg,
    required double maxPricePerKg,
    required bool kiloProOnly,
    required bool ratingFilter,
    required bool weekendFilter,
    required bool priceFilter,
  }) onApply;
  final void Function({
    required bool isActive,
    double? lat,
    double? lng,
    required double radius,
  }) onNearMeChanged;

  @override
  State<_ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<_ResultsView> {
  // ── Section 5: client-side filter logic (AND semantics) ─────────────────────
  static const double _kSheetInitial = 0.55;
  static const double _kSheetMin = 0.15;

  final _sheetController = DraggableScrollableController();
  double _sheetSize = _kSheetInitial;

  bool get _isMapHidden => _sheetSize > 0.92;

  bool _errorBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetSizeChanged);
  }

  void _onSheetSizeChanged() {
    if (_sheetController.isAttached) {
      final s = _sheetController.size;
      if ((s - _sheetSize).abs() > 0.001) {
        setState(() => _sheetSize = s);
      }
    }
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetSizeChanged);
    _sheetController.dispose();
    super.dispose();
  }

  void _showMap() {
    _sheetController.animateTo(
      _kSheetInitial,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  List<AnnouncementModel> _applyFilters(List<AnnouncementModel> all) {
    final list = all.where((a) {
      if (widget.ratingActive.value) {
        final r = a.traveler?.averageRating;
        if (r == null || r < 4.7) {
          return false;
        }
      }
      if (widget.weekActive.value) {
        final now = DateTime.now();
        final weekEnd = now.add(const Duration(days: 7));
        if (a.departureDate.isBefore(now) ||
            a.departureDate.isAfter(weekEnd)) {
          return false;
        }
      }
      if (widget.weightActive.value && a.availableKg < 10) {
        return false;
      }
      return true;
    }).toList();
    if (widget.priceActive.value) {
      list.sort((a, b) => a.pricePerKg.compareTo(b.pricePerKg));
    }
    return list;
  }

  Widget _buildFilterChipsRow(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          widget.ratingActive,
          widget.priceActive,
          widget.weekActive,
          widget.weightActive,
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
              active: widget.ratingActive.value,
              onTap: () => widget.ratingActive.value =
                  !widget.ratingActive.value,
            ),
            const SizedBox(width: DonySpacing.sm),
            _FilterChip(
              label: '€/kg ↓',
              active: widget.priceActive.value,
              onTap: () => widget.priceActive.value =
                  !widget.priceActive.value,
            ),
            const SizedBox(width: DonySpacing.sm),
            _FilterChip(
              label: 'Cette semaine',
              active: widget.weekActive.value,
              onTap: () =>
                  widget.weekActive.value = !widget.weekActive.value,
            ),
            const SizedBox(width: DonySpacing.sm),
            _FilterChip(
              label: '+10 kg',
              active: widget.weightActive.value,
              onTap: () => widget.weightActive.value =
                  !widget.weightActive.value,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListColumn(
    BuildContext context,
    AnnouncementState state, {
    required List<AnnouncementModel> results,
  }) {
    return _buildResultsBody(context, state, results: results);
  }

  Widget _buildResultsBody(
    BuildContext context,
    AnnouncementState state, {
    required List<AnnouncementModel> results,
  }) {
    if (state is AnnouncementLoading || state is AnnouncementInitial) {
      return const Center(
        child: CircularProgressIndicator(color: DonyColors.primary),
      );
    }
    if (state is AnnouncementError && state.previousResults == null) {
      return _ErrorView(
        message: state.message,
        onRetry: () => context.read<AnnouncementBloc>().add(
              AnnouncementSearchRequested(
                departureCity: widget.departureCity,
                arrivalCity: widget.arrivalCity,
                sortBy: 'date',
              ),
            ),
      );
    }
    if (results.isEmpty) {
      return _EmptyView(onBack: widget.onBack);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.base,
        DonySpacing.base,
        DonySpacing.base,
        DonySpacing.huge,
      ),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: DonySpacing.md),
      itemBuilder: (context, i) {
        final announcement = results[i];
        final authState = context.read<AuthBloc>().state;
        final currentUserId =
            authState is AuthAuthenticated ? authState.user.id : null;
        final isOwn = currentUserId != null &&
            announcement.travelerId == currentUserId;
        return TravelerCard(
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

  // ── GPS permission helper ─────────────────────────────────────────────────
  Future<Position?> _ensureUserPosition() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    );
  }

  // ── Section 8: filter bottom sheet (DraggableScrollableSheet) ───────────────
  void _showFilterBottomSheet(BuildContext ctx) {
    String depCity = widget.departureCity;
    String arrCity = widget.arrivalCity;
    DateTime? date = widget.date;
    double weightKg = widget.weightKg;
    double maxPricePerKg = widget.maxPricePerKg;
    bool kiloProOnly = widget.kiloProOnly;
    bool ratingFilter = widget.ratingFilter;
    bool weekendFilter = widget.weekendFilter;
    bool priceFilter = widget.priceFilter;
    // Near me — initialise from parent notifiers
    bool nearMeActive = widget.isNearMeActive.value;
    double nearMeRadius = widget.radiusKm.value;

    showModalBottomSheet<void>(
      context: ctx,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        expand: false,
        builder: (sheetCtx, scrollCtrl) => StatefulBuilder(
          builder: (sbCtx, setSheet) {
            final tt = Theme.of(sbCtx).textTheme;
            return Container(
              decoration: const BoxDecoration(
                color: DonyColors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(DonyRadius.sheet),
                ),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: DonySpacing.md),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: DonyColors.neutral200,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(
                        DonySpacing.lg, 0, DonySpacing.lg, DonySpacing.xxl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: DonyColors.white,
                              borderRadius:
                                  BorderRadius.circular(DonyRadius.card),
                              border: Border.all(color: DonyColors.neutral200),
                            ),
                            child: Column(
                              children: [
                                _LocationRow(
                                  isDeparture: true,
                                  value: depCity,
                                  cities: _departureCities,
                                  onChanged: (v) =>
                                      setSheet(() => depCity = v),
                                ),
                                const Padding(
                                  padding:
                                      EdgeInsets.only(left: _kRowIndent),
                                  child: Divider(
                                      height: 1, color: DonyColors.neutral200),
                                ),
                                _LocationRow(
                                  isDeparture: false,
                                  value: arrCity,
                                  cities: _arrivalCities,
                                  onChanged: (v) =>
                                      setSheet(() => arrCity = v),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: DonySpacing.base),
                          Row(
                            children: [
                              Expanded(
                                child: _DateField(
                                  date: date,
                                  onChanged: (v) =>
                                      setSheet(() => date = v),
                                ),
                              ),
                              const SizedBox(width: DonySpacing.md),
                              Expanded(
                                child: _WeightField(
                                  weightKg: weightKg,
                                  onChanged: (v) =>
                                      setSheet(() => weightKg = v),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: DonySpacing.xl),
                          Text(
                            'FILTRES RAPIDES',
                            style: tt.labelMedium
                                ?.copyWith(color: DonyColors.neutral400),
                          ),
                          const SizedBox(height: DonySpacing.md),
                          Wrap(
                            spacing: DonySpacing.sm,
                            runSpacing: DonySpacing.sm,
                            children: [
                              _QuickChip(
                                label: 'Kilo Pro uniquement',
                                active: kiloProOnly,
                                onChanged: (v) =>
                                    setSheet(() => kiloProOnly = v),
                              ),
                              _QuickChip(
                                label: 'Note ≥ 4.5',
                                active: ratingFilter,
                                onChanged: (v) =>
                                    setSheet(() => ratingFilter = v),
                              ),
                              _QuickChip(
                                label: 'Arrivée ce week-end',
                                active: weekendFilter,
                                onChanged: (v) =>
                                    setSheet(() => weekendFilter = v),
                              ),
                              _QuickChip(
                                label:
                                    'Prix ≤ ${maxPricePerKg.toStringAsFixed(0)}€/kg',
                                active: priceFilter,
                                onChanged: (v) =>
                                    setSheet(() => priceFilter = v),
                              ),
                            ],
                          ),
                          const SizedBox(height: DonySpacing.xxl),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Prix max par kg',
                                  style: tt.titleMedium),
                              Text(
                                '${maxPricePerKg.toStringAsFixed(0)} €',
                                style: tt.titleMedium
                                    ?.copyWith(color: DonyColors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: DonySpacing.sm),
                          SliderTheme(
                            data: SliderTheme.of(sbCtx).copyWith(
                              activeTrackColor: DonyColors.primary,
                              inactiveTrackColor: DonyColors.neutral200,
                              thumbColor: DonyColors.primary,
                              overlayColor: DonyColors.primary
                                  .withValues(alpha: 0.1),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: maxPricePerKg,
                              min: 5,
                              max: 25,
                              divisions: 20,
                              onChanged: (v) =>
                                  setSheet(() => maxPricePerKg = v),
                            ),
                          ),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text('5 €',
                                  style: tt.bodySmall?.copyWith(
                                      color: DonyColors.neutral400)),
                              Text('25 €',
                                  style: tt.bodySmall?.copyWith(
                                      color: DonyColors.neutral400)),
                            ],
                          ),

                          // ── Filtre "Près de moi" ──────────────────────────
                          const SizedBox(height: DonySpacing.xxl),
                          const Divider(height: 1, color: DonyColors.neutral200),
                          const SizedBox(height: DonySpacing.md),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Près de moi',
                                style: tt.titleMedium),
                            subtitle: Text(
                              'Annonces dont le point de remise est dans le rayon',
                              style: tt.bodySmall?.copyWith(
                                  color: DonyColors.neutral400),
                            ),
                            value: nearMeActive,
                            activeThumbColor: DonyColors.primary,
                            onChanged: (on) async {
                              if (on) {
                                final pos = await _ensureUserPosition();
                                if (pos != null) {
                                  setSheet(() => nearMeActive = true);
                                }
                              } else {
                                setSheet(() => nearMeActive = false);
                              }
                            },
                          ),
                          if (nearMeActive) ...[
                            const SizedBox(height: DonySpacing.sm),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Rayon', style: tt.titleMedium),
                                Text(
                                  '${nearMeRadius.round()} km',
                                  style: tt.titleMedium?.copyWith(
                                      color: DonyColors.primary,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: DonySpacing.sm),
                            SliderTheme(
                              data: SliderTheme.of(sbCtx).copyWith(
                                activeTrackColor: DonyColors.primary,
                                inactiveTrackColor: DonyColors.neutral200,
                                thumbColor: DonyColors.primary,
                                overlayColor: DonyColors.primary
                                    .withValues(alpha: 0.1),
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: nearMeRadius,
                                min: 5,
                                max: 200,
                                divisions: 39,
                                onChanged: (v) =>
                                    setSheet(() => nearMeRadius = v),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('5 km',
                                    style: tt.bodySmall?.copyWith(
                                        color: DonyColors.neutral400)),
                                Text('200 km',
                                    style: tt.bodySmall?.copyWith(
                                        color: DonyColors.neutral400)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      DonySpacing.lg,
                      DonySpacing.base,
                      DonySpacing.lg,
                      MediaQuery.of(sbCtx).padding.bottom + DonySpacing.base,
                    ),
                    decoration: const BoxDecoration(
                      color: DonyColors.white,
                      border:
                          Border(top: BorderSide(color: DonyColors.neutral200)),
                    ),
                    child: DonyButton(
                      label: 'Appliquer',
                      onPressed: () async {
                        // Resolve GPS position if near-me was turned on in sheet
                        double? resolvedLat;
                        double? resolvedLng;
                        if (nearMeActive) {
                          final pos = await _ensureUserPosition();
                          if (pos != null) {
                            resolvedLat = pos.latitude;
                            resolvedLng = pos.longitude;
                          } else {
                            // Permission denied — silently disable near-me
                            nearMeActive = false;
                          }
                        }
                        if (!sbCtx.mounted) return;
                        sbCtx.pop();
                        widget.onNearMeChanged(
                          isActive: nearMeActive,
                          lat: resolvedLat,
                          lng: resolvedLng,
                          radius: nearMeRadius,
                        );
                        widget.onApply(
                          departureCity: depCity,
                          arrivalCity: arrCity,
                          date: date,
                          weightKg: weightKg,
                          maxPricePerKg: maxPricePerKg,
                          kiloProOnly: kiloProOnly,
                          ratingFilter: ratingFilter,
                          weekendFilter: weekendFilter,
                          priceFilter: priceFilter,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    // Section 7: badge visible when any Level-1 or Level-2 filter is active
    final hasActiveFilters = widget.kiloProOnly ||
        widget.ratingFilter ||
        widget.weekendFilter ||
        widget.priceFilter ||
        widget.ratingActive.value ||
        widget.priceActive.value ||
        widget.weekActive.value ||
        widget.weightActive.value;

    return Scaffold(
      backgroundColor: DonyColors.bg,
      appBar: AppBar(
        backgroundColor: DonyColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 20, color: DonyColors.primary),
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
            // Section 6: dynamic count from filtered results
            BlocBuilder<AnnouncementBloc, AnnouncementState>(
              builder: (context, state) {
                if (state is! AnnouncementSearchLoaded) {
                  return const SizedBox.shrink();
                }
                final count = _applyFilters(state.results).length;
                return Text(
                  '$count voyageur${count > 1 ? 's' : ''}',
                  style: tt.bodySmall?.copyWith(color: DonyColors.neutral400),
                );
              },
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded, color: DonyColors.ink900),
                onPressed: () => _showFilterBottomSheet(context),
                tooltip: 'Filtres',
              ),
              if (hasActiveFilters)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: DonyColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: DonyColors.neutral200),
        ),
      ),
      body: BlocConsumer<AnnouncementBloc, AnnouncementState>(
        listener: (context, state) {
          if (state is AnnouncementError && state.previousResults != null) {
            setState(() => _errorBannerDismissed = false);
          }
        },
        builder: (context, state) {
          // Cas 1 — pas encore de résultats : vue liste-seule (loading | error | initial).
          final hasResults =
              state is AnnouncementSearchLoaded ||
              (state is AnnouncementError && state.previousResults != null);
          if (!hasResults) {
            return _buildListColumn(context, state, results: const []);
          }

          // Cas 2 — résultats disponibles : monter la liste ET la map.
          final List<AnnouncementModel> rawResults =
              state is AnnouncementSearchLoaded
                  ? state.results
                  : (state as AnnouncementError).previousResults!;

          return ListenableBuilder(
            listenable: Listenable.merge([
              widget.ratingActive,
              widget.priceActive,
              widget.weekActive,
              widget.weightActive,
              widget.isNearMeActive,
              widget.radiusKm,
              widget.userPosition,
            ]),
            builder: (context, _) {
              final filtered = _applyFilters(rawResults);
              final pos = widget.userPosition.value;
              final tt = Theme.of(context).textTheme;
              final bottomPad = MediaQuery.of(context).padding.bottom;
              return Stack(
                children: [
                  // ── Carte (fond permanent) ──
                  Positioned.fill(
                    child: AnnouncementMapView(
                      announcements: filtered,
                      searchDepartureCity: widget.departureCity,
                      searchArrivalCity: widget.arrivalCity,
                      onNearMeRequested: (lat, lng, radius) {
                        widget.onNearMeChanged(isActive: true, lat: lat, lng: lng, radius: radius);
                      },
                      onNearMeDisabled: () {
                        widget.onNearMeChanged(isActive: false, radius: widget.radiusKm.value);
                      },
                      isNearMeActive: widget.isNearMeActive.value,
                      activeRadiusKm: widget.radiusKm.value,
                      userPosition: pos != null ? LatLng(pos.lat, pos.lng) : null,
                    ),
                  ),

                  // ── Sheet draggable ──
                  DraggableScrollableSheet(
                    controller: _sheetController,
                    initialChildSize: _kSheetInitial,
                    minChildSize: _kSheetMin,
                    maxChildSize: 1.0,
                    snap: true,
                    snapSizes: const [_kSheetInitial, 1.0],
                    builder: (context, scrollController) {
                      return Container(
                        decoration: BoxDecoration(
                          color: DonyColors.white,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 20,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Drag handle
                            Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 10),
                                width: 40, height: 4,
                                decoration: BoxDecoration(
                                  color: DonyColors.neutral200,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            _buildFilterChipsRow(context),
                            const Divider(height: 1, color: DonyColors.neutral200),
                            // Compteur + Trier
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                DonySpacing.lg, DonySpacing.md, DonySpacing.lg, DonySpacing.xs,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '${filtered.length} voyageur${filtered.length > 1 ? 's' : ''}',
                                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () => _showFilterBottomSheet(context),
                                    child: Text(
                                      'Trier',
                                      style: tt.labelMedium?.copyWith(
                                        color: DonyColors.primary, fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Liste scrollable
                            Expanded(
                              child: filtered.isEmpty
                                  ? SingleChildScrollView(
                                      controller: scrollController,
                                      child: _EmptyView(onBack: widget.onBack),
                                    )
                                  : ListView.separated(
                                      controller: scrollController,
                                      padding: EdgeInsets.fromLTRB(
                                        DonySpacing.base, DonySpacing.sm,
                                        DonySpacing.base, bottomPad + DonySpacing.huge,
                                      ),
                                      itemCount: filtered.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: DonySpacing.md),
                                      itemBuilder: (context, i) {
                                        final a = filtered[i];
                                        final authState = context.read<AuthBloc>().state;
                                        final currentUserId = authState is AuthAuthenticated
                                            ? authState.user.id : null;
                                        final isOwn = currentUserId != null && a.travelerId == currentUserId;
                                        return TravelerCard(
                                          announcement: a,
                                          index: i,
                                          isOwnAnnouncement: isOwn,
                                          onTap: isOwn
                                              ? null
                                              : () => context.push('/search/${a.id}', extra: a),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // ── Reload spinner ──
                  if (state is AnnouncementSearchLoaded && state.isReloading)
                    Positioned(
                      top: DonySpacing.md, right: DonySpacing.md,
                      child: Container(
                        key: const Key('search-reload-overlay'),
                        padding: const EdgeInsets.all(DonySpacing.sm),
                        decoration: BoxDecoration(
                          color: DonyColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2)),
                          ],
                        ),
                        child: const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(color: DonyColors.primary, strokeWidth: 2),
                        ),
                      ),
                    ),

                  // ── Error banner ──
                  if (state is AnnouncementError &&
                      state.previousResults != null &&
                      !_errorBannerDismissed)
                    Positioned(
                      key: const Key('search-error-banner'),
                      left: DonySpacing.md, right: DonySpacing.md,
                      bottom: bottomPad + DonySpacing.md,
                      child: DonyStatusBanner(
                        type: DonyStatusBannerType.error,
                        message: state.message,
                        onDismiss: () => setState(() => _errorBannerDismissed = true),
                      ),
                    ),

                  // ── FAB "Carte" ──
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    bottom: _isMapHidden ? bottomPad + DonySpacing.lg : -(DonySpacing.huge + 20),
                    left: 0, right: 0,
                    child: Center(child: _CarteFab(onTap: _showMap)),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ── FAB Carte ────────────────────────────────────────────────────────────────

class _CarteFab extends StatelessWidget {
  const _CarteFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: DonyColors.ink900,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Carte',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
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
              Icon(icon,
                  size: 14,
                  color: active
                      ? DonyColors.primary
                      : DonyColors.neutral400),
              const SizedBox(width: DonySpacing.xs),
            ],
            Text(
              label,
              style: tt.labelMedium?.copyWith(
                color: active
                    ? DonyColors.primary
                    : DonyColors.neutral400,
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
                    ? DonyColors.primary
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
                color: DonyColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 48, color: DonyColors.primary),
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
              style: tt.bodyMedium?.copyWith(color: DonyColors.neutral400),
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
                size: 56, color: DonyColors.neutral200),
            const SizedBox(height: DonySpacing.base),
            Text(
              'Connexion impossible',
              style: tt.headlineMedium,
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              message,
              style: tt.bodySmall?.copyWith(color: DonyColors.neutral400),
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
