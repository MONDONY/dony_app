import 'dart:async';

import 'package:dony/app/main_shell.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/shipment_filter_cubit.dart';
import 'package:dony/features/matching/bloc/stats_period_cubit.dart';
import 'package:dony/features/matching/bloc/tools_completion_cubit.dart';
import 'package:dony/features/matching/bloc/traveler_bids_bloc.dart';
import 'package:dony/features/matching/bloc/traveler_bids_event.dart';
import 'package:dony/features/matching/bloc/traveler_bids_state.dart';
import 'package:dony/features/matching/bloc/trips_summary_cubit.dart';
import 'package:dony/features/matching/data/models/tools_completion_model.dart';
import 'package:dony/features/matching/presentation/screens/mes_colis_screen.dart';
import 'package:dony/features/matching/presentation/widgets/activites_menu_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/activity_tile.dart';
import 'package:dony/features/matching/presentation/widgets/stat_tile.dart';
import 'package:dony/features/matching/presentation/widgets/tool_key_presentation.dart';
import 'package:dony/features/matching/presentation/widgets/tool_status_badge.dart';
import 'package:dony/features/matching/presentation/widgets/tools_completion_card.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:dony/features/profile/presentation/widgets/contextual_tutorial_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

void _logEvent(String event) {
  unawaited(getIt<AnalyticsService>().logEvent(event));
}

/// Trace l'intention puis ouvre la destination. Partagé par le hub et sa
/// grille de tuiles, qui poussent tous deux des routes tracées.
void _openRoute(BuildContext context, String event, String route) {
  _logEvent(event);
  context.push(route);
}

/// Compteur « Colis en route » — partagé entre la tuile et la détection
/// d'activité, pour que les deux restent alignés sur [kEnvoisEnCours].
int envoisEnCours(BidState state) => state is BidListLoaded
    ? state.bids.where((b) => kEnvoisEnCours.contains(b.status)).length
    : 0;

/// Onglet Activités — hub unique, identique pour tous les utilisateurs.
///
/// Remplace le dispatch par rôle de l'ancien `MatchingManagementScreen` : dans
/// le modèle double rôle, chacun est à la fois expéditeur et transporteur, donc
/// les quatre domaines d'activité sont toujours visibles.
class ActivitesHubScreen extends StatelessWidget {
  const ActivitesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<TripsSummaryCubit>()),
        BlocProvider(create: (_) => getIt<ToolsCompletionCubit>()),
        // TravelerBidsBloc est désormais un singleton (partagé avec l'onglet) :
        // `.value` pour ne pas le fermer quand le hub se démonte.
        BlocProvider.value(value: getIt<TravelerBidsBloc>()),
        BlocProvider(create: (_) => getIt<BidBloc>()),
        BlocProvider(create: (_) => getIt<StatsPeriodCubit>()),
        BlocProvider.value(value: getIt<NegotiationListBloc>()),
        // Singleton partagé (volet « Envoyées » de l'écran Demandes) : sert à
        // allumer la pastille de la carte Demandes quand une demande envoyée
        // est en négociation.
        BlocProvider.value(value: getIt<PackageRequestBloc>()),
      ],
      child: const _ActivitesHubView(),
    );
  }
}

/// Variante de test : les blocs sont fournis par le contexte parent.
@visibleForTesting
class ActivitesHubScreenTesting extends StatelessWidget {
  const ActivitesHubScreenTesting({super.key});

  @override
  Widget build(BuildContext context) => const _ActivitesHubView();
}

class _ActivitesHubView extends StatefulWidget {
  const _ActivitesHubView();

  @override
  State<_ActivitesHubView> createState() => _ActivitesHubViewState();
}

class _ActivitesHubViewState extends State<_ActivitesHubView> {
  late final EnvoisRefreshNotifier _refreshNotifier;
  late bool _showIntro;
  DateTime? _lastLoadAt;

