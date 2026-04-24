import 'package:dony/app/theme.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// Corridors MVP
const _departureCities = ['Paris', 'Lyon', 'Marseille'];
const _arrivalCities = ['Dakar', 'Abidjan', 'Bamako', 'Douala'];
const _sortOptions = [
  ('date', 'Date de départ'),
  ('price', 'Prix au kg'),
  ('rating', 'Meilleures notes'),
];

class SearchAnnouncementScreen extends StatefulWidget {
  const SearchAnnouncementScreen({super.key});

  @override
  State<SearchAnnouncementScreen> createState() => _SearchAnnouncementScreenState();
}

class _SearchAnnouncementScreenState extends State<SearchAnnouncementScreen> {
  // Filters
  String? _departureCity;
  String? _arrivalCity;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  double _minKg = 1;
  String _sortBy = 'date';

  bool get _hasActiveFilters =>
      _departureCity != null ||
      _arrivalCity != null ||
      _dateFrom != null ||
      _dateTo != null ||
      _minKg > 1;

  @override
  void initState() {
    super.initState();
    _search();
  }

  void _search() {
    context.read<AnnouncementBloc>().add(AnnouncementSearchRequested(
      departureCity: _departureCity,
      arrivalCity: _arrivalCity,
      departureDateFrom: _dateFrom,
      departureDateTo: _dateTo,
      minAvailableKg: _minKg > 1 ? _minKg : null,
      sortBy: _sortBy,
    ));
  }

  void _resetFilters() {
    setState(() {
      _departureCity = null;
      _arrivalCity = null;
      _dateFrom = null;
      _dateTo = null;
      _minKg = 1;
    });
    _search();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: CustomScrollView(
        slivers: [
          // Large title — Apple HIG
          SliverAppBar(
            pinned: true,
            expandedHeight: 100,
            backgroundColor: kSurface,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.black12,
            forceElevated: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Text(
                'Trouver un trajet',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                ),
              ),
              expandedTitleScale: 1.4,
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
              color: kGreenPrimary,
              onPressed: () => context.pop(),
            ),
            actions: [
              if (_hasActiveFilters)
                TextButton(
                  onPressed: _resetFilters,
                  child: Text(
                    'Réinitialiser',
                    style: GoogleFonts.plusJakartaSans(
                      color: kError,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: kBorder, height: 1),
            ),
          ),

          // Sticky filter bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterBarDelegate(
              child: _FilterBar(
                departureCity: _departureCity,
                arrivalCity: _arrivalCity,
                dateFrom: _dateFrom,
                dateTo: _dateTo,
                minKg: _minKg,
                sortBy: _sortBy,
                onFilterTap: () => _showFilterSheet(),
                onSortTap: () => _showSortSheet(),
                hasActiveFilters: _hasActiveFilters,
              ),
            ),
          ),

          // Results
          BlocBuilder<AnnouncementBloc, AnnouncementState>(
            builder: (context, state) {
              if (state is AnnouncementLoading) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: kGreenPrimary)),
                );
              }

              if (state is AnnouncementError) {
                return SliverFillRemaining(child: _ErrorView(message: state.message, onRetry: _search));
              }

              if (state is AnnouncementSearchLoaded) {
                if (state.isEmpty) {
                  return SliverFillRemaining(
                    child: _EmptyView(onReset: _hasActiveFilters ? _resetFilters : null),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  sliver: SliverList.separated(
                    itemCount: state.results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _TravelerCard(
                      announcement: state.results[i],
                      index: i,
                      onTap: () => context.push(
                        '/search/${state.results[i].id}/bid',
                        extra: state.results[i],
                      ),
                    ),
                  ),
                );
              }

              return const SliverToBoxAdapter(child: SizedBox());
            },
          ),
        ],
      ),
    );
  }

  // ── Filter bottom sheet ─────────────────────────────────────────────────────

  void _showFilterSheet() {
    // Local mutable copies for the sheet
    String? dept = _departureCity;
    String? arr = _arrivalCity;
    DateTime? from = _dateFrom;
    DateTime? to = _dateTo;
    double kg = _minKg;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => _FilterSheet(
          departureCity: dept,
          arrivalCity: arr,
          dateFrom: from,
          dateTo: to,
          minKg: kg,
          onChanged: ({d, a, df, dt, mk}) {
            setSheetState(() {
              if (d != null) dept = d;
              if (a != null) arr = a;
              if (df != null) from = df;
              if (dt != null) to = dt;
              if (mk != null) kg = mk;
            });
          },
          onApply: () {
            setState(() {
              _departureCity = dept;
              _arrivalCity = arr;
              _dateFrom = from;
              _dateTo = to;
              _minKg = kg;
            });
            Navigator.pop(sheetCtx);
            _search();
          },
          onReset: () {
            setSheetState(() {
              dept = null;
              arr = null;
              from = null;
              to = null;
              kg = 1;
            });
          },
        ),
      ),
    );
  }

  // ── Sort bottom sheet ───────────────────────────────────────────────────────

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _SortSheet(
        current: _sortBy,
        onSelect: (value) {
          setState(() => _sortBy = value);
          Navigator.pop(sheetCtx);
          _search();
        },
      ),
    );
  }
}

