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
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/presentation/widgets/cancellation_dialog.dart';
import 'package:dony/features/matching/presentation/widgets/colis_card.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
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
import 'package:intl/intl.dart';

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
        } else if (state is acs.BidFailed) {
          DonySnackbar.show(
            context,
            message: state.message,
            type: DonySnackbarType.error,
          );
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
                    title: 'Mon colis #$bidCode',
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
                                      _TripDetailsCard(bid: _bid),
                                      const SizedBox(height: DonySpacing.base),
                                    ],

                                    // Package card
                                    ColisCard(bid: _bid),
                                    const SizedBox(height: DonySpacing.base),

                                    // Recipient card
                                    DestinataireCard(bid: _bid),
                                    const SizedBox(height: DonySpacing.base),

                                    // Disclaimer
                                    _DisclaimerCard(bid: _bid),

                                    // Handover window
                                    if (_bid.handoverLocation != null) ...[
                                      const SizedBox(height: DonySpacing.base),
                                      _HandoverCard(bid: _bid),
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
                                      _PaymentReleaseCard(bid: _bid),
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
                          builder: (context, _) => _SenderActionBar(
                            bid: _bid,
                            isLoading: isLoading,
                            existingPayment: _existingPaymentNotifier.value,
                            paymentLoaded: _paymentLoadedNotifier.value,
                          ),
                        )
                      : !isSender && _bid.status == 'PENDING'
                      ? _ActionBar(bid: _bid, isLoading: isLoading)
                      : !isSender && _bid.status == 'REJECTED'
                      ? _TravelerRejectedBar(bid: _bid, isLoading: isLoading)
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
                      ? _ConfirmPresenceBar(bid: _bid, isLoading: isLoading)
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

// ── Payment release row ───────────────────────────────────────────────────────

