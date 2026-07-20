import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/presentation/screens/shipment_list_screen.dart';
import 'package:dony/features/matching/presentation/widgets/activity_header_widgets.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/package_request/presentation/package_request_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Écran « Envoyer » — liste des envois de l'expéditeur.
///
/// Le segmented control « Envois / Demandes » a été retiré : les demandes
/// d'envoi publiées sont désormais consultables depuis le hub Activités, volet
/// « Envoyées » de l'écran Demandes (`/demandes`). Cet écran ne montre donc
/// plus qu'une seule liste.
class EnvoyerHubScreen extends StatefulWidget {
  const EnvoyerHubScreen({
    super.key,
    this.onShowTrips,
    this.showBackButton = false,
  });

  /// Si non nul, un bouton « Mes trajets » apparaît dans le header.
  final VoidCallback? onShowTrips;

  /// Affiche un bouton retour quand l'écran est ouvert via `context.push`.
  final bool showBackButton;

  @override
  State<EnvoyerHubScreen> createState() => _EnvoyerHubScreenState();
}

class _EnvoyerHubScreenState extends State<EnvoyerHubScreen> {
  @override
  void initState() {
    super.initState();
    getIt<PackageRequestBloc>().add(const FetchMyRequests());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        getIt<AnalyticsService>().logScreen(AnalyticsEvents.envoyerEnvoisScreen),
      );
    });
  }

  Future<void> _onNew() async {
    final created = await openPackageRequestWizard(context);
    if (created && mounted) {
      context.read<PackageRequestBloc>().add(const RefreshMyRequests());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: getIt<PackageRequestBloc>()),
        // Pas d'event ici : ShipmentListScreen déclenche son propre
        // chargement, l'ajouter aussi ferait deux requêtes à l'ouverture.
        BlocProvider(create: (_) => getIt<BidBloc>()),
      ],
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: const Color(0xFFF0F2F6),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _EnvoyerHeader(
                  onNew: _onNew,
                  onShowTrips: widget.onShowTrips,
                  showBackButton: widget.showBackButton,
                ),
                const Expanded(child: ShipmentListBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _EnvoyerHeader extends StatelessWidget {
  const _EnvoyerHeader({
    required this.onNew,
    this.onShowTrips,
    this.showBackButton = false,
  });

  final VoidCallback onNew;

  /// Si non nul, affiche la pill « Mes trajets ».
  final VoidCallback? onShowTrips;

  /// Affiche un bouton retour quand le hub est ouvert via `context.push`.
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.base,
        DonySpacing.lg,
        DonySpacing.sm,
      ),
      child: Row(
        children: [
          if (showBackButton)
            const DonyAppBarBackButton(key: Key('envoyer-back')),
          Text(
            'Envoyer',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: cs.onSurface,
                  height: 1.1,
                ),
          ),
          const Spacer(),
          if (onShowTrips != null) ...[
            HeaderPill(
              key: const Key('show-trips-pill'),
              label: 'Mes trajets',
              iconAsset: 'plane-takeoff',
              style: HeaderPillStyle.soft,
              onTap: onShowTrips!,
            ),
            const SizedBox(width: DonySpacing.xs),
          ],
          HeaderPill(label: '+ Nouveau', onTap: onNew),
        ],
      ),
    );
  }
}