// ── Filter bar (sticky) ─────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String? departureCity;
  final String? arrivalCity;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final double minKg;
  final String sortBy;
  final bool hasActiveFilters;
  final VoidCallback onFilterTap;
  final VoidCallback onSortTap;

  const _FilterBar({
    required this.departureCity,
    required this.arrivalCity,
    required this.dateFrom,
    required this.dateTo,
    required this.minKg,
    required this.sortBy,
    required this.hasActiveFilters,
    required this.onFilterTap,
    required this.onSortTap,
  });

  String get _corridorLabel {
    if (departureCity != null && arrivalCity != null) {
      return '$departureCity → $arrivalCity';
    }
    if (departureCity != null) return 'De $departureCity';
    if (arrivalCity != null) return 'Vers $arrivalCity';
    return 'Corridor';
  }

  String get _sortLabel =>
      _sortOptions.firstWhere((o) => o.$1 == sortBy, orElse: () => _sortOptions.first).$2;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kSurface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _FilterChip(
                  icon: Icons.tune_rounded,
                  label: 'Filtres',
                  active: hasActiveFilters,
                  onTap: onFilterTap,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  icon: Icons.flight_takeoff_rounded,
                  label: _corridorLabel,
                  active: departureCity != null || arrivalCity != null,
                  onTap: onFilterTap,
                ),
                const SizedBox(width: 8),
                if (dateFrom != null || dateTo != null)
                  _FilterChip(
                    icon: Icons.calendar_today_rounded,
                    label: dateFrom != null
                        ? '${DateFormat('dd/MM').format(dateFrom!)}${dateTo != null ? ' – ${DateFormat('dd/MM').format(dateTo!)}' : ''}'
                        : 'Dates',
                    active: true,
                    onTap: onFilterTap,
                  ),
                if (dateFrom != null || dateTo != null) const SizedBox(width: 8),
                if (minKg > 1)
                  _FilterChip(
                    icon: Icons.scale_rounded,
                    label: '≥ ${minKg.toStringAsFixed(0)} kg',
                    active: true,
                    onTap: onFilterTap,
                  ),
                if (minKg > 1) const SizedBox(width: 8),
                _FilterChip(
                  icon: Icons.sort_rounded,
                  label: _sortLabel,
                  active: false,
                  onTap: onSortTap,
                  trailingIcon: Icons.expand_more_rounded,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? trailingIcon;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? kGreenPrimary : kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? kGreenPrimary : kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? Colors.white : kTextSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : kTextPrimary,
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 2),
              Icon(trailingIcon, size: 14, color: kTextSecondary),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Traveler card ───────────────────────────────────────────────────────────

class _TravelerCard extends StatelessWidget {
  final AnnouncementModel announcement;
  final VoidCallback onTap;
  final int index;

  const _TravelerCard({
    required this.announcement,
    required this.onTap,
    required this.index,
  });

