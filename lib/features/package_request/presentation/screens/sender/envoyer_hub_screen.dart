import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/presentation/screens/shipment_list_screen.dart';
import 'package:dony/features/matching/presentation/widgets/activity_header_widgets.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/package_request/presentation/package_request_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Écran « Envoyer » — liste des envois de l'expéditeur.
///
/// Le segmented control « Envois / Demandes » a été retiré : les demandes
/// d'envoi publiées sont consultables depuis le hub Activités, volet
/// « Publiés » de l'écran « Mes colis » (`/envois`). Cet écran ne montre donc
/// plus qu'une seule liste.
class EnvoyerHubScreen extends StatefulWidget {
  const EnvoyerHubScreen({super.key, this.showBackButton = false});

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
        getIt<AnalyticsService>().logScreen(
          AnalyticsEvents.envoyerEnvoisScreen,
        ),
      );
    });
  }

  Future<void> _onNew() async {
    final created = await openPackageRequestWizard(context);
    if (created && mounted) {
      // Singleton DI : le lookup par context échouerait ici, le State est
      // au-dessus du MultiBlocProvider posé dans build().
      getIt<PackageRequestBloc>().add(const RefreshMyRequests());
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
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _EnvoyerHeader(
                  onNew: _onNew,
                  showBackButton: widget.showBackButton,
                ),
                const Expanded(child: ShipmentListScreen()),
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
  const _EnvoyerHeader({required this.onNew, this.showBackButton = false});

  final VoidCallback onNew;

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
          HeaderPill(label: '+ Nouveau', onTap: onNew),
        ],
      ),
    );
  }
}
