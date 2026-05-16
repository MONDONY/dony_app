import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement_bottom_sheet.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/locked_trip_context.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Screen shown to the traveler after sender accepted the offer.
/// They must pick one of their existing trips matching the corridor + date,
/// or create a new one which will be auto-linked.
class LinkTripScreen extends StatefulWidget {
  const LinkTripScreen({required this.thread, super.key});
  final NegotiationThread thread;

  @override
  State<LinkTripScreen> createState() => _LinkTripScreenState();
}

class _LinkTripScreenState extends State<LinkTripScreen> {
  PackageRequest? _request;
  List<AnnouncementModel> _matchingTrips = const [];
  AnnouncementModel? _selectedTrip;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedTrip = null;
    });
    try {
      // Fetch the request to know its corridor + date window
      final request = await getIt<PackageRequestRepository>()
          .getById(widget.thread.packageRequestId);

      // Fetch all the traveler's announcements (paginated, just first page for now)
      final myTrips =
          await getIt<AnnouncementRepository>().getMyAnnouncements();

      // Filter by corridor + date window.
      //
      // City comparison normalizes both sides to just the city name before the
      // first comma: "Paris, France" and "Paris" both normalize to "paris".
      // This handles legacy announcements stored with country suffix.
      //
      // Date window: we use desiredDate ± dateToleranceDays, which is exactly
      // the range the backend accepts in submitTrip. This ensures every trip
      // shown here will be accepted by the server (no silent 422s).
      String cityKey(String city) => city.split(',').first.toLowerCase().trim();

      final dateFrom = request.desiredDate
          .subtract(Duration(days: request.dateToleranceDays));
      final dateTo = request.desiredDate
          .add(Duration(days: request.dateToleranceDays));
      final matching = myTrips.announcements.where((ann) {
        final corridorMatch =
            cityKey(ann.departureCity) == cityKey(request.departureCity) &&
            cityKey(ann.arrivalCity) == cityKey(request.arrivalCity);
        final d = ann.departureDate;
        final dateMatch = !DateTime(d.year, d.month, d.day)
                .isBefore(DateTime(dateFrom.year, dateFrom.month, dateFrom.day)) &&
            !DateTime(d.year, d.month, d.day)
                .isAfter(DateTime(dateTo.year, dateTo.month, dateTo.day));
        return corridorMatch && dateMatch;
      }).toList();

      if (mounted) {
        setState(() {
          _request = request;
          _matchingTrips = matching;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _selectTrip(AnnouncementModel ann) {
    setState(() => _selectedTrip = ann);
  }

  Future<void> _confirmTrip() async {
    final ann = _selectedTrip;
    if (ann == null) return;
    context.read<NegotiationBloc>().add(NegotiationSubmitTripRequested(
      threadId: widget.thread.id,
      travelerAnnouncementId: ann.id,
    ));
    // Navigation handled by BlocListener on NegotiationLoaded(awaitingPayment).
  }

  Future<void> _createNewTrip() async {
    final r = _request;
    if (r == null) return;
    final lockContext = LockedTripContext(
      threadId: widget.thread.id,
      packageRequestId: r.id,
      departureCity: r.departureCity,
      arrivalCity: r.arrivalCity,
      desiredDate: r.desiredDate,
      dateToleranceDays: r.dateToleranceDays,
      weightKg: r.weightKg,
      transportMode: r.transportMode,
      agreedPriceEur: widget.thread.currentPriceEur,
    );
    await CreateAnnouncementBottomSheet.show(
      context,
      lockContext: lockContext,
      negotiationBloc: context.read<NegotiationBloc>(),
    );
    // The sheet's BlocListener pops itself on success and the screen-level
    // listener below will pop us back. If the user cancelled, we still
    // refresh the matching list.
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocListener<NegotiationBloc, NegotiationState>(
      listenWhen: (prev, curr) =>
          curr is NegotiationLoaded || curr is NegotiationError,
      listener: (context, state) {
        if (state is NegotiationLoaded &&
            state.thread.status == NegotiationThreadStatus.awaitingPayment) {
          // Trip linked successfully: leave this screen.
          if (context.canPop()) context.pop();
        } else if (state is NegotiationError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error.message),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: const DonyAppBar(title: 'Lier un trajet'),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: cs.primary))
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _load)
                : _buildBody(),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.sm,
              DonySpacing.lg,
              DonySpacing.base,
            ),
            child: DonySelectBar(
              defaultLabel: 'Sélectionner un trajet',
              confirmedLabel: 'Confirmer ce trajet',
              selectedSummary: _selectedTrip != null
                  ? '${DateFormat('EEE d MMM', 'fr').format(_selectedTrip!.departureDate)} · ${_selectedTrip!.availableKg} kg dispo'
                  : null,
              selectedCount: _selectedTrip != null ? '1 trajet' : null,
              onConfirm: _selectedTrip != null ? _confirmTrip : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final cs = Theme.of(context).colorScheme;
    final r = _request!;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.lg,
        DonySpacing.lg,
        MediaQuery.paddingOf(context).bottom + 100, // room for DonySelectBar + safe area
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(DonySpacing.base),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [DonyColors.blue500, DonyColors.blue700],
              ),
              borderRadius: BorderRadius.circular(DonyRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Demande acceptée à ${widget.thread.currentPriceEur.toStringAsFixed(0)} €',
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 6),
                Text(
                  '${r.departureCity} → ${r.arrivalCity}',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Date de voyage : ${DateFormat('d MMM yyyy', 'fr').format(widget.thread.travelerTravelDate)}',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DonySpacing.xl),
          Text(
            _matchingTrips.isEmpty
                ? 'Aucun de tes trajets ne match'
                : 'Tes trajets compatibles',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kTextSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          if (_matchingTrips.isEmpty)
            Container(
              padding: const EdgeInsets.all(DonySpacing.lg),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(DonyRadius.md),
                border: Border.all(color: cs.outline),
              ),
              child: Column(
                children: [
                  const Icon(Icons.flight_outlined,
                      size: 36, color: kTextHint),
                  const SizedBox(height: DonySpacing.sm),
                  Text(
                    'Crée un trajet correspondant à cette demande',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontSize: 14,
                      color: kTextSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._matchingTrips
                .asMap()
                .entries
                .map((e) => _TripTile(
                      announcement: e.value,
                      index: e.key,
                      isSelected: _selectedTrip?.id == e.value.id,
                      onTap: () => _selectTrip(e.value),
                    )),
          const SizedBox(height: DonySpacing.base),
          OutlinedButton.icon(
            onPressed: _createNewTrip,
            icon: const Icon(Icons.add_rounded),
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

class _TripTile extends StatelessWidget {
  const _TripTile({
    required this.announcement,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });
  final AnnouncementModel announcement;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isSelected ? cs.primaryContainer : cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DonyRadius.md),
              border: Border.all(
                color: isSelected ? cs.primary : cs.outline,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected ? cs.primary : cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSelected
                        ? Icons.check_rounded
                        : Icons.flight_takeoff_rounded,
                    color: isSelected ? cs.onPrimary : cs.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEE d MMM', 'fr')
                            .format(announcement.departureDate),
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${announcement.availableKg} kg dispo · ${announcement.pricePerKg.toStringAsFixed(0)} €/kg',
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          fontSize: 12,
                          color: kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? cs.primary : kTextHint,
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 220.ms, delay: (40 * index).ms)
        .slideY(begin: 0.04);
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
            const Icon(Icons.error_outline_rounded, size: 48, color: kError),
            const SizedBox(height: DonySpacing.base),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontSize: 14,
                color: kTextSecondary,
              ),
            ),
            const SizedBox(height: DonySpacing.base),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
