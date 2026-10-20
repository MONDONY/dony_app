import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/commission_pricing.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/core/utils/map_launcher.dart';
import 'package:dony/core/utils/trip_local_time.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/presentation/widgets/auth_required_sheet.dart';
import 'package:dony/features/content_categories/presentation/content_category_labels.dart';
import 'package:dony/features/corridor_alerts/bloc/trip_space_alert_cubit.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/trip_space_alert_footer.dart';
import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:dony/features/favorites/presentation/widgets/favorite_heart_button.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_status_bottom_sheet.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/habitual_operator_cubit.dart';
import 'package:dony/features/matching/bloc/trip_group_cubit.dart';
import 'package:dony/features/matching/bloc/trip_mobile_money_networks_cubit.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/mobile_money_network.dart';
import 'package:dony/features/matching/data/repositories/bid_negotiation_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/matching/presentation/existing_trip_request.dart';
import 'package:dony/features/matching/presentation/trip_domain_labels.dart';
import 'package:dony/features/matching/presentation/trip_view_recording.dart';
import 'package:dony/features/matching/presentation/widgets/address_location_row.dart';
import 'package:dony/features/matching/presentation/widgets/billet/trip_billet_card.dart';
import 'package:dony/features/matching/presentation/widgets/block_user_action.dart';
import 'package:dony/features/matching/presentation/widgets/create_bid_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/trip_legs_card.dart';
import 'package:dony/features/profile/presentation/screens/profile_public_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

/// Statuts d'un trajet qui n'accepte plus de nouvelle demande.
const _kClosedTripStatuses = {'IN_PROGRESS', 'COMPLETED', 'CANCELLED'};

/// Navigation demandée par la feuille trajet en se fermant, quand elle est
/// ouverte par la route `/traveler/:announcementId` (`returnsNavigation`).
///
/// Cette route n'est qu'une page d'accueil vide sous la feuille : elle se
/// referme dès que la feuille se ferme. Une action qui fermait la feuille puis
/// naviguait elle-même (« Voir mon colis », « Signaler ce trajet »…) voyait sa
/// navigation annulée par ce `pop`, et l'utilisateur revenait à l'écran
/// précédent, les notifications typiquement (Sentry FLUTTER-HR). La feuille
/// rend donc la suite à donner, et la page d'accueil l'exécute en se
/// retirant.
sealed class TravelerSheetExit {
  const TravelerSheetExit();
}

/// Ouvrir [location] à la place de la page d'accueil (`pushReplacement`).
final class TravelerSheetRoute extends TravelerSheetExit {
  const TravelerSheetRoute(this.location, {this.extra});

  final String location;
  final Object? extra;
}

/// Poursuivre un parcours en feuilles (demande de transport, vérification
/// d'identité, connexion) une fois la page d'accueil retirée. [run] reçoit le
/// contexte du navigateur racine, qui survit à cette page.
final class TravelerSheetFollowUp extends TravelerSheetExit {
  const TravelerSheetFollowUp(this.run);

  final Future<void> Function(BuildContext rootContext) run;
}

