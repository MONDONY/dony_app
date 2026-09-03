import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/presentation/screens/shipment_list_screen.dart';
import 'package:dony/features/matching/presentation/widgets/activity_header_widgets.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/presentation/screens/sender/my_package_requests_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Volet affiché par [MesColisScreen].
enum MesColisTab {
  /// Envois acceptés par un voyageur — le colis a trouvé son transporteur.
  enRoute,

  /// Demandes d'envoi publiées, encore en recherche d'un voyageur.
  publies,
}

/// Écran « Mes colis » — le parcours expéditeur en une seule destination.
///
/// Les deux volets partitionnent exactement les colis de l'expéditeur :
/// « Publiés » liste les demandes encore en recherche (`isSearchRequest`, qui
/// écarte ACCEPTED et COMPLETED) et « En route » les envois qui ont trouvé
/// leur voyageur. Ce volet « Publiés » vivait auparavant derrière le toggle
/// « Envoyées » de l'écran Demandes, au milieu d'un écran voyageur ; il
/// rejoint ici la liste qui parle du même objet.
class MesColisScreen extends StatelessWidget {
  const MesColisScreen({super.key, this.initialTab = MesColisTab.enRoute});

  /// Volet ouvert à l'arrivée — permet à un appelant de viser « Publiés ».
  final MesColisTab initialTab;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // ShipmentListScreen lit le BidBloc depuis son parent et déclenche
        // lui-même son chargement : pas d'event à ajouter ici.
        BlocProvider(create: (_) => getIt<BidBloc>()),
        // Singletons partagés avec le hub Activités : `.value` (ne pas les
        // fermer au pop, la tuile « Mes colis » en dépend).
        BlocProvider.value(value: getIt<PackageRequestBloc>()),
        BlocProvider.value(value: getIt<NegotiationListBloc>()),
      ],
      child: _MesColisView(initialTab: initialTab),
    );
  }
}

/// Variante de test : les blocs sont fournis par le contexte parent.
@visibleForTesting
class MesColisScreenTesting extends StatelessWidget {
  const MesColisScreenTesting({super.key, this.initialTab = MesColisTab.enRoute});

  final MesColisTab initialTab;

  @override
  Widget build(BuildContext context) => _MesColisView(initialTab: initialTab);
}

class _MesColisView extends StatefulWidget {
  const _MesColisView({required this.initialTab});

  final MesColisTab initialTab;

  @override
  State<_MesColisView> createState() => _MesColisViewState();
}

class _MesColisViewState extends State<_MesColisView> {
  late MesColisTab _tab = widget.initialTab;

  @override
  void initState() {
    super.initState();
    context.read<PackageRequestBloc>().add(const FetchMyRequests());
    // Le badge du volet « Publiés » compte les discussions non lues : il faut
    // la liste des fils, comme le faisait le volet « Envoyées » d'où il vient.
    context.read<NegotiationListBloc>().add(
      const NegotiationListRefreshRequested(),
    );
  }

  void _selectTab(MesColisTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
  }

