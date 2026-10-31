import 'dart:async';

import 'package:dony/core/config/api_config.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/core/utils/share_position.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/billing/presentation/pro_limit_dialog.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/presentation/widgets/cancellation_bottom_sheet.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/trip_group_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/matching/presentation/widgets/recipient_contact/notify_recipients_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_announcement_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/live_trip.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_arrival.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_bid_answer.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_owner_body.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_owner_options_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_owner_sticky_bar.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_routes.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_live.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_tiles.dart';
import 'package:dony/features/tracking/bloc/tracking_consent_cubit.dart';
import 'package:dony/features/tracking/bloc/trip_depart_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

/// Écran plein écran « Trajet » côté propriétaire (voyageur).
///
/// Barre d'application : retour, icône de partage de l'affiche (trajet
/// ouvert), menu ⋮ ([TripOwnerOptionsButton]), scarabée. Corps en tableau de
/// bord ([TripOwnerBody] : billet, carte de statut, « À traiter » avec la
/// réponse directe aux demandes, ligne Colis, « Votre trajet ») ;
/// pied collant hors du défilement ([TripOwnerStickyBar], un ou deux
/// boutons). Le [TripBidAnswerScope] est posé au-dessus des trois.
///
/// L'écran possède les blocs de la route et en écoute les suites : les
/// actions lancées depuis le pied, le menu ou les sheets (publier, dépublier,
/// reporter, annuler, supprimer, marquer l'arrivée) aboutissent ici
/// (snackbars, écran de succès, relectures, sortie). Il fournit aussi le
/// `TripDepartCubit` du trajet, partagé par la tuile « Je pars » et son
/// sheet.
class TripOwnerDetailScreen extends StatefulWidget {
  const TripOwnerDetailScreen({
    super.key,
    required this.announcementId,
    this.initial,
  });

  /// Identifiant du trajet — sert au rechargement via [AnnouncementBloc].
  final String announcementId;

  /// Annonce passée en `extra` au moment de la navigation. Permet un premier
  /// rendu instantané pendant que le détail complet se recharge.
  final AnnouncementModel? initial;

  @override
  State<TripOwnerDetailScreen> createState() => _TripOwnerDetailScreenState();
}

class _TripOwnerDetailScreenState extends State<TripOwnerDetailScreen> {
  /// Dernière annonce connue (chargée ou passée en `extra`) — sert de repli
  /// pour construire les [CreateTripArgs] quand le listener reçoit un state
  /// d'erreur (ex. [AnnouncementDepartureDatePassed]) qui ne porte pas le
  /// modèle complet.
  AnnouncementModel? _current;

  /// Dernier modèle reçu de `GET /announcements/{id}`. Le modèle passé en
  /// `extra` vient de la liste, sans réseaux mobile money : seul celui-ci dit
  /// que « aucun réseau » est la réponse du back.
  AnnouncementModel? _detailModel;

  /// L'écran a déjà été quitté au profit de la vue expéditeur — ne jamais
  /// rediriger deux fois (les listeners Auth et Announcement peuvent tous deux
  /// aboutir au même verdict).
  bool _leftForSenderView = false;

  /// `trip_owner_detail_opened` déjà émis — l'événement ne compte que les
  /// ouvertures par le propriétaire confirmé, une seule fois par écran.
  bool _loggedOwnerOpen = false;

  /// Le trajet vient d'être marqué arrivé : à la liste des colis rechargée
  /// (statuts passés à ARRIVED), la feuille « Prévenir les destinataires »
  /// s'ouvre d'elle-même. Mutée hors `setState`, elle ne pilote aucun rendu.
  bool _notifyAfterArrival = false;

  /// Consentement au suivi demandé à l'ouverture (au plus une fois par écran).
  bool _askedTrackingConsent = false;

