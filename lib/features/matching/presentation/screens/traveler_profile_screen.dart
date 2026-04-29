import 'dart:async';

import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/services/saved_trips_service.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class TravelerProfileScreen extends StatefulWidget {
  final AnnouncementModel announcement;
  /// When true: hides trip/tarif/handover sections and the "Envoyer un colis" CTA.
  /// Used when consulting a traveler profile outside of the search flow.
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

  AnnouncementModel get _announcement => widget.announcement;

  String get _abbreviatedName {
    final name = _announcement.traveler?.resolvedName ?? 'Voyageur';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0]} ${parts[1][0]}.';
    }
    return parts[0];
  }

  @override
  void initState() {
    super.initState();
    _isSaved = _savedTripsService.isSaved(_announcement.id);
  }

  Future<void> _toggleSave() async {
    unawaited(HapticFeedback.lightImpact());
    if (_isSaved) {
      await _savedTripsService.removeTrip(_announcement.id);
    } else {
      await _savedTripsService.saveTrip(_announcement);
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
    final traveler = _announcement.traveler;
    final isKiloPro = traveler?.kiloPro ?? false;
    final consultOnly = widget.consultOnly;

    return Scaffold(
      appBar: DonyAppBar(
        title: 'Profil voyageur',
        actions: consultOnly
            ? null
            : [
                IconButton(
                  icon: Icon(
                    _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: _isSaved ? cs.primary : cs.onSurfaceVariant,
                    size: 24,
                  ),
                  onPressed: _toggleSave,
                  tooltip: _isSaved ? 'Retirer des sauvegardes' : 'Sauvegarder ce trajet',
                ),
                IconButton(
                  icon: Icon(Icons.chat_bubble_outline_rounded, color: cs.onSurfaceVariant, size: 22),
                  onPressed: () {}, // TODO: messagerie
                  tooltip: 'Contacter',
                ),
              ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              DonySpacing.lg, DonySpacing.xxl, DonySpacing.lg, consultOnly ? DonySpacing.huge : 120,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── En-tête voyageur ────────────────────────────────────
                Column(
                  children: [
                    DonyAvatar(
                      name: _announcement.traveler?.resolvedName ?? 'Voyageur',
                      size: DonyAvatarSize.xl,
                    ),
                    const SizedBox(height: DonySpacing.md),
                    Text(
                      _abbreviatedName,
                      style: tt.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (traveler?.phoneNumber != null) ...[
                      const SizedBox(height: DonySpacing.xs),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone_rounded, size: 13, color: cs.onSurfaceVariant),
                          const SizedBox(width: DonySpacing.xs),
                          Text(
                            traveler!.phoneNumber!,
                            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: DonySpacing.sm),
                    Wrap(
                      spacing: DonySpacing.sm,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        if (isKiloPro)
                          _Badge(
                            icon: Icons.star_rounded,
                            label: 'Kilo Pro',
                            iconColor: DonyColors.amberDark,
                            bgColor: DonyColors.amberLight,
                            textColor: DonyColors.amberDark,
                            tt: tt,
                          ),
                        _Badge(
                          icon: Icons.verified_rounded,
                          label: 'Identité vérifiée',
                          iconColor: cs.primary,
                          bgColor: cs.primaryContainer,
                          textColor: cs.primary,
                          tt: tt,
                        ),
                      ],
                    ),
                    const SizedBox(height: DonySpacing.xl),
                    // Stats
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: DonySpacing.base),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(DonyRadius.card),
                        border: Border.all(color: cs.outline),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatItem(
                            value: traveler?.averageRating != null
                                ? traveler!.averageRating!.toStringAsFixed(1)
                                : '–',
                            label: 'Note',
                            cs: cs,
                            tt: tt,
                          ),
                          Container(width: 1, height: 36, color: cs.outline),
                          _StatItem(
                            value: traveler?.totalTrips != null
                                ? '${traveler!.totalTrips}'
                                : '–',
                            label: 'Trajets',
                            cs: cs,
                            tt: tt,
                          ),
                          Container(width: 1, height: 36, color: cs.outline),
                          _StatItem(
                            value: '–',
                            label: 'Livraison',
                            cs: cs,
                            tt: tt,
                          ),
                        ],
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 280.ms),

                const SizedBox(height: DonySpacing.xl),

                if (!consultOnly) ...[
                  // ── Trajet proposé ─────────────────────────────────────
                  Text(
                    'Trajet proposé',
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.sm),
                  _TripCard(announcement: _announcement, cs: cs, tt: tt).animate().fadeIn(delay: 80.ms),

                  const SizedBox(height: DonySpacing.lg),

                  // ── Lieux de remise ────────────────────────────────────
                  Text(
                    'Lieux de remise',
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.sm),
                  _HandoverCard(announcement: _announcement, cs: cs, tt: tt).animate().fadeIn(delay: 110.ms),

                  const SizedBox(height: DonySpacing.lg),

                  // ── Tarif ──────────────────────────────────────────────
                  Text(
                    'Tarif',
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.sm),
                  _TarifCard(announcement: _announcement, cs: cs, tt: tt).animate().fadeIn(delay: 150.ms),

                  const SizedBox(height: DonySpacing.lg),
                ],

                // ── À propos ─────────────────────────────────────────────
                _AboutSection(announcement: _announcement, cs: cs, tt: tt)
                    .animate()
                    .fadeIn(delay: consultOnly ? 80.ms : 190.ms),

                const SizedBox(height: DonySpacing.lg),

                // ── Avis récents ─────────────────────────────────────────
                Text(
                  'Avis récents',
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                _ReviewsCard(announcement: _announcement, cs: cs, tt: tt)
                    .animate()
                    .fadeIn(delay: consultOnly ? 130.ms : 230.ms),
              ],
            ),
          ),

          // ── CTA fixe (mode recherche uniquement) ─────────────────────
          if (!consultOnly)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  DonySpacing.lg,
                  14,
                  DonySpacing.lg,
                  MediaQuery.of(context).padding.bottom + DonySpacing.base,
                ),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(top: BorderSide(color: cs.outline)),
                ),
                child: DonyButton(
                  label: 'Envoyer un colis',
                  onPressed: () => context.push(
                    '/search/${_announcement.id}/bid',
                    extra: _announcement,
                  ),
                ),
              ).animate().slideY(begin: 0.5, duration: 280.ms, curve: Curves.easeOutCubic),
            ),
        ],
      ),
    );
  }
}

