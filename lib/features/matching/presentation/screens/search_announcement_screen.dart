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
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

const _departureCities = ['Paris · CDG, ORY', 'Lyon · LYS', 'Marseille · MRS'];
const _arrivalCities = ['Dakar · DKR', 'Abidjan · ABJ', 'Bamako · BKO', 'Douala · DLA'];

class SearchAnnouncementScreen extends StatefulWidget {
  const SearchAnnouncementScreen({super.key});

  @override
  State<SearchAnnouncementScreen> createState() =>
      _SearchAnnouncementScreenState();
}

class _SearchAnnouncementScreenState extends State<SearchAnnouncementScreen> {
  // Filtres
  String _departureCity = _departureCities[0];
  String _arrivalCity = _arrivalCities[0];
  DateTime? _date;
  double _weightKg = 6;
  double _maxPricePerKg = 25;

  // Filtres rapides
  bool _kiloProOnly = false;
  bool _ratingFilter = false;
  bool _weekendFilter = false;
  bool _priceFilter = false;

  // État
  bool _showResults = false;

  String get _departureCityShort =>
      _departureCity.split(' ').first;
  String get _arrivalCityShort =>
      _arrivalCity.split(' ').first;

  void _search() {
    context.read<AnnouncementBloc>().add(AnnouncementSearchRequested(
      departureCity: _departureCityShort,
      arrivalCity: _arrivalCityShort,
      departureDateFrom: _date,
      minAvailableKg: _weightKg > 1 ? _weightKg : null,
      sortBy: 'date',
    ));
    setState(() => _showResults = true);
  }

