import 'dart:async';

import 'package:share_plus/share_plus.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/payments/data/models/payment_model.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/presentation/widgets/cancellation_dialog.dart';
import 'package:dony/features/matching/presentation/widgets/colis_card.dart';
import 'package:dony/features/matching/presentation/widgets/destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/expediteur_card.dart';
import 'package:dony/features/matching/presentation/widgets/handover_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/billet/colis_billet.dart';
import 'package:dony/features/matching/presentation/widgets/sender_profile_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/suivi_button.dart';
import 'package:dony/features/matching/presentation/widgets/voyageur_card.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/ratings/presentation/widgets/rating_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/disclaimer_card.dart';
import 'package:dony/features/matching/presentation/widgets/handover_card.dart';
import 'package:dony/features/matching/presentation/widgets/payment_release_card.dart';
import 'package:dony/features/matching/presentation/widgets/action_bars/bid_detail_action_bars.dart';
import 'package:dony/features/matching/presentation/widgets/trajet_card.dart';

class BidDetailScreen extends StatelessWidget {
  final BidModel bid;

  /// When true, the back arrow goes to /home (the sender's "mes envois") instead
  /// of popping the navigation stack. Used after a fresh payment so the user
  /// doesn't go back to the create-bid form.
  final bool fromPayment;

  const BidDetailScreen({
    super.key,
    required this.bid,
    this.fromPayment = false,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<BidBloc>()),
        BlocProvider(create: (_) => getIt<BidAcceptanceBloc>()),
        BlocProvider(create: (_) => getIt<TrackingBloc>()),
        BlocProvider(create: (_) => getIt<ConversationOpenBloc>()),
        BlocProvider(create: (_) => getIt<RatingBloc>()),
        BlocProvider(create: (_) => getIt<CancellationBloc>()),
      ],
      child: _BidDetailView(initialBid: bid, fromPayment: fromPayment),
    );
  }
}

class _BidDetailView extends StatefulWidget {
  final BidModel initialBid;
  final bool fromPayment;
  const _BidDetailView({required this.initialBid, this.fromPayment = false});

  @override
  State<_BidDetailView> createState() => _BidDetailViewState();
}

class _BidDetailViewState extends State<_BidDetailView> {
  late BidModel _bid;
  bool _skeletonLoading = false;
  Timer? _refreshTimer;