  String get _initials {
    final name = announcement.traveler?.displayName;
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final traveler = announcement.traveler;
    final rating = traveler?.averageRating;
    final trips = traveler?.totalTrips ?? 0;
    final isKiloPro = traveler?.kiloPro ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Stack(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E88E5), Color(0xFF42A5F5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _initials,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (isKiloPro)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: kSurface,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified_rounded, size: 16, color: Color(0xFFF59E0B)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Info voyageur
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                traveler?.displayName ?? 'Voyageur',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: kTextPrimary,
                                ),
                              ),
                            ),
                            if (rating != null)
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                                  const SizedBox(width: 2),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: kTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            // Corridor
                            Text(
                              '${announcement.departureCity} → ${announcement.arrivalCity}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: kGreenPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (trips > 0) ...[
                              const Icon(Icons.flight_rounded, size: 13, color: kTextHint),
                              const SizedBox(width: 3),
                              Text(
                                '$trips trajet${trips > 1 ? 's' : ''}',
                                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kTextSecondary),
                              ),
                              const SizedBox(width: 10),
                            ],
                            if (isKiloPro) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Kilo Pro',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Stats bottom row
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: kBorder)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _StatPill(
                    icon: Icons.calendar_month_rounded,
                    label: DateFormat('dd MMM', 'fr').format(announcement.departureDate),
                  ),
                  const SizedBox(width: 8),
                  _StatPill(
                    icon: Icons.scale_rounded,
                    label: '${announcement.availableKg.toStringAsFixed(1)} kg dispo',
                  ),
                  const Spacer(),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${announcement.pricePerKg.toStringAsFixed(0)} €',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: kTextPrimary,
                          ),
                        ),
                        TextSpan(
                          text: '/kg',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: kGreenPrimary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Choisir',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: Duration(milliseconds: 60 * index)).slideY(begin: 0.04, curve: Curves.easeOutCubic),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: kBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: kTextSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter sheet ────────────────────────────────────────────────────────────

class _FilterSheet extends StatelessWidget {
  final String? departureCity;
  final String? arrivalCity;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final double minKg;
  final void Function({String? d, String? a, DateTime? df, DateTime? dt, double? mk}) onChanged;
  final VoidCallback onApply;
  final VoidCallback onReset;

  const _FilterSheet({
    required this.departureCity,
    required this.arrivalCity,
    required this.dateFrom,
    required this.dateTo,
    required this.minKg,
    required this.onChanged,
    required this.onApply,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filtres',
                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              TextButton(
                onPressed: onReset,
                child: Text(
                  'Réinitialiser',
                  style: GoogleFonts.plusJakartaSans(color: kError, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Corridor
          Text('Corridor', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SheetDropdown(
                  label: 'Départ',
                  value: departureCity,
                  items: _departureCities,
                  onChanged: (v) => onChanged(d: v),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.arrow_forward_rounded, size: 16, color: kTextSecondary),
              ),
              Expanded(
                child: _SheetDropdown(
                  label: 'Arrivée',
                  value: arrivalCity,
                  items: _arrivalCities,
                  onChanged: (v) => onChanged(a: v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Dates
          Text('Plage de dates', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DateButton(
                  label: 'Du',
                  date: dateFrom,
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: dateFrom ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (c, child) => Theme(
                        data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: kGreenPrimary)),
                        child: child!,
                      ),
                    );
                    if (d != null) onChanged(df: d);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateButton(
                  label: 'Au',
                  date: dateTo,
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: dateTo ?? dateFrom ?? DateTime.now(),
                      firstDate: dateFrom ?? DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (c, child) => Theme(
                        data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: kGreenPrimary)),
                        child: child!,
                      ),
                    );
                    if (d != null) onChanged(dt: d);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Poids min
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Poids minimum', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary)),
              Text(
                '${minKg.toStringAsFixed(0)} kg',
                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: kGreenPrimary),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: kGreenPrimary,
              inactiveTrackColor: kGreenLight,
              thumbColor: kGreenPrimary,
              overlayColor: kGreenPrimary.withValues(alpha: 0.1),
              trackHeight: 4,
            ),
            child: Slider(
              value: minKg,
              min: 1,
              max: 30,
              divisions: 29,
              onChanged: (v) => onChanged(mk: v),
            ),
          ),
          const SizedBox(height: 24),

          // Apply
          ElevatedButton(
            onPressed: onApply,
            child: Text(
              'Appliquer les filtres',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sort sheet ──────────────────────────────────────────────────────────────

class _SortSheet extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelect;

  const _SortSheet({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text(
            'Trier par',
            style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          ..._sortOptions.map((option) {
            final isSelected = option.$1 == current;
            return InkWell(
              onTap: () => onSelect(option.$1),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? kGreenLight : kBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? kGreenPrimary : Colors.transparent),
                ),
                child: Row(
                  children: [
                    Text(
                      option.$2,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? kGreenPrimary : kTextPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (isSelected) const Icon(Icons.check_rounded, color: kGreenPrimary, size: 18),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final VoidCallback? onReset;
  const _EmptyView({this.onReset});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: kGreenLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded, size: 48, color: kGreenPrimary),
          ),
          const SizedBox(height: 20),
          Text(
            'Aucun voyageur disponible',
            style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: kTextPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Aucun voyageur disponible sur ce corridor pour ces dates.',
            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: kTextSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          if (onReset != null)
            OutlinedButton.icon(
              icon: const Icon(Icons.filter_alt_off_rounded),
              label: const Text('Effacer les filtres'),
              onPressed: onReset,
            ),
          const SizedBox(height: 12),
          // Placeholder V2
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_outlined, color: kTextSecondary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Créer une alerte — disponible en V2',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: kTextSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}

// ── Error view ──────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 56, color: kTextHint),
          const SizedBox(height: 16),
          Text(
            'Connexion impossible',
            style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(message, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: kTextSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            label: const Text('Réessayer'),
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _FilterBarDelegate({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  double get maxExtent => 57;
  @override
  double get minExtent => 57;
  @override
  bool shouldRebuild(_FilterBarDelegate old) => true;
}

class _SheetDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _SheetDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem(value: null, child: Text('Tous', style: GoogleFonts.plusJakartaSans(fontSize: 14))),
        ...items.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600)))),
      ],
      onChanged: onChanged,
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateButton({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: date != null ? kGreenLight : kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: date != null ? kGreenPrimary : kBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 14, color: date != null ? kGreenPrimary : kTextHint),
            const SizedBox(width: 6),
            Text(
              date != null ? DateFormat('dd/MM/yy').format(date!) : label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: date != null ? FontWeight.w600 : FontWeight.w400,
                color: date != null ? kGreenPrimary : kTextHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