  @override
  void initState() {
    super.initState();
    _current = widget.initial;
    // Étapes du voyage (FLUTTER-4D) lues dès l'ouverture : le cubit de la
    // route est paresseux, et la carte des étapes qui le créait a rejoint le
    // sheet « Itinéraire et lieux ». Sans cette lecture, « Supprimer » ne
    // proposait plus d'annuler les étapes suivantes tant que ce sheet
    // n'avait pas été ouvert.
    maybeRead<TripGroupCubit>(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final a = _current;
      if (mounted && a != null) {
        _evaluateViewer(context, a);
      }
    });
  }

  /// Trajet ouvert par son propriétaire pendant la fenêtre de suivi : la
  /// feuille de consentement se montre au plus une fois dans la vie du
  /// compte (le cubit mémorise la réponse). Ne bloque rien.
  ///
  /// Seulement pour un trajet publié, complet ou en cours
  /// ([tripTrackingStatusOpen], même règle que « Je pars ») : le back sert la
  /// fenêtre ouverte sans regarder le statut, un trajet annulé avec un colis
  /// remis en retour la verrait encore ouverte.
  void _askTrackingConsentOnce(AnnouncementModel a) {
    if (_askedTrackingConsent ||
        !a.trackingActive ||
        !tripTrackingStatusOpen(a.status)) {
      return;
    }
    _askedTrackingConsent = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        getIt<TrackingConsentCubit>().ensureAsked(
          context,
          source: TrackingConsentSource.tripScreen,
        ),
      );
    });
  }

  /// Verdict d'appartenance : `true`/`false` quand l'état d'auth est tranché,
  /// `null` tant qu'il ne l'est pas. Au démarrage à froid via deep link,
  /// l'AuthBloc peut encore être en cours de résolution : classer alors le
  /// propriétaire en visiteur l'enverrait à tort vers la vue expéditeur, donc
  /// on attend un état définitif (authentifié ou session invité).
  bool? _ownershipVerdict(AuthState authState, AnnouncementModel a) {
    final currentUserId = authState.currentUserId;
    if (currentUserId != null) {
      return a.travelerId == currentUserId;
    }
    if (authState is AuthGuestSessionReady) {
      return false;
    }
    return null;
  }

  /// Le lien d'affiche partagée (`yadony://annonce/{id}`) fait atterrir tout le
  /// monde ici. Un visiteur qui n'est pas le voyageur propriétaire ne doit pas
  /// voir l'écran propriétaire : on le renvoie vers la vue expéditeur du feed
  /// (sheet « Faire une demande » / « Proposer un prix »). Le propriétaire
  /// confirmé reste, et c'est à ce moment-là que `trip_owner_detail_opened`
  /// est émis.
  void _evaluateViewer(BuildContext context, AnnouncementModel a) {
    if (_leftForSenderView) {
      return;
    }
    AuthState authState;
    try {
      authState = context.read<AuthBloc>().state;
    } catch (_) {
      return;
    }
    final verdict = _ownershipVerdict(authState, a);
    if (verdict == null) {
      return;
    }
    if (verdict) {
      if (!_loggedOwnerOpen) {
        _loggedOwnerOpen = true;
        unawaited(
          getIt<AnalyticsService>().logEvent(
            AnalyticsEvents.tripOwnerDetailOpened,
            properties: {'status': a.status},
          ),
        );
      }
      return;
    }
    _leftForSenderView = true;
    // Contexte du navigateur racine, capturé AVANT le pop : il survit à la
    // fermeture de cet écran et se trouve sous les blocs globaux de app.dart
    // (AuthBloc, BidBloc) que la sheet lit.
    final rootCtx = Navigator.of(context, rootNavigator: true).context;
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/home');
    }
    showTravelerAnnouncementSheet(
      rootCtx,
      announcement: a,
      fromDetail: identical(a, _detailModel),
    );
  }

  /// Dernier trajet connu hors des états qui le portent (erreurs, chargement).
  AnnouncementModel? _known() => _current ?? widget.initial;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final id = widget.announcementId;

    // « Je pars » : la tuile « À traiter » et son sheet lisent le même cubit
    // (état « parti » partagé), fourni au-dessus de la barre, du corps et du
    // pied.
    return BlocProvider<TripDepartCubit>(
      create: (_) => getIt<TripDepartCubit>(param1: id),
      // Réponse directe aux demandes (carte « Demande 1 sur N », sheet des
      // demandes) : au-dessus de la barre, du corps et du pied, sous les
      // blocs de la route qu'elle relit après chaque réponse. Le pied
      // « Voir les demandes (N) » suit ainsi les réponses données depuis
      // l'écran. Ses blocs ne sont créés qu'à la première réponse : un
      // visiteur n'en crée aucun.
      child: TripBidAnswerScope(
        tripId: id,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: DonyAppBar(
            title: context.l10n.listingHeroTripLabel,
            // Partage à portée de pouce, puis le menu ⋮ ; le scarabée suit.
            // Toujours montés une fois le trajet connu : chacun décide de se
            // masquer, son contexte (d'où partent ses actions) reste stable.
            actions: [
              _LiveTrip(
                tripId: id,
                known: _known,
                builder: (context, live, isOwner) =>
                    isOwner && canShareTripPoster(live.trip)
                    ? IconButton(
                        key: const Key('trip-owner-share-button'),
                        tooltip: context.l10n.tripPosterShareButton,
                        icon: const DonyIcon('share-2', size: 22),
                        onPressed: () => openTripPoster(context, live.trip),
                      )
                    : const SizedBox.shrink(),
              ),
              _LiveTrip(
                tripId: id,
                known: _known,
                builder: (context, live, isOwner) => TripOwnerOptionsButton(
                  trip: live.trip,
                  bids: live.bids,
                  isOwner: isOwner,
                ),
              ),
            ],
          ),
          body: MultiBlocListener(
            listeners: [
              BlocListener<AuthBloc, AuthState>(
                listener: (context, _) {
                  final a = _current;
                  if (a != null) {
                    _evaluateViewer(context, a);
                  }
                },
              ),
              BlocListener<BidBloc, BidState>(listener: _onBidState),
              BlocListener<CancellationBloc, CancellationState>(
                listener: _onCancellationState,
              ),
              // « Je pars » confirmé, sheet ouvert ou déjà refermé pendant
              // l'appel : la confirmation part de l'écran (le message est
              // dédoublonné avec celle du bouton du sheet).
              BlocListener<TripDepartCubit, TripDepartState>(
                listenWhen: (a, b) => !a.departed && b.departed,
                listener: (context, _) => DonySnackbar.show(
                  context,
                  message: context.l10n.tripDepartConfirmedSnackbar,
                  type: DonySnackbarType.success,
                ),
              ),
            ],
            child: BlocConsumer<AnnouncementBloc, AnnouncementState>(
              listener: _onAnnouncementState,
              builder: (context, state) {
                final a = state is AnnouncementDetailLoaded
                    ? state.announcement
                    : _known();
                if (a == null) {
                  // Détail en échec sans trajet à montrer (ouvert par une
                  // notification ou un lien, sans `extra`) : un état d'erreur
                  // avec « Réessayer » plutôt qu'un squelette sans fin.
                  if (state is AnnouncementError) {
                    return _LoadError(
                      error: state.error,
                      onRetry: () => context.read<AnnouncementBloc>().add(
                        AnnouncementDetailRequested(id),
                      ),
                    );
                  }
                  return const DonyDetailSkeleton();
                }
                return _OwnerOf(
                  trip: a,
                  builder: (context, isOwner) {
                    if (isOwner) _askTrackingConsentOnce(a);
                    return TripOwnerBody(
                      trip: a,
                      isOwner: isOwner,
                      bottomPadding: safeBottom,
                    );
                  },
                );
              },
            ),
          ),
          bottomNavigationBar: _LiveTrip(
            tripId: id,
            known: _known,
            builder: (context, live, isOwner) => TripOwnerStickyBar(
              trip: live.trip,
              bids: live.bids,
              isOwner: isOwner,
            ),
          ),
        ),
      ),
    );
  }

  /// Suites des actions du trajet (pied, menu, sheets) et relectures.
  void _onAnnouncementState(BuildContext context, AnnouncementState state) {
    final id = widget.announcementId;
    if (state is AnnouncementDetailLoaded) {
      _current = state.announcement;
      _detailModel = state.announcement;
      _evaluateViewer(context, state.announcement);
    } else if (state is AnnouncementUpdated) {
      _current = state.announcement;
    } else if (state is AnnouncementTripArrived) {
      _current = state.announcement;
      _notifyAfterArrival = true;
      // Pas silencieuse : un échec doit abandonner l'ouverture automatique
      // de « Prévenir les destinataires » (BidError).
      context.read<BidBloc>().add(BidListRequested(id));
    } else if (state is AnnouncementRescheduled) {
      _current = state.announcement;
      context.read<BidBloc>().add(BidListRequested(id, silent: true));
    } else if (state is AnnouncementArrivalInstructionsUpdated) {
      _current = state.announcement;
      context.read<BidBloc>().add(BidListRequested(id, silent: true));
    }
    if (state is AnnouncementDeleted) {
      DonySnackbar.show(
        context,
        message: state.followingFailed > 0
            ? context.l10n.tripLegsFollowingFailed(state.followingFailed)
            : context.l10n.tripOwnerDeletedSnackbar,
        type: state.followingFailed > 0
            ? DonySnackbarType.warning
            : DonySnackbarType.success,
      );
      if (context.mounted) {
        context.pop(true);
      }
    } else if (state is AnnouncementNotFound) {
      DonySnackbar.show(
        context,
        message: context.l10n.listingAnnouncementGoneMessage,
        type: DonySnackbarType.warning,
      );
      if (context.mounted) {
        context.pop(true);
      }
    } else if (state is AnnouncementDeleteBlockedByAcceptedBid) {
      unawaited(_onDeleteBlocked(context, state.announcementId));
    } else if (state is AnnouncementPublished) {
      _current = state.announcement;
      context.read<AnnouncementBloc>().add(AnnouncementDetailRequested(id));
      _showPublished(context, state.announcement);
    } else if (state is AnnouncementKycRequired) {
      DonySnackbar.show(
        context,
        message: ErrorPresenter.resolve(
          state.error,
          l10n: context.l10n,
        ).message,
        type: DonySnackbarType.warning,
      );
      context.push('/kyc/status');
    } else if (state is AnnouncementDepartureDatePassed) {
      DonySnackbar.show(
        context,
        message: ErrorPresenter.resolve(
          state.error,
          l10n: context.l10n,
        ).message,
        type: DonySnackbarType.warning,
      );
      unawaited(_onDepartureDatePassed(context));
    } else if (state is AnnouncementProLimitReached) {
      unawaited(_onProLimitReached(context, state.error));
    } else if (state is AnnouncementError) {
      // Sans trajet affiché, l'état d'erreur de l'écran le dit déjà.
      if (_known() != null) ErrorPresenter.show(context, state.error);
    }
  }

  /// Écran de succès « Trajet publié » (brouillon publié depuis le pied).
  void _showPublished(BuildContext context, AnnouncementModel published) {
    final l = context.l10n;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeContext) => DonySuccessScreen(
          mascotteType: DonyMascotteType.succes,
          title: l.tripOwnerPublishedTitle,
          subtitle: l.tripOwnerPublishedSubtitle(
            published.departureCity,
            published.arrivalCity,
          ),
          ctaLabel: l.commonContinue,
          ctaVariant: DonyButtonVariant.accent,
          onCta: () => Navigator.of(
            routeContext,
          ).pop(), // revient au détail, déjà rafraîchi
          analyticsContext: 'trip_draft_published',
          secondaryLabel: l.tripOwnerShareMyTrip,
          onSecondary: () => unawaited(
            Share.share(
              l.tripOwnerShareMessage(
                published.departureCity,
                published.arrivalCity,
                DateFormat.MMMMd(l.localeName).format(published.departureDate),
                '$posterShareBaseUrl/annonce/${published.id}',
              ),
              sharePositionOrigin: sharePositionOriginFor(routeContext),
            ),
          ),
        ),
      ),
    );
  }

  /// Après « Marquer arrivé », la liste des colis se recharge : dès qu'elle
  /// arrive, la feuille « Prévenir les destinataires » s'ouvre sur les colis
  /// concernés. Un échec de rechargement abandonne l'ouverture automatique,
  /// le bouton de l'écran reste là.
  void _onBidState(BuildContext context, BidState state) {
    if (!_notifyAfterArrival) {
      return;
    }
    if (state is BidListLoaded) {
      _notifyAfterArrival = false;
      unawaited(
        NotifyRecipientsSheet.show(
          context,
          bids: state.bids,
          source: NotifyRecipientsSource.afterArrival,
          instructions: _current?.arrivalInstructions,
        ),
      );
    } else if (state is BidError || state is BidNotFound) {
      _notifyAfterArrival = false;
    }
  }

  /// Issue de l'annulation du trajet, envoyée depuis [CancellationBottomSheet]
  /// une fois la feuille fermée : l'écran se recharge pour montrer le trajet
  /// et ses colis annulés. Sans cela, il restait affiché tel quel et le
  /// voyageur croyait l'annulation ratée (FLUTTER-FH).
  void _onCancellationState(BuildContext context, CancellationState state) {
    if (state is CancellationSuccess) {
      final l = context.l10n;
      final toReturn = state.cancellation.parcelsToReturnCount;
      DonySnackbar.show(
        context,
        message: toReturn > 0
            ? l.cancellationTripCanceledWithReturnsSnackbar(toReturn)
            : l.cancellationTripCanceledSnackbar,
        type: DonySnackbarType.success,
      );
      context.read<AnnouncementBloc>().add(
        AnnouncementDetailRequested(widget.announcementId),
      );
      context.read<BidBloc>().add(
        BidListRequested(widget.announcementId, silent: true),
      );
    } else if (state is CancellationError) {
      ErrorPresenter.show(context, state.error);
    }
  }

  /// Colis du trajet déjà remis au voyageur : leur retour s'ouvre à
  /// l'annulation, la feuille d'annulation le signale.
  int _handedOverParcels(BuildContext context) {
    final state = context.read<BidBloc>().state;
    return tripHandedOverParcelCount(
      state is BidListLoaded ? state.bids : null,
    );
  }

  /// Suppression bloquée par un colis déjà accepté — propose l'annulation du
  /// voyage.
  Future<void> _onDeleteBlocked(
    BuildContext context,
    String announcementId,
  ) async {
    final l = context.l10n;
    final confirmed = await DonyDialog.show(
      context,
      title: l.tripOwnerDeleteBlockedTitle,
      message: l.tripOwnerDeleteBlockedMessage,
      confirmLabel: l.tripOwnerCancelTripButton,
      cancelLabel: l.commonClose,
      variant: DonyDialogVariant.destructive,
      iconAsset: 'calendar-x',
    );
    if (confirmed == true && context.mounted) {
      await CancellationBottomSheet.show(
        context,
        announcementId: announcementId,
        handedOverParcels: _handedOverParcels(context),
      );
    }
  }

  /// La date de départ est passée : publication refusée tant que
  /// l'utilisateur ne corrige pas la date. Ouvre directement l'édition.
  Future<void> _onDepartureDatePassed(BuildContext context) async {
    final current = _current;
    if (current == null) {
      return;
    }
    final changed = await context.push<bool>(
      '/trips/create',
      extra: CreateTripArgs(announcement: current),
    );
    if ((changed ?? false) && context.mounted) {
      context.read<AnnouncementBloc>().add(
        AnnouncementDetailRequested(widget.announcementId),
      );
    }
  }

  /// Limite mensuelle de trajets PRO atteinte — invite à passer PRO (pattern
  /// repris de [CreateTripScreen]).
  Future<void> _onProLimitReached(
    BuildContext context,
    AppException error,
  ) async {
    final goPro = await showProLimitReachedDialog(
      context,
      title: context.l10n.tripOwnerProLimitTitle,
      message: ErrorPresenter.resolve(error, l10n: context.l10n).message,
    );
    if (goPro && context.mounted) {
      unawaited(context.push('/profile/upgrade-to-pro'));
    }
  }
}