  final _existingPaymentNotifier = ValueNotifier<PaymentModel?>(null);
  final _paymentLoadedNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _bid = widget.initialBid;
    _skeletonLoading = _bid.isSkeleton;
    context.read<BidBloc>().add(BidDetailRequested(_bid.id));
    _loadPaymentStatus();
    if (_bid.status == 'ACCEPTED' ||
        _bid.status == 'HANDED_OVER' ||
        _bid.status == 'IN_TRANSIT') {
      _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (mounted) context.read<BidBloc>().add(BidDetailRequested(_bid.id));
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _existingPaymentNotifier.dispose();
    _paymentLoadedNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentStatus() async {
    if (_bid.status == 'REJECTED' || _bid.status == 'CANCELLED') {
      return;
    }
    try {
      final payment = await getIt<PaymentRepository>().getPaymentForBid(
        _bid.id,
      );
      if (mounted) {
        _existingPaymentNotifier.value = payment;
        _paymentLoadedNotifier.value = true;
      }
    } catch (_) {
      if (mounted) _paymentLoadedNotifier.value = true;
    }
  }

  void _showCardDeclinedSheet(BuildContext context, String message) {
    DonyBottomSheet.show<void>(
      context,
      title: 'Paiement refusé',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: DonyColors.textPrimary)),
          const SizedBox(height: 8),
          Text(
            'Changez votre carte de commission pour accepter cette demande.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: DonyColors.textMuted),
          ),
        ],
      ),
      stickyBottom: DonyButton(
        label: 'Changer ma carte de commission',
        onPressed: () {
          context.pop();
          context.push('/payments/commission-method');
        },
      ),
    );
  }

  void _showWalletInsufficientSheet(
      BuildContext context, acs.BidWalletInsufficient state) {
    DonyBottomSheet.show<void>(
      context,
      title: 'Solde insuffisant',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Commission requise : ${state.requiredCommission.toStringAsFixed(2)} €',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: DonyColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Solde wallet : ${state.availableBalance.toStringAsFixed(2)} €',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: DonyColors.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            'Rechargez votre wallet ou payez la commission directement par carte.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: DonyColors.textMuted),
          ),
        ],
      ),
      stickyBottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyButton(
            label: 'Recharger mon wallet',
            onPressed: () async {
              context.pop();
              // /topup/method est le point d'entrée correct : sélectionne la méthode
              // avant de pousser /topup/amount avec extra (String), qui crasherait si null.
              final recharged = await context.push<bool>('/payments/wallet/topup/method');
              if ((recharged ?? false) && context.mounted) {
                context.read<BidAcceptanceBloc>().add(ace.BidAcceptRequested(state.bidId));
              }
            },
          ),
          if (state.hasCard) ...[
            const SizedBox(height: 8),
            DonyButton(
              label: 'Payer par carte',
              variant: DonyButtonVariant.secondary,
              onPressed: () {
                context.pop();
                context.read<BidAcceptanceBloc>().add(ace.BidAcceptWithCardRequested(state.bidId));
              },
            ),
          ] else ...[
            const SizedBox(height: 8),
            DonyButton(
              label: 'Ajouter une carte',
              variant: DonyButtonVariant.secondary,
              onPressed: () async {
                context.pop();
                await context.push('/payments/commission-method');
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocListener<BidAcceptanceBloc, acs.BidAcceptanceState>(
      listener: (context, state) {
        if (state is acs.BidAccepted) {
          DonySnackbar.show(
            context,
            message:
                'Demande acceptée ! Définissez maintenant la fenêtre de remise.',
            type: DonySnackbarType.success,
          );
          context.read<BidBloc>().add(BidDetailRequested(_bid.id));
        } else if (state is acs.BidWalletInsufficient) {
          _showWalletInsufficientSheet(context, state);
        } else if (state is acs.BidFailed) {
          if (state.cardDeclined) {
            _showCardDeclinedSheet(context, state.message);
          } else {
            DonySnackbar.show(
              context,
              message: state.message,
              type: DonySnackbarType.error,
            );
          }
        }
      },
      child: BlocListener<CancellationBloc, CancellationState>(
        listener: (context, state) {
          if (state is NoShowReported) {
            DonySnackbar.show(
              context,
              message: "Absence signalée. L'expéditeur a 48 h pour contester.",
              type: DonySnackbarType.info,
            );
            context.read<BidBloc>().add(BidDetailRequested(_bid.id));
          } else if (state is NoShowContested) {
            DonySnackbar.show(
              context,
              message:
                  'Contestation envoyée. Notre équipe va examiner votre demande.',
              type: DonySnackbarType.success,
            );
            context.read<BidBloc>().add(BidDetailRequested(_bid.id));
          } else if (state is CancellationError) {
            ErrorPresenter.show(context, state.error);
          }
        },
        child: BlocListener<RatingBloc, RatingState>(
          listener: (context, state) {
            if (state is RatingSuccess) {
              context.read<BidBloc>().add(BidDetailRequested(_bid.id));
            }
          },
          child: BlocListener<ConversationOpenBloc, ConversationOpenState>(
            listener: (context, state) {
              if (state is ConversationOpenSuccess) {
                context.push(
                  '/conversations/${state.conversation.id}',
                  extra: state.conversation,
                );
              } else if (state is ConversationOpenError) {
                ErrorPresenter.show(context, state.error);
              }
            },
            child: BlocConsumer<BidBloc, BidState>(
              listener: (context, state) {
                if (state is BidAccepted) {
                  _bid = state.bid;
                  DonySnackbar.show(
                    context,
                    message:
                        'Demande acceptée ! Définissez maintenant la fenêtre de remise.',
                    type: DonySnackbarType.success,
                  );
                  HandoverBottomSheet.show(context, bid: _bid);
                } else if (state is BidRejected) {
                  _bid = state.bid;
                  DonySnackbar.show(context, message: 'Demande refusée.');
                  if (context.canPop())
                    context.pop();
                  else
                    context.go('/home');
                } else if (state is BidPresenceConfirmed) {
                  _bid = state.bid;
                  DonySnackbar.show(
                    context,
                    message: 'Présence confirmée !',
                    type: DonySnackbarType.success,
                  );
                } else if (state is BidCancelled) {
                  _refreshTimer?.cancel();
                  _bid = state.bid;
                  DonySnackbar.show(
                    context,
                    message: 'Demande annulée. L\'expéditeur sera remboursé.',
                    type: DonySnackbarType.info,
                  );
                  if (context.canPop())
                    context.pop();
                  else
                    context.go('/home');
                } else if (state is BidDeleted) {
                  DonySnackbar.show(context, message: 'Demande supprimée.');
                  if (context.canPop())
                    context.pop();
                  else
                    context.go('/home');
                } else if (state is BidNotFound) {
                  _refreshTimer?.cancel();
                  DonySnackbar.show(
                    context,
                    message: 'Ce colis n\'existe plus',
                    type: DonySnackbarType.warning,
                  );
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                } else if (state is BidDetailLoaded) {
                  final previousBidId = _bid.id;
                  _bid = state.bid;
                  _skeletonLoading = false;
                  if (state.bid.id != previousBidId) {
                    _existingPaymentNotifier.value = null;
                    _paymentLoadedNotifier.value = false;
                  }
                  if ((state.bid.status == 'PENDING' ||
                          state.bid.status == 'ACCEPTED') &&
                      !_paymentLoadedNotifier.value) {
                    _loadPaymentStatus();
                  }
                  // Restart timer if bid transitioned to HANDED_OVER or IN_TRANSIT
                  if ((state.bid.status == 'ACCEPTED' ||
                          state.bid.status == 'HANDED_OVER' ||
                          state.bid.status == 'IN_TRANSIT') &&
                      _refreshTimer == null) {
                    _refreshTimer = Timer.periodic(
                      const Duration(seconds: 10),
                      (_) {
                        if (mounted)
                          context.read<BidBloc>().add(
                            BidDetailRequested(_bid.id),
                          );
                      },
                    );
                  } else if (state.bid.status != 'ACCEPTED' &&
                      state.bid.status != 'HANDED_OVER' &&
                      state.bid.status != 'IN_TRANSIT') {
                    _refreshTimer?.cancel();
                    _refreshTimer = null;
                  }
                } else if (state is BidError) {
                  if (_skeletonLoading) {
                    _skeletonLoading = false;
                    if (context.canPop())
                      context.pop();
                    else
                      context.go('/home');
                  }
                  ErrorPresenter.show(context, state.error);
                }
              },
              builder: (context, state) {
                final isLoading = state is BidLoading;
                final authState = context.read<AuthBloc>().state;
                final isSender =
                    authState is AuthAuthenticated &&
                    authState.user.id == _bid.senderId;

                // Derive bid code from tracking number or id
                final bidCode =
                    _bid.trackingNumber ??
                    _bid.id.substring(0, 6).toUpperCase();

                return Scaffold(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  appBar: DonyAppBar(
                    title: '#$bidCode',
                    onBack: () {
                      if (widget.fromPayment) {
                        context.go('/home');
                      } else if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                    actions: [
                      IconButton(
                        icon: Icon(Icons.share_rounded, color: cs.onSurface),
                        onPressed: () {
                          if (_bid.trackingNumber != null) {
                            Share.share(
                              'Suivez mon colis dony #${_bid.trackingNumber}',
                            );
                          }
                        },
                        tooltip: 'Partager',
                      ),
                    ],
                  ),
                  body: _skeletonLoading
                      ? Center(
                          child: CircularProgressIndicator(color: cs.primary),
                        )
                      : Builder(
                          builder: (context) {
                            final h = DonyLayout.hPadding(context);
                            return SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                h,
                                DonySpacing.lg,
                                h,
                                100,
                              ),
                              child: DonyLayout.constrained(
                                context,
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Billet de colis (status, corridor, dates, talon)
                                    ColisBillet(bid: _bid, isSender: isSender),
                                    const SizedBox(height: DonySpacing.base),

                                    // Badge CASH (affiché sous le billet si paiement en espèces)
                                    if (_bid.paymentMethod ==
                                        BidPaymentMethod.cash) ...[
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: _CashBadge(),
                                      ),
                                      const SizedBox(height: DonySpacing.base),
                                    ],

                                    // Traveler card (visible to sender when accepted or completed)
                                    if (isSender &&
                                        (_bid.status == 'ACCEPTED' ||
                                            _bid.status == 'HANDED_OVER' ||
                                            _bid.status == 'IN_TRANSIT' ||
                                            _bid.status == 'COMPLETED')) ...[
                                      VoyageurCard(bid: _bid),
                                      const SizedBox(height: DonySpacing.base),
                                    ],

                                    // Sender card (visible to traveler — tappable pour voir le profil)
                                    if (!isSender) ...[
                                      ExpediteurCard(
                                        bid: _bid,
                                        onTap: () => showSenderProfileSheet(
                                          context,
                                          _bid,
                                        ),
                                      ),
                                      const SizedBox(height: DonySpacing.base),
                                    ],

                                    // Trip details (visible to sender)
                                    if (isSender) ...[
                                      TrajetCard(bid: _bid),
                                      const SizedBox(height: DonySpacing.base),
                                    ],

                                    // Package card
                                    ColisCard(bid: _bid),
                                    const SizedBox(height: DonySpacing.base),

                                    // Recipient card
                                    DestinataireCard(bid: _bid),
                                    const SizedBox(height: DonySpacing.base),

                                    // Disclaimer
                                    DisclaimerCard(bid: _bid),

                                    // Handover window
                                    if (_bid.handoverLocation != null) ...[
                                      const SizedBox(height: DonySpacing.base),
                                      HandoverCard(bid: _bid),
                                    ],

                                    // Tracking link
                                    if ((_bid.status == 'ACCEPTED' ||
                                            _bid.status == 'HANDED_OVER' ||
                                            _bid.status == 'IN_TRANSIT') &&
                                        _bid.trackingToken != null) ...[
                                      const SizedBox(height: DonySpacing.base),
                                      _TrackingLinkCard(bid: _bid),
                                    ],

                                    // Suivi du colis
                                    if (_bid.status == 'ACCEPTED' ||
                                        _bid.status == 'HANDED_OVER' ||
                                        _bid.status == 'IN_TRANSIT' ||
                                        _bid.status == 'COMPLETED' ||
                                        _bid.status == 'DELIVERED') ...[
                                      const SizedBox(height: DonySpacing.base),
                                      SuiviButton(bid: _bid),
                                    ],

                                    // Payment release row
                                    if (_bid.status == 'COMPLETED') ...[
                                      const SizedBox(height: DonySpacing.base),
                                      PaymentReleaseCard(bid: _bid),
                                    ],

                                    // Rating CTA (sender only, bid completed)
                                    if (isSender &&
                                        _bid.status == 'COMPLETED') ...[
                                      const SizedBox(height: DonySpacing.base),
                                      if (_bid.senderHasRated)
                                        const _RatingDoneCard()
                                      else
                                        DonyButton(
                                          label: 'Noter le voyageur',
                                          icon: Icons.star_rounded,
                                          variant: DonyButtonVariant.secondary,
                                          onPressed: () =>
                                              RatingBottomSheet.show(
                                                context,
                                                bidId: _bid.id,
                                                travelerName:
                                                    _bid.travelerName ??
                                                    'le voyageur',
                                              ),
                                        ),
                                    ],

                                    // Rating CTA (traveler only, bid completed)
                                    // La notation s'affiche automatiquement après validation du code.
                                    if (!isSender &&
                                        _bid.status == 'COMPLETED' &&
                                        _bid.travelerHasRated) ...[
                                      const SizedBox(height: DonySpacing.base),
                                      const _RatingDoneCard(),
                                    ],

                                    // No-show contestation banner (sender, CASH, PENDING_CONFIRMATION)
                                    if (isSender &&
                                        _bid.paymentMethod ==
                                            BidPaymentMethod.cash &&
                                        _bid.cancellationNoShowStatus ==
                                            'PENDING_CONFIRMATION') ...[
                                      const SizedBox(height: DonySpacing.xl),
                                      _NoShowContestationBanner(bid: _bid),
                                    ],

                                    // No-show button (traveler, CASH bid, ACCEPTED, past handover window)
                                    if (!isSender &&
                                        _bid.paymentMethod ==
                                            BidPaymentMethod.cash &&
                                        _bid.status == 'ACCEPTED' &&
                                        _bid.handoverWindowEnd != null &&
                                        DateTime.now().isAfter(
                                          _bid.handoverWindowEnd!,
                                        )) ...[
                                      const SizedBox(height: DonySpacing.xl),
                                      _NoShowSection(bid: _bid),
                                    ],

                                    // Cancel section (traveler only, ACCEPTED / HANDED_OVER / IN_TRANSIT)
                                    if (!isSender &&
                                        (_bid.status == 'ACCEPTED' ||
                                            _bid.status == 'HANDED_OVER' ||
                                            _bid.status == 'IN_TRANSIT')) ...[
                                      const SizedBox(height: DonySpacing.xl),
                                      _TravelerCancelSection(
                                        bid: _bid,
                                        isLoading: isLoading,
                                      ),
                                    ],
                                  ],
                                ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
                              ),
                            );
                          },
                        ),
                  bottomNavigationBar:
                      (isSender &&
                          (_bid.status == 'PENDING' ||
                              _bid.status == 'ACCEPTED'))
                      ? ListenableBuilder(
                          listenable: Listenable.merge([
                            _existingPaymentNotifier,
                            _paymentLoadedNotifier,
                          ]),
                          builder: (context, _) => SenderActionBar(
                            bid: _bid,
                            isLoading: isLoading,
                            existingPayment: _existingPaymentNotifier.value,
                            paymentLoaded: _paymentLoadedNotifier.value,
                          ),
                        )
                      : !isSender && _bid.status == 'PENDING'
                      ? TravelerPendingBar(bid: _bid, isLoading: isLoading)
                      : !isSender && _bid.status == 'REJECTED'
                      ? TravelerRejectedBar(bid: _bid, isLoading: isLoading)
                      : _bid.status == 'ACCEPTED' &&
                            !_bid.voyageurConfirmed &&
                            !isSender &&
                            _bid.handoverWindowStart != null &&
                            DateTime.now().isAfter(
                              _bid.handoverWindowStart!.subtract(
                                const Duration(hours: 4),
                              ),
                            ) &&
                            DateTime.now().isBefore(
                              _bid.handoverWindowEnd ??
                                  DateTime.now().add(const Duration(hours: 1)),
                            )
                      ? ConfirmPresenceBar(bid: _bid, isLoading: isLoading)
                      : null,
                );
              },
            ), // BlocConsumer<BidBloc>
          ), // BlocListener<ConversationOpenBloc>
        ), // BlocListener<RatingBloc>
      ), // BlocListener<CancellationBloc>
    ); // BlocListener<BidAcceptanceBloc>
  }
}

