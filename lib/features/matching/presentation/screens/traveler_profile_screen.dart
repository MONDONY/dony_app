import 'dart:async';

import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/data/services/saved_trips_service.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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

  String get _initials => _announcement.traveler?.resolvedInitials ?? '?';

  String get _abbreviatedName {
    final name = _announcement.traveler?.resolvedName ?? 'Voyageur';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0]} ${parts[1][0]}.';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSaved ? 'Trajet sauvegardé' : 'Trajet retiré des sauvegardes',
            style: GoogleFonts.sora(fontWeight: FontWeight.w500),
          ),
          backgroundColor: _isSaved ? DonyColors.success : DonyColors.grey400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final traveler = _announcement.traveler;
    final isKiloPro = traveler?.kiloPro ?? false;
    final consultOnly = widget.consultOnly;

    return Scaffold(
      backgroundColor: DonyColors.grey50,
      appBar: AppBar(
        title: Text(
          'Profil voyageur',
          style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: DonyColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20, color: DonyColors.blue400),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (!consultOnly) ...[
            IconButton(
              icon: Icon(
                _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: _isSaved ? DonyColors.blue400 : DonyColors.grey400,
                size: 24,
              ),
              onPressed: _toggleSave,
              tooltip: _isSaved ? 'Retirer des sauvegardes' : 'Sauvegarder ce trajet',
            ),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded, color: DonyColors.grey400, size: 22),
              onPressed: () {}, // TODO: messagerie
              tooltip: 'Contacter',
            ),
          ],
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 28, 20, consultOnly ? 40 : 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── En-tête voyageur ────────────────────────────────────
                Column(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [DonyColors.blue600, DonyColors.blue300],
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
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _abbreviatedName,
                      style: GoogleFonts.sora(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: DonyColors.dark900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (traveler?.phoneNumber != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_rounded, size: 13, color: DonyColors.grey400),
                          const SizedBox(width: 5),
                          Text(
                            traveler!.phoneNumber!,
                            style: GoogleFonts.sora(
                              fontSize: 14,
                              color: DonyColors.grey400,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        if (isKiloPro)
                          _Badge(
                            icon: Icons.star_rounded,
                            label: 'Kilo Pro',
                            iconColor: const Color(0xFFB45309),
                            bgColor: const Color(0xFFFEF3C7),
                            textColor: const Color(0xFFB45309),
                          ),
                        _Badge(
                          icon: Icons.verified_rounded,
                          label: 'Identité vérifiée',
                          iconColor: DonyColors.blue400,
                          bgColor: DonyColors.blue100,
                          textColor: DonyColors.blue400,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    // Stats
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: DonyColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: DonyColors.grey100),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatItem(
                            value: traveler?.averageRating != null
                                ? traveler!.averageRating!.toStringAsFixed(1)
                                : '–',
                            label: 'Note',
                          ),
                          Container(width: 1, height: 36, color: DonyColors.grey100),
                          _StatItem(
                            value: traveler?.totalTrips != null
                                ? '${traveler!.totalTrips}'
                                : '–',
                            label: 'Trajets',
                          ),
                          Container(width: 1, height: 36, color: DonyColors.grey100),
                          _StatItem(
                            value: '–',
                            label: 'Livraison',
                          ),
                        ],
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 280.ms),

                const SizedBox(height: 24),

                if (!consultOnly) ...[
                  // ── Trajet proposé ─────────────────────────────────────
                  Text(
                    'Trajet proposé',
                    style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: DonyColors.dark900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _TripCard(announcement: _announcement).animate().fadeIn(delay: 80.ms),

                  const SizedBox(height: 20),

                  // ── Lieux de remise ────────────────────────────────────
                  Text(
                    'Lieux de remise',
                    style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: DonyColors.dark900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _HandoverCard(announcement: _announcement).animate().fadeIn(delay: 110.ms),

                  const SizedBox(height: 20),

                  // ── Tarif ──────────────────────────────────────────────
                  Text(
                    'Tarif',
                    style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: DonyColors.dark900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _TarifCard(announcement: _announcement).animate().fadeIn(delay: 150.ms),

                  const SizedBox(height: 20),
                ],

                // ── À propos ─────────────────────────────────────────────
                _AboutSection(announcement: _announcement)
                    .animate()
                    .fadeIn(delay: consultOnly ? 80.ms : 190.ms),

                const SizedBox(height: 20),

                // ── Avis récents ─────────────────────────────────────────
                Text(
                  'Avis récents',
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: DonyColors.dark900,
                  ),
                ),
                const SizedBox(height: 10),
                _ReviewsCard(announcement: _announcement)
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
                  20,
                  14,
                  20,
                  MediaQuery.of(context).padding.bottom + 16,
                ),
                decoration: const BoxDecoration(
                  color: DonyColors.white,
                  border: Border(top: BorderSide(color: DonyColors.grey100)),
                ),
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => context.push(
                      '/search/${_announcement.id}/bid',
                      extra: _announcement,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DonyColors.blue400,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Envoyer un colis',
                      style: GoogleFonts.sora(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
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
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color bgColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.sora(
              fontSize: 12,
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
  const _StatItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.sora(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: DonyColors.dark900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.sora(
            fontSize: 12,
            color: DonyColors.grey400,
          ),
        ),
      ],
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.announcement});
  final AnnouncementModel announcement;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DonyColors.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chip kg dispo
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: DonyColors.blue100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${announcement.availableKg.toStringAsFixed(0)} kg dispo',
                style: GoogleFonts.sora(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: DonyColors.blue400,
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
                      decoration: const BoxDecoration(
                        color: DonyColors.blue400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 2,
                          decoration: BoxDecoration(
                            color: DonyColors.grey100,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: DonyColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
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
                      ),
                      const SizedBox(height: 18),
                      _RouteStop(
                        date: announcement.departureDate,
                        time: announcement.arrivalTime,
                        city: announcement.arrivalCity,
                        location: announcement.arrivalLocation,
                        isArrival: true,
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
  });

  final DateTime date;
  final String? time;
  final String city;
  final String? location;
  final bool isArrival;

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
          style: GoogleFonts.sora(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: DonyColors.grey400,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          city,
          style: GoogleFonts.sora(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: DonyColors.dark900,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Icon(
              isArrival ? Icons.location_on_rounded : Icons.location_on_outlined,
              size: 12,
              color: hasLocation
                  ? (isArrival ? DonyColors.error : DonyColors.blue400)
                  : DonyColors.grey200,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                hasLocation ? location! : 'Lieu non précisé',
                style: GoogleFonts.sora(
                  fontSize: 12,
                  color: hasLocation ? DonyColors.grey400 : DonyColors.grey200,
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
  const _HandoverCard({required this.announcement});
  final AnnouncementModel announcement;

  @override
  Widget build(BuildContext context) {
    final depLoc = announcement.departureLocation;
    final arrLoc = announcement.arrivalLocation;
    final hasDepLoc = depLoc != null && depLoc.isNotEmpty;
    final hasArrLoc = arrLoc != null && arrLoc.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DonyColors.grey100),
      ),
      child: Column(
        children: [
          // Lieu de remise (départ)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: DonyColors.blue100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.location_on_rounded, size: 14, color: DonyColors.blue400),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lieu de remise (départ)',
                      style: GoogleFonts.sora(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: DonyColors.grey400,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasDepLoc ? depLoc : 'Non précisé par le voyageur',
                      style: GoogleFonts.sora(
                        fontSize: 14,
                        fontWeight: hasDepLoc ? FontWeight.w600 : FontWeight.w400,
                        color: hasDepLoc ? DonyColors.dark900 : DonyColors.grey200,
                        fontStyle: hasDepLoc ? FontStyle.normal : FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),

          // Lieu de récupération (arrivée)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.location_on_rounded, size: 14, color: DonyColors.error),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lieu de récupération (arrivée)',
                      style: GoogleFonts.sora(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: DonyColors.grey400,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasArrLoc ? arrLoc : 'Non précisé par le voyageur',
                      style: GoogleFonts.sora(
                        fontSize: 14,
                        fontWeight: hasArrLoc ? FontWeight.w600 : FontWeight.w400,
                        color: hasArrLoc ? DonyColors.dark900 : DonyColors.grey200,
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
  const _TarifCard({required this.announcement});
  final AnnouncementModel announcement;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DonyColors.grey100),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Prix par kilo',
                style: GoogleFonts.sora(
                  fontSize: 14,
                  color: DonyColors.grey400,
                ),
              ),
              Text(
                '${announcement.pricePerKg.toStringAsFixed(0)} €/kg',
                style: GoogleFonts.sora(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: DonyColors.dark900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Capacité restante',
                style: GoogleFonts.sora(
                  fontSize: 14,
                  color: DonyColors.grey400,
                ),
              ),
              Text(
                '${announcement.availableKg.toStringAsFixed(0)} kg',
                style: GoogleFonts.sora(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: DonyColors.dark900,
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
  const _AboutSection({required this.announcement});
  final AnnouncementModel announcement;

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
    return Container(
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DonyColors.grey100),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text(
                    'À propos',
                    style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: DonyColors.dark900,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: DonyColors.grey400, size: 22),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                _bio,
                style: GoogleFonts.sora(
                  fontSize: 14,
                  color: DonyColors.grey400,
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
  const _ReviewsCard({required this.announcement});
  final AnnouncementModel announcement;

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
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DonyColors.grey100),
      ),
      child: Column(
        children: [
          for (int i = 0; i < reviews.length; i++) ...[
            _ReviewTile(review: reviews[i]),
            if (i < reviews.length - 1)
              const Padding(
                padding: EdgeInsets.only(left: 56),
                child: Divider(height: 1),
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
  const _ReviewTile({required this.review});
  final _ReviewData review;

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
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: DonyColors.blue100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                review.authorInitial,
                style: GoogleFonts.sora(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: DonyColors.blue400,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      review.authorName,
                      style: GoogleFonts.sora(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: DonyColors.dark900,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      timeLabel,
                      style: GoogleFonts.sora(
                        fontSize: 11,
                        color: DonyColors.grey200,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < review.stars
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 13,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  review.comment,
                  style: GoogleFonts.sora(
                    fontSize: 13,
                    color: DonyColors.grey400,
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

class TravelerProfileLoaderScreen extends StatefulWidget {
  final String announcementId;
  const TravelerProfileLoaderScreen({super.key, required this.announcementId});

  @override
  State<TravelerProfileLoaderScreen> createState() =>
      _TravelerProfileLoaderScreenState();
}

class _TravelerProfileLoaderScreenState
    extends State<TravelerProfileLoaderScreen> {
  AnnouncementModel? _announcement;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final a = await getIt<AnnouncementRepository>()
          .getAnnouncementDetail(widget.announcementId);
      if (mounted) setState(() => _announcement = a);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                size: 20, color: DonyColors.blue400),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Color(0xFF6B7A8D)),
              const SizedBox(height: 12),
              Text(
                'Impossible de charger le profil',
                style: GoogleFonts.sora(
                    fontSize: 15, color: const Color(0xFF6B7A8D)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _announcement = null;
                  });
                  _fetch();
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_announcement == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                size: 20, color: DonyColors.blue400),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: DonyColors.blue400),
        ),
      );
    }

    return TravelerProfileScreen(announcement: _announcement!, consultOnly: true);
  }
}

