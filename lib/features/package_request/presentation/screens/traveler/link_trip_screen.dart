import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement_bottom_sheet.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
    });
    try {
      // Fetch the request to know its corridor + date window
      final request = await getIt<PackageRequestRepository>()
          .getById(widget.thread.packageRequestId);

      // Fetch all the traveler's announcements (paginated, just first page for now)
      final myTrips =
          await getIt<AnnouncementRepository>().getMyAnnouncements();

      // Filter by corridor + date window
      final dateFrom =
          request.desiredDate.subtract(Duration(days: request.dateToleranceDays));
      final dateTo =
          request.desiredDate.add(Duration(days: request.dateToleranceDays));
      final matching = myTrips.announcements.where((ann) {
        final corridorMatch = ann.departureCity.toLowerCase() ==
                request.departureCity.toLowerCase() &&
            ann.arrivalCity.toLowerCase() ==
                request.arrivalCity.toLowerCase();
        final dateMatch = !ann.departureDate.isBefore(dateFrom) &&
            !ann.departureDate.isAfter(dateTo);
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

  Future<void> _selectTrip(AnnouncementModel ann) async {
    final bloc = context.read<NegotiationBloc>();
    bloc.add(NegotiationSubmitTripRequested(
      threadId: widget.thread.id,
      travelerAnnouncementId: ann.id,
    ));
    if (mounted) context.pop();
  }

  Future<void> _createNewTrip() async {
    // Open the existing CreateAnnouncementBottomSheet. After it closes,
    // refresh our matching list — if a new matching trip exists, the user
    // can tap it to link.
    await CreateAnnouncementBottomSheet.show(context);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 20, color: kGreenPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Lier un trajet',
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreenPrimary))
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final r = _request!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kGreenPrimary, kGreenDark],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Demande acceptée à ${widget.thread.currentPriceEur.toStringAsFixed(0)} €',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 6),
                Text(
                  '${r.departureCity} → ${r.arrivalCity}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Date souhaitée ${DateFormat('d MMM yyyy', 'fr').format(r.desiredDate)} (±${r.dateToleranceDays}j)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _matchingTrips.isEmpty
                ? 'Aucun de tes trajets ne match'
                : 'Tes trajets compatibles',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kTextSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          if (_matchingTrips.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                children: [
                  const Icon(Icons.flight_outlined,
                      size: 36, color: kTextHint),
                  const SizedBox(height: 8),
                  Text(
                    'Crée un trajet correspondant à cette demande',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
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
                      onTap: () => _selectTrip(e.value),
                    )),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _createNewTrip,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Créer un nouveau trajet'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              foregroundColor: kGreenPrimary,
              side: const BorderSide(color: kGreenPrimary, width: 1.5),
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
    required this.onTap,
  });
  final AnnouncementModel announcement;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: kGreenLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flight_takeoff_rounded,
                      color: kGreenPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEE d MMM', 'fr')
                            .format(announcement.departureDate),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${announcement.availableKg} kg dispo · ${announcement.pricePerKg.toStringAsFixed(0)} €/kg',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: kTextHint),
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
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: kTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