  /// Même geste que la pill « Envoyer » de la liste d'envois : l'écran d'intro
  /// applique le gate KYC puis ouvre le wizard.
  void _onNewRequest() {
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.shipmentNewRequestOpened,
      ),
    );
    context.push('/parcels/send-intro');
  }

  @override
  Widget build(BuildContext context) {
    final hp = DonyLayout.hPadding(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _MesColisHeader(onNewRequest: _onNewRequest),
            Padding(
              padding: EdgeInsets.fromLTRB(
                hp,
                DonySpacing.md,
                hp,
                DonySpacing.sm,
              ),
              // Le badge du volet « Publiés » compte les discussions de prix
              // non lues sur mes demandes : le signal exact que portait le
              // volet « Envoyées » avant son déménagement.
              child: BlocBuilder<PackageRequestBloc, PackageRequestState>(
                builder: (context, prState) =>
                    BlocBuilder<NegotiationListBloc, NegotiationListState>(
                      builder: (context, negoState) => _VoletSegmented(
                        selected: _tab,
                        publiesBadge: negosNonLuesSurMesColis(
                          prState,
                          negoState,
                        ),
                        onSelect: _selectTab,
                      ),
                    ),
              ),
            ),
            // IndexedStack, pas un switch : basculer de volet ne doit pas
            // redéclencher le refetch forcé de la liste d'envois (le hub
            // throttle déjà ses rechargements pour ne pas épuiser le
            // rate-limit nginx), ni perdre la recherche en cours de l'autre
            // volet.
            Expanded(
              child: IndexedStack(
                key: const Key('mes-colis-body'),
                index: _tab.index,
                children: const [
                  ShipmentListScreen(),
                  MyPackageRequestsBody(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Discussions de prix non lues portant sur mes demandes publiées.
///
/// Partagé avec la tuile « Mes colis » du hub, pour que la pastille du hub et
/// le badge du volet désignent la même chose. On compte des non-lus, pas des
/// demandes en négociation : un badge qui ne retombe jamais n'est plus un
/// signal d'attention.
int negosNonLuesSurMesColis(
  PackageRequestState requestState,
  NegotiationListState negotiationState,
) => negotiationState.unreadCountForRequests(
  requestState.requests.map((r) => r.id).toSet(),
);

/// Nombre de colis publiés encore en recherche d'un voyageur.
///
/// Volontairement restreint à OPEN et NEGOTIATING : un brouillon n'est pas
/// publié, et une demande expirée ou annulée n'a plus rien en cours.
int colisPublies(PackageRequestState state) => state.requests
    .where(
      (r) =>
          r.status == PackageRequestStatus.open ||
          r.status == PackageRequestStatus.negotiating,
    )
    .length;

// ── Header ───────────────────────────────────────────────────────────────────

/// Reprend l'anatomie du header de la liste d'envois (surface claire, titre
/// encre, liseré bas, pill « Envoyer ») : seul le titre change, l'écran couvre
/// désormais les deux volets.
class _MesColisHeader extends StatelessWidget {
  const _MesColisHeader({required this.onNewRequest});

  final VoidCallback onNewRequest;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final canGoBack = context.canPop();

    return Container(
      color: cs.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: kToolbarHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.xs,
                0,
                DonySpacing.base,
                0,
              ),
              child: Row(
                children: [
                  if (canGoBack)
                    const DonyAppBarBackButton()
                  else
                    const SizedBox(width: DonySpacing.base),
                  const SizedBox(width: DonySpacing.xs),
                  Expanded(
                    child: Text(
                      'Mes colis',
                      style: tt.titleLarge?.copyWith(
                        color: cs.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  HeaderPill(
                    key: const Key('mes-colis-new-request'),
                    label: 'Envoyer',
                    iconAsset: 'package',
                    style: HeaderPillStyle.warm,
                    onTap: onNewRequest,
                  ),
                ],
              ),
            ),
          ),
          Container(height: 1, color: cs.outline),
        ],
      ),
    );
  }
}

// ── Segmented control de volet ───────────────────────────────────────────────

/// Bascule En route / Publiés : une seule surface connectée avec une capsule
/// qui glisse, plutôt que deux pastilles séparées.
class _VoletSegmented extends StatelessWidget {
  const _VoletSegmented({
    required this.selected,
    required this.publiesBadge,
    required this.onSelect,
  });

  final MesColisTab selected;
  final int publiesBadge;
  final ValueChanged<MesColisTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 46,
      padding: const EdgeInsets.all(DonySpacing.xs),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.lg),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              AnimatedAlign(
                duration: DonyDuration.base,
                curve: DonyCurve.easeOut,
                alignment: selected == MesColisTab.enRoute
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  width: segWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                    boxShadow: DonyShadows.card,
                  ),
                ),
              ),
              // Positioned.fill : sans ça la rangée de labels se cale en haut
              // à gauche du Stack et le texte n'est pas centré verticalement.
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: _VoletSegLabel(
                        key: const Key('mes-colis-tab-en-route'),
                        label: 'En route',
                        badge: 0,
                        selected: selected == MesColisTab.enRoute,
                        onTap: () => onSelect(MesColisTab.enRoute),
                      ),
                    ),
                    Expanded(
                      child: _VoletSegLabel(
                        key: const Key('mes-colis-tab-publies'),
                        label: 'Publiés',
                        badge: publiesBadge,
                        selected: selected == MesColisTab.publies,
                        onTap: () => onSelect(MesColisTab.publies),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VoletSegLabel extends StatelessWidget {
  const _VoletSegLabel({
    super.key,
    required this.label,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: tt.labelLarge?.copyWith(
              color: selected ? cs.onSurface : cs.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (badge > 0) ...[
            const SizedBox(width: DonySpacing.xs),
            Container(
              constraints: const BoxConstraints(minWidth: 18),
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.error,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                badge > 99 ? '99+' : '$badge',
                style: tt.labelSmall?.copyWith(
                  color: cs.onError,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
