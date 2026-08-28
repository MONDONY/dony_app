import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/billing/bloc/subscription_bloc.dart';
import 'package:dony/features/billing/data/models/pro_subscription_model.dart';
import 'package:dony/features/billing/presentation/widgets/subscription_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Se pose en tête de l'écran Profil et se fournit lui-même son
/// [SubscriptionBloc] : l'écran hôte n'a donc rien d'autre à faire que
/// monter ce widget.
///
/// [isProAccount] filtre l'appel réseau à la source. `GET
/// /billing/subscription` répond 200 même sans abonnement, mais les seuls
/// statuts porteurs d'une alerte impliquent tous que l'utilisateur est PRO :
/// interroger l'endpoint pour la quasi-totalité des utilisateurs, qui ne
/// sont pas PRO, à chaque ouverture du Profil serait une requête inutile.
/// Quand [isProAccount] est faux, on rend `SizedBox.shrink()` avant même de
/// créer le BLoC — le créer puis s'abstenir de lui envoyer l'event ne ferait
/// que retarder l'instanciation, pas l'éviter.
class SubscriptionBannerHost extends StatelessWidget {
  const SubscriptionBannerHost({required this.isProAccount, super.key});

  final bool isProAccount;

  @override
  Widget build(BuildContext context) {
    if (!isProAccount) {
      return const SizedBox.shrink();
    }

    return BlocProvider<SubscriptionBloc>(
      create: (_) =>
          getIt<SubscriptionBloc>()..add(const SubscriptionRequested()),
      child: BlocConsumer<SubscriptionBloc, SubscriptionState>(
        listener: (context, state) {
          // État transitoire, jamais un drapeau porté par SubscriptionLoaded
          // (voir sa documentation) : traité ici, dans le listener, pas dans
          // le builder.
          if (state is SubscriptionPortalLaunchFailed) {
            DonySnackbar.show(
              context,
              message:
                  "Impossible d'ouvrir la page. Vérifiez votre connexion et "
                  'réessayez.',
              type: DonySnackbarType.error,
            );
          }
        },
        builder: (context, state) {
          if (state is! SubscriptionLoaded) {
            // Ni chargement, ni erreur ne doivent se voir sur le Profil :
            // un appel secondaire raté ou lent ne doit jamais se manifester
            // sur cet écran.
            return const SizedBox.shrink();
          }
          return SubscriptionStatusBanner(
            subscription: state.subscription,
            onAction: () => context.read<SubscriptionBloc>().add(
              ProPortalOpenRequested(_targetFor(state.subscription.status)),
            ),
          );
        },
      ),
    );
  }

  /// Seule une grâce historique (jamais payé) doit atteindre la page de
  /// vente. Tous les autres statuts porteurs d'une action (impayé, ou
  /// abonnement actif dont l'utilisateur gère la résiliation) mènent à la
  /// gestion du moyen de paiement.
  ProPortalTarget _targetFor(ProSubscriptionStatus status) =>
      status == ProSubscriptionStatus.legacyGrace
      ? ProPortalTarget.upgrade
      : ProPortalTarget.manage;
}
