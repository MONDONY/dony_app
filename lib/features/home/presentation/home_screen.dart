import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_map_view.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:dony/features/notifications/presentation/notification_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

// ── Home-screen specific constants ────────────────────────────────────────────

enum _HomeTab { voyageurs, demandes }

typedef _CorridorOpt = ({String label, String departure, String arrival});

const _corridorOptions = <_CorridorOpt>[
  (label: 'Paris → Dakar',      departure: 'Paris · CDG, ORY', arrival: 'Dakar · DKR'),
  (label: 'Paris → Abidjan',    departure: 'Paris · CDG, ORY', arrival: 'Abidjan · ABJ'),
  (label: 'Lyon → Abidjan',     departure: 'Lyon · LYS',       arrival: 'Abidjan · ABJ'),
  (label: 'Paris → Bamako',     departure: 'Paris · CDG, ORY', arrival: 'Bamako · BKO'),
  (label: 'Paris → Douala',     departure: 'Paris · CDG, ORY', arrival: 'Douala · DLA'),
  (label: 'Marseille → Bamako', departure: 'Marseille · MRS',  arrival: 'Bamako · BKO'),
];

// Accent clair sur fond ink pour le texte de mise en valeur (compatible design system)
const _kAccentOnDark = DonyColors.blue200;