  // En dessous de ce délai, un retour sur l'onglet ne redéclenche pas les 6
  // requêtes concurrentes de _loadAll() : à chaque va-et-vient rapide entre
  // onglets, ce hub retirait tout au complet côté serveur, ce qui épuisait
  // le rate-limit nginx (burst api_general) en quelques allers-retours et
  // faisait échouer les chargements en cours. Le pull-to-refresh explicite
  // (_onRefresh) contourne volontairement ce throttle.
  static const _minReloadInterval = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    // Le shell notifie ce singleton au retour sur l'onglet (main_shell._onTap).
    _refreshNotifier = getIt<EnvoisRefreshNotifier>();
    _refreshNotifier.addListener(_onTabRefreshRequested);
    _showIntro = !_introDismissed();
    _loadAll();
  }

  /// Hive indisponible (tests, init en échec) → carte masquée : elle est un
  /// bonus d'accueil, jamais un bloqueur.
  bool _introDismissed() {
    if (!getIt.isRegistered<HiveService>()) {
      return true;
    }
    try {
      return getIt<HiveService>().userPrefs.get(
            HiveService.kHubIntroDismissed,
            defaultValue: false,
          )
          as bool;
    } catch (_) {
      return true;
    }
  }

  void _dismissIntro() {
    _logEvent(AnalyticsEvents.activitesHubIntroDismissed);
    unawaited(
      getIt<HiveService>().userPrefs.put(HiveService.kHubIntroDismissed, true),
    );
    setState(() => _showIntro = false);
  }

  @override
  void dispose() {
    _refreshNotifier.removeListener(_onTabRefreshRequested);
    super.dispose();
  }

  void _onTabRefreshRequested() {
    if (!mounted) {
      return;
    }
    final lastLoadAt = _lastLoadAt;
    if (lastLoadAt != null &&
        DateTime.now().difference(lastLoadAt) < _minReloadInterval) {
      return;
    }
    _loadAll();
  }

  void _loadAll() {
    _lastLoadAt = DateTime.now();
    final period = context.read<StatsPeriodCubit>().state;
    unawaited(context.read<TripsSummaryCubit>().load(period: period));
    context.read<TravelerBidsBloc>().add(
      const TravelerBidsRequested(force: true),
    );
    context.read<BidBloc>().add(
      const BidMyListAutoRefreshRequested(force: true),
    );
    context.read<NegotiationListBloc>().add(
      const NegotiationListFetchRequested(),
    );
    context.read<PackageRequestBloc>().add(const FetchMyRequests());
    unawaited(context.read<ToolsCompletionCubit>().load());
  }

  Future<void> _onRefresh() async {
    _loadAll();
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  void _open(String event, String route) => _openRoute(context, event, route);

  /// Feuille de menu du bouton burger. Elle est montée sur le navigateur
  /// racine et ne voit donc ni le `GoRouter` du shell ni les blocs du hub :
  /// elle rend la destination choisie, c'est ici qu'on trace et qu'on navigue.
  Future<void> _openMenu() async {
    _logEvent(AnalyticsEvents.activitesHubMenuOpened);
    final model = context.read<ToolsCompletionCubit>().state.model;
    final choice = await ActivitesMenuSheet.show(context, tools: model);
    if (choice == null || !mounted) return;
    // Un outil ouvert depuis le menu doit remonter sa jauge au retour,
    // exactement comme sa tuile.
    final isTool = ToolKey.values.any((k) => k.route == choice.route);
    if (isTool) {
      await _openTool(choice.event, choice.route);
    } else {
      _open(choice.event, choice.route);
    }
  }

  /// Ouvre une tuile-outil et attend le retour pour recharger la complétion :
  /// un destinataire ajouté doit faire passer le badge et la jauge sans
  /// quitter l'onglet.
  Future<void> _openTool(String event, String route) async {
    _logEvent(event);
    await context.push(route);
    if (!mounted) return;
    unawaited(context.read<ToolsCompletionCubit>().load());
  }

  Future<void> _onToolCta(ToolKey tool) async {
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.activitesHubToolsCtaTapped,
        properties: {'tool': tool.apiKey},
      ),
    );
    await context.push(tool.route);
    if (!mounted) return;
    unawaited(context.read<ToolsCompletionCubit>().load());
  }

  /// Badge d'une tuile-outil, ou `null` tant que la complétion n'est pas
  /// connue : ne jamais afficher « À configurer » sur un simple échec réseau.
  Widget? _toolBadge(ToolsCompletionState state, ToolKey tool, String title) {
    final model = state.model;
    if (state.status != ToolsCompletionStatus.loaded || model == null) {
      return null;
    }
    final count = model.countOf(tool);
    final ready = count > 0;
    final label = ready ? tool.badgeLabel(count) : 'À configurer';
    return ToolStatusBadge(
      ready: ready,
      label: label,
      semanticsLabel: ready ? '$title, prêt, $label' : '$title, à configurer',
    );
  }

  void _onNewRequest() {
    _logEvent(AnalyticsEvents.activitesHubRequestCreateOpened);
    // Passe d'abord par l'écran d'intro (conditions + responsabilités) ; c'est
    // lui qui applique le gate KYC et ouvre le wizard une fois vérifié.
    context.push('/parcels/send-intro');
  }

  /// Vrai dès qu'un compteur ou une statistique est non nul. Tant que tout est
  /// à zéro, la section Statistiques est masquée : « Revenus 0 € » n'apprend
  /// rien à un nouvel utilisateur et fait tableau de bord mort.
  bool _hasAnyActivity(BuildContext context) {
    final summary = context.watch<TripsSummaryCubit>().state.summary;
    final bidState = context.watch<BidBloc>().state;
    final travelerState = context.watch<TravelerBidsBloc>().state;
    final negoState = context.watch<NegotiationListBloc>().state;

    final demandes = travelerState is TravelerBidsLoaded
        ? travelerState.pendingCount
        : 0;

    return (summary?.activeTrips ?? 0) > 0 ||
        envoisEnCours(bidState) > 0 ||
        demandes > 0 ||
        negoState.activeCount > 0 ||
        (summary?.revenue ?? 0) > 0 ||
        (summary?.kgSold ?? 0) > 0 ||
        (summary?.tripsPublished ?? 0) > 0 ||
        (summary?.parcelsSent ?? 0) > 0;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final summaryState = context.watch<TripsSummaryCubit>().state;
    final period = context.watch<StatsPeriodCubit>().state;
    final toolsState = context.watch<ToolsCompletionCubit>().state;
    // Trois portes gardent la section visible en plus de l'activité détectée :
    // le chargement (pas de flash pendant un reload), et une période non par
    // défaut — sinon sélectionner « 7 jours » à zéro ferait disparaître les
    // chips, seul moyen de revenir à « 30 jours » (cul-de-sac).
    final showStats =
        _hasAnyActivity(context) ||
        summaryState.status == TripsSummaryStatus.loading ||
        period != StatsPeriod.thirtyDays;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocListener<StatsPeriodCubit, StatsPeriod>(
          listener: (context, period) {
            _logEvent(AnalyticsEvents.activitesHubStatsPeriodChanged);
            unawaited(context.read<TripsSummaryCubit>().load(period: period));
          },
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  // Aucune marge basse : la rangée de statistiques suit
                  // immédiatement, à la distance donnée par le SizedBox final.
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.lg,
                    DonySpacing.md,
                    DonySpacing.lg,
                    0,
                  ),
                  sliver: SliverList.list(
                    children: [
                      _Header(onMenu: _openMenu),
                      if (_showIntro) ...[
                        const SizedBox(height: DonySpacing.md),
                        _IntroCard(onDismiss: _dismissIntro),
                      ],
                      const SizedBox(height: DonySpacing.md),
                      const ContextualTutorialCard(
                        context: TutorialContext.activities,
                      ),
                      const SizedBox(height: DonySpacing.base),
                      _ActionRow(
                        onPublishTrip: () => _open(
                          AnalyticsEvents.activitesHubTripCreateOpened,
                          '/trips/publish-intro',
                        ),
                        onNewRequest: _onNewRequest,
                      ),
                      const SizedBox(height: DonySpacing.xl),
                      Text('En ce moment', style: tt.titleMedium),
                      const SizedBox(height: DonySpacing.md),
                      const _ActivityGrid(),
                      if (showStats) ...[
                        const SizedBox(height: DonySpacing.xl),
                        Text('Statistiques', style: tt.titleMedium),
                        const SizedBox(height: DonySpacing.md),
                        const _PeriodChips(),
                        const SizedBox(height: DonySpacing.md),
                      ],
                    ],
                  ),
                ),
                if (showStats) const SliverToBoxAdapter(child: _StatsRow()),
                SliverPadding(
                  // Le shell monte cet écran avec extendBody: true — sans
                  // cette réserve, les tuiles « Outils » passent sous la
                  // barre d'onglets.
                  padding: EdgeInsets.fromLTRB(
                    DonySpacing.lg,
                    DonySpacing.xl,
                    DonySpacing.lg,
                    MainShell.navBarContentHeight +
                        MediaQuery.paddingOf(context).bottom +
                        DonySpacing.lg,
                  ),
                  sliver: SliverList.list(
                    children: [
                      Text('Outils', style: tt.titleMedium),
                      const SizedBox(height: DonySpacing.md),
                      if (toolsState.status == ToolsCompletionStatus.loaded &&
                          toolsState.model != null) ...[
                        ToolsCompletionCard(
                          model: toolsState.model!,
                          onCtaTap: _onToolCta,
                        ),
                        const SizedBox(height: DonySpacing.md),
                      ],
                      _TileRow(
                        left: _OtherTile(
                          iconName: 'bell',
                          label: 'Mes alertes',
                          subtitle: 'Nouveaux trajets et colis',
                          color: cs.primary,
                          badge: _toolBadge(
                            toolsState,
                            ToolKey.alerts,
                            'Mes alertes',
                          ),
                          onTap: () => _openTool(
                            AnalyticsEvents.activitesHubAlertsOpened,
                            '/corridor-alerts',
                          ),
                        ),
                        right: _OtherTile(
                          iconName: 'bookmark',
                          label: 'Modèles de trajet',
                          subtitle: 'Republiez vos trajets habituels',
                          color: DonyColors.violet,
                          badge: _toolBadge(
                            toolsState,
                            ToolKey.tripTemplates,
                            'Modèles de trajet',
                          ),
                          onTap: () => _openTool(
                            AnalyticsEvents.activitesHubTemplatesOpened,
                            '/trip-templates',
                          ),
                        ),
                      ),
                      const SizedBox(height: DonySpacing.md),
                      _TileRow(
                        // La grille de prix vit ici, aux côtés des modèles de
                        // trajet : ce sont les deux réglages qu'un voyageur
                        // prépare avant de publier. Elle était rangée sous
                        // « ARGENT » dans le profil, entre le solde et les
                        // virements, alors qu'elle ne parle pas d'argent reçu
                        // mais de tarifs proposés.
                        left: _OtherTile(
                          iconName: 'layout-grid',
                          label: 'Ma grille de prix',
                          subtitle: 'Tarifs par article pour vos trajets',
                          color: cs.primary,
                          badge: _toolBadge(
                            toolsState,
                            ToolKey.priceGrid,
                            'Ma grille de prix',
                          ),
                          onTap: () => _openTool(
                            AnalyticsEvents.activitesHubPriceGridOpened,
                            '/profile/price-grid',
                          ),
                        ),
                        right: _OtherTile(
                          iconName: 'map-pin',
                          label: 'Mes adresses',
                          subtitle: 'Vos lieux d\'envoi enregistrés',
                          color: cs.secondary,
                          badge: _toolBadge(
                            toolsState,
                            ToolKey.addresses,
                            'Mes adresses',
                          ),
                          onTap: () => _openTool(
                            AnalyticsEvents.activitesHubAddressesOpened,
                            '/profile/addresses',
                          ),
                        ),
                      ),
                      const SizedBox(height: DonySpacing.md),
                      _TileRow(
                        left: _OtherTile(
                          iconName: 'contact',
                          label: 'Mes destinataires',
                          subtitle: 'Les personnes à qui vous envoyez',
                          color: DonyColors.violet,
                          badge: _toolBadge(
                            toolsState,
                            ToolKey.recipients,
                            'Mes destinataires',
                          ),
                          onTap: () => _openTool(
                            AnalyticsEvents.activitesHubRecipientsOpened,
                            '/profile/recipients',
                          ),
                        ),
                        right: _OtherTile(
                          iconName: 'chart-line',
                          label: 'Historique',
                          subtitle: 'Tout ce qui est terminé',
                          color: cs.primary,
                          onTap: () => _open(
                            AnalyticsEvents.activitesHubHistoryOpened,
                            '/profile/shipments/history',
                          ),
                        ),
                      ),
                      const SizedBox(height: DonySpacing.md),
                      _TileRow(
                        left: _OtherTile(
                          iconName: 'circle-help',
                          label: 'Aide & support',
                          subtitle: 'Une question, un souci ?',
                          color: DonyColors.amberDark,
                          onTap: () => _open(
                            AnalyticsEvents.activitesHubHelpOpened,
                            '/profile/help/faq',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.onMenu});

  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        // Le burger remplace l'ancien bouton « Suivre un colis », qui occupait
        // seul le coin de l'en-tête pour une seule route. Il est à gauche,
        // comme partout : le menu s'ouvre du même côté que son bouton, et le
        // suivi n'est plus qu'une entrée parmi d'autres dans la feuille.
        SizedBox(
          width: kDonyMinTapTarget,
          height: kDonyMinTapTarget,
          child: IconButton(
            key: const Key('hub-menu-button'),
            padding: EdgeInsets.zero,
            onPressed: onMenu,
            tooltip: 'Menu',
            icon: DonyIcon('menu', color: cs.onSurface, semanticLabel: 'Menu'),
          ),
        ),
        const SizedBox(width: DonySpacing.sm),
        Expanded(child: Text('Activités', style: tt.headlineLarge)),
      ],
    );
  }
}

