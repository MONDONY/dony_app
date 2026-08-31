import 'package:dony/core/config/pro_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/browser_return_refresh_mixin.dart';
import 'package:dony/features/billing/bloc/subscription_bloc.dart';
import 'package:dony/features/billing/presentation/pro_portal_copy.dart';
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
class SubscriptionBannerHost extends StatefulWidget {
  const SubscriptionBannerHost({required this.isProAccount, super.key});

  final bool isProAccount;

  @override
  State<SubscriptionBannerHost> createState() => _SubscriptionBannerHostState();
}

class _SubscriptionBannerHostState extends State<SubscriptionBannerHost>
    with
        WidgetsBindingObserver,
        BrowserReturnRefreshMixin<SubscriptionBannerHost> {
  /// Conservée pour pouvoir recharger depuis `onResumedAfterBrowserLaunch`,
  /// où le `context` de ce State n'est plus sous le `BlocProvider` créé dans
  /// `build`.
  SubscriptionBloc? _bloc;

  /// Même mécanique que l'écran « Compte PRO » : ce bandeau ouvre lui aussi
  /// le portail (« Régler », « Gérer », « S'abonner »), et sans rechargement
  /// au retour, l'utilisateur qui vient de régulariser depuis son Profil
  /// retrouve un bandeau inchangé.
  @override
  void onResumedAfterBrowserLaunch() {
    _bloc?.add(const SubscriptionRequested());
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isProAccount) {
      return const SizedBox.shrink();
    }

    // Même porte pour le feature flag : offre PRO fermée, le bandeau (et son
    // appel réseau) n'ont pas lieu d'être, même pour un compte PRO — ses
    // actions mèneraient à un portail que l'application ne propose plus.
    return ValueListenableBuilder<bool>(
      valueListenable: proEnabledListenable,
      builder: (context, proEnabled, _) {
        if (!proEnabled) {
          return const SizedBox.shrink();
        }
        return _buildBanner(context);
      },
    );
  }

  Widget _buildBanner(BuildContext context) {
    return BlocProvider<SubscriptionBloc>(
      create: (_) {
        final bloc = getIt<SubscriptionBloc>()
          ..add(const SubscriptionRequested());
        _bloc = bloc;
        return bloc;
      },
      child: BlocConsumer<SubscriptionBloc, SubscriptionState>(
        listener: (context, state) {
          // État transitoire, jamais un drapeau porté par SubscriptionLoaded
          // (voir sa documentation) : traité ici, dans le listener, pas dans
          // le builder.
          if (state is SubscriptionPortalLaunchFailed) {
            clearBrowserLaunched();
            DonySnackbar.show(
              context,
              message: kProPortalOpenFailedMessage,
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
          final subscription = state.subscription;
          if (!subscriptionHasVisibleAlert(subscription)) {
            // Rien à signaler : zéro hauteur, espacement de section compris.
            // Le composant porte lui-même son encombrement — l'écran hôte
            // (`profile_screen.dart`) ne doit jamais ajouter un espacement
            // conditionné à une décision qu'il ne peut pas connaître (l'état
            // du BLoC n'est disponible qu'ici, une fois le réseau résolu).
            return const SizedBox.shrink();
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SubscriptionStatusBanner(
                subscription: subscription,
                // Une action qui mène à la gestion exige une source Stripe :
                // voir `proPortalActionIsLegitimate`. Le bandeau reste
                // affiché (l'alerte doit être dite), seule son action
                // disparaît quand elle ne mènerait nulle part.
                onAction: proPortalActionIsLegitimate(subscription)
                    ? () {
                        markBrowserLaunched();
                        context.read<SubscriptionBloc>().add(
                          ProPortalOpenRequested(
                            proPortalTargetFor(subscription.status),
                          ),
                        );
                      }
                    : null,
              ),
              // Même espacement que celui utilisé entre les sections
              // voisines de l'écran Profil, porté ici plutôt que par
              // l'appelant : sans ça, un `gap` inconditionnel ajouté après
              // ce widget s'additionnerait au padding déjà porté par le
              // `SliverPadding` de l'écran hôte quand rien n'est affiché,
              // doublant l'espacement en tête de liste pour la majorité des
              // comptes (non-PRO, ou PRO sans rien à signaler).
              const SizedBox(height: DonySpacing.lg),
            ],
          );
        },
      ),
    );
  }
}