// ── HomeScreen ───────────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveRoleCubit, ActiveRole>(
      builder: (context, activeRole) {
        return BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            final user = authState is AuthAuthenticated
                ? authState.user
                : authState is AuthProfileUpdated
                    ? authState.user
                    : null;

            if (activeRole == ActiveRole.traveler) {
              return _TravelerView(displayName: user?.displayName ?? 'Voyageur');
            }
            return const _MapSenderView();
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MAP SENDER VIEW
// ══════════════════════════════════════════════════════════════════════════════

class _MapSenderView extends StatefulWidget {
  const _MapSenderView();

  @override
  State<_MapSenderView> createState() => _MapSenderViewState();
}

class _MapSenderViewState extends State<_MapSenderView> {
  final _sheetController = DraggableScrollableController();
  double _sheetSize = 0.45;
  bool get _isMapHidden => _sheetSize > 0.92;

  _HomeTab _tab = _HomeTab.voyageurs;
  _CorridorOpt _corridor = _corridorOptions.first;

  DateTime? _date;
  bool _kiloProOnly = false;

  bool _isNearMeActive = false;
  double? _nearMeRadiusKm;
  LatLng? _userPosition;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetSizeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _dispatchSearch());
  }

  void _onSheetSizeChanged() {
    if (!_sheetController.isAttached) return;
    final newSize = _sheetController.size;
    final wasHidden = _isMapHidden;
    _sheetSize = newSize;
    // Rebuild uniquement quand l'état caché/visible change, pas à chaque frame
    if (wasHidden != _isMapHidden) setState(() {});
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetSizeChanged);
    _sheetController.dispose();
    super.dispose();
  }

  void _dispatchSearch() {
    if (!mounted) return;
    context.read<AnnouncementBloc>().add(AnnouncementSearchRequested(
          departureCity: _corridor.departure.split(' ').first,
          arrivalCity: _corridor.arrival.split(' ').first,
          departureDateFrom: _date,
          kiloProOnly: _kiloProOnly ? true : null,
          userLat: _isNearMeActive ? _userPosition?.latitude : null,
          userLng: _isNearMeActive ? _userPosition?.longitude : null,
          radiusKm: _isNearMeActive ? _nearMeRadiusKm : null,
        ));
  }

  void _showMap() {
    _sheetController.animateTo(
      0.45,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _showFilterSheet(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HomeFilterSheet(
        corridor: _corridor,
        date: _date,
        kiloProOnly: _kiloProOnly,
        onApply: ({
          required _CorridorOpt corridor,
          required DateTime? date,
          required bool kiloProOnly,
        }) {
          setState(() {
            _corridor = corridor;
            _date = date;
            _kiloProOnly = kiloProOnly;
          });
          _dispatchSearch();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DonyColors.bgApp,
      body: BlocBuilder<AnnouncementBloc, AnnouncementState>(
        builder: (context, state) {
          final announcements = state is AnnouncementSearchLoaded
              ? state.results
              : <AnnouncementModel>[];

          return Stack(
            children: [
              Positioned.fill(
                child: AnnouncementMapView(
                  announcements:
                      _tab == _HomeTab.voyageurs ? announcements : const [],
                  isNearMeActive: _isNearMeActive,
                  activeRadiusKm: _nearMeRadiusKm,
                  userPosition: _userPosition,
                  onNearMeRequested: (lat, lng, radius) {
                    setState(() {
                      _isNearMeActive = true;
                      _nearMeRadiusKm = radius;
                      _userPosition = LatLng(lat, lng);
                    });
                    _dispatchSearch();
                  },
                  onNearMeDisabled: () {
                    setState(() {
                      _isNearMeActive = false;
                      _nearMeRadiusKm = null;
                      _userPosition = null;
                    });
                    _dispatchSearch();
                  },
                  fabBottomPadding: MediaQuery.of(context).size.height * 0.45,
                ),
              ),

              // ── Top overlay (disparaît en plein écran) ────────────────────
              Positioned(
                top: MediaQuery.of(context).padding.top + DonySpacing.sm,
                left: DonySpacing.md,
                right: DonySpacing.md,
                child: IgnorePointer(
                  ignoring: _isMapHidden,
                  child: AnimatedOpacity(
                    opacity: _isMapHidden ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CorridorBar(
                          key: const Key('corridor-bar'),
                          label: _corridor.label,
                          hasActiveFilters: _date != null || _kiloProOnly,
                          onTap: () => _showFilterSheet(context),
                        ),
                        const SizedBox(height: DonySpacing.sm),
                        Center(
                          child: _TabToggle(
                            tab: _tab,
                            voyageursCount: announcements.length,
                            onChanged: (t) => setState(() => _tab = t),
                          ),
                        ),
                        if (_date != null || _kiloProOnly) ...[
                          const SizedBox(height: DonySpacing.xs),
                          _ActiveFilterChips(
                            date: _date,
                            kiloProOnly: _kiloProOnly,
                            onRemoveDate: () {
                              setState(() => _date = null);
                              _dispatchSearch();
                            },
                            onRemoveKiloPro: () {
                              setState(() => _kiloProOnly = false);
                              _dispatchSearch();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // ── DraggableScrollableSheet ──────────────────────────────────
              DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: 0.45,
                minChildSize: 0.15,
                maxChildSize: 1.0,
                snap: true,
                snapSizes: const [0.45, 1.0],
                builder: (ctx, scrollCtrl) => _buildSheet(
                  ctx,
                  scrollCtrl,
                  announcements,
                  MediaQuery.of(context).padding.bottom,
                ),
              ),

              // ── FAB "Carte" (visible quand sheet plein écran) ─────────────
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                bottom: _isMapHidden
                    ? MediaQuery.of(context).padding.bottom + DonySpacing.lg
                    : -80,
                left: 0,
                right: 0,
                child: Center(child: _HomeCarteFab(onTap: _showMap)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSheet(
    BuildContext ctx,
    ScrollController scrollCtrl,
    List<AnnouncementModel> announcements,
    double bottomPad,
  ) {
    final tt = Theme.of(ctx).textTheme;
    final count = announcements.length;

    final statusBarHeight = MediaQuery.of(ctx).padding.top;

    return Container(
      key: const Key('home-sheet'),
      decoration: BoxDecoration(
        color: DonyColors.surface,
        borderRadius: _isMapHidden
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(DonyRadius.sheet)),
      ),
      child: Column(
        children: [
          // Padding status bar quand le sheet est en plein écran
          if (_isMapHidden) SizedBox(height: statusBarHeight),
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DonyColors.neutral200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xs,
              DonySpacing.lg,
              DonySpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tab == _HomeTab.voyageurs
                            ? 'VOYAGEURS DISPONIBLES'
                            : 'DEMANDES D\'ENVOI',
                        style: tt.labelSmall?.copyWith(
                          color: DonyColors.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _tab == _HomeTab.voyageurs
                            ? '$count résultat${count > 1 ? 's' : ''} · ${_corridor.label}'
                            : _corridor.label,
                        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                if (_tab == _HomeTab.voyageurs && count > 0)
                  GestureDetector(
                    onTap: () => _showFilterSheet(ctx),
                    child: Text(
                      'Trier',
                      style: tt.labelMedium?.copyWith(
                        color: DonyColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: DonyColors.neutral200),
          Expanded(
            child: _tab == _HomeTab.demandes
                ? CustomScrollView(
                    controller: scrollCtrl,
                    slivers: const [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _DemandesPlaceholder(),
                      ),
                    ],
                  )
                : count == 0
                    ? CustomScrollView(
                        controller: scrollCtrl,
                        slivers: [
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(
                                'Aucun voyageur sur ce corridor',
                                style: tt.bodyMedium
                                    ?.copyWith(color: DonyColors.textMuted),
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        key: const Key('home-announcements-list'),
                        controller: scrollCtrl,
                        padding: EdgeInsets.fromLTRB(
                          DonySpacing.base,
                          DonySpacing.sm,
                          DonySpacing.base,
                          bottomPad + DonySpacing.huge,
                        ),
                        itemCount: count,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: DonySpacing.md),
                        itemBuilder: (context, i) {
                          final a = announcements[i];
                          final authState = context.read<AuthBloc>().state;
                          final currentUserId = authState is AuthAuthenticated
                              ? authState.user.id
                              : null;
                          final isOwn = currentUserId != null &&
                              a.travelerId == currentUserId;
                          return TravelerCard(
                            announcement: a,
                            index: i,
                            isOwnAnnouncement: isOwn,
                            onTap: isOwn
                                ? null
                                : () => context.push(
                                      '/search/${a.id}',
                                      extra: a,
                                    ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TRAVELER VIEW
// ══════════════════════════════════════════════════════════════════════════════

class _TravelerView extends StatefulWidget {
  const _TravelerView({required this.displayName});

  final String displayName;

  @override
  State<_TravelerView> createState() => _TravelerViewState();
}

class _TravelerViewState extends State<_TravelerView> {
  final _scroll = ScrollController();

  static const double _kContentHeight = 76.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() => setState(() {});

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final topPad = MediaQuery.of(context).padding.top;

    final expandedHeight = topPad + 56.0 + _kContentHeight;

    final offset = _scroll.hasClients
        ? _scroll.offset.clamp(0.0, double.infinity)
        : 0.0;
    final progress = (offset / _kContentHeight).clamp(0.0, 1.0);

    final headerBg = Color.lerp(DonyColors.ink800, DonyColors.surface, progress)!;
    final iconColor = Color.lerp(DonyColors.white, DonyColors.ink900, progress)!;
    final titleColor = Color.lerp(
      DonyColors.white.withValues(alpha: 0.0),
      DonyColors.ink900,
      progress,
    )!;

    return Scaffold(
      backgroundColor: DonyColors.bg,
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          // ── Collapsing header ────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: expandedHeight,
            pinned: true,
            floating: false,
            backgroundColor: headerBg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            automaticallyImplyLeading: false,
            // Titre (visible seulement quand collapsed)
            title: Text(
              widget.displayName,
              style: tt.titleMedium!.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              BlocBuilder<NotificationBloc, NotificationState>(
                builder: (context, notifState) {
                  final unread = notifState is NotificationLoaded
                      ? notifState.unreadCount
                      : 0;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: Icon(Icons.notifications_outlined,
                            color: iconColor),
                        onPressed: () => showNotificationBottomSheet(context),
                        tooltip: 'Notifications',
                      ),
                      if (unread > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: _NotifBadge(count: unread),
                        ),
                    ],
                  );
                },
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Opacity(
                opacity: progress,
                child: const Divider(height: 1, color: DonyColors.borderDefault),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradient
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          DonyColors.ink800,
                          DonyColors.ink600,
                        ],
                      ),
                    ),
                  ),
                  // Cercle décoratif
                  Positioned(
                    right: -40,
                    top: topPad - 30,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: DonyColors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  // Profil : avatar + nom + rating
                  Positioned(
                    left: DonySpacing.lg,
                    right: DonySpacing.lg,
                    top: topPad + 56,
                    bottom: DonySpacing.md,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.displayName,
                                style: tt.headlineMedium!.copyWith(
                                  color: DonyColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ).animate().fadeIn(duration: 300.ms),
                              const SizedBox(height: DonySpacing.xxs),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded,
                                      color: DonyColors.warning, size: 14),
                                  const SizedBox(width: DonySpacing.xxs),
                                  Text(
                                    '4.9',
                                    style: tt.bodySmall!.copyWith(
                                      color: DonyColors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: DonySpacing.sm),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: DonySpacing.sm,
                                      vertical: DonySpacing.xxs,
                                    ),
                                    decoration: BoxDecoration(
                                      color: DonyColors.white
                                          .withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(DonyRadius.full),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 11,
                                          color: _kAccentOnDark,
                                        ),
                                        const SizedBox(width: DonySpacing.xxs),
                                        Text(
                                          'VTC vérifié',
                                          style: tt.labelSmall!.copyWith(
                                              color: DonyColors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ).animate().fadeIn(delay: 60.ms, duration: 280.ms),
                            ],
                          ),
                        ),
                        DonyAvatar(
                          name: widget.displayName,
                          size: DonyAvatarSize.md,
                          verified: true,
                        ).animate().fadeIn(delay: 80.ms, duration: 280.ms),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Contenu scrollable ───────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              0,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _StatsCard()
                    .animate()
                    .fadeIn(delay: 60.ms)
                    .slideY(begin: 0.03, curve: Curves.easeOutCubic),

                const SizedBox(height: DonySpacing.xxl),

                Text(
                  'MES TRAJETS ACTIFS',
                  style: tt.labelMedium!.copyWith(
                    color: DonyColors.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),

                const SizedBox(height: DonySpacing.md),

                const _ActiveTripCard().animate().fadeIn(delay: 100.ms),

                const SizedBox(height: DonySpacing.xl),

                DonyButton(
                  label: 'Publier un trajet',
                  icon: Icons.send_rounded,
                  onPressed: () => CreateAnnouncementBottomSheet.show(context),
                ).animate().fadeIn(delay: 140.ms),

                const SizedBox(height: DonySpacing.xl),

                const _PayoutFooter().animate().fadeIn(delay: 180.ms),

                const SizedBox(height: DonySpacing.huge),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats card (dark greenDark background) ────────────────────────────────────

class _StatsCard extends StatelessWidget {
  const _StatsCard();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.xl),
      decoration: BoxDecoration(
        color: DonyColors.ink800,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CE MOIS-CI',
            style: tt.labelSmall!.copyWith(
              color: DonyColors.white.withValues(alpha: 0.6),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            '248,50 €',
            style: tt.displaySmall!.copyWith(color: DonyColors.white),
          ),
          const SizedBox(height: DonySpacing.xxs),
          Text(
            '4 colis · paiement Wed',
            style: tt.bodySmall!.copyWith(
              color: DonyColors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: DonySpacing.base),
          const Row(
            children: [
              _StatPill(label: 'Trajets', value: '8'),
              SizedBox(width: DonySpacing.sm),
              _StatPill(label: 'Portés', value: '62kg'),
              SizedBox(width: DonySpacing.sm),
              _StatPill(label: 'Complétés', value: '100%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md, vertical: DonySpacing.sm),
      decoration: BoxDecoration(
        color: DonyColors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(DonyRadius.xl),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: tt.titleSmall!
                .copyWith(color: DonyColors.white, fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            style: tt.labelSmall!
                .copyWith(color: DonyColors.white.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

// ── Active trip card ──────────────────────────────────────────────────────────

class _ActiveTripCard extends StatelessWidget {
  const _ActiveTripCard();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    const double reserved = 5;
    const double total = 15;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'CDG → DSS',
                style: tt.titleLarge!.copyWith(
                  color: DonyColors.ink900,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.sm, vertical: DonySpacing.xxs),
                decoration: BoxDecoration(
                  color: DonyColors.successLight,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                ),
                child: Text(
                  'OUVERT',
                  style: tt.labelSmall!.copyWith(
                    color: DonyColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            'Ven 18 · 14h05 · 5 kg réservés',
            style: tt.bodySmall!.copyWith(color: DonyColors.textMuted),
          ),
          const SizedBox(height: DonySpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(DonyRadius.full),
            child: LinearProgressIndicator(
              value: reserved / total,
              minHeight: 6,
              color: DonyColors.primary,
              backgroundColor: DonyColors.borderDefault,
            ),
          ),
          const SizedBox(height: DonySpacing.xxs),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${reserved.toStringAsFixed(0)} / ${total.toStringAsFixed(0)} kg',
              style: tt.bodySmall!.copyWith(color: DonyColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Notification bell badge ────────────────────────────────────────────────────

class _NotifBadge extends StatelessWidget {
  final int count;
  const _NotifBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : count.toString();
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: DonyColors.error,
        borderRadius: BorderRadius.all(Radius.circular(DonyRadius.sm)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: DonyColors.white,
          height: 1.6,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Payout footer row ─────────────────────────────────────────────────────────

class _PayoutFooter extends StatelessWidget {
  const _PayoutFooter();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        const Icon(Icons.access_time_rounded, color: DonyColors.textMuted, size: 16),
        const SizedBox(width: DonySpacing.xs),
        Text(
          'Prochain payout · mer. 23/04',
          style: tt.bodyMedium!.copyWith(color: DonyColors.ink900),
        ),
        const Spacer(),
        Text(
          '248,50 €',
          style: tt.titleMedium!.copyWith(
            color: DonyColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
// ══════════════════════════════════════════════════════════════════════════════
// MAP SENDER — sub-widgets
// ══════════════════════════════════════════════════════════════════════════════

// ── _CorridorBar ──────────────────────────────────────────────────────────────

class _CorridorBar extends StatelessWidget {
  const _CorridorBar({
    super.key,
    required this.label,
    required this.hasActiveFilters,
    required this.onTap,
  });

  final String label;
  final bool hasActiveFilters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: DonyColors.surface,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 18, color: DonyColors.textMuted),
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: Text(
                label,
                style: tt.bodyMedium?.copyWith(
                  color: DonyColors.ink900,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: hasActiveFilters ? DonyColors.primary : DonyColors.bgApp,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.tune_rounded,
                size: 18,
                color: hasActiveFilters ? DonyColors.surface : DonyColors.ink900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _TabToggle ────────────────────────────────────────────────────────────────

class _TabToggle extends StatelessWidget {
  const _TabToggle({
    required this.tab,
    required this.voyageursCount,
    required this.onChanged,
  });

  final _HomeTab tab;
  final int? voyageursCount;
  final void Function(_HomeTab) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: DonyColors.surface,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TabPill(
            label: voyageursCount != null
                ? 'Voyageurs · $voyageursCount'
                : 'Voyageurs',
            isActive: tab == _HomeTab.voyageurs,
            dotColor: DonyColors.primary,
            onTap: () => onChanged(_HomeTab.voyageurs),
          ),
          const SizedBox(width: 2),
          _TabPill(
            label: 'Demandes',
            isActive: tab == _HomeTab.demandes,
            dotColor: DonyColors.success,
            onTap: () => onChanged(_HomeTab.demandes),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.isActive,
    required this.dotColor,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final Color dotColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isActive ? DonyColors.ink900 : Colors.transparent,
          borderRadius: BorderRadius.circular(DonyRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: isActive ? DonyColors.surface : dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: DonySpacing.xs),
            Text(
              label,
              style: tt.labelMedium?.copyWith(
                color: isActive ? DonyColors.surface : DonyColors.ink900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _ActiveFilterChips ────────────────────────────────────────────────────────

class _ActiveFilterChips extends StatelessWidget {
  const _ActiveFilterChips({
    required this.date,
    required this.kiloProOnly,
    required this.onRemoveDate,
    required this.onRemoveKiloPro,
  });

  final DateTime? date;
  final bool kiloProOnly;
  final VoidCallback onRemoveDate;
  final VoidCallback onRemoveKiloPro;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DonySpacing.xs,
      children: [
        if (date != null)
          _FilterChip(
            label: DateFormat('d MMM', 'fr').format(date!),
            onRemove: onRemoveDate,
          ),
        if (kiloProOnly)
          _FilterChip(
            label: 'Kilo Pro',
            onRemove: onRemoveKiloPro,
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: DonyColors.surface,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: DonyColors.ink900,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: DonySpacing.xs),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 14, color: DonyColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── _DemandesPlaceholder ──────────────────────────────────────────────────────

class _DemandesPlaceholder extends StatelessWidget {
  const _DemandesPlaceholder();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(DonySpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: DonyColors.primarySoft,
              borderRadius: BorderRadius.circular(DonyRadius.full),
            ),
            child: const Icon(Icons.inbox_outlined, color: DonyColors.primary, size: 28),
          ),
          const SizedBox(height: DonySpacing.md),
          Text(
            'Demandes bientôt disponibles',
            style: tt.titleMedium?.copyWith(
              color: DonyColors.ink900,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            'Tu pourras bientôt consulter les demandes d\'envoi postées par les expéditeurs.',
            style: tt.bodySmall?.copyWith(color: DonyColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── _HomeCarteFab ─────────────────────────────────────────────────────────────

class _HomeCarteFab extends StatelessWidget {
  const _HomeCarteFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: DonyColors.ink900,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 16, color: Colors.white),
            const SizedBox(width: DonySpacing.xs),
            Text(
              'Carte',
              style: tt.labelMedium?.copyWith(
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

// ── _HomeFilterSheet ──────────────────────────────────────────────────────────

class _HomeFilterSheet extends StatefulWidget {
  const _HomeFilterSheet({
    required this.corridor,
    required this.date,
    required this.kiloProOnly,
    required this.onApply,
  });

  final _CorridorOpt corridor;
  final DateTime? date;
  final bool kiloProOnly;
  final void Function({
    required _CorridorOpt corridor,
    required DateTime? date,
    required bool kiloProOnly,
  }) onApply;

  @override
  State<_HomeFilterSheet> createState() => _HomeFilterSheetState();
}

class _HomeFilterSheetState extends State<_HomeFilterSheet> {
  late _CorridorOpt _corridor;
  late DateTime? _date;
  late bool _kiloProOnly;

  @override
  void initState() {
    super.initState();
    _corridor = widget.corridor;
    _date = widget.date;
    _kiloProOnly = widget.kiloProOnly;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.80,
      minChildSize: 0.50,
      maxChildSize: 0.95,
      expand: false,
      builder: (sheetCtx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: DonyColors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(DonyRadius.sheet)),
        ),
        child: Column(
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                0,
                DonySpacing.lg,
                DonySpacing.md,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Filtres',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const Divider(height: 1, color: DonyColors.neutral200),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(
                  DonySpacing.lg,
                  DonySpacing.lg,
                  DonySpacing.lg,
                  DonySpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CORRIDOR',
                      style: tt.labelMedium?.copyWith(
                        color: DonyColors.textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.sm),
                    ...List.generate(_corridorOptions.length, (i) {
                      final opt = _corridorOptions[i];
                      final isSelected = opt.label == _corridor.label;
                      return GestureDetector(
                        onTap: () => setState(() => _corridor = opt),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: DonySpacing.xs),
                          padding: const EdgeInsets.symmetric(
                            horizontal: DonySpacing.base,
                            vertical: DonySpacing.md,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? DonyColors.primarySoft
                                : DonyColors.bgApp,
                            borderRadius:
                                BorderRadius.circular(DonyRadius.card),
                            border: Border.all(
                              color: isSelected
                                  ? DonyColors.primary
                                  : DonyColors.neutral200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  opt.label,
                                  style: tt.bodyMedium?.copyWith(
                                    color: isSelected
                                        ? DonyColors.primary
                                        : DonyColors.ink900,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                  color: DonyColors.primary,
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: DonySpacing.xl),
                    Text(
                      'DATE DE DÉPART',
                      style: tt.labelMedium?.copyWith(
                        color: DonyColors.textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.sm),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                          locale: const Locale('fr'),
                        );
                        if (picked != null) {
                          setState(() => _date = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DonySpacing.base,
                          vertical: DonySpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: DonyColors.bgApp,
                          borderRadius:
                              BorderRadius.circular(DonyRadius.card),
                          border: Border.all(color: DonyColors.neutral200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                size: 16, color: DonyColors.textMuted),
                            const SizedBox(width: DonySpacing.sm),
                            Text(
                              _date != null
                                  ? DateFormat('EEE d MMM', 'fr').format(_date!)
                                  : 'Toutes les dates',
                              style: tt.bodyMedium?.copyWith(
                                color: _date != null
                                    ? DonyColors.ink900
                                    : DonyColors.textMuted,
                              ),
                            ),
                            const Spacer(),
                            if (_date != null)
                              GestureDetector(
                                onTap: () => setState(() => _date = null),
                                child: const Icon(Icons.close_rounded,
                                    size: 16, color: DonyColors.textMuted),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: DonySpacing.xl),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Kilo Pro uniquement', style: tt.titleMedium),
                      subtitle: Text(
                        'Voyageurs avec badge KYC vérifié',
                        style: tt.bodySmall
                            ?.copyWith(color: DonyColors.neutral400),
                      ),
                      value: _kiloProOnly,
                      activeThumbColor: DonyColors.primary,
                      onChanged: (v) => setState(() => _kiloProOnly = v),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.base,
                DonySpacing.lg,
                MediaQuery.of(sheetCtx).padding.bottom + DonySpacing.base,
              ),
              decoration: const BoxDecoration(
                color: DonyColors.white,
                border: Border(top: BorderSide(color: DonyColors.neutral200)),
              ),
              child: DonyButton(
                label: 'Appliquer',
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                  widget.onApply(
                    corridor: _corridor,
                    date: _date,
                    kiloProOnly: _kiloProOnly,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