// ── Carte d'introduction ─────────────────────────────────────────────────────

/// Explique le modèle double rôle une bonne fois, au premier lancement.
/// Fermée d'un X, elle ne revient jamais (flag Hive).
class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.base,
        DonySpacing.base,
        DonySpacing.sm,
        DonySpacing.base,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Envoyez ou transportez, c\'est vous qui choisissez',
                  style: tt.titleSmall?.copyWith(color: cs.onPrimaryContainer),
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  'Envoyez vos colis avec des voyageurs de confiance, ou '
                  'transportez des colis pendant vos trajets pour gagner de '
                  'l\'argent. Tout se suit depuis cet écran.',
                  style: tt.bodySmall?.copyWith(color: cs.onPrimaryContainer),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('hub-intro-dismiss'),
            onPressed: onDismiss,
            tooltip: 'Fermer',
            visualDensity: VisualDensity.compact,
            icon: DonyIcon('x', size: 16, color: cs.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}

// ── Actions ──────────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.onPublishTrip, required this.onNewRequest});

  final VoidCallback onPublishTrip;
  final VoidCallback onNewRequest;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: const Key('hub-publish-trip'),
            onPressed: onPublishTrip,
            icon: DonyIcon('send', size: 16, color: cs.onPrimary),
            label: const Text('Publier un trajet'),
          ),
        ),
        const SizedBox(width: DonySpacing.md),
        Expanded(
          // Terracotta plein sur fond clair, comme la maquette : le bouton
          // contouré par défaut du thème porte une bordure grise qui le
          // rapprochait trop du fond.
          child: OutlinedButton.icon(
            key: const Key('hub-new-request'),
            onPressed: onNewRequest,
            icon: DonyIcon('package', size: 16, color: cs.secondary),
            label: const Text('Publier un colis'),
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.secondary,
              backgroundColor: cs.secondaryContainer,
              side: BorderSide(color: cs.secondary.withValues(alpha: 0.35)),
              // Le rembourrage par défaut d'OutlinedButton.icon fait passer le
              // libellé sur deux lignes une fois la largeur partagée en deux.
              padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Grille d'activité ────────────────────────────────────────────────────────

class _ActivityGrid extends StatelessWidget {
  const _ActivityGrid();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Un BlocBuilder par tuile, pas un global : une erreur sur les statistiques
    // ne doit pas vider les trois autres compteurs.
    final trips = BlocBuilder<TripsSummaryCubit, TripsSummaryState>(
      builder: (context, state) => ActivityTile(
        key: const Key('hub-tile-trips'),
        iconName: 'plane',
        iconColor: cs.primary,
        value: state.summary?.activeTrips ?? 0,
        label: 'Trajets actifs',
        subtitle: 'Vos voyages à venir',
        emptyHint: 'Publiez un trajet',
        isLoading: state.status == TripsSummaryStatus.loading,
        hasError: state.status == TripsSummaryStatus.hidden,
        onTap: () => _openRoute(
          context,
          AnalyticsEvents.activitesHubTripsOpened,
          '/announcements/trips',
        ),
      ),
    );

    final shipments = BlocBuilder<BidBloc, BidState>(
      builder: (context, state) {
        // La tuile couvre tout le parcours expéditeur : les envois qui ont
        // trouvé leur voyageur ET les demandes encore publiées. Ce sont les
        // deux volets de « Mes colis », donc les deux moitiés d'un compteur.
        final requestState = context
            .select<PackageRequestBloc, PackageRequestState>((b) => b.state);
        final negoState = context
            .select<NegotiationListBloc, NegotiationListState>((b) => b.state);
        final negociations = negosNonLuesSurMesColis(requestState, negoState);
        final count = envoisEnCours(state) + colisPublies(requestState);
        return ActivityTile(
          key: const Key('hub-tile-shipments'),
          iconName: 'package',
          iconColor: cs.secondary,
          value: count,
          label: 'Mes colis',
          subtitle: 'Publiés, négociés, en route',
          emptyHint: 'Envoyez un colis',
          isLoading: state is BidLoading,
          hasError: state is BidError,
          // Une discussion de prix attend une décision de l'expéditeur : le
          // seul signal d'action que porte cette tuile.
          showNotificationDot: negociations > 0,
          onTap: () => _openRoute(
            context,
            AnalyticsEvents.activitesHubEnvoisOpened,
            '/envois',
          ),
        );
      },
    );

    final requests = BlocBuilder<TravelerBidsBloc, TravelerBidsState>(
      builder: (context, state) {
        final loaded = state is TravelerBidsLoaded ? state : null;
        final count = loaded?.pendingCount ?? 0;
        return ActivityTile(
          key: const Key('hub-tile-requests'),
          iconName: 'bell',
          // Ambre, pas rouge : une demande reçue est une opportunité qui
          // attend une réponse, pas une erreur — cs.error criait au problème.
          iconColor: DonyColors.amberDark,
          value: count,
          label: 'Demandes reçues',
          subtitle: 'Des colis à transporter pour vous',
          emptyHint: 'Aucune pour l\'instant',
          isLoading: state is TravelerBidsLoading,
          hasError: state is TravelerBidsError,
          showNotificationDot: count > 0,
          onTap: () => _openRoute(
            context,
            AnalyticsEvents.activitesHubDemandesOpened,
            '/demandes',
          ),
        );
      },
    );

    final negotiations = BlocBuilder<NegotiationListBloc, NegotiationListState>(
      builder: (context, state) {
        final count = state.activeCount;
        return ActivityTile(
          key: const Key('hub-tile-negotiations'),
          iconName: 'arrow-left-right',
          // Violet : la seule des quatre tuiles hors palette de marque, pour
          // séparer la négociation des trois domaines bleu/terracotta/rouge.
          iconColor: DonyColors.violet,
          value: count,
          label: 'Discussions de prix',
          subtitle: 'Proposez ou acceptez un tarif',
          emptyHint: 'Aucune en cours',
          isLoading: state.status == NegotiationListStatus.loading,
          hasError: state.status == NegotiationListStatus.error,
          showNotificationDot: count > 0,
          onTap: () => _openRoute(
            context,
            AnalyticsEvents.activitesHubNegotiationsOpened,
            '/negotiations',
          ),
        );
      },
    );

    return Column(
      children: [
        _TileRow(left: trips, right: shipments),
        const SizedBox(height: DonySpacing.md),
        _TileRow(left: requests, right: negotiations),
      ],
    );
  }
}

/// Deux tuiles de hauteur égale.
///
/// `IntrinsicHeight` est nécessaire : dans un scroll, `stretch` seul réclame
/// une hauteur infinie et fait échouer le layout.
class _TileRow extends StatelessWidget {
  const _TileRow({required this.left, this.right});

  final Widget left;

  /// Rangée impaire : la dernière tuile reste sur sa demi-largeur plutôt que
  /// de s'étirer, sinon elle se lit comme une section à part.
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: DonySpacing.md),
          Expanded(child: right ?? const SizedBox.shrink()),
        ],
      ),
    );
  }
}