// ── Composants ───────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.bgColor,
    required this.textColor,
    required this.tt,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color bgColor;
  final Color textColor;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm, vertical: DonySpacing.xs),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(DonyRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: DonySpacing.xs),
          Text(
            label,
            style: tt.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.cs,
    required this.tt,
  });

  final String value;
  final String label;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: tt.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: DonySpacing.xxs),
        Text(
          label,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.announcement, required this.cs, required this.tt});
  final AnnouncementModel announcement;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chip kg dispo
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm, vertical: DonySpacing.xs),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(DonyRadius.xl),
              ),
              child: Text(
                '${announcement.availableKg.toStringAsFixed(0)} kg dispo',
                style: tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Timeline
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ligne verticale
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 2,
                          decoration: BoxDecoration(
                            color: cs.outline,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: cs.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: DonySpacing.md),
                // Infos départ + arrivée
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RouteStop(
                        date: announcement.departureDate,
                        time: announcement.departureTime,
                        city: announcement.departureCity,
                        location: announcement.departureLocation,
                        cs: cs,
                        tt: tt,
                      ),
                      const SizedBox(height: DonySpacing.base),
                      _RouteStop(
                        date: announcement.departureDate,
                        time: announcement.arrivalTime,
                        city: announcement.arrivalCity,
                        location: announcement.arrivalLocation,
                        isArrival: true,
                        cs: cs,
                        tt: tt,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.date,
    required this.time,
    required this.city,
    this.location,
    this.isArrival = false,
    required this.cs,
    required this.tt,
  });

  final DateTime date;
  final String? time;
  final String city;
  final String? location;
  final bool isArrival;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('EEE d MMM', 'fr').format(date).toUpperCase();
    final timeLabel = time != null ? '$formattedDate · $time' : formattedDate;
    final hasLocation = location != null && location!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          timeLabel,
          style: tt.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          city,
          style: tt.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Icon(
              isArrival ? Icons.location_on_rounded : Icons.location_on_outlined,
              size: 12,
              color: hasLocation
                  ? (isArrival ? cs.error : cs.primary)
                  : cs.outline,
            ),
            const SizedBox(width: DonySpacing.xs),
            Expanded(
              child: Text(
                hasLocation ? location! : 'Lieu non précisé',
                style: tt.bodySmall?.copyWith(
                  color: hasLocation ? cs.onSurfaceVariant : cs.outline,
                  fontStyle: hasLocation ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HandoverCard extends StatelessWidget {
  const _HandoverCard({required this.announcement, required this.cs, required this.tt});
  final AnnouncementModel announcement;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final depLoc = announcement.departureLocation;
    final arrLoc = announcement.arrivalLocation;
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
          // Lieu de remise (départ)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(DonySpacing.xs),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(DonyRadius.sm),
                ),
                child: Icon(Icons.location_on_rounded, size: 14, color: cs.primary),
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lieu de remise (départ)',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasDepLoc ? depLoc : 'Non précisé par le voyageur',
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: hasDepLoc ? FontWeight.w600 : FontWeight.w400,
                        color: hasDepLoc ? cs.onSurface : cs.outline,
                        fontStyle: hasDepLoc ? FontStyle.normal : FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: DonySpacing.md),
            child: Divider(height: 1),
          ),

          // Lieu de récupération (arrivée)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(DonySpacing.xs),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(DonyRadius.sm),
                ),
                child: Icon(Icons.location_on_rounded, size: 14, color: cs.error),
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lieu de récupération (arrivée)',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasArrLoc ? arrLoc : 'Non précisé par le voyageur',
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: hasArrLoc ? FontWeight.w600 : FontWeight.w400,
                        color: hasArrLoc ? cs.onSurface : cs.outline,
                        fontStyle: hasArrLoc ? FontStyle.normal : FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TarifCard extends StatelessWidget {
  const _TarifCard({required this.announcement, required this.cs, required this.tt});
  final AnnouncementModel announcement;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base, vertical: DonySpacing.md,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Prix par kilo',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                '${announcement.pricePerKg.toStringAsFixed(0)} €/kg',
                style: tt.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.md),
          const Divider(height: 1),
          const SizedBox(height: DonySpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Capacité restante',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                '${announcement.availableKg.toStringAsFixed(0)} kg',
                style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── À propos ──────────────────────────────────────────────────────────────────

class _AboutSection extends StatefulWidget {
  const _AboutSection({required this.announcement, required this.cs, required this.tt});
  final AnnouncementModel announcement;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  State<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<_AboutSection> {
  bool _expanded = false;

  String get _bio {
    final dep = widget.announcement.departureCity;
    final arr = widget.announcement.arrivalCity;
    return 'Voyageur régulier sur la liaison $dep – $arr. '
        'Je fais ce trajet plusieurs fois par an et je prends grand soin de '
        'chaque colis confié. Disponible pour répondre à toutes vos questions '
        'avant et pendant le voyage.\n\nFrançais · Anglais';
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final tt = widget.tt;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(DonyRadius.card),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.base, vertical: DonySpacing.md,
              ),
              child: Row(
                children: [
                  Text(
                    'À propos',
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: cs.onSurfaceVariant, size: 22),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.base, 0, DonySpacing.base, DonySpacing.base,
              ),
              child: Text(
                _bio,
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.55,
                ),
              ),
            ),
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

// ── Avis récents ──────────────────────────────────────────────────────────────

class _ReviewsCard extends StatelessWidget {
  const _ReviewsCard({required this.announcement, required this.cs, required this.tt});
  final AnnouncementModel announcement;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final travelerName =
        announcement.traveler?.displayName ?? 'Ce voyageur';
    final firstName = travelerName.split(' ').first;

    final reviews = [
      _ReviewData(
        authorInitial: 'A',
        authorName: 'Aminata F.',
        stars: 5,
        comment:
            '$firstName a livré mon colis en main propre chez ma mère avec photo. Je recommande à 100 %.',
        daysAgo: 12,
      ),
      _ReviewData(
        authorInitial: 'C',
        authorName: 'Cheikh N.',
        stars: 5,
        comment:
            'Très sérieux, ponctuel et de très bon contact. Le colis est arrivé en parfait état.',
        daysAgo: 28,
      ),
      _ReviewData(
        authorInitial: 'M',
        authorName: 'Marième D.',
        stars: 4,
        comment:
            'Bonne communication tout au long du trajet. Je re-ferai appel sans hésiter.',
        daysAgo: 45,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          for (int i = 0; i < reviews.length; i++) ...[
            _ReviewTile(review: reviews[i], cs: cs, tt: tt),
            if (i < reviews.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 56),
                child: Divider(height: 1, color: cs.outline),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReviewData {
  const _ReviewData({
    required this.authorInitial,
    required this.authorName,
    required this.stars,
    required this.comment,
    required this.daysAgo,
  });
  final String authorInitial;
  final String authorName;
  final int stars;
  final String comment;
  final int daysAgo;
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review, required this.cs, required this.tt});
  final _ReviewData review;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final String timeLabel;
    if (review.daysAgo < 7) {
      timeLabel = 'Il y a ${review.daysAgo} j.';
    } else if (review.daysAgo < 30) {
      timeLabel = 'Il y a ${(review.daysAgo / 7).floor()} sem.';
    } else {
      timeLabel = 'Il y a ${(review.daysAgo / 30).floor()} mois';
    }

    return Padding(
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonyAvatar(
            name: review.authorName,
            size: DonyAvatarSize.sm,
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      review.authorName,
                      style: tt.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      timeLabel,
                      style: tt.labelSmall?.copyWith(color: cs.outline),
                    ),
                  ],
                ),
                const SizedBox(height: DonySpacing.xs),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < review.stars
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 13,
                      color: DonyColors.warning,
                    ),
                  ),
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  review.comment,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Global loader — accessible depuis n'importe quel contexte ─────────────────

class TravelerProfileLoaderScreen extends StatelessWidget {
  final String announcementId;
  const TravelerProfileLoaderScreen({super.key, required this.announcementId});

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

          // Error state
          final description = state is AnnouncementError ? state.message : 'Impossible de charger le profil';
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