// ── Rating done card ──────────────────────────────────────────────────────────

class _RatingDoneCard extends StatelessWidget {
  const _RatingDoneCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 16, color: cs.primary),
          const SizedBox(width: DonySpacing.xs),
          Text(
            'Évaluation envoyée',
            style: tt.bodyMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tracking link card ────────────────────────────────────────────────────────

class _TrackingLinkCard extends StatelessWidget {
  final BidModel bid;
  const _TrackingLinkCard({required this.bid});

  static const String _trackingPublicBase = String.fromEnvironment(
    'TRACKING_PUBLIC_URL',
    defaultValue: 'https://track.dony.app',
  );

  String get _trackingUrl => '$_trackingPublicBase/${bid.trackingToken}';

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LIEN DE SUIVI',
            style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          Container(
            padding: const EdgeInsets.all(DonySpacing.md),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(DonyRadius.sm),
              border: Border.all(color: cs.outline),
            ),
            child: Row(
              children: [
                Icon(Icons.link_rounded, color: cs.primary, size: 16),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: Text(
                    _trackingUrl,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _trackingUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Lien copié',
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        backgroundColor: cs.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DonyRadius.sm),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: Text(
                    'Copier',
                    style: tt.titleSmall?.copyWith(color: cs.primary),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.primary,
                    side: BorderSide(color: cs.primary),
                    padding: const EdgeInsets.symmetric(
                      vertical: DonySpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DonyRadius.md),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Share.share(
                    'Suivez votre colis dony en temps réel :\n$_trackingUrl',
                    subject:
                        'Suivi de colis dony — ${bid.trackingNumber ?? ""}',
                  ),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: Text(
                    'Partager',
                    style: tt.titleSmall?.copyWith(color: DonyColors.white),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: DonyColors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      vertical: DonySpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DonyRadius.md),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── Traveler cancel section ───────────────────────────────────────────────────

class _TravelerCancelSection extends StatelessWidget {
  final BidModel bid;
  final bool isLoading;
  const _TravelerCancelSection({required this.bid, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ANNULATION',
          style: tt.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: DonySpacing.md),
        DonyButton(
          label: 'Annuler la demande',
          icon: Icons.cancel_outlined,
          onPressed: isLoading ? null : () => _showCancellationDialog(context),
          variant: DonyButtonVariant.ghost,
          isLoading: isLoading,
        ),
      ],
    );
  }

  Future<void> _showCancellationDialog(BuildContext context) async {
    final isInTransit = bid.status == 'IN_TRANSIT';
    final reason = await CancellationDialog.show(
      context,
      isInTransit: isInTransit,
    );
    if (reason == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    // reason == "" means no reason given (ACCEPTED case)
    // reason.isNotEmpty means reason was provided
    context.read<BidBloc>().add(
      BidCancelRequested(bid.id, reason: reason.isEmpty ? null : reason),
    );
  }
}

// ── No-show contestation banner (sender) ─────────────────────────────────────

class _NoShowContestationBanner extends StatefulWidget {
  final BidModel bid;
  const _NoShowContestationBanner({required this.bid});

  @override
  State<_NoShowContestationBanner> createState() =>
      _NoShowContestationBannerState();
}

class _NoShowContestationBannerState extends State<_NoShowContestationBanner> {
  Timer? _tick;
  String _timeLeft = '';

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(_updateCountdown);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    final deadline = widget.bid.contestationDeadline;
    if (deadline == null) {
      _timeLeft = '';
      return;
    }
    final remaining = deadline.difference(DateTime.now());
    if (remaining.isNegative) {
      _timeLeft = 'Délai expiré';
      return;
    }
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    _timeLeft =
        '${h}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return BlocBuilder<CancellationBloc, CancellationState>(
      builder: (context, state) {
        final isLoading = state is CancellationLoading;
        return Container(
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            color: cs.errorContainer.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.error.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: cs.error, size: 18),
                  const SizedBox(width: DonySpacing.sm),
                  Expanded(
                    child: Text(
                      'Absence signalée par le voyageur',
                      style: tt.titleSmall?.copyWith(
                        color: cs.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.sm),
              Text(
                "Le voyageur indique que vous n'étiez pas présent au point de remise.",
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              if (_timeLeft.isNotEmpty) ...[
                const SizedBox(height: DonySpacing.sm),
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: DonySpacing.xs),
                    Text(
                      'Temps restant pour contester : $_timeLeft',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: DonySpacing.base),
              Row(
                children: [
                  Expanded(
                    child: DonyButton(
                      label: 'Je conteste',
                      icon: Icons.gavel_rounded,
                      isLoading: isLoading,
                      onPressed: isLoading
                          ? null
                          : () => _showContestSheet(context),
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Expanded(
                    child: DonyButton(
                      label: 'Je confirme',
                      icon: Icons.check_circle_outline_rounded,
                      variant: DonyButtonVariant.ghost,
                      isLoading: isLoading,
                      onPressed: isLoading
                          ? null
                          : () => _showConfirmSheet(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showContestSheet(BuildContext context) async {
    final confirmed = await DonyBottomSheet.show<bool>(
      context,
      title: 'Contester l\'absence',
      stickyBottom: Builder(
        builder: (ctx) => DonyButton(
          label: 'Confirmer la contestation',
          icon: Icons.gavel_rounded,
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vous contestez l\'absence signalée par le voyageur.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: DonySpacing.md),
            Text(
              'Notre équipe examinera votre demande et vous contactera sous 24 h.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }
    context.read<CancellationBloc>().add(NoShowContestRequested(widget.bid.id));
  }

  Future<void> _showConfirmSheet(BuildContext context) async {
    await DonyBottomSheet.show<void>(
      context,
      title: 'Confirmer votre absence',
      stickyBottom: Builder(
        builder: (ctx) => DonyButton(
          label: 'Compris',
          variant: DonyButtonVariant.ghost,
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
        child: Text(
          "En confirmant votre absence, le bid sera annulé "
          'et vous ne serez pas débité.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

// ── Cash badge ────────────────────────────────────────────────────────────────

class _CashBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.payments_rounded, size: 12, color: cs.onTertiaryContainer),
          const SizedBox(width: DonySpacing.xs),
          Text(
            'CASH',
            style: tt.labelSmall?.copyWith(
              color: cs.onTertiaryContainer,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── No-show section (traveler, CASH, ACCEPTED, past window) ───────────────────

class _NoShowSection extends StatelessWidget {
  final BidModel bid;
  const _NoShowSection({required this.bid});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return BlocBuilder<CancellationBloc, CancellationState>(
      builder: (context, state) {
        final isLoading = state is CancellationLoading;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ABSENCE EXPÉDITEUR',
              style: tt.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: DonySpacing.md),
            DonyButton(
              label: "L'expéditeur n'est pas venu",
              icon: Icons.person_off_rounded,
              variant: DonyButtonVariant.ghost,
              isLoading: isLoading,
              onPressed: isLoading ? null : () => _confirmNoShow(context),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmNoShow(BuildContext context) async {
    final confirmed = await DonyBottomSheet.show<bool>(
      context,
      title: 'Signaler une absence',
      stickyBottom: Builder(
        builder: (ctx) => DonyButton(
          label: 'Confirmer l\'absence',
          icon: Icons.person_off_rounded,
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "L'expéditeur ne s'est pas présenté au point de remise.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: DonySpacing.md),
            Text(
              "L'expéditeur aura 48 h pour contester. "
              'Sans réponse de sa part, le bid sera annulé.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }
    context.read<CancellationBloc>().add(NoShowReportRequested(bid.id));
  }
}