// ── Statistiques ─────────────────────────────────────────────────────────────

class _PeriodChips extends StatelessWidget {
  const _PeriodChips();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StatsPeriodCubit, StatsPeriod>(
      builder: (context, selected) => Row(
        children: [
          for (final p in StatsPeriod.values) ...[
            DonyChip(
              key: Key('hub-period-${p.apiValue}'),
              label: p.label,
              selected: p == selected,
              onTap: () => context.read<StatsPeriodCubit>().select(p),
            ),
            if (p != StatsPeriod.values.last)
              const SizedBox(width: DonySpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  String _money(double v) => formatPriceActive(v);

  String _weight(double v) => '${v.toStringAsFixed(v % 1 == 0 ? 0 : 1)} kg';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocBuilder<TripsSummaryCubit, TripsSummaryState>(
      builder: (context, state) {
        final summary = state.summary;
        final loading = state.status == TripsSummaryStatus.loading;
        // Même code couleur que les tuiles d'activité : vert = gains, bleu =
        // volume, violet = trajets, terracotta = envois.
        final tiles = <Widget>[
          StatTile(
            iconName: 'euro',
            label: 'Revenus',
            value: _money(summary?.revenue ?? 0),
            color: cs.success,
            isLoading: loading,
          ),
          StatTile(
            iconName: 'scale',
            label: 'Kg vendus',
            value: _weight(summary?.kgSold ?? 0),
            color: cs.primary,
            isLoading: loading,
          ),
          // Un backend antérieur ne renvoie pas ces deux compteurs. Afficher 0
          // laisserait croire à une absence d'activité : on montre « — »,
          // comme les tuiles dont le compteur est indisponible.
          StatTile(
            iconName: 'plane',
            label: 'Trajets',
            value: summary?.tripsPublished == null
                ? '—'
                : '${summary!.tripsPublished} publiés',
            color: DonyColors.violet,
            isLoading: loading,
          ),
          StatTile(
            iconName: 'package',
            label: 'Envois',
            value: summary?.parcelsSent == null
                ? '—'
                : '${summary!.parcelsSent} envoyés',
            color: cs.secondary,
            isLoading: loading,
          ),
        ];

        return SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: DonySpacing.lg),
            itemCount: tiles.length,
            separatorBuilder: (_, _) => const SizedBox(width: DonySpacing.md),
            itemBuilder: (_, i) => tiles[i],
          ),
        );
      },
    );
  }
}

// ── Outils ───────────────────────────────────────────────────────────────────

class _OtherTile extends StatelessWidget {
  const _OtherTile({
    required this.iconName,
    required this.label,
    required this.color,
    required this.onTap,
    this.subtitle,
    this.badge,
  });

  final String iconName;
  final String label;

  /// Couleur de la catégorie : remplit la pastille d'icône (icône blanche).
  final Color color;
  final String? subtitle;

  /// Pastille d'état de l'outil, sur sa propre ligne sous l'icône. `null` pour
  /// les tuiles sans rien à remplir (Historique, Aide) ou tant que l'état est
  /// inconnu.
  final Widget? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return DonyCard(
      onTap: onTap,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DonyIconContainer(
                iconAsset: iconName,
                size: DonyIconContainerSize.sm,
                backgroundColor: color,
                iconColor: DonyColors.neutral0,
                borderRadius: DonyRadius.iconBtn,
              ),
            ],
          ),
          // La pastille prend sa propre ligne plutôt que la place restante à
          // droite de l'icône : sur un écran de 360 dp une tuile ne fait que
          // 154 px, il ne restait qu'une cinquantaine de pixels et « 4
          // destinataires » se coupait en « 4 desti… ».
          if (badge != null) ...[
            const SizedBox(height: DonySpacing.sm),
            badge!,
          ],
          const SizedBox(height: DonySpacing.xl),
          Text(
            label,
            style: tt.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: DonySpacing.xxs),
            Text(
              subtitle!,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