  void _resetSearch() {
    setState(() => _showResults = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showResults) {
      return _ResultsView(
        departureCity: _departureCityShort,
        arrivalCity: _arrivalCityShort,
        onBack: _resetSearch,
      );
    }

    return _FilterFormView(
      departureCity: _departureCity,
      arrivalCity: _arrivalCity,
      date: _date,
      weightKg: _weightKg,
      maxPricePerKg: _maxPricePerKg,
      kiloProOnly: _kiloProOnly,
      ratingFilter: _ratingFilter,
      weekendFilter: _weekendFilter,
      priceFilter: _priceFilter,
      onDepartureChanged: (v) => setState(() => _departureCity = v),
      onArrivalChanged: (v) => setState(() => _arrivalCity = v),
      onDateChanged: (v) => setState(() => _date = v),
      onWeightChanged: (v) => setState(() => _weightKg = v),
      onMaxPriceChanged: (v) => setState(() => _maxPricePerKg = v),
      onKiloProChanged: (v) => setState(() => _kiloProOnly = v),
      onRatingChanged: (v) => setState(() => _ratingFilter = v),
      onWeekendChanged: (v) => setState(() => _weekendFilter = v),
      onPriceChanged: (v) => setState(() => _priceFilter = v),
      onSearch: _search,
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
    return Scaffold(
      backgroundColor: DonyColors.grey50,
      appBar: AppBar(
        title: Text(
          'Rechercher un trajet',
          style: GoogleFonts.sora(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: DonyColors.ink900,
          ),
        ),
        backgroundColor: DonyColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 20, color: DonyColors.green400),
          onPressed: () => context.pop(),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carte départ / arrivée
            Container(
              decoration: BoxDecoration(
                color: DonyColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DonyColors.grey100),
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
                    padding: EdgeInsets.only(left: 56),
                    child: Divider(height: 1),
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
            const SizedBox(height: 16),

            // Date + Poids
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    date: date,
                    onChanged: onDateChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _WeightField(
                    weightKg: weightKg,
                    onChanged: onWeightChanged,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 60.ms),
            const SizedBox(height: 24),

            // Filtres rapides
            Text(
              'FILTRES RAPIDES',
              style: GoogleFonts.sora(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: DonyColors.grey400,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
            const SizedBox(height: 28),

            // Slider prix
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Prix max par kg',
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: DonyColors.ink900,
                  ),
                ),
                Text(
                  '${maxPricePerKg.toStringAsFixed(0)} €',
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: DonyColors.green400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: DonyColors.green400,
                inactiveTrackColor: DonyColors.green100,
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
                Text('5 €', style: GoogleFonts.sora(fontSize: 12, color: DonyColors.grey200)),
                Text('25 €', style: GoogleFonts.sora(fontSize: 12, color: DonyColors.grey200)),
              ],
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: const BoxDecoration(
          color: DonyColors.white,
          border: Border(top: BorderSide(color: DonyColors.grey100)),
        ),
        child: BlocBuilder<AnnouncementBloc, AnnouncementState>(
          builder: (context, state) {
            final isLoading = state is AnnouncementLoading;
            final count = state is AnnouncementSearchLoaded
                ? state.results.length
                : null;
            return SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : onSearch,
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        count != null
                            ? 'Voir $count trajet${count > 1 ? 's' : ''}'
                            : 'Rechercher',
                        style: GoogleFonts.sora(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DonyColors.grey50,
      appBar: AppBar(
        title: Text(
          '${widget.departureCity} → ${widget.arrivalCity}',
          style: GoogleFonts.sora(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: DonyColors.ink900,
          ),
        ),
        backgroundColor: DonyColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 20, color: DonyColors.green400),
          onPressed: widget.onBack,
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: BlocBuilder<AnnouncementBloc, AnnouncementState>(
        builder: (context, state) {
          if (state is AnnouncementLoading || state is AnnouncementInitial) {
            return const Center(
              child: CircularProgressIndicator(color: DonyColors.green400),
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              itemCount: state.results.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final announcement = state.results[i];
                final authState = context.read<AuthBloc>().state;
                final currentUserId = authState is AuthAuthenticated
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

          return const SizedBox();
        },
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
    return InkWell(
      onTap: () => _showPicker(context),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDeparture ? DonyColors.green400 : const Color(0xFFE53935),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDeparture ? 'DÉPART' : 'ARRIVÉE',
                    style: GoogleFonts.sora(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: DonyColors.grey400,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.sora(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: DonyColors.ink900,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: DonyColors.grey200),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: DonyColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: DonyColors.grey100, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(
              isDeparture ? 'Ville de départ' : 'Ville d\'arrivée',
              style: GoogleFonts.sora(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ...cities.map((city) => ListTile(
                  title: Text(
                    city,
                    style: GoogleFonts.sora(
                      fontWeight: FontWeight.w500,
                      color: value == city ? DonyColors.green400 : DonyColors.ink900,
                    ),
                  ),
                  trailing: value == city
                      ? const Icon(Icons.check_rounded, color: DonyColors.green400)
                      : null,
                  onTap: () {
                    onChanged(city);
                    Navigator.pop(context);
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
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (c, child) => Theme(
            data: Theme.of(c).copyWith(
              colorScheme:
                  const ColorScheme.light(primary: DonyColors.green400),
            ),
            child: child!,
          ),
        );
        onChanged(d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: DonyColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DonyColors.grey100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DATE',
              style: GoogleFonts.sora(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: DonyColors.grey400,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 14, color: DonyColors.green400),
                const SizedBox(width: 6),
                Text(
                  date != null
                      ? DateFormat('d MMM', 'fr').format(date!)
                      : 'Choisir',
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color:
                        date != null ? DonyColors.ink900 : DonyColors.grey200,
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
    return GestureDetector(
      onTap: () => _showWeightPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: DonyColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DonyColors.grey100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'POIDS',
              style: GoogleFonts.sora(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: DonyColors.grey400,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.scale_rounded,
                    size: 14, color: DonyColors.green400),
                const SizedBox(width: 6),
                Text(
                  '${weightKg.toStringAsFixed(0)} kg',
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: DonyColors.ink900,
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
    double localWeight = weightKg;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: DonyColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DonyColors.grey100,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Poids du colis',
                style: GoogleFonts.sora(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${localWeight.toStringAsFixed(0)}',
                    style: GoogleFonts.sora(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: DonyColors.green400,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'kg',
                      style: GoogleFonts.sora(
                        fontSize: 20,
                        color: DonyColors.grey400,
                      ),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: DonyColors.green400,
                  inactiveTrackColor: DonyColors.green100,
                  thumbColor: DonyColors.green400,
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    onChanged(localWeight);
                    Navigator.pop(ctx);
                  },
                  child: Text(
                    'Confirmer',
                    style: GoogleFonts.sora(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
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
    return GestureDetector(
      onTap: () => onChanged(!active),
      child: AnimatedContainer(
        duration: 180.ms,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? DonyColors.ink900 : DonyColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? DonyColors.ink900 : DonyColors.grey100,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.sora(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : DonyColors.ink900,
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

  String get _initials => announcement.traveler?.resolvedInitials ?? '?';

  String get _displayName => announcement.traveler?.resolvedName ?? 'Voyageur';

  @override
  Widget build(BuildContext context) {
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DonyColors.grey100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar ─────────────────────────────────────────
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [DonyColors.green400, DonyColors.green300],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _initials,
                    style: GoogleFonts.sora(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // ── Contenu ────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ligne 1 : nom (ou téléphone) + badge Kilo Pro
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _displayName,
                            style: GoogleFonts.sora(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: DonyColors.ink900,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isKiloPro)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: const Color(0xFFF59E0B)
                                      .withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              'Kilo Pro',
                              style: GoogleFonts.sora(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFB45309),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Ligne 2 : note + nombre de trajets
                    if (rating != null)
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 13, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 3),
                          Text(
                            rating.toStringAsFixed(1),
                            style: GoogleFonts.sora(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: DonyColors.ink900,
                            ),
                          ),
                          if (totalTrips != null && totalTrips > 0) ...[
                            Text(
                              ' · $totalTrips trajet${totalTrips > 1 ? 's' : ''}',
                              style: GoogleFonts.sora(
                                fontSize: 12,
                                color: DonyColors.grey400,
                              ),
                            ),
                          ],
                        ],
                      ),
                    const SizedBox(height: 8),

                    // Ligne 3 : route + date
                    Row(
                      children: [
                        const Icon(Icons.flight_takeoff_rounded,
                            size: 13, color: DonyColors.green400),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '${announcement.departureCity} → ${announcement.arrivalCity}',
                            style: GoogleFonts.sora(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: DonyColors.ink900,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateStr,
                          style: GoogleFonts.sora(
                            fontSize: 11,
                            color: DonyColors.grey400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Ligne 4 : capacité + prix + bouton
                    Row(
                      children: [
                        _Pill(
                          label:
                              '${announcement.availableKg.toStringAsFixed(0)} kg dispo',
                        ),
                        const SizedBox(width: 6),
                        _Pill(
                          label:
                              '${announcement.pricePerKg.toStringAsFixed(0)} €/kg',
                          primary: true,
                        ),
                        const Spacer(),
                        if (isOwnAnnouncement)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: DonyColors.grey50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: DonyColors.grey100),
                            ),
                            child: Text(
                              'Votre trajet',
                              style: GoogleFonts.sora(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: DonyColors.grey400,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: DonyColors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: DonyColors.green400),
                            ),
                            child: Text(
                              'Voir →',
                              style: GoogleFonts.sora(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: DonyColors.green400,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(delay: Duration(milliseconds: 60 * index)).slideY(
            begin: 0.04,
            curve: Curves.easeOutCubic,
          ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.primary = false});

  final String label;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primary ? DonyColors.green100 : DonyColors.grey50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.sora(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: primary ? DonyColors.green400 : DonyColors.grey400,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: DonyColors.green100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 48, color: DonyColors.green400),
            ),
            const SizedBox(height: 20),
            Text(
              'Aucun voyageur disponible',
              style: GoogleFonts.sora(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: DonyColors.ink900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Essayez avec d\'autres critères de recherche.',
              style: GoogleFonts.sora(
                fontSize: 14,
                color: DonyColors.grey400,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: onBack,
              child: const Text('Modifier la recherche'),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 56, color: DonyColors.grey200),
            const SizedBox(height: 16),
            Text(
              'Connexion impossible',
              style: GoogleFonts.sora(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.sora(
                fontSize: 13,
                color: DonyColors.grey400,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('Réessayer'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
