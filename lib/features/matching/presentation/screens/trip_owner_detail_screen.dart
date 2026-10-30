import 'dart:async';

import 'package:dony/core/config/api_config.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
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
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_detail_body.dart';
import 'package:dony/features/matching/presentation/widgets/arrival_instructions_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/arrival_instructions_card.dart';
import 'package:dony/features/matching/presentation/widgets/owner_action_grid.dart';
import 'package:dony/features/matching/presentation/widgets/recipient_contact/notify_recipients_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_announcement_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/trip_audience_section.dart';
import 'package:dony/features/matching/presentation/widgets/trip_depart_button.dart';
import 'package:dony/features/matching/presentation/widgets/trip_legs_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_arrival.dart';
import 'package:dony/features/matching/presentation/widgets/trip_parcels_section.dart';
import 'package:dony/features/matching/presentation/widgets/trip_summary_card.dart';
import 'package:dony/features/tracking/bloc/tracking_consent_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

/// Écran plein écran « Trajet » côté propriétaire (voyageur).
///
/// Bouton retour + bouton de signalement de bug dans l'AppBar, puis, dans l'ordre :
/// le détail complet du trajet via [AnnouncementDetailBody], la grille d'actions
/// [OwnerActionGrid] (Demandes / Colis / Modifier / Supprimer) et la section des
/// colis déjà embarqués [TripParcelsSection].
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
  void _askTrackingConsentOnce(AnnouncementModel a) {
    if (_askedTrackingConsent || !a.trackingActive) {
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

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DonyAppBar(
        title: context.l10n.listingHeroTripLabel,
        // Partage à portée de pouce : la tuile « Affiche » de la grille reste
        // en bas de page, sous le détail du trajet.
        actions: [
          BlocBuilder<AnnouncementBloc, AnnouncementState>(
            builder: (context, state) {
              final a = state is AnnouncementDetailLoaded
                  ? state.announcement
                  : (_current ?? widget.initial);
              if (a == null ||
                  !_isOwner(context, a) ||
                  !canShareTripPoster(a)) {
                return const SizedBox.shrink();
              }
              return IconButton(
                key: const Key('trip-owner-share-button'),
                tooltip: context.l10n.tripPosterShareButton,
                icon: const DonyIcon('share-2', size: 22),
                onPressed: () => openTripPoster(context, a),
              );
            },
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
        ],
        child: BlocConsumer<AnnouncementBloc, AnnouncementState>(
          listener: (context, state) {
            if (state is AnnouncementDetailLoaded) {
              _current = state.announcement;
              _detailModel = state.announcement;
              _evaluateViewer(context, state.announcement);
            } else if (state is AnnouncementUpdated) {
              _current = state.announcement;
            } else if (state is AnnouncementTripArrived) {
              _current = state.announcement;
              _notifyAfterArrival = true;
              context.read<BidBloc>().add(
                BidListRequested(widget.announcementId),
              );
            } else if (state is AnnouncementRescheduled) {
              _current = state.announcement;
              context.read<BidBloc>().add(
                BidListRequested(widget.announcementId),
              );
            } else if (state is AnnouncementArrivalInstructionsUpdated) {
              _current = state.announcement;
              context.read<BidBloc>().add(
                BidListRequested(widget.announcementId),
              );
            }
            if (state is AnnouncementDeleted) {
              DonySnackbar.show(
                context,
                message: state.followingFailed > 0
                    ? context.l10n.tripLegsFollowingFailed(
                        state.followingFailed,
                      )
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
              context.read<AnnouncementBloc>().add(
                AnnouncementDetailRequested(widget.announcementId),
              );
              final l = context.l10n;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (routeContext) => DonySuccessScreen(
                    mascotteType: DonyMascotteType.succes,
                    title: l.tripOwnerPublishedTitle,
                    subtitle: l.tripOwnerPublishedSubtitle(
                      state.announcement.departureCity,
                      state.announcement.arrivalCity,
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
                          state.announcement.departureCity,
                          state.announcement.arrivalCity,
                          DateFormat.MMMMd(
                            l.localeName,
                          ).format(state.announcement.departureDate),
                          '$posterShareBaseUrl/annonce/${state.announcement.id}',
                        ),
                        sharePositionOrigin: sharePositionOriginFor(
                          routeContext,
                        ),
                      ),
                    ),
                  ),
                ),
              );
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
              ErrorPresenter.show(context, state.error);
            }
          },
          builder: (context, state) {
            final a = state is AnnouncementDetailLoaded
                ? state.announcement
                : (_current ?? widget.initial);
            if (a == null) {
              return const DonyDetailSkeleton();
            }
            final isOwner = _isOwner(context, a);
            if (isOwner) {
              _askTrackingConsentOnce(a);
            }
            final summary = isOwner ? a.parcelsSummary : null;
            final hasSummary = summary != null && summary.count > 0;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.md,
                DonySpacing.lg,
                DonySpacing.lg + safeBottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (a.status == 'DRAFT') ...[
                    DonyStatusBanner(
                      type: DonyStatusBannerType.warning,
                      title: context.l10n.tripOwnerDraftBannerTitle,
                      message: context.l10n.tripOwnerDraftBannerMessage,
                    ),
                    const SizedBox(height: DonySpacing.md),
                  ],
                  AnnouncementDetailBody(
                    a: a,
                    onEnableCardOnTrip: isOwner
                        ? () => unawaited(_openEditToEnableCard(context))
                        : null,
                  ),
                  const SizedBox(height: DonySpacing.lg),
                  // Voyage à plusieurs étapes (FLUTTER-4D).
                  TripLegsCard(
                    announcementId: a.id,
                    padding: const EdgeInsets.only(bottom: DonySpacing.lg),
                    onOpenLeg: (leg) =>
                        context.push('/announcements/${leg.id}/trip'),
                  ),
                  if (hasSummary) ...[
                    TripSummaryCard(summary: summary),
                    if (a.trackingActive) ...[
                      const SizedBox(height: DonySpacing.md),
                      TripDepartButton(announcementId: a.id),
                    ],
                    const SizedBox(height: DonySpacing.lg),
                  ],
                  if (isOwner) TripAudienceSection(announcementId: a.id),
                  OwnerActionGrid(a: a, isOwner: isOwner),
                  const SizedBox(height: DonySpacing.lg),
                  TripParcelsSection(announcementId: a.id),
                  // Relecture du texte envoyé aux expéditeurs : le voyageur ne
                  // le voyait que dans la feuille d'édition, qui disparaît avec
                  // le dernier colis actif.
                  if (isOwner &&
                      ArrivalInstructionsCard.hasText(a.arrivalInstructions))
                    Padding(
                      padding: const EdgeInsets.only(top: DonySpacing.md),
                      child: ArrivalInstructionsCard(
                        instructions: a.arrivalInstructions!,
                      ),
                    ),
                  BlocBuilder<BidBloc, BidState>(
                    builder: (context, bidState) {
                      if (!isOwner || bidState is! BidListLoaded) {
                        return const SizedBox.shrink();
                      }
                      final cta = tripArrivalCtaFor(bidState.bids);
                      final toNotify = recipientsToNotify(bidState.bids);
                      if (cta == null && toNotify.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      final isEditing = cta == TripArrivalCta.editInstructions;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (cta != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: DonySpacing.md,
                              ),
                              child: DonyButton(
                                label: isEditing
                                    ? context
                                          .l10n
                                          .tripOwnerEditInstructionsButton
                                    : context.l10n.tripOwnerMarkArrivedButton,
                                variant: isEditing
                                    ? DonyButtonVariant.secondary
                                    : DonyButtonVariant.primary,
                                onPressed: () =>
                                    ArrivalInstructionsBottomSheet.show(
                                      context,
                                      announcementId: a.id,
                                      initialInstructions:
                                          a.arrivalInstructions,
                                      isEditing: isEditing,
                                    ),
                              ),
                            ),
                          // Destinataires des colis remis, en transit ou
                          // arrivés : message pré-rempli WhatsApp / SMS, ou
                          // appel.
                          if (toNotify.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: DonySpacing.sm,
                              ),
                              child: DonyButton(
                                key: const Key('notify-recipients-button'),
                                label: context.l10n.notifyRecipientsButton(
                                  toNotify.length,
                                ),
                                iconAsset: 'message-circle',
                                variant: DonyButtonVariant.ghost,
                                onPressed: () => NotifyRecipientsSheet.show(
                                  context,
                                  bids: bidState.bids,
                                  source: NotifyRecipientsSource.manual,
                                  instructions: a.arrivalInstructions,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
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

  /// Détermine si l'utilisateur courant est le voyageur propriétaire du trajet.
  ///
  /// Lit l'`AuthBloc` global (fourni par l'app, instance unique). En l'absence
  /// d'utilisateur authentifié — ou si le provider n'est pas dans l'arbre —
  /// considère que ce n'est pas le propriétaire (sécurité non-propriétaire).
  bool _isOwner(BuildContext context, AnnouncementModel a) {
    AuthState authState;
    try {
      authState = context.read<AuthBloc>().state;
    } catch (_) {
      return false;
    }
    final currentUserId = authState.currentUserId;
    return currentUserId != null && a.travelerId == currentUserId;
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
      context.read<BidBloc>().add(BidListRequested(widget.announcementId));
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

  /// Trajet publié en espèces avant l'activation de Stripe : l'édition
  /// propose désormais la carte (statut rechargé à l'ouverture), puis le
  /// détail est relu pour que l'encart disparaisse (Sentry FLUTTER-DH).
  Future<void> _openEditToEnableCard(BuildContext context) async {
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
