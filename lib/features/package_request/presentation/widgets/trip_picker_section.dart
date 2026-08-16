import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:dony/features/package_request/presentation/widgets/traveler/trip_tile.dart';
import 'package:flutter/material.dart';

/// Reusable trip-picking section: loads the traveler's trips, filters them
/// by corridor + date window + capacity, and lets the caller decide what
/// happens on selection or on "create a new trip" — it never navigates
/// itself. Used by `LinkTripScreen` and (task 12) `MakeOfferBottomSheet`.
class TripPickerSection extends StatefulWidget {
  const TripPickerSection({
    required this.departureCity,
    required this.arrivalCity,
    required this.desiredDate,
    required this.dateToleranceDays,
    required this.weightKg,
    required this.onSelected,
    required this.onCreateDedicated,
    this.selected,
    this.onModify,
    this.canModify,
    super.key,
  });

  final String departureCity;
  final String arrivalCity;
  final DateTime desiredDate;
  final int dateToleranceDays;
  final double weightKg;
  final void Function(AnnouncementModel) onSelected;
  final VoidCallback onCreateDedicated;
  final AnnouncementModel? selected;

  /// Optional per-trip "Modifier" action. `null` hides the button entirely
  /// (used by callers, e.g. the offer sheet, that don't offer inline trip
  /// editing).
  final void Function(AnnouncementModel)? onModify;

  /// Optional gate deciding whether a given trip can be modified (e.g. it
  /// needs complete pickup/delivery addresses). Ignored when [onModify] is
  /// `null`. When [onModify] is set and this is omitted, every trip is
  /// considered modifiable.
  final bool Function(AnnouncementModel)? canModify;

  @override
  State<TripPickerSection> createState() => TripPickerSectionState();
}

class TripPickerSectionState extends State<TripPickerSection> {
  final _loadingNotifier = ValueNotifier<bool>(true);
  final _errorNotifier = ValueNotifier<String?>(null);
  final _matchingTripsNotifier = ValueNotifier<List<AnnouncementModel>>(
    const [],
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TripPickerSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Le voyageur peut choisir sa date de voyage APRÈS l'ouverture de ce
    // sélecteur (ex. dans la feuille d'offre) : sans rechargement, la liste
    // resterait calculée sur la fenêtre du premier build et masquerait ou
    // proposerait à tort des trajets.
    if (oldWidget.desiredDate != widget.desiredDate ||
        oldWidget.dateToleranceDays != widget.dateToleranceDays ||
        oldWidget.departureCity != widget.departureCity ||
        oldWidget.arrivalCity != widget.arrivalCity ||
        oldWidget.weightKg != widget.weightKg) {
      _load();
    }
  }

  @override
  void dispose() {
    _loadingNotifier.dispose();
    _errorNotifier.dispose();
    _matchingTripsNotifier.dispose();
    super.dispose();
  }

  /// Public: called by parents (e.g. `LinkTripScreen`) after a trip was
  /// created/modified elsewhere, to refresh the matching list.
  Future<void> reload() => _load();

  Future<void> _load() async {
    _loadingNotifier.value = true;
    _errorNotifier.value = null;
    try {
      final myTrips = await getIt<AnnouncementRepository>()
          .getMyAnnouncements();
      String cityKey(String city) => city.split(',').first.toLowerCase().trim();
      final dateFrom = widget.desiredDate.subtract(
        Duration(days: widget.dateToleranceDays),
      );
      final dateTo = widget.desiredDate.add(
        Duration(days: widget.dateToleranceDays),
      );
      final matching = myTrips.announcements.where((ann) {
        // Seuls les trajets encore ACTIFS avec assez de capacité disponible
        // peuvent porter ce colis. Un trajet COMPLETED / IN_PROGRESS / CANCELLED
        // ou sans place ne doit jamais être proposé.
        final linkable =
            ann.status == 'ACTIVE' && ann.availableKg >= widget.weightKg;
        final corridorMatch =
            cityKey(ann.departureCity) == cityKey(widget.departureCity) &&
            cityKey(ann.arrivalCity) == cityKey(widget.arrivalCity);
        final d = ann.departureDate;
        final dateMatch =
            !DateTime(
              d.year,
              d.month,
              d.day,
            ).isBefore(DateTime(dateFrom.year, dateFrom.month, dateFrom.day)) &&
            !DateTime(
              d.year,
              d.month,
              d.day,
            ).isAfter(DateTime(dateTo.year, dateTo.month, dateTo.day));
        return linkable && corridorMatch && dateMatch;
      }).toList();
      if (mounted) {
        _matchingTripsNotifier.value = matching;
        _loadingNotifier.value = false;
      }
    } catch (e) {
      if (mounted) {
        _errorNotifier.value = e.toString();
        _loadingNotifier.value = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: _loadingNotifier,
      builder: (context, loading, _) {
        if (loading) {
          return Center(child: CircularProgressIndicator(color: cs.primary));
        }
        return ValueListenableBuilder<String?>(
          valueListenable: _errorNotifier,
          builder: (context, error, _) {
            if (error != null) {
              return Container(
                padding: const EdgeInsets.all(DonySpacing.lg),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                  border: Border.all(color: cs.outline),
                ),
                child: Column(
                  children: [
                    DonyIcon('circle-alert', size: 36, color: cs.error),
                    const SizedBox(height: DonySpacing.sm),
                    Text(
                      'Impossible de charger tes trajets',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 14,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.sm),
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              );
            }
            return _matchingTripsList(context, cs);
          },
        );
      },
    );
  }

  Widget _matchingTripsList(BuildContext context, ColorScheme cs) {
    return ValueListenableBuilder<List<AnnouncementModel>>(
      valueListenable: _matchingTripsNotifier,
      builder: (context, matchingTrips, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            matchingTrips.isEmpty
                ? 'Aucun de tes trajets ne correspond'
                : 'Tes trajets compatibles',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          if (matchingTrips.isEmpty)
            Container(
              padding: const EdgeInsets.all(DonySpacing.lg),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(DonyRadius.md),
                border: Border.all(color: cs.outline),
              ),
              child: Column(
                children: [
                  const DonyIcon('plane', size: 36, color: kTextHint),
                  const SizedBox(height: DonySpacing.sm),
                  Text(
                    'Crée un trajet correspondant à cette demande',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else
            ...matchingTrips.asMap().entries.map(
              (e) => TripTile(
                key: Key('trip-tile-${e.key}'),
                announcement: e.value,
                index: e.key,
                isSelected: widget.selected?.id == e.value.id,
                onTap: () => widget.onSelected(e.value),
                onModify:
                    widget.onModify != null &&
                        (widget.canModify?.call(e.value) ?? true)
                    ? () => widget.onModify!(e.value)
                    : null,
              ),
            ),
          const SizedBox(height: DonySpacing.base),
          OutlinedButton.icon(
            onPressed: widget.onCreateDedicated,
            icon: const DonyIcon('plus'),
            label: const Text('Créer un nouveau trajet'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              foregroundColor: cs.primary,
              side: BorderSide(color: cs.primary, width: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