class _PaymentReleaseCard extends StatelessWidget {
  final BidModel bid;
  const _PaymentReleaseCard({required this.bid});

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fonds libérés à ${bid.travelerName ?? 'Ibrahima'}',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                ),
                Text(
                  'Reçu disponible · ${bid.pricePerKg != null ? (bid.pricePerKg! * bid.weightKg * 0.88).toStringAsFixed(2) : '—'} €',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          // "Reçu" chip
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.md,
              vertical: DonySpacing.xs,
            ),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(DonyRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: cs.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: DonySpacing.xs),
                Text(
                  'Reçu',
                  style: tt.labelSmall?.copyWith(
                    color: cs.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  final BidModel bid;
  const _DisclaimerCard({required this.bid});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return DetailCard(
      title: 'Responsabilité légale',
      child: Row(
        children: [
          Icon(Icons.verified_outlined, color: cs.success, size: 20),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              bid.disclaimerSignedAt != null
                  ? 'Disclaimer signé le ${DateFormat('dd/MM/yyyy à HH:mm').format(bid.disclaimerSignedAt!.toLocal())}'
                  : 'Disclaimer signé',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _HandoverCard extends StatelessWidget {
  final BidModel bid;
  const _HandoverCard({required this.bid});

  @override
  Widget build(BuildContext context) {
    return DetailCard(
      title: 'Fenêtre de remise',
      child: Column(
        children: [
          InfoRow(label: 'Lieu', value: bid.handoverLocation ?? '—'),
          if (bid.handoverWindowStart != null) ...[
            const SizedBox(height: DonySpacing.sm),
            InfoRow(
              label: 'Début',
              value: DateFormat(
                'dd/MM/yyyy HH:mm',
              ).format(bid.handoverWindowStart!.toLocal()),
            ),
          ],
          if (bid.handoverWindowEnd != null) ...[
            const SizedBox(height: DonySpacing.sm),
            InfoRow(
              label: 'Fin',
              value: DateFormat(
                'dd/MM/yyyy HH:mm',
              ).format(bid.handoverWindowEnd!.toLocal()),
            ),
          ],
          const SizedBox(height: DonySpacing.sm),
          InfoRow(
            label: 'Présence confirmée',
            value: bid.voyageurConfirmed ? 'Oui ✓' : 'Non encore',
          ),
        ],
      ),
    );
  }
}

class _TripDetailsCard extends StatelessWidget {
  final BidModel bid;
  const _TripDetailsCard({required this.bid});

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return DateFormat('EEE dd MMM yyyy', 'fr').format(d);
  }

  String _formatTime(String? t) {
    if (t == null || t.isEmpty) return '—';
    return t.length >= 5 ? t.substring(0, 5) : t;
  }

  @override
  Widget build(BuildContext context) {
    return DetailCard(
      title: 'Détails du trajet',
      child: Column(
        children: [
          InfoRow(
            label: 'Date de départ',
            value: _formatDate(bid.departureDate),
          ),
          if (bid.departureTime != null) ...[
            const SizedBox(height: DonySpacing.sm),
            InfoRow(
              label: 'Heure de départ',
              value: _formatTime(bid.departureTime),
            ),
          ],
          if (bid.arrivalTime != null) ...[
            const SizedBox(height: DonySpacing.sm),
            InfoRow(
              label: 'Heure d\'arrivée',
              value: _formatTime(bid.arrivalTime),
            ),
          ],
          if (bid.pricePerKg != null) ...[
            const SizedBox(height: DonySpacing.sm),
            InfoRow(
              label: 'Tarif par kg',
              value: '${bid.pricePerKg!.toStringAsFixed(2)} €',
            ),
          ],
        ],
      ),
    );
  }
}

// ── Action bars ───────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final BidModel bid;
  final bool isLoading;
  const _ActionBar({required this.bid, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = DonyLayout.hPadding(context);
    return Container(
      color: cs.surface,
      padding: EdgeInsets.fromLTRB(
        h,
        DonySpacing.base,
        h,
        MediaQuery.of(context).padding.bottom + DonySpacing.base,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : () => _showRejectDialog(context),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Refuser'),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.error,
                side: BorderSide(color: cs.error),
                padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.lg),
                ),
              ),
            ),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: FilledButton.icon(
              onPressed: isLoading
                  ? null
                  : () {
                      if (bid.paymentMethod == BidPaymentMethod.cash) {
                        context.read<BidAcceptanceBloc>().add(
                          ace.BidAcceptRequested(bid.id),
                        );
                      } else {
                        context.read<BidBloc>().add(BidAcceptRequested(bid.id));
                      }
                    },
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: DonyColors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: const Text('Accepter'),
              style: FilledButton.styleFrom(
                backgroundColor: cs.success,
                foregroundColor: DonyColors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.lg),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final reasonCtrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(DonyRadius.xl),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.base,
            DonySpacing.base,
            DonySpacing.base,
            DonySpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: DonySpacing.base),
              Text('Refuser la demande', style: tt.headlineMedium),
              const SizedBox(height: DonySpacing.sm),
              Text(
                'Souhaitez-vous indiquer une raison à l\'expéditeur ?',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: DonySpacing.md),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                autofocus: true,
                scrollPadding: const EdgeInsets.only(bottom: 120),
                decoration: InputDecoration(
                  hintText: 'Raison (optionnelle)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                  ),
                  hintStyle: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: DonySpacing.base),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => ctx.pop(),
                    child: Text(
                      'Annuler',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  FilledButton(
                    onPressed: () {
                      ctx.pop();
                      context.read<BidBloc>().add(
                        BidRejectRequested(
                          bid.id,
                          reason: reasonCtrl.text.trim().isEmpty
                              ? null
                              : reasonCtrl.text.trim(),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.error,
                      foregroundColor: DonyColors.white,
                      elevation: 0,
                    ),
                    child: Text(
                      'Confirmer le refus',
                      style: tt.labelLarge?.copyWith(color: DonyColors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmPresenceBar extends StatelessWidget {
  final BidModel bid;
  final bool isLoading;
  const _ConfirmPresenceBar({required this.bid, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = DonyLayout.hPadding(context);
    return Container(
      color: cs.surface,
      padding: EdgeInsets.fromLTRB(
        h,
        DonySpacing.base,
        h,
        MediaQuery.of(context).padding.bottom + DonySpacing.base,
      ),
      child: DonyButton(
        label: 'Confirmer ma présence',
        icon: Icons.location_on_rounded,
        onPressed: isLoading
            ? null
            : () => context.read<BidBloc>().add(
                BidConfirmPresenceRequested(bid.id),
              ),
        isLoading: isLoading,
      ),
    );
  }
}

class _EscrowBadge extends StatelessWidget {
  final PaymentModel payment;
  final String bidStatus;
  const _EscrowBadge({required this.payment, required this.bidStatus});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final (IconData icon, Color color, String label) = _resolve(cs);

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DonyRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: DonySpacing.sm),
          Flexible(
            child: Text(
              label,
              style: tt.titleSmall?.copyWith(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, String) _resolve(ColorScheme cs) {
    final amount = payment.amount.toStringAsFixed(2);
    return switch (payment.status) {
      'RELEASED' => (
        Icons.check_circle_rounded,
        cs.success,
        'Voyageur payé — $amount €',
      ),
      'REFUNDED' => (
        Icons.replay_rounded,
        cs.onSurfaceVariant,
        'Remboursé — $amount €',
      ),
      'FAILED' => (Icons.error_outline_rounded, cs.error, 'Paiement échoué'),
      _ when bidStatus == 'PENDING' => (
        Icons.lock_clock_rounded,
        cs.warning,
        'Paiement sécurisé · En attente du voyageur',
      ),
      _ when bidStatus == 'ACCEPTED' => (
        Icons.lock_rounded,
        cs.success,
        'Paiement sécurisé — $amount €',
      ),
      _ => (Icons.lock_rounded, cs.success, 'Paiement sécurisé — $amount €'),
    };
  }
}

class _SenderActionBar extends StatelessWidget {
  final BidModel bid;
  final bool isLoading;
  final PaymentModel? existingPayment;
  final bool paymentLoaded;
  const _SenderActionBar({
    required this.bid,
    required this.isLoading,
    this.existingPayment,
    this.paymentLoaded = false,
  });

  void _openOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SenderOptionsSheet(bid: bid, outerContext: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = DonyLayout.hPadding(context);
    return Container(
      color: cs.surface,
      padding: EdgeInsets.fromLTRB(
        h,
        DonySpacing.base,
        h,
        MediaQuery.of(context).padding.bottom + DonySpacing.base,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: OutlinedButton(
              onPressed: () => _openOptions(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.onSurfaceVariant,
                side: BorderSide(color: cs.outline),
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.lg),
                ),
              ),
              child: const Icon(Icons.more_horiz_rounded, size: 22),
            ),
          ),
          if (bid.status == 'PENDING' || bid.status == 'ACCEPTED') ...[
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: !paymentLoaded
                  ? Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(DonyRadius.lg),
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : existingPayment != null
                  ? _EscrowBadge(
                      payment: existingPayment!,
                      bidStatus: bid.status,
                    )
                  : FilledButton.icon(
                      onPressed: () =>
                          context.push('/payments/pay', extra: bid),
                      icon: const Icon(Icons.lock_rounded, size: 18),
                      label: const Text('Payer mon envoi'),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: DonyColors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          vertical: DonySpacing.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DonyRadius.lg),
                        ),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Options bottom sheet ──────────────────────────────────────────────────────

class _SenderOptionsSheet extends StatelessWidget {
  final BidModel bid;
  final BuildContext outerContext;

  const _SenderOptionsSheet({required this.bid, required this.outerContext});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    final h = DonyLayout.hPadding(context);
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(h, 0, h, bottomPad + DonySpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: DonySpacing.md),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Options', style: tt.headlineMedium),
          const SizedBox(height: DonySpacing.base),
          _OptionTile(
            icon: Icons.flag_outlined,
            iconColor: cs.error,
            iconBg: cs.errorLight,
            label: 'Signaler ce trajet',
            subtitle: 'Signaler un problème au support Dony',
            onTap: () {
              context.pop();
              _showReportSheet(outerContext);
            },
          ),
          const SizedBox(height: DonySpacing.sm),
          _OptionTile(
            icon: Icons.chat_bubble_outline_rounded,
            iconColor: cs.primary,
            iconBg: cs.primaryContainer,
            label: 'Contacter le voyageur',
            subtitle: 'Envoyer un message au voyageur',
            onTap: () {
              context.pop();
              outerContext.read<ConversationOpenBloc>().add(
                ConversationOpenRequested(bid.id),
              );
            },
          ),
          const SizedBox(height: DonySpacing.sm),
          if (bid.status == 'PENDING') ...[
            _OptionTile(
              icon: Icons.block_rounded,
              iconColor: cs.error,
              iconBg: cs.errorLight,
              label: 'Annuler la demande',
              subtitle: 'Votre paiement sera remboursé automatiquement',
              onTap: () {
                context.pop();
                _showCancelDialog(outerContext);
              },
            ),
            const SizedBox(height: DonySpacing.sm),
          ],
          if (bid.status == 'COMPLETED' ||
              bid.status == 'REJECTED' ||
              bid.status == 'CANCELLED') ...[
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              iconColor: cs.error,
              iconBg: cs.errorLight,
              label: 'Supprimer cette demande',
              subtitle: 'Retirer définitivement de votre historique',
              onTap: () {
                context.pop();
                _showDeleteDialog(outerContext);
              },
            ),
            const SizedBox(height: DonySpacing.sm),
          ],
        ],
      ),
    );
  }

  void _showReportSheet(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final reasons = [
      'Informations fausses sur le trajet',
      'Comportement inapproprié',
      'Tentative d\'arnaque',
      'Autre',
    ];
    String? selected;

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(DonyRadius.sheet),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            DonySpacing.lg,
            0,
            DonySpacing.lg,
            MediaQuery.of(ctx).padding.bottom + DonySpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: DonySpacing.md),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Signaler ce trajet', style: tt.headlineMedium),
              const SizedBox(height: DonySpacing.xs),
              Text(
                'Votre signalement sera traité par l\'équipe Dony.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: DonySpacing.base),
              ...reasons.map(
                (r) => RadioListTile<String>(
                  value: r,
                  groupValue: selected,
                  onChanged: (v) => setSheetState(() => selected = v),
                  title: Text(r, style: tt.bodyMedium),
                  activeColor: cs.primary,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const SizedBox(height: DonySpacing.base),
              DonyButton(
                label: 'Envoyer le signalement',
                variant: DonyButtonVariant.destructive,
                onPressed: selected == null
                    ? null
                    : () {
                        ctx.pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Signalement envoyé. Merci !',
                              style: tt.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            backgroundColor: cs.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                DonyRadius.sm,
                              ),
                            ),
                          ),
                        );
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.sheet),
        ),
        title: Text('Annuler la demande', style: tt.headlineMedium),
        content: Text(
          'Voulez-vous vraiment annuler votre demande d\'envoi ? Cette action est définitive.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: Text(
              'Non',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          FilledButton(
            onPressed: () {
              ctx.pop();
              context.read<BidBloc>().add(BidCancelRequested(bid.id));
            },
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: DonyColors.white,
              elevation: 0,
            ),
            child: Text('Oui, annuler', style: tt.labelLarge),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.sheet),
        ),
        title: Text('Supprimer cette demande', style: tt.headlineMedium),
        content: Text(
          'Cette demande sera définitivement supprimée de votre historique.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: Text(
              'Annuler',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          FilledButton(
            onPressed: () {
              ctx.pop();
              context.read<BidBloc>().add(BidDeleteRequested(bid.id));
            },
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: DonyColors.white,
              elevation: 0,
            ),
            child: Text('Supprimer', style: tt.labelLarge),
          ),
        ],
      ),
    );
  }
}

// ── Traveler rejected bar ─────────────────────────────────────────────────────

class _TravelerRejectedBar extends StatelessWidget {
  final BidModel bid;
  final bool isLoading;
  const _TravelerRejectedBar({required this.bid, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = DonyLayout.hPadding(context);
    return Container(
      color: cs.surface,
      padding: EdgeInsets.fromLTRB(
        h,
        DonySpacing.base,
        h,
        MediaQuery.of(context).padding.bottom + DonySpacing.base,
      ),
      child: DonyButton(
        label: 'Supprimer cette demande',
        icon: Icons.delete_outline_rounded,
        variant: DonyButtonVariant.destructive,
        onPressed: isLoading ? null : () => _showDeleteDialog(context),
        isLoading: isLoading,
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.sheet),
        ),
        title: Text('Supprimer cette demande', style: tt.headlineMedium),
        content: Text(
          'Cette demande refusée sera retirée définitivement de votre liste.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: Text(
              'Annuler',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          FilledButton(
            onPressed: () {
              ctx.pop();
              context.read<BidBloc>().add(BidTravelerDismissRequested(bid.id));
            },
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: DonyColors.white,
              elevation: 0,
            ),
            child: Text('Supprimer', style: tt.labelLarge),
          ),
        ],
      ),
    );
  }
}

// ── Option tile ───────────────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final bool disabled;

  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(DonySpacing.md),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(DonyRadius.lg),
            border: Border.all(color: cs.outline),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DonySpacing.sm),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(DonyRadius.sm),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: tt.titleSmall?.copyWith(color: cs.onSurface),
                    ),
                    Text(
                      subtitle,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (!disabled)
                Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onSurfaceVariant,
                  size: 18,
                ),
              if (disabled)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.sm,
                    vertical: DonySpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: cs.outline,
                    borderRadius: BorderRadius.circular(DonyRadius.sm),
                  ),
                  child: Text(
                    'Bientôt',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
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
    defaultValue: 'https://api.dony.app/api/v1',
  );

  String get _trackingUrl =>
      '$_trackingPublicBase/tracking/public/${bid.trackingToken}';

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