/// Rend la feuille et se termine à sa fermeture.
///
/// Le `Future` sert à la route `/traveler/:announcementId`, qui doit se refermer
/// derrière la feuille pour ne pas laisser une page vide dans la pile. Avec
/// [returnsNavigation], les actions qui quittent la feuille ne naviguent pas
/// elles-mêmes : elles la ferment avec un [TravelerSheetExit] que la route
/// exécute (FLUTTER-HR). Les autres appelants (carte, liste, recherche…)
/// laissent [returnsNavigation] à faux et ignorent le résultat, toujours nul.
///
/// [fromMap] : fiche ouverte depuis la carte des trajets, où la mention des
/// frais de service ne dit pas leur minimum (« + frais de service »).
///
/// [fromDetail] : le trajet vient de `GET /announcements/{id}` (route
/// `/traveler/:id`, relecture après un rematch, lien d'affiche). Ses réseaux
/// mobile money sont alors définitifs, une liste vide veut dire « aucun compte »
/// et la feuille ne relit pas le détail. Faux par défaut : un trajet venu de
/// la recherche ou de l'accueil n'a pas ses réseaux.
Future<TravelerSheetExit?> showTravelerAnnouncementSheet(
  BuildContext context, {
  required AnnouncementModel announcement,
  String? existingBidStatus,
  BidModel? existingBid,
  bool returnsNavigation = false,
  bool fromMap = false,
  bool fromDetail = false,
}) {
  // Captured before DonyBottomSheet.show() — context may be invalid inside
  // onPressed since useRootNavigator: true places the sheet outside BlocProvider.
  final authState = context.read<AuthBloc>().state;
  // currentUser couvre AuthAuthenticated ET AuthProfileUpdated (émis après
  // upload avatar / édition profil) — sinon le KYC repasserait à false.
  final isKycVerified = authState.currentUser?.isKycVerified ?? false;
  // Sert à masquer le blocage sur son propre trajet. Lu ici, comme le reste :
  // la feuille s'affiche hors de l'arbre de providers.
  final lecteurId = authState.currentUserId;
  // Audience du trajet : une personne de plus pour le voyageur, sans attendre.
  recordTripView(announcement, viewerId: lecteurId);
  // Un expéditeur non vérifié peut quand même écrire à un voyageur qui a
  // désactivé « profils vérifiés uniquement » : sans cette exception, le réglage
  // du voyageur resterait sans effet, le client barrant la route avant l'appel.
  // Le serveur reste l'autorité (403 contact-kyc-required s'il s'est ravisé).
  final canSendRequest =
      isKycVerified || (announcement.traveler?.acceptsUnverified ?? false);
  // R13 : le backend rejette toute négociation en mobile money (422
  // mobile-money-negotiation-unsupported, `BidNegotiationService`) —
  // décision produit « offres classiques seulement ». Un trajet qui
  // n'accepte QUE le mobile money ne propose donc pas l'entrée de
  // négociation, même si `announcement.negotiable` vaut true côté back.
  final canNegotiate =
      announcement.negotiable &&
      (announcement.acceptedPaymentMethods.contains(BidPaymentMethod.stripe) ||
          announcement.acceptedPaymentMethods.contains(BidPaymentMethod.cash));
  // Capture la référence au BidBloc du parent (carousel / liste) pour pouvoir
  // déclencher un refresh après la fermeture de CreateBidBottomSheet, même
  // quand useRootNavigator: true sort du BlocProvider tree.
  final BidBloc? parentBidBloc = context.mounted
      ? context.read<BidBloc>()
      : null;

  // Détecte un colis existant du viewer sur ce trajet — même si l'appelant n'a
  // pas passé existingBid (certains points d'entrée — carte, accueil — ne le
  // font pas). On lit le BidBloc du parent maintenant (avant le sheet : avec
  // useRootNavigator le sheet sort du BlocProvider tree). Le bid négocié
  // matérialisé (statut ACCEPTED) y figure → on grise « Faire une demande ».
  BidModel? resolvedBid = existingBid;
  if (resolvedBid == null && context.mounted) {
    try {
      resolvedBid = context
          .read<BidBloc>()
          .state
          .activeBidsByAnnouncement()[announcement.id];
    } catch (_) {
      /* BidBloc indisponible dans ce contexte — on ignore */
    }
  }
  final resolvedStatus = resolvedBid?.status ?? existingBidStatus;

  // « A déjà un colis sur ce trajet » couvre tout colis en cours, demande
  // jusqu'à livraison (EN ROUTE / LIVRÉ inclus) — pas seulement en attente/accepté.
  final hasActiveBid =
      resolvedStatus != null &&
      MyActiveBidsLookup.ongoingBidStatuses.contains(resolvedStatus);

  // `useRootNavigator: true` place la feuille hors de l'arbre de providers :
  // le cubit doit être capturé ici et réinjecté par `wrapper`, sinon le cœur
  // des favoris ne trouverait rien à lire.
  FavoriteIdsCubit? favoris;
  try {
    favoris = context.read<FavoriteIdsCubit>();
  } catch (_) {
    /* Absent de ce contexte (tests, points d'entrée isolés) : pas de cœur. */
  }

  // Trajet complet d'un autre voyageur (FLUTTER-JH) : ni demande ni
  // négociation, mais « Me prévenir si de la place se libère ». Le cubit vit
  // dans le `wrapper`, le bouton dans le `stickyBottom`.
  // Son propre trajet (ouvert depuis un point d'entrée qui ne teste pas la
  // propriété, FLUTTER-R9) : ni demande, ni proposition de prix, ni signet.
  // Le back refuse de toute façon une demande sur son propre trajet.
  final estProprietaire =
      lecteurId != null && lecteurId == announcement.travelerId;
  final offersSpaceAlert =
      announcement.isFull &&
      !estProprietaire &&
      getIt.isRegistered<TripSpaceAlertCubit>();
  final hasSession =
      getIt.isRegistered<FirebaseSessionProbe>() &&
      getIt<FirebaseSessionProbe>().hasRealSession;

  return DonyBottomSheet.show<TravelerSheetExit>(
    context,
    title: context.l10n.listingTripDetailTitle,
    // Scarabée de signalement dans l'en-tête, comme sur les écrans
    // (FLUTTER-83 : la feuille en était dépourvue).
    showFeedback: true,
    wrapper: favoris == null && !offersSpaceAlert
        ? null
        : (child) {
            var wrapped = child;
            if (offersSpaceAlert) {
              wrapped = BlocProvider<TripSpaceAlertCubit>(
                create: (_) {
                  final cubit = getIt<TripSpaceAlertCubit>(
                    param1: announcement.id,
                  );
                  // Invité : rien à lire, le bouton l'invite à se connecter.
                  if (hasSession) unawaited(cubit.load());
                  return cubit;
                },
                child: wrapped,
              );
            }
            if (favoris != null) {
              wrapped = BlocProvider<FavoriteIdsCubit>.value(
                value: favoris,
                child: wrapped,
              );
            }
            return wrapped;
          },
    stickyBottom: Builder(
      builder: (innerCtx) {
        if (estProprietaire) {
          return _OwnTripFooter(
            onManage: () {
              final navigator = Navigator.of(innerCtx, rootNavigator: true);
              final location = '/announcements/${announcement.id}/trip';
              if (returnsNavigation) {
                navigator.pop(
                  TravelerSheetRoute(location, extra: announcement),
                );
                return;
              }
              navigator.pop();
              if (context.mounted) {
                context.push(location, extra: announcement);
              }
            },
          );
        }
        // Le viewer a déjà un colis sur ce trajet : on n'autorise pas une
        // nouvelle demande (le back la refuserait). On l'oriente vers son colis.
        if (hasActiveBid) {
          final tt = Theme.of(innerCtx).textTheme;
          final cs = Theme.of(innerCtx).colorScheme;
          final innerL = innerCtx.l10n;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: DonySpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DonyIcon('info', size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: DonySpacing.xs),
                    Flexible(
                      child: Text(
                        innerL.listingAlreadyHasParcelMessage,
                        textAlign: TextAlign.center,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              DonyButton(
                key: const Key('see-my-parcel-btn'),
                label: innerL.listingSeeMyParcelButton,
                iconAsset: 'package',
                onPressed: resolvedBid == null
                    ? null
                    : () {
                        final navigator = Navigator.of(
                          innerCtx,
                          rootNavigator: true,
                        );
                        final location = '/bids/${resolvedBid!.id}';
                        if (returnsNavigation) {
                          navigator.pop(
                            TravelerSheetRoute(location, extra: resolvedBid),
                          );
                          return;
                        }
                        navigator.pop();
                        if (context.mounted) {
                          context.push(location, extra: resolvedBid);
                        }
                      },
              ),
            ],
          );
        }
        // Trajet parti, arrivé ou annulé : il n'accepte plus de demande, le
        // back la refuserait (FLUTTER-AE). On le dit plutôt que d'ouvrir un
        // formulaire voué au refus.
        if (_kClosedTripStatuses.contains(announcement.status)) {
          final tt = Theme.of(innerCtx).textTheme;
          final cs = Theme.of(innerCtx).colorScheme;
          return Padding(
            key: const Key('trip-closed-message'),
            padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DonyIcon('info', size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: DonySpacing.xs),
                Flexible(
                  child: Text(
                    innerCtx.l10n.listingTripClosedMessage,
                    textAlign: TextAlign.center,
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          );
        }
        // Date limite de dépôt passée : le back refuserait la demande en 409
        // `handover-deadline-passed`. On le dit au lieu d'ouvrir un
        // formulaire voué au refus (PROD-1R).
        if (announcement.isHandoverClosed) {
          return const _HandoverClosedFooter();
        }
        Future<void> continueCreateBid(
          BuildContext rootCtx, {
          required bool negotiation,
        }) async {
          // Session Firebase, pas AuthBloc (FLUTTER-7X).
          if (!getIt<FirebaseSessionProbe>().hasRealSession) {
            await AuthRequiredSheet.show(
              rootCtx,
              reason: AuthRequiredReason.offer,
            );
            return;
          }
          if (canSendRequest) {
            // Le cache lu plus haut peut être périmé (négociation payée dans
            // son fil, bid NEGOTIATING absent de /bids/me) : on relit le
            // serveur avant d'ouvrir le formulaire, pour ne pas le laisser
            // remplir jusqu'au 409 `already-bid` du paiement.
            final existing = await _findExistingTripRequest(announcement.id);
            if (!rootCtx.mounted) return;
            if (existing != null) {
              // Le cache se remet d'aplomb : à la prochaine ouverture, la
              // feuille affiche d'emblée « Voir mon colis ».
              parentBidBloc?.add(
                const BidMyListAutoRefreshRequested(force: true),
              );
              _openExistingTripRequest(rootCtx, existing);
              return;
            }
            await CreateBidBottomSheet.show(
              rootCtx,
              announcement: announcement,
              negotiation: negotiation,
            );
            // Refresh silencieux du BidBloc parent pour que la liste
            // affiche immédiatement le chip "Demande en attente".
            parentBidBloc?.add(
              const BidMyListAutoRefreshRequested(force: true),
            );
          } else {
            await KycStatusBottomSheet.show(rootCtx);
          }
        }

        Future<void> openCreateBid({required bool negotiation}) async {
          final navigator = Navigator.of(innerCtx, rootNavigator: true);
          if (returnsNavigation) {
            // Depuis `/traveler/:id`, la suite attend que la page d'accueil
            // se soit retirée : son `pop` fermerait sinon la feuille suivante.
            navigator.pop(
              TravelerSheetFollowUp(
                (rootCtx) =>
                    continueCreateBid(rootCtx, negotiation: negotiation),
              ),
            );
            return;
          }
          final rootCtx = navigator.context;
          navigator.pop();
          await continueCreateBid(rootCtx, negotiation: negotiation);
        }

        final tt = Theme.of(innerCtx).textTheme;
        final cs = Theme.of(innerCtx).colorScheme;
        final innerL = innerCtx.l10n;
        // Trajet complet : on peut le consulter, mais plus lui faire de
        // demande ni lui proposer de prix (FLUTTER-BG). On peut en revanche
        // demander à être prévenu quand une place se libère (FLUTTER-JH).
        if (offersSpaceAlert) {
          return TripSpaceAlertFooter(
            hasSession: hasSession,
            onAuthRequired: () => AuthRequiredSheet.show(innerCtx),
          );
        }
        if (announcement.isFull) {
          return Column(
            key: const Key('trip-full-footer'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: DonySpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DonyIcon('info', size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: DonySpacing.xs),
                    Flexible(
                      child: Text(
                        innerL.listingTripFullMessage,
                        textAlign: TextAlign.center,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              DonyButton(
                key: const Key('make-request-btn-disabled'),
                label: innerL.listingMakeRequestButton,
                iconAsset: 'send',
                onPressed: null,
              ),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyButton(
              label: innerL.listingMakeRequestButton,
              iconAsset: 'send',
              onPressed: () => openCreateBid(negotiation: false),
            ),
            // Vrai bouton secondaire, plus un lien texte : relégué sous le CTA,
            // il passait inaperçu et l'expéditrice payait au prix affiché sans
            // savoir qu'elle pouvait proposer le sien (Sentry FLUTTER-DA).
            // Réservé aux trajets ouverts aux propositions : sur un prix ferme,
            // il n'y aurait rien à proposer. Voir `canNegotiate` plus haut pour
            // l'exclusion mobile-money-only.
            if (canNegotiate) ...[
              const SizedBox(height: DonySpacing.sm),
              DonyButton(
                key: const Key('negotiate-price-btn'),
                label: innerL.listingProposePriceLink,
                iconAsset: 'handshake',
                variant: DonyButtonVariant.secondary,
                onPressed: () => openCreateBid(negotiation: true),
              ),
            ],
          ],
        );
      },
    ),
    child: _TravelerAnnouncementContent(
      announcement: announcement,
      avecFavori: favoris != null && !estProprietaire,
      lecteurId: lecteurId,
      returnsNavigation: returnsNavigation,
      fromMap: fromMap,
      fromDetail: fromDetail,
    ),
  );
}

Future<ExistingTripRequest?> _findExistingTripRequest(String announcementId) {
  if (!getIt.isRegistered<BidRepository>() ||
      !getIt.isRegistered<BidNegotiationRepository>()) {
    return Future.value();
  }
  return ExistingTripRequestLookup(
    getIt<BidRepository>(),
    getIt<BidNegotiationRepository>(),
  ).find(announcementId);
}

/// Amène l'expéditeur à la demande qu'il a déjà sur ce trajet, au lieu du
/// formulaire que le back refuserait.
void _openExistingTripRequest(
  BuildContext context,
  ExistingTripRequest existing,
) {
  final l = context.l10n;
  switch (existing) {
    case ExistingTripBid(:final bid):
      DonySnackbar.show(context, message: l.listingAlreadyHasParcelMessage);
      unawaited(context.push('/bids/${bid.id}', extra: bid));
    case ExistingTripNegotiation(:final bidId):
      DonySnackbar.show(context, message: l.listingAlreadyNegotiatingMessage);
      unawaited(context.push('/bids/$bidId/negotiation'));
  }
}

/// Pied de la feuille quand la date limite de dépôt est passée : badge
/// « Dépôt clos », explication et bouton de demande désactivé (PROD-1R).
class _HandoverClosedFooter extends StatelessWidget {
  const _HandoverClosedFooter();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Column(
      key: const Key('handover-closed-footer'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          key: const Key('handover-closed-badge'),
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.sm,
            vertical: DonySpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: cs.errorContainer,
            borderRadius: BorderRadius.circular(DonyRadius.card),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DonyIcon('calendar', size: 14, color: cs.onErrorContainer),
              const SizedBox(width: DonySpacing.xxs),
              Text(
                l.listingHandoverClosedBadge,
                style: tt.labelMedium?.copyWith(
                  color: cs.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
          child: Text(
            l.listingHandoverClosedMessage,
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        DonyButton(
          key: const Key('make-request-btn-disabled'),
          label: l.listingMakeRequestButton,
          iconAsset: 'send',
          onPressed: null,
        ),
      ],
    );
  }
}

/// Pied de la feuille quand le lecteur est le voyageur du trajet : il ne peut
/// pas s'envoyer de demande, on l'oriente vers l'écran de gestion du trajet.
class _OwnTripFooter extends StatelessWidget {
  const _OwnTripFooter({required this.onManage});

  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Column(
      key: const Key('own-trip-footer'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: DonySpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DonyIcon('info', size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: DonySpacing.xs),
              Flexible(
                child: Text(
                  l.listingOwnTripMessage,
                  textAlign: TextAlign.center,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        DonyButton(
          key: const Key('manage-own-trip-btn'),
          label: l.listingOwnTripManageButton,
          iconAsset: 'plane',
          onPressed: onManage,
        ),
      ],
    );
  }
}

class _TravelerAnnouncementContent extends StatelessWidget {
  const _TravelerAnnouncementContent({
    required this.announcement,
    this.avecFavori = false,
    this.lecteurId,
    this.returnsNavigation = false,
    this.fromMap = false,
    this.fromDetail = false,
  });

  /// Ouverte depuis la carte : frais de service sans minimum.
  final bool fromMap;

  /// Trajet issu du détail : ses réseaux mobile money sont définitifs.
  final bool fromDetail;

  /// Ouverte par `/traveler/:id` : « Signaler ce trajet » rend sa route au
  /// lieu de naviguer (voir [TravelerSheetExit]).
  final bool returnsNavigation;

  /// Identifiant du lecteur, pour ne pas lui proposer de se bloquer lui-même.
  final String? lecteurId;

  /// Le voyageur du trajet, sauf s'il s'agit du lecteur lui-même.
  TravelerProfile? get _voyageurBloquable {
    final voyageur = announcement.traveler;
    if (voyageur == null) return null;
    final estSien =
        lecteurId != null &&
        (lecteurId == announcement.travelerId || lecteurId == voyageur.id);
    return estSien ? null : voyageur;
  }

  /// Faux quand le point d'ouverture n'a pas de `FavoriteIdsCubit` : un
  /// `BlocBuilder` sans provider **lève**, il ne se contente pas de ne rien
  /// afficher.
  final bool avecFavori;

  final AnnouncementModel announcement;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final categories = announcement.acceptedContentTypes ?? [];
    final hasGrid =
        announcement.pricingMode == 'MIXED' &&
        announcement.priceGridItems.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (avecFavori)
          _HeroWithFavorite(announcement: announcement)
        else
          TripBilletCard(announcement: announcement),
        const SizedBox(height: DonySpacing.md),
        _StatCardsRow(
          announcement: announcement,
          hasGrid: hasGrid,
          fromMap: fromMap,
        ),
        if (hasGrid) ...[
          const SizedBox(height: DonySpacing.md),
          _PriceGridCard(
            items: announcement.priceGridItems,
            currency: announcement.currency,
            convertedCurrency: announcement.convertedCurrency,
          ),
        ],
        // Voyage à plusieurs étapes (FLUTTER-4D) : « Étape 1/2 du voyage »
        // et accès aux autres étapes, chacune ouverte comme un trajet.
        // Garde : un point d'ouverture sans DI complète (tests, aperçus)
        // garde la fiche ordinaire.
        if (getIt.isRegistered<TripGroupCubit>())
          BlocProvider<TripGroupCubit>(
            create: (_) => getIt<TripGroupCubit>()..load(announcement.id),
            child: TripLegsCard(
              announcementId: announcement.id,
              padding: const EdgeInsets.only(top: DonySpacing.md),
              onOpenLeg: (leg) => context.push('/traveler/${leg.id}'),
            ),
          ),
        const SizedBox(height: DonySpacing.md),
        _TravelerCard(announcement: announcement),
        if (announcement.pickupAddress != null ||
            announcement.deliveryAddress != null) ...[
          const SizedBox(height: DonySpacing.md),
          _LocationsCard(announcement: announcement),
        ],

        if (announcement.acceptedPaymentMethods.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.lg),
          _AcceptedPayments(announcement: announcement, fromDetail: fromDetail),
        ],

        if (announcement.arrivalInstructions != null &&
            announcement.arrivalInstructions!.trim().isNotEmpty) ...[
          const SizedBox(height: DonySpacing.lg),
          _InstructionsCard(text: announcement.arrivalInstructions!.trim()),
        ],

        if (categories.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.lg),
          Text(
            l.listingCategoriesAcceptedTitle,
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.sm),
          Wrap(
            spacing: DonySpacing.xs,
            runSpacing: DonySpacing.xs,
            children: categories
                .map(
                  (c) => _CategoryChip(label: contentCategoryDisplayName(l, c)),
                )
                .toList(),
          ),
        ],

        if (announcement.description != null &&
            announcement.description!.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.lg),
          Text(
            l.listingTravelerMessageTitle,
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(announcement.description!, style: tt.bodyMedium),
        ],

        const SizedBox(height: DonySpacing.lg),
        Center(
          child: InkWell(
            key: const Key('report-announcement-link'),
            borderRadius: BorderRadius.circular(DonyRadius.sm),
            onTap: () {
              const location = '/settings/report-incident';
              final extra = {
                'targetType': IncidentTargetType.announcement,
                'targetId': announcement.id,
              };
              final navigator = Navigator.of(context, rootNavigator: true);
              if (returnsNavigation) {
                navigator.pop(TravelerSheetRoute(location, extra: extra));
                return;
              }
              navigator.pop();
              context.push(location, extra: extra);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.sm,
                vertical: DonySpacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DonyIcon('flag', size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: DonySpacing.xs),
                  Text(
                    l.listingReportTripLink,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Le blocage vivait sur l'écran « Détail annonce », supprimé au profit
        // de cette feuille. Sans ce report, un des points d'entrée du blocage
        // disparaîtrait. Masqué sur son propre trajet : on ne se bloque pas.
        if (_voyageurBloquable != null)
          Center(
            child: InkWell(
              key: const Key('block-traveler-link'),
              borderRadius: BorderRadius.circular(DonyRadius.sm),
              onTap: () => showBlockMenu(
                context,
                userId: _voyageurBloquable!.id,
                displayName: _voyageurBloquable!.travelerName(context.l10n),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.sm,
                  vertical: DonySpacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DonyIcon('ban', size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: DonySpacing.xs),
                    Text(
                      l.listingBlockTravelerLink,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: DonySpacing.md),
      ],
    );
  }
}

/// Carte héro navy du corridor — même dégradé que la carte du détail
/// propriétaire ([AnnouncementDetailBody]) pour garder un seul langage visuel
/// entre les deux faces du trajet.
/// Carte héro surmontée du cœur des favoris.
///
/// Le cœur vivait dans la barre de titre de l'écran « Détail annonce ». Cet
/// écran disparaît au profit de cette feuille : sans ce report, une annonce
/// ouverte depuis une notification ne pourrait plus être mise en favori.
class _HeroWithFavorite extends StatelessWidget {
  const _HeroWithFavorite({required this.announcement});

  final AnnouncementModel announcement;

  @override
  Widget build(BuildContext context) {
    // N'est monté que lorsque le cubit existe : le point d'entrée sans favoris
    // rend `TripBilletCard` directement.
    return BlocBuilder<FavoriteIdsCubit, FavoriteIdsState>(
      builder: (context, state) {
        final estFavori = state.tripIds.contains(announcement.id);
        // Billet clair (FLUTTER-GG) : signet aux couleurs par défaut, dans
        // l'en-tête du billet plutôt que superposé au corridor.
        return TripBilletCard(
          announcement: announcement,
          trailing: FavoriteHeartButton(
            isFavorite: estFavori,
            onToggle: () =>
                unawaited(_basculerFavori(context, announcement.id)),
          ),
        );
      },
    );
  }

  Future<void> _basculerFavori(BuildContext context, String id) async {
    final cubit = context.read<FavoriteIdsCubit>();
    try {
      await cubit.toggleTrip(id);
      if (!context.mounted) return;
      final desormaisFavori = cubit.isTripFav(id);
      DonySnackbar.show(
        context,
        message: desormaisFavori
            ? context.l10n.listingFavoriteAddedMessage
            : context.l10n.listingFavoriteRemovedMessage,
        type: desormaisFavori
            ? DonySnackbarType.success
            : DonySnackbarType.info,
      );
    } catch (_) {
      if (!context.mounted) return;
      DonySnackbar.show(
        context,
        message: context.l10n.listingFavoriteToggleErrorMessage,
        type: DonySnackbarType.error,
      );
    }
  }
}

class _StatCardsRow extends StatelessWidget {
  const _StatCardsRow({
    required this.announcement,
    required this.hasGrid,
    this.fromMap = false,
  });

  final AnnouncementModel announcement;
  final bool hasGrid;
  final bool fromMap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Heure de la ville de départ, comme le départ (PROD-1R).
    final deadlineInstant = announcement.handoverDeadline;
    final deadline = deadlineInstant == null
        ? null
        : tripWallTime(deadlineInstant, announcement.departureTimezone);
    final handoverClosed = announcement.isHandoverClosed;
    // Prix frais de service inclus, comme la carte de recherche
    // (YADONY-FLUTTER-PROD-1J) : aucune mention séparée des frais.
    // IntrinsicHeight : égalise la hauteur des deux cartes sans stretch
    // non borné (la colonne parente est dans un scrollable).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: hasGrid
                ? _GridStatCard(
                    items: announcement.priceGridItems,
                    currency: announcement.currency,
                  )
                : _PriceStatCard(announcement: announcement),
          ),
          if (deadline != null) ...[
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: _StatCard(
                // Jour et heure (Sentry FLUTTER-MY), sur deux lignes : en une
                // seule, la demi-largeur coupait l'heure (FLUTTER-Q2).
                key: const Key('trip-deadline-stat'),
                value: DateFormat.MMMEd(
                  l.localeName,
                ).format(deadline.wallClock),
                secondary: l.tripPosterTileDeadlineTime(
                  formatTripTime(l, deadline, city: announcement.departureCity),
                ),
                label: l.listingDepositDeadlineLabel,
                valueColor: handoverClosed
                    ? Theme.of(context).colorScheme.error
                    : null,
                subtitle: handoverClosed ? l.listingHandoverClosedBadge : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    super.key,
    required this.value,
    required this.label,
    this.valueColor,
    this.secondary,
    this.subtitle,
  });

  final String value;
  final String label;
  final Color? valueColor;

  /// Complément de la valeur, sur sa propre ligne (l'heure de la date limite).
  final String? secondary;

  /// Ligne discrète sous la valeur (équivalent « environ » multidevise).
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 21,
              color: valueColor ?? cs.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (secondary != null)
            Text(
              secondary!,
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor ?? cs.onSurface,
              ),
              textAlign: TextAlign.center,
              // Deux lignes : « à 20:30, heure de Paris » quand le fuseau du
              // trajet diffère de celui du téléphone (PROD-1R).
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: DonySpacing.xxs),
          Text(
            label,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class _PriceStatCard extends StatelessWidget {
  const _PriceStatCard({required this.announcement});

  final AnnouncementModel announcement;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    // Garde sur hasKgPrice (valeur > 0), pas sur la seule nullité :
    // senderPricePerKg n'est en pratique jamais null (pricePerKgDisplay
    // toujours servi), 0 est la vraie valeur trompeuse en mode MIXED.
    if (!announcement.hasKgPrice) {
      return _StatCard(value: '—', label: l.tripPosterPriceUnavailable);
    }
    return _StatCard(
      value: formatPriceIn(
        announcement.searchCardPricePerKg!,
        announcement.currency,
      ),
      // Repère « environ » du même montant (brut expéditeur) dans la devise du
      // lecteur, servi par le détail depuis le lot 5.
      subtitle:
          announcement.searchCardPricePerKgDisplayConverted != null &&
              announcement.convertedCurrency != null
          ? l.listingApproxPricePerKg(
              formatPriceIn(
                announcement.searchCardPricePerKgDisplayConverted!,
                announcement.convertedCurrency,
              ),
            )
          : null,
      label: l.listingPricePerKiloLabel,
      valueColor: cs.primary,
    );
  }
}

/// Carte compacte annonçant la grille tarifaire, avec le nombre d'articles et
/// le prix d'appel le plus bas — le détail vit dans [_PriceGridCard].
class _GridStatCard extends StatelessWidget {
  const _GridStatCard({required this.items, required this.currency});

  final List<AnnouncementGridItemModel> items;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final minPrice =
        items.map((i) => i.unitPriceDisplay).reduce((a, b) => a < b ? a : b) *
        feeIncludedFactor(currency);
    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.blue200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DonyIcon('layout-grid', size: 16, color: cs.primary),
              const SizedBox(width: DonySpacing.xs + 2),
              Flexible(
                child: Text(
                  l.listingPriceGridLabel,
                  style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: cs.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.xxs),
          Text(
            '${l.listingItemCount(items.length)} · '
            '${l.tripPosterFromPrice(formatPriceIn(minPrice, currency))}',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Liste « Tarif par article », plafonnée à [_collapsedCount] lignes : au-delà,
/// un pied « Voir tous les tarifs (N) » déplie le reste sur place pour que la
/// grille ne repousse pas le voyageur et le CTA hors du premier regard.
class _PriceGridCard extends StatefulWidget {
  const _PriceGridCard({
    required this.items,
    required this.currency,
    this.convertedCurrency,
  });

  /// Devise du lecteur pour les équivalents « environ » des items (lot 5).
  final String? convertedCurrency;

  final List<AnnouncementGridItemModel> items;
  final String currency;

  @override
  State<_PriceGridCard> createState() => _PriceGridCardState();
}

class _PriceGridCardState extends State<_PriceGridCard> {
  static const _collapsedCount = 4;

  /// Dépliage purement éphémère — ValueNotifier plutôt que setState pour ne
  /// reconstruire que la liste, pas la carte entière.
  final ValueNotifier<bool> _expanded = ValueNotifier(false);

  @override
  void dispose() {
    _expanded.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.md,
              DonySpacing.md,
              DonySpacing.md,
              DonySpacing.sm,
            ),
            child: Text(
              l.listingPricePerItemTitle,
              style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _expanded,
            builder: (context, expanded, _) {
              final showAll =
                  expanded || widget.items.length <= _collapsedCount;
              final visible = showAll
                  ? widget.items
                  : widget.items.take(_collapsedCount).toList();
              return AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < visible.length; i++) ...[
                      if (i > 0)
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(
                            horizontal: DonySpacing.md,
                          ),
                          color: cs.surfaceContainerHighest,
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DonySpacing.md,
                          vertical: DonySpacing.sm,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                visible[i].label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.bodyMedium,
                              ),
                            ),
                            const SizedBox(width: DonySpacing.sm),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatPriceIn(
                                    visible[i].unitPriceDisplay *
                                        feeIncludedFactor(widget.currency),
                                    widget.currency,
                                  ),
                                  style: tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cs.primary,
                                  ),
                                ),
                                // Équivalent « environ » (lot 5), serveur.
                                if (visible[i].convertedUnitPriceDisplay !=
                                        null &&
                                    widget.convertedCurrency != null)
                                  Text(
                                    l.listingApproxPrice(
                                      formatPriceIn(
                                        visible[i].convertedUnitPriceDisplay! *
                                            feeIncludedFactor(widget.currency),
                                        widget.convertedCurrency,
                                      ),
                                    ),
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (!showAll)
                      InkWell(
                        key: const Key('price-grid-expand'),
                        onTap: () => _expanded.value = true,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            border: Border(top: BorderSide(color: cs.outline)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l.listingSeeAllPricesButton(
                                  widget.items.length,
                                ),
                                style: tt.bodySmall?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: DonySpacing.xs),
                              DonyIcon(
                                'chevron-down',
                                size: 14,
                                color: cs.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Lieux de remise et de récupération du colis — mêmes libellés que la page
/// web publique du trajet, masqués individuellement quand l'annonce (legacy)
/// ne porte pas l'adresse.
class _LocationsCard extends StatelessWidget {
  const _LocationsCard({required this.announcement});

  final AnnouncementModel announcement;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final pickup = announcement.pickupAddress;
    final delivery = announcement.deliveryAddress;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pickup != null && delivery != null)
            _RouteMiniMap(pickup: pickup, delivery: delivery),
          if (pickup != null)
            AddressLocationRow(
              key: const Key('location-pickup'),
              iconAsset: 'upload',
              iconColor: cs.primary,
              iconBackground: cs.primaryContainer,
              title: l.listingPickupParcelTitle,
              address: pickup,
            ),
          if (pickup != null && delivery != null)
            Divider(height: 1, color: cs.surfaceContainerHighest),
          if (delivery != null)
            AddressLocationRow(
              key: const Key('location-delivery'),
              iconAsset: 'download',
              iconColor: DonyColors.accent,
              iconBackground: DonyColors.accentSoft,
              title: l.listingDeliveryPickupTitle,
              address: delivery,
            ),
        ],
      ),
    );
  }
}

/// Mini-carte non interactive de l'itinéraire (remise → récupération), en tête
/// de la card Lieux. Tap = ouvre la carte native centrée sur la remise. En
/// `liteMode` sur Android (bitmap léger) ; sur iOS, une carte figée (tous les
/// gestes désactivés). Un `GestureDetector` par-dessus capte le tap partout.
class _RouteMiniMap extends StatefulWidget {
  const _RouteMiniMap({required this.pickup, required this.delivery});

  final AddressData pickup;
  final AddressData delivery;

  @override
  State<_RouteMiniMap> createState() => _RouteMiniMapState();
}

class _RouteMiniMapState extends State<_RouteMiniMap> {
  /// Cadre la carte sur l'itinéraire à la frame suivante. La feuille peut
  /// être fermée entre-temps : la carte détruite, `animateCamera` lève un
  /// StateError (Sentry FLUTTER-4K). On vérifie `mounted` et on avale l'échec,
  /// le cadrage n'étant qu'un confort visuel.
  void _fitBounds(GoogleMapController controller, LatLngBounds bounds) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        unawaited(
          controller
              .animateCamera(CameraUpdate.newLatLngBounds(bounds, 40))
              .catchError((Object _) {}),
        );
      } on StateError catch (_) {
        // Carte détruite entre le contrôle de mounted et l'appel.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pickup = widget.pickup;
    final delivery = widget.delivery;
    final swLat = pickup.lat < delivery.lat ? pickup.lat : delivery.lat;
    final swLng = pickup.lng < delivery.lng ? pickup.lng : delivery.lng;
    final neLat = pickup.lat > delivery.lat ? pickup.lat : delivery.lat;
    final neLng = pickup.lng > delivery.lng ? pickup.lng : delivery.lng;

    return SizedBox(
      height: 130,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                (pickup.lat + delivery.lat) / 2,
                (pickup.lng + delivery.lng) / 2,
              ),
              zoom: 2,
            ),
            liteModeEnabled: true,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            // Carte figée : le tap est géré par le GestureDetector au-dessus.
            zoomGesturesEnabled: false,
            scrollGesturesEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            markers: {
              Marker(
                markerId: const MarkerId('pickup'),
                position: LatLng(pickup.lat, pickup.lng),
              ),
              Marker(
                markerId: const MarkerId('delivery'),
                position: LatLng(delivery.lat, delivery.lng),
              ),
            },
            onMapCreated: (c) => _fitBounds(
              c,
              LatLngBounds(
                southwest: LatLng(swLat, swLng),
                northeast: LatLng(neLat, neLng),
              ),
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => unawaited(
                openInMaps(
                  getIt<ExternalUrlLauncher>(),
                  lat: pickup.lat,
                  lng: pickup.lng,
                  label: pickup.label,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille d'un réseau mobile money accepté : marque et nom d'opérateur, sans
/// numéro. Même gabarit que [_PaymentChip].
class _MobileMoneyNetworkChip extends StatelessWidget {
  const _MobileMoneyNetworkChip({required this.network, required this.label});

  final MobileMoneyNetwork network;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: DonyBrandMark(brand: network.brand, size: 20),
          ),
          const SizedBox(width: DonySpacing.xs + 2),
          Text(
            label,
            style: tt.bodySmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// « Paiements acceptés » : une puce par moyen, et pour le mobile money une
/// pastille par réseau du voyageur. Ouvert depuis la recherche ou l'accueil,
/// le trajet arrive sans ses réseaux (le back ne les sert qu'au détail) :
/// [TripMobileMoneyNetworksCubit] les relit, la puce générique « Mobile
/// money » reste en attendant ou en cas d'échec. Un trajet déjà issu du détail
/// ([fromDetail]) n'est pas relu.
class _AcceptedPayments extends StatelessWidget {
  const _AcceptedPayments({
    required this.announcement,
    required this.fromDetail,
  });

  final AnnouncementModel announcement;
  final bool fromDetail;

  @override
  Widget build(BuildContext context) {
    // Garde : un point d'ouverture sans DI complète (tests, aperçus) garde
    // les réseaux reçus avec le trajet.
    if (!getIt.isRegistered<TripMobileMoneyNetworksCubit>()) {
      return _content(context, announcement.acceptedMobileMoneyNetworks);
    }
    return BlocProvider<TripMobileMoneyNetworksCubit>(
      // Un autre trajet dans la même feuille repart d'une lecture neuve.
      key: ValueKey(announcement.id),
      create: (_) =>
          getIt<TripMobileMoneyNetworksCubit>()
            ..load(announcement, fromDetail: fromDetail),
      child:
          BlocBuilder<TripMobileMoneyNetworksCubit, List<MobileMoneyNetwork>>(
            builder: _content,
          ),
    );
  }

  Widget _content(BuildContext context, List<MobileMoneyNetwork> networks) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.listingPaymentsAcceptedTitle,
          style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.sm),
        Wrap(
          spacing: DonySpacing.xs + 2,
          runSpacing: DonySpacing.xs,
          children: [
            for (final m in announcement.acceptedPaymentMethods)
              if (m == BidPaymentMethod.mobileMoney && networks.isNotEmpty)
                // Une pastille par compte du voyageur, à la place de la
                // puce générique « Mobile money ».
                for (final n in networks)
                  _MobileMoneyNetworkChip(
                    network: n,
                    label: mobileMoneyNetworkChipLabel(n, networks),
                  )
              else
                _PaymentChip(method: m),
          ],
        ),
        if (networks.isNotEmpty)
          _HabitualOperatorHint(announcement: announcement, networks: networks),
        // Avertissement porté jusqu'ici par le seul écran « Détail annonce ».
        // Il ne relève pas de la présentation : un trajet payé de la main à
        // la main sort du séquestre, donc de toute garantie de remboursement.
        if (announcement.acceptedPaymentMethods.length == 1 &&
            announcement.acceptedPaymentMethods.contains(
              BidPaymentMethod.cash,
            )) ...[
          const SizedBox(height: DonySpacing.md),
          DonyStatusBanner(
            type: DonyStatusBannerType.warning,
            iconAsset: 'triangle-alert',
            messageSpan: TextSpan(
              children: [
                TextSpan(
                  text: l.listingCashOnlyWarningBold,
                  style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: l.listingCashOnlyWarningBody),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Encart orange « Vous payez d'habitude avec {opérateur}, que ce voyageur
/// n'accepte pas » : l'opérateur du dernier paiement ou de la dernière
/// recharge mobile money réussis, gardé sur l'appareil, n'est pas parmi ceux
/// du voyageur. Annonce le repli (carte, sinon espèces) ; rien à dire sans
/// repli.
class _HabitualOperatorHint extends StatelessWidget {
  const _HabitualOperatorHint({
    required this.announcement,
    required this.networks,
  });

  final AnnouncementModel announcement;

  /// Réseaux acceptés par le voyageur (non vide).
  final List<MobileMoneyNetwork> networks;

  @override
  Widget build(BuildContext context) {
    final methods = announcement.acceptedPaymentMethods;
    final card = methods.contains(BidPaymentMethod.stripe);
    final cash = methods.contains(BidPaymentMethod.cash);
    return BlocProvider<HabitualOperatorCubit>(
      // Un autre trajet dans la même feuille repart d'une lecture neuve.
      key: ValueKey(announcement.id),
      create: (_) =>
          getIt<HabitualOperatorCubit>()
            ..load(networks, fallbackAvailable: card || cash),
      child: BlocBuilder<HabitualOperatorCubit, String?>(
        builder: (context, operator) {
          if (operator == null) return const SizedBox.shrink();
          final l = context.l10n;
          return Padding(
            padding: const EdgeInsets.only(top: DonySpacing.md),
            child: DonyStatusBanner(
              type: DonyStatusBannerType.warning,
              iconAsset: 'triangle-alert',
              message: card
                  ? l.listingHabitualOperatorNotAcceptedCard(operator)
                  : l.listingHabitualOperatorNotAcceptedCash(operator),
            ),
          );
        },
      ),
    );
  }
}

/// Chip d'un moyen de paiement accepté (espèces / mobile money / carte).
class _PaymentChip extends StatelessWidget {
  const _PaymentChip({required this.method});

  final BidPaymentMethod method;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final isCash = method == BidPaymentMethod.cash;
    // Le mobile money s'affichait « Carte » : un expéditeur en zone CFA
    // cherchait une carte qui n'existe pas.
    final isMobileMoney = method == BidPaymentMethod.mobileMoney;
    final label = isCash
        ? l.paymentMethodCash
        : isMobileMoney
        ? l.paymentMethodMobileMoney
        : l.paymentMethodCard;
    final icon = isCash
        ? 'banknote'
        : isMobileMoney
        ? 'smartphone'
        : 'credit-card';
    final fg = isCash ? cs.success : cs.primary;
    final bg = isCash ? cs.successLight : cs.primaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm + DonySpacing.xxs,
        vertical: DonySpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon(icon, size: 13, color: fg),
          const SizedBox(width: DonySpacing.xs),
          Text(
            label,
            style: tt.bodySmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Encart « Instructions du voyageur » (consignes de retrait), ton neutre.
class _InstructionsCard extends StatelessWidget {
  const _InstructionsCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceWarm,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonyIcon('info', size: 16, color: cs.warning),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.listingInstructionsCardTitle,
                  style: tt.labelMedium?.copyWith(color: cs.warning),
                ),
                const SizedBox(height: DonySpacing.xxs),
                Text(text, style: tt.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte voyageur compacte — tappable pour ouvrir le profil public complet.
class _TravelerCard extends StatelessWidget {
  const _TravelerCard({required this.announcement});

  final AnnouncementModel announcement;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final traveler = announcement.traveler;
    final rating = traveler?.averageRating;
    final totalTrips = traveler?.totalTrips ?? 0;
    final isKycVerified = traveler?.kycVerified ?? false;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: InkWell(
        key: const Key('traveler-block'),
        borderRadius: BorderRadius.circular(DonyRadius.card),
        onTap: traveler == null
            ? null
            : () => context.push(
                '/profile/public',
                extra: ProfilePublicArgs(userId: traveler.id),
              ),
        child: Padding(
          padding: const EdgeInsets.all(DonySpacing.md),
          child: Row(
            children: [
              DonyAvatar(
                name:
                    traveler?.travelerName(context.l10n) ??
                    context.l10n.tripTravelerFallbackName,
                imageUrl: traveler?.avatarUrl,
                verified: isKycVerified,
                pro: traveler?.isProAccount ?? false,
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            traveler?.travelerName(context.l10n) ??
                                context.l10n.tripTravelerFallbackName,
                            style: tt.titleLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isKycVerified) ...[
                          const SizedBox(width: DonySpacing.xs),
                          const _KycVerifiedBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: DonySpacing.xxs),
                    Row(
                      children: [
                        DonyIcon('star', size: 14, color: cs.warning),
                        const SizedBox(width: DonySpacing.xxs),
                        Text(
                          rating != null
                              ? '${rating.toStringAsFixed(1)}/5'
                              : context.l10n.listingNewRatingLabel,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: DonySpacing.xs),
                        // Flexible : à 360 px la ligne débordait de 13 px.
                        Flexible(
                          child: Text(
                            context.l10n.listingTravelerTrips(totalTrips),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              DonyIcon('chevron-right', size: 20, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(DonyRadius.xl),
        border: Border.all(color: cs.outline),
      ),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}

class _KycVerifiedBadge extends StatelessWidget {
  const _KycVerifiedBadge();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const Key('traveler-kyc-badge'),
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: cs.successLight,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon('badge-check', size: 11, color: cs.success),
          const SizedBox(width: DonySpacing.xxs),
          Text(
            context.l10n.listingIdentityBadge,
            style: tt.labelSmall?.copyWith(
              color: cs.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
