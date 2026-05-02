import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/services/saved_trips_service.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_profile_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class TravelerProfileScreen extends StatefulWidget {
  final AnnouncementModel announcement;
  final bool consultOnly;

  const TravelerProfileScreen({
    super.key,
    required this.announcement,
    this.consultOnly = false,
  });

  @override
  State<TravelerProfileScreen> createState() => _TravelerProfileScreenState();
}

class _TravelerProfileScreenState extends State<TravelerProfileScreen> {
  late bool _isSaved;
  final _savedTripsService = getIt<SavedTripsService>();

  AnnouncementModel get _a => widget.announcement;

  @override
  void initState() {
    super.initState();
    _isSaved = _savedTripsService.isSaved(_a.id);
  }

  Future<void> _toggleSave() async {
    unawaited(HapticFeedback.lightImpact());
    if (_isSaved) {
      await _savedTripsService.removeTrip(_a.id);
    } else {
      await _savedTripsService.saveTrip(_a);
    }
    setState(() => _isSaved = !_isSaved);
    if (mounted) {
      DonySnackbar.show(
        context,
        message: _isSaved ? 'Trajet sauvegardé' : 'Trajet retiré des sauvegardes',
        type: _isSaved ? DonySnackbarType.success : DonySnackbarType.info,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final acceptedTypes = _a.acceptedContentTypes ?? [];
    final refusedTypes = _a.refusedTypes ?? [];
    final description = _a.description;

    return Scaffold(
      appBar: DonyAppBar(
        title: 'Détail annonce',
        actions: widget.consultOnly
            ? null
            : [
                IconButton(
                  icon: Icon(
                    _isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: _isSaved ? cs.primary : cs.onSurfaceVariant,
                    size: 24,
                  ),
                  onPressed: _toggleSave,
                  tooltip: _isSaved ? 'Retirer' : 'Sauvegarder',
                ),
                IconButton(
                  icon: Icon(Icons.chat_bubble_outline_rounded,
                      color: cs.onSurfaceVariant, size: 22),
                  onPressed: () {},
                  tooltip: 'Contacter',
                ),
              ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              DonyLayout.hPadding(context),
              DonySpacing.xl,
              DonyLayout.hPadding(context),
              widget.consultOnly
                  ? DonySpacing.huge
                  : MediaQuery.of(context).padding.bottom + 100,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Corridor ─────────────────────────────────────────────
                _CorridorBanner(announcement: _a, cs: cs, tt: tt)
                    .animate()
                    .fadeIn(duration: 260.ms),
                const SizedBox(height: DonySpacing.xl),

                // ── Lieux de remise ──────────────────────────────────────
                _SectionTitle(label: 'Lieux de remise', tt: tt, cs: cs),
                const SizedBox(height: DonySpacing.sm),
                _HandoverCard(announcement: _a, cs: cs, tt: tt)
                    .animate()
                    .fadeIn(delay: 60.ms),
                const SizedBox(height: DonySpacing.lg),

                // ── Ce que j'accepte ─────────────────────────────────────
                if (acceptedTypes.isNotEmpty) ...[
                  _SectionTitle(label: "Ce que j'accepte", tt: tt, cs: cs),
                  const SizedBox(height: DonySpacing.sm),
                  _ContentTypesCard(
                    types: acceptedTypes,
                    chipColor: DonyColors.success,
                    cs: cs,
                    tt: tt,
                  ).animate().fadeIn(delay: 90.ms),
                  const SizedBox(height: DonySpacing.lg),
                ],

                // ── Ce que je refuse ─────────────────────────────────────
                if (refusedTypes.isNotEmpty) ...[
                  _SectionTitle(label: 'Ce que je refuse', tt: tt, cs: cs),
                  const SizedBox(height: DonySpacing.sm),
                  _ContentTypesCard(
                    types: refusedTypes,
                    chipColor: cs.error,
                    cs: cs,
                    tt: tt,
                  ).animate().fadeIn(delay: 120.ms),
                  const SizedBox(height: DonySpacing.lg),
                ],

                // ── Note du voyageur ─────────────────────────────────────
                if (description != null && description.isNotEmpty) ...[
                  _SectionTitle(label: 'Note du voyageur', tt: tt, cs: cs),
                  const SizedBox(height: DonySpacing.sm),
                  _NoteCard(note: description, cs: cs, tt: tt)
                      .animate()
                      .fadeIn(delay: 150.ms),
                  const SizedBox(height: DonySpacing.lg),
                ],

                // ── Séparateur ───────────────────────────────────────────
                Divider(color: cs.outline, height: 1),
                const SizedBox(height: DonySpacing.xl),

                // ── Le voyageur ──────────────────────────────────────────
                _SectionTitle(label: 'Le voyageur', tt: tt, cs: cs),
                const SizedBox(height: DonySpacing.sm),
                if (_a.traveler != null)
                  DonyUserCard(
                    name: _a.traveler!.resolvedName,
                    subtitle: [
                      if (_a.traveler!.totalTrips != null)
                        '${_a.traveler!.totalTrips} trajets',
                      if (_a.traveler!.phoneNumber != null)
                        _a.traveler!.phoneNumber!,
                    ].join(' · '),
                    rating: _a.traveler!.averageRating,
                    verified: true,
                    onTap: () =>
                        showTravelerProfileSheet(context, _a.traveler!),
                  ).animate().fadeIn(delay: 180.ms),
              ],
            ),
          ),

          // ── CTA fixe ────────────────────────────────────────────────
          if (!widget.consultOnly)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  DonyLayout.hPadding(context),
                  14,
                  DonyLayout.hPadding(context),
                  MediaQuery.of(context).padding.bottom + DonySpacing.base,
                ),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(top: BorderSide(color: cs.outline)),
                ),
                child: DonyButton(
                  label: 'Envoyer un colis',
                  onPressed: () => context.push(
                    '/search/${_a.id}/bid',
                    extra: _a,
                  ),
                ),
              ).animate().slideY(
                    begin: 0.5,
                    duration: 280.ms,
                    curve: Curves.easeOutCubic,
                  ),
            ),
        ],
      ),
    );
  }
}