/// Rend [builder] avec les dernières données du trajet [tripId] (trajet relu,
/// derniers colis chargés, [TripTodoLive]) et le verdict de propriété, dès
/// que le trajet est connu ([known] : `extra` ou dernier relu). Une fois le
/// trajet connu, le widget rendu reste monté : la barre d'application et le
/// pied gardent un contexte stable, d'où partent leurs actions.
class _LiveTrip extends StatelessWidget {
  const _LiveTrip({
    required this.tripId,
    required this.known,
    required this.builder,
  });

  final String tripId;
  final AnnouncementModel? Function() known;
  final Widget Function(
    BuildContext context,
    TripTodoLiveData live,
    bool isOwner,
  )
  builder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnnouncementBloc, AnnouncementState>(
      buildWhen: (_, state) => tripAnnouncementIn(state, tripId) != null,
      builder: (context, state) {
        final trip = tripAnnouncementIn(state, tripId) ?? known();
        if (trip == null) return const SizedBox.shrink();
        return TripTodoLive(
          trip: trip,
          blocs: TripTodoBlocs.of(context),
          builder: (context, live) => _OwnerOf(
            trip: live.trip,
            builder: (context, isOwner) => builder(context, live, isOwner),
          ),
        );
      },
    );
  }
}

/// Le voyageur connecté est-il le propriétaire de [trip] ? Suit l'`AuthBloc`
/// global : une session qui se tranche après l'ouverture (démarrage à froid
/// par un lien) reconstruit le verdict. Sans `AuthBloc` dans l'arbre, ou
/// tant que la session n'est pas tranchée : non (rien du voyageur ne fuit).
class _OwnerOf extends StatelessWidget {
  const _OwnerOf({required this.trip, required this.builder});

  final AnnouncementModel trip;
  final Widget Function(BuildContext context, bool isOwner) builder;

  @override
  Widget build(BuildContext context) {
    if (maybeRead<AuthBloc>(context) == null) return builder(context, false);
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (a, b) => a.currentUserId != b.currentUserId,
      builder: (context, auth) {
        final userId = auth.currentUserId;
        return builder(context, userId != null && trip.travelerId == userId);
      },
    );
  }
}

/// Détail du trajet introuvable faute de réseau (ou refusé) alors qu'aucun
/// trajet n'est affiché : le motif et « Réessayer ».
class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final AppException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: DonyEmptyState(
        key: const Key('trip-owner-load-error'),
        type: DonyEmptyStateType.error,
        iconAsset: 'circle-alert',
        title: l.commonLoadError,
        description: ErrorPresenter.resolve(error, l10n: l).message,
        actionLabel: l.commonRetry,
        onAction: onRetry,
      ),
    );
  }
}
