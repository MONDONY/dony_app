import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// ── Static corridor data ─────────────────────────────────────────────────────

typedef _Corridor = ({String code, int travelers, bool isHot});

const List<_Corridor> _corridors = [
  (code: 'PAR → DKR', travelers: 23, isHot: true),
  (code: 'LYS → ABJ', travelers: 11, isHot: false),
  (code: 'MRS → BKO', travelers: 7, isHot: false),
  (code: 'PAR → DLA', travelers: 14, isHot: false),
];

// Couleur accent vert clair pour le texte caveat sur fond sombre
const _kGreenAccent = Color(0xFF4CAF7D);

// ── HomeScreen ───────────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final user = authState is AuthAuthenticated
            ? authState.user
            : authState is AuthProfileUpdated
                ? authState.user
                : null;

        final isTraveler = user?.roles.contains('ROLE_TRAVELER') ?? false;

        if (isTraveler) {
          return _TravelerView(displayName: user?.displayName ?? 'Voyageur');
        }
        return _SenderView(
          firstName: user?.firstName ?? user?.displayName ?? 'vous',
          displayName: user?.displayName ?? 'vous',
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SENDER VIEW
// ══════════════════════════════════════════════════════════════════════════════

class _SenderView extends StatefulWidget {
  const _SenderView({required this.firstName, required this.displayName});

  final String firstName;
  final String displayName;

  @override
  State<_SenderView> createState() => _SenderViewState();
}

class _SenderViewState extends State<_SenderView> {
  final _scroll = ScrollController();

  // Hauteur du contenu visible sous la toolbar dans le header étendu
  static const double _kContentHeight = 88.0;

  String get _initials {
    if (widget.displayName.isEmpty) return '?';
    final parts = widget.displayName
        .trim()
        .split(' ')
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return widget.displayName[0].toUpperCase();
  }

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

    // expandedHeight = zone status bar + toolbar + contenu additionnel
    final expandedHeight = topPad + 56.0 + _kContentHeight;

    // Progress 0→1 sur la plage de collapse (= _kContentHeight px)
    final offset = _scroll.hasClients
        ? _scroll.offset.clamp(0.0, double.infinity)
        : 0.0;
    final progress = (offset / _kContentHeight).clamp(0.0, 1.0);

    // Interpolation des couleurs
    final headerBg = Color.lerp(DonyColors.greenDark, DonyColors.white, progress)!;
    final iconColor = Color.lerp(DonyColors.white, DonyColors.ink900, progress)!;
    final logoColor = Color.lerp(DonyColors.white, DonyColors.ink900, progress)!;
    final avatarBg = Color.lerp(
      DonyColors.white.withValues(alpha: 0.15),
      DonyColors.green50,
      progress,
    )!;
    final avatarBorder = Color.lerp(
      DonyColors.white.withValues(alpha: 0.3),
      DonyColors.green200,
      progress,
    )!;
    final avatarTextColor =
        Color.lerp(DonyColors.white, DonyColors.green400, progress)!;

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
            // Barre persistante : logo + icônes
            title: Row(
              children: [
                Text(
                  'dony',
                  style: DonyTypography.caveat(fontSize: 26, color: logoColor),
                ),
                Text(
                  '.',
                  style: DonyTypography.caveat(
                      fontSize: 26, color: DonyColors.green400),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.notifications_outlined, color: iconColor),
                onPressed: () => context.push('/messages'),
                tooltip: 'Notifications',
              ),
              Container(
                margin: const EdgeInsets.only(right: DonySpacing.base),
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.sm,
                  vertical: DonySpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: avatarBg,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                  border: Border.all(color: avatarBorder),
                ),
                child: Text(
                  _initials,
                  style: tt.labelMedium!.copyWith(
                    color: avatarTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            // Diviseur visible seulement en mode collapsed
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Opacity(
                opacity: progress,
                child: const Divider(height: 1, color: DonyColors.grey200),
              ),
            ),
            // Zone flexible : dégradé vert + salutation + titre
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Dégradé de fond
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          DonyColors.greenDark,
                          Color(0xFF1E7A44),
                        ],
                      ),
                    ),
                  ),
                  // Cercles décoratifs semi-transparents
                  Positioned(
                    right: -40,
                    top: topPad - 30,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: DonyColors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 50,
                    top: topPad + 10,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: DonyColors.white.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
                  // Contenu textuel : salutation + accroche
                  Positioned(
                    left: DonySpacing.lg,
                    right: DonySpacing.lg,
                    // Positionné sous la toolbar
                    top: topPad + 56,
                    bottom: DonySpacing.lg,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bonjour ${widget.firstName},',
                          style: tt.bodyMedium!.copyWith(
                            color: DonyColors.white.withValues(alpha: 0.75),
                          ),
                        ).animate().fadeIn(duration: 280.ms),
                        const SizedBox(height: DonySpacing.xs),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'on envoie quoi ',
                                style: tt.headlineMedium!.copyWith(
                                  color: DonyColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: Text(
                                  "aujourd'hui",
                                  style: DonyTypography.caveat(
                                    fontSize: 22,
                                    color: _kGreenAccent,
                                  ),
                                ),
                              ),
                              TextSpan(
                                text: ' ?',
                                style: tt.headlineMedium!.copyWith(
                                  color: DonyColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 60.ms, duration: 300.ms),
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
                const _SearchFormCard()
                    .animate()
                    .fadeIn(delay: 100.ms)
                    .slideY(begin: 0.04, curve: Curves.easeOutCubic),

                const SizedBox(height: DonySpacing.base),

                DonyButton(
                  label: 'Trouver un voyageur',
                  icon: Icons.search,
                  onPressed: () => context.push('/search'),
                ).animate().fadeIn(delay: 140.ms),

                const SizedBox(height: DonySpacing.xxl),

                Row(
                  children: [
                    Text(
                      'CORRIDORS POPULAIRES',
                      style: tt.labelMedium!.copyWith(
                        color: DonyColors.grey400,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'cette semaine',
                      style: tt.bodySmall!.copyWith(color: DonyColors.grey400),
                    ),
                  ],
                ),

                const SizedBox(height: DonySpacing.md),

                const _CorridorsGrid().animate().fadeIn(delay: 180.ms),

                const SizedBox(height: DonySpacing.xl),

                const _GarantieCard().animate().fadeIn(delay: 220.ms),

                const SizedBox(height: DonySpacing.huge),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search form card ─────────────────────────────────────────────────────────

class _SearchFormCard extends StatefulWidget {
  const _SearchFormCard();

  @override
  State<_SearchFormCard> createState() => _SearchFormCardState();
}

class _SearchFormCardState extends State<_SearchFormCard> {
  String _departure = 'Paris CDG';
  String _arrival = 'Dakar DKR';

  void _swap() {
    setState(() {
      final tmp = _departure;
      _departure = _arrival;
      _arrival = tmp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.grey200),
      ),
      child: Column(
        children: [
          // Row 1: DÉPART
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DonySpacing.base, DonySpacing.base, DonySpacing.base, DonySpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DÉPART',
                        style: tt.labelSmall!.copyWith(color: DonyColors.grey400),
                      ),
                      const SizedBox(height: DonySpacing.xxs),
                      Text(
                        _departure,
                        style: tt.titleMedium!.copyWith(
                          color: DonyColors.ink900,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.swap_vert_rounded,
                      color: DonyColors.green400),
                  onPressed: _swap,
                  tooltip: 'Inverser',
                ),
              ],
            ),
          ),
          // Row 2: ARRIVÉE
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DonySpacing.base, 0, DonySpacing.base, DonySpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ARRIVÉE',
                        style: tt.labelSmall!.copyWith(color: DonyColors.grey400),
                      ),
                      const SizedBox(height: DonySpacing.xxs),
                      Text(
                        _arrival,
                        style: tt.titleMedium!.copyWith(
                          color: DonyColors.ink900,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/search'),
                  child: Text(
                    'Modifier',
                    style: tt.bodySmall!.copyWith(
                      color: DonyColors.green400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: DonyColors.grey200),
          // Row 3: Date + Poids
          Padding(
            padding: const EdgeInsets.all(DonySpacing.base),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 12, color: DonyColors.grey400),
                const SizedBox(width: DonySpacing.xs),
                Text(
                  'Cette semaine',
                  style: tt.bodySmall!.copyWith(color: DonyColors.ink900),
                ),
                const Spacer(),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: "Jusqu'à ",
                        style: tt.bodySmall!.copyWith(color: DonyColors.ink900),
                      ),
                      TextSpan(
                        text: '15',
                        style: tt.titleMedium!.copyWith(
                          color: DonyColors.ink900,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: ' kg',
                        style: tt.bodySmall!.copyWith(color: DonyColors.ink900),
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

// ── Corridors grid ────────────────────────────────────────────────────────────

class _CorridorsGrid extends StatelessWidget {
  const _CorridorsGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: DonySpacing.sm,
        mainAxisSpacing: DonySpacing.sm,
        childAspectRatio: 2.2,
      ),
      itemCount: _corridors.length,
      itemBuilder: (context, i) {
        final corridor = _corridors[i];
        return _CorridorChip(corridor: corridor);
      },
    );
  }
}

class _CorridorChip extends StatelessWidget {
  const _CorridorChip({required this.corridor});

  final _Corridor corridor;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () => context.push('/search'),
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.md),
        decoration: BoxDecoration(
          color: DonyColors.white,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: DonyColors.grey200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    corridor.code,
                    style: tt.titleSmall!.copyWith(
                      color: DonyColors.ink900,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (corridor.isHot) ...[
                  const SizedBox(width: DonySpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.xs, vertical: DonySpacing.xxs),
                    decoration: BoxDecoration(
                      color: DonyColors.errorLight,
                      borderRadius: BorderRadius.circular(DonyRadius.xs),
                    ),
                    child: Text(
                      'HOT',
                      style: tt.labelSmall!.copyWith(
                        color: DonyColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: DonySpacing.xxs),
            Text(
              '${corridor.travelers} voyageurs',
              style: tt.bodySmall!.copyWith(color: DonyColors.grey400),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Garantie Dony card ────────────────────────────────────────────────────────

class _GarantieCard extends StatelessWidget {
  const _GarantieCard();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: DonyColors.grey50,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.green200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: DonyColors.green400, size: 22),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Garantie Dony',
                  style: tt.titleMedium!.copyWith(
                    color: DonyColors.ink900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: DonySpacing.xxs),
                Text(
                  "Remboursé jusqu'à 200 € si le colis n'arrive pas.",
                  style: tt.bodySmall!.copyWith(color: DonyColors.grey400),
                ),
              ],
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

    final headerBg = Color.lerp(DonyColors.greenDark, DonyColors.white, progress)!;
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
              IconButton(
                icon: Icon(Icons.notifications_outlined, color: iconColor),
                onPressed: () => context.push('/messages'),
                tooltip: 'Notifications',
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Opacity(
                opacity: progress,
                child: const Divider(height: 1, color: DonyColors.grey200),
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
                          DonyColors.greenDark,
                          Color(0xFF1E7A44),
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
                                          color: _kGreenAccent,
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
                    color: DonyColors.grey400,
                    letterSpacing: 0.8,
                  ),
                ),

                const SizedBox(height: DonySpacing.md),

                const _ActiveTripCard().animate().fadeIn(delay: 100.ms),

                const SizedBox(height: DonySpacing.xl),

                DonyButton(
                  label: 'Publier un trajet',
                  icon: Icons.send_rounded,
                  onPressed: () => context.push('/announcements/create'),
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
        color: DonyColors.greenDark,
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
        border: Border.all(color: DonyColors.grey200),
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
            style: tt.bodySmall!.copyWith(color: DonyColors.grey400),
          ),
          const SizedBox(height: DonySpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(DonyRadius.full),
            child: LinearProgressIndicator(
              value: reserved / total,
              minHeight: 6,
              color: DonyColors.green400,
              backgroundColor: DonyColors.grey200,
            ),
          ),
          const SizedBox(height: DonySpacing.xxs),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${reserved.toStringAsFixed(0)} / ${total.toStringAsFixed(0)} kg',
              style: tt.bodySmall!.copyWith(color: DonyColors.grey400),
            ),
          ),
        ],
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
        const Icon(Icons.access_time_rounded, color: DonyColors.grey400, size: 16),
        const SizedBox(width: DonySpacing.xs),
        Text(
          'Prochain payout · mer. 23/04',
          style: tt.bodyMedium!.copyWith(color: DonyColors.ink900),
        ),
        const Spacer(),
        Text(
          '248,50 €',
          style: tt.titleMedium!.copyWith(
            color: DonyColors.green400,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}