// ─── Corridor banner ──────────────────────────────────────────────────────────

class _CorridorBanner extends StatelessWidget {
  const _CorridorBanner({
    required this.announcement,
    required this.cs,
    required this.tt,
  });

  final AnnouncementModel announcement;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final date =
        DateFormat('EEEE d MMMM yyyy', 'fr').format(announcement.departureDate);
    final hasTimes =
        announcement.departureTime != null || announcement.arrivalTime != null;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [DonyColors.blue700, cs.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DonyRadius.xl),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Corridor
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                announcement.departureCity,
                style: tt.headlineLarge?.copyWith(
                  color: cs.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: cs.onPrimary.withValues(alpha: 0.7),
                  size: 20,
                ),
              ),
              Text(
                announcement.arrivalCity,
                style: tt.headlineLarge?.copyWith(
                  color: cs.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
          // Date
          Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                color: cs.onPrimary.withValues(alpha: 0.6),
                size: 14,
              ),
              const SizedBox(width: DonySpacing.xs),
              Expanded(
                child: Text(
                  date,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
          // Flight times
          if (hasTimes) ...[
            const SizedBox(height: DonySpacing.xs),
            Row(
              children: [
                if (announcement.departureTime != null) ...[
                  Icon(
                    Icons.flight_takeoff_rounded,
                    color: cs.onPrimary.withValues(alpha: 0.6),
                    size: 13,
                  ),
                  const SizedBox(width: DonySpacing.xs),
                  Text(
                    announcement.departureTime!,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onPrimary.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (announcement.departureTime != null &&
                    announcement.arrivalTime != null)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
                    child: Text(
                      '→',
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onPrimary.withValues(alpha: 0.5)),
                    ),
                  ),
                if (announcement.arrivalTime != null) ...[
                  Icon(
                    Icons.flight_land_rounded,
                    color: cs.onPrimary.withValues(alpha: 0.6),
                    size: 13,
                  ),
                  const SizedBox(width: DonySpacing.xs),
                  Text(
                    announcement.arrivalTime!,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onPrimary.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: DonySpacing.md),
          // Capacity + price pills
          Row(
            children: [
              _StatPill(
                icon: Icons.scale_rounded,
                label:
                    '${announcement.availableKg.toStringAsFixed(0)} kg dispo',
                cs: cs,
              ),
              const SizedBox(width: DonySpacing.sm),
              _StatPill(
                icon: Icons.euro_rounded,
                label:
                    '${announcement.pricePerKg.toStringAsFixed(0)} €/kg',
                cs: cs,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.cs,
  });

  final IconData icon;
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.sm, vertical: DonySpacing.xs),
      decoration: BoxDecoration(
        color: cs.onPrimary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: cs.onPrimary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: cs.onPrimary),
          const SizedBox(width: DonySpacing.xs),
          Text(
            label,
            style: tt.labelMedium?.copyWith(
              color: cs.onPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section title ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.label,
    required this.tt,
    required this.cs,
  });

  final String label;
  final TextTheme tt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: tt.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
      ),
    );
  }
}

// ─── Content types chips ──────────────────────────────────────────────────────

class _ContentTypesCard extends StatelessWidget {
  const _ContentTypesCard({
    required this.types,
    required this.chipColor,
    required this.cs,
    required this.tt,
  });

  final List<String> types;
  final Color chipColor;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Wrap(
        spacing: DonySpacing.xs,
        runSpacing: DonySpacing.xs,
        children: types
            .map(
              (type) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.md,
                  vertical: DonySpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                  border:
                      Border.all(color: chipColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  type,
                  style: tt.bodySmall?.copyWith(
                    color: chipColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ─── Note card ────────────────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.cs,
    required this.tt,
  });

  final String note;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Text(
        note,
        style: tt.bodyMedium?.copyWith(
          color: cs.onSurface,
          height: 1.55,
        ),
      ),
    );
  }
}

// ─── Handover card ────────────────────────────────────────────────────────────

class _HandoverCard extends StatelessWidget {
  const _HandoverCard(
      {required this.announcement, required this.cs, required this.tt});

  final AnnouncementModel announcement;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final depLoc = announcement.pickupAddress?.label;
    final arrLoc = announcement.deliveryAddress?.label;
    final hasDepLoc = depLoc != null && depLoc.isNotEmpty;
    final hasArrLoc = arrLoc != null && arrLoc.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          _LocationRow(
            label: 'Lieu de remise (départ)',
            value: hasDepLoc ? depLoc : 'Non précisé par le voyageur',
            hasValue: hasDepLoc,
            icon: Icons.location_on_rounded,
            iconBg: cs.primaryContainer,
            iconColor: cs.primary,
            cs: cs,
            tt: tt,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: DonySpacing.md),
            child: Divider(height: 1),
          ),
          _LocationRow(
            label: 'Lieu de récupération (arrivée)',
            value: hasArrLoc ? arrLoc : 'Non précisé par le voyageur',
            hasValue: hasArrLoc,
            icon: Icons.location_on_rounded,
            iconBg: cs.errorContainer,
            iconColor: cs.error,
            cs: cs,
            tt: tt,
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.label,
    required this.value,
    required this.hasValue,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.cs,
    required this.tt,
  });

  final String label;
  final String value;
  final bool hasValue;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(DonySpacing.xs),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(DonyRadius.sm),
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: DonySpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: tt.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 0.3),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: tt.bodyMedium?.copyWith(
                  fontWeight:
                      hasValue ? FontWeight.w600 : FontWeight.w400,
                  color: hasValue ? cs.onSurface : cs.outline,
                  fontStyle:
                      hasValue ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Global loader ────────────────────────────────────────────────────────────

class TravelerProfileLoaderScreen extends StatelessWidget {
  final String announcementId;
  const TravelerProfileLoaderScreen(
      {super.key, required this.announcementId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AnnouncementBloc>()
        ..add(AnnouncementDetailRequested(announcementId)),
      child: BlocBuilder<AnnouncementBloc, AnnouncementState>(
        builder: (context, state) {
          if (state is AnnouncementInitial || state is AnnouncementLoading) {
            return Scaffold(
              appBar: const DonyAppBar(title: ''),
              body: Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            );
          }

          if (state is AnnouncementDetailLoaded) {
            return TravelerProfileScreen(
              announcement: state.announcement,
              consultOnly: true,
            );
          }

          final description = state is AnnouncementError
              ? state.message
              : 'Impossible de charger le détail';
          return Scaffold(
            appBar: const DonyAppBar(title: ''),
            body: DonyEmptyState(
              icon: Icons.error_outline_rounded,
              type: DonyEmptyStateType.error,
              title: 'Erreur de chargement',
              description: description,
              actionLabel: 'Réessayer',
              onAction: () => context.read<AnnouncementBloc>().add(
                    AnnouncementDetailRequested(announcementId),
                  ),
            ),
          );
        },
      ),
    );
  }
}
