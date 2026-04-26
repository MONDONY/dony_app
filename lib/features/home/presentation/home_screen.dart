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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AnnouncementBloc>().add(AnnouncementSearchRequested(
      sortBy: 'date',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final user = authState is AuthAuthenticated
            ? authState.user
            : authState is AuthProfileUpdated
                ? authState.user
                : null;
        final displayName = user?.displayName ?? 'vous';

        return Scaffold(
          backgroundColor: DonyColors.grey50,
          body: RefreshIndicator(
            color: DonyColors.blue400,
            onRefresh: () async {
              context
                  .read<AnnouncementBloc>()
                  .add(AnnouncementSearchRequested(sortBy: 'date'));
            },
            child: CustomScrollView(
              slivers: [
                // ── Header ────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _Header(displayName: displayName),
                ),

                // ── Barre de recherche ─────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _SearchBar(),
                  ),
                ),

                // ── Voyageurs disponibles ──────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                    child: BlocBuilder<AnnouncementBloc, AnnouncementState>(
                      builder: (context, state) {
                        final count = state is AnnouncementSearchLoaded
                            ? state.results.length
                            : 0;
                        return Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Voyageurs disponibles',
                                style: GoogleFonts.sora(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: DonyColors.dark900,
                                ),
                              ),
                            ),
                            if (count > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: DonyColors.blue100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$count trajets',
                                  style: GoogleFonts.sora(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: DonyColors.blue400,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                // ── Liste voyageurs (scroll horizontal) ───────────────
                SliverToBoxAdapter(
                  child: BlocBuilder<AnnouncementBloc, AnnouncementState>(
                    builder: (context, state) {
                      if (state is AnnouncementLoading ||
                          state is AnnouncementInitial) {
                        return const SizedBox(
                          height: 200,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: DonyColors.blue400,
                            ),
                          ),
                        );
                      }

                      if (state is AnnouncementSearchLoaded &&
                          state.results.isNotEmpty) {
                        return SizedBox(
                          height: 200,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: state.results.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, i) {
                              final announcement = state.results[i];
                              final authState = context.read<AuthBloc>().state;
                              final currentUserId = authState is AuthAuthenticated
                                  ? authState.user.id
                                  : authState is AuthProfileUpdated
                                      ? authState.user.id
                                      : null;
                              final isOwn = currentUserId != null &&
                                  announcement.travelerId == currentUserId;
                              return _TravelerCard(
                                announcement: announcement,
                                isOwnAnnouncement: isOwn,
                                onTap: isOwn
                                    ? null
                                    : () => context.push(
                                          '/search/${announcement.id}',
                                          extra: announcement,
                                        ),
                              );
                            },
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                        child: _EmptyTravelers(),
                      );
                    },
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.displayName});

  final String displayName;

  String get _firstName {
    final parts = displayName.split(' ');
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0];
    return displayName;
  }

  String get _initials {
    if (displayName.isEmpty) return '?';
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DonyColors.white,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        20,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour,',
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    color: DonyColors.grey400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _firstName,
                      style: GoogleFonts.sora(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: DonyColors.dark900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('👋', style: TextStyle(fontSize: 20)),
                  ],
                ),
              ],
            ),
          ),
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [DonyColors.blue600, DonyColors.blue400],
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
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 300.ms),
    );
  }
}

// ── Barre de recherche ───────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/search'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DonyColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DonyColors.grey100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OÙ ENVOYER ?',
                    style: GoogleFonts.sora(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: DonyColors.grey400,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Paris → Dakar · ${DateFormat('d MMM', 'fr').format(DateTime.now())}',
                    style: GoogleFonts.sora(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: DonyColors.dark900,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: DonyColors.blue400,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
    );
  }
}

// ── Carte voyageur (scroll horizontal) ──────────────────────────────────────

class _TravelerCard extends StatelessWidget {
  const _TravelerCard({
    required this.announcement,
    required this.onTap,
    this.isOwnAnnouncement = false,
  });

  final AnnouncementModel announcement;
  final VoidCallback? onTap;
  final bool isOwnAnnouncement;

  String get _initials => announcement.traveler?.resolvedInitials ?? '?';

  String get _displayName => announcement.traveler?.resolvedName ?? 'Voyageur';

  @override
  Widget build(BuildContext context) {
    final traveler = announcement.traveler;
    final rating = traveler?.averageRating;
    final trips = traveler?.totalTrips ?? 0;
    final isKiloPro = traveler?.kiloPro ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isOwnAnnouncement ? DonyColors.grey50 : DonyColors.white,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar + name + badge
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [DonyColors.blue400, DonyColors.blue300],
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
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName,
                        style: GoogleFonts.sora(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: DonyColors.dark900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isKiloPro)
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 11,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Kilo Pro',
                              style: GoogleFonts.sora(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Rating + trips
            if (rating != null)
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 13,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    rating.toStringAsFixed(1),
                    style: GoogleFonts.sora(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: DonyColors.dark900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '· $trips trajet${trips > 1 ? 's' : ''}',
                    style: GoogleFonts.sora(
                      fontSize: 12,
                      color: DonyColors.grey400,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            // Corridor
            Row(
              children: [
                const Icon(Icons.flight_takeoff_rounded,
                    size: 12, color: DonyColors.blue400),
                const SizedBox(width: 4),
                Text(
                  '${announcement.departureCity} → ${announcement.arrivalCity}',
                  style: GoogleFonts.sora(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: DonyColors.blue400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Date
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 12, color: DonyColors.grey400),
                const SizedBox(width: 4),
                Text(
                  DateFormat('EEE d MMM', 'fr').format(announcement.departureDate),
                  style: GoogleFonts.sora(
                    fontSize: 12,
                    color: DonyColors.grey400,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Capacity + price + button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${announcement.availableKg.toStringAsFixed(0)} kg dispo',
                      style: GoogleFonts.sora(
                        fontSize: 11,
                        color: DonyColors.grey400,
                      ),
                    ),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text:
                                '${announcement.pricePerKg.toStringAsFixed(0)} €',
                            style: GoogleFonts.sora(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: DonyColors.dark900,
                            ),
                          ),
                          TextSpan(
                            text: '/kg',
                            style: GoogleFonts.sora(
                              fontSize: 11,
                              color: DonyColors.grey400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isOwnAnnouncement ? DonyColors.grey100 : DonyColors.blue400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: isOwnAnnouncement
                      ? Text(
                          'Votre trajet',
                          style: GoogleFonts.sora(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: DonyColors.grey400,
                          ),
                        )
                      : Row(
                          children: [
                            Text(
                              'Voir',
                              style: GoogleFonts.sora(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                          ],
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

// ── État vide ────────────────────────────────────────────────────────────────

class _EmptyTravelers extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DonyColors.grey100),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DonyColors.blue100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.flight_takeoff_rounded,
              color: DonyColors.blue400,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Aucun voyageur disponible',
            style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: DonyColors.dark900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Revenez bientôt pour trouver un voyageur.',
            style: GoogleFonts.sora(
              fontSize: 13,
              color: DonyColors.grey400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}
