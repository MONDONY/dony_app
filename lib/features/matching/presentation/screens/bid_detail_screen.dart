import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/utils/share_position.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_bloc.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/bid_labels.dart';
import 'package:dony/features/matching/presentation/widgets/action_bars/bid_detail_action_bars.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/quick_actions_row.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_detail_body.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_sticky_bar.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_detail_body.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_options_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_sticky_bar.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/payments/data/models/payment_model.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:dony/features/payments/wallet/presentation/commission_shortfall_text.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
        BlocProvider(create: (_) => getIt<ContactRevealBloc>()),
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
  // Statuts vivants : le colis peut encore transitionner vers COMPLETED
  // à tout moment → le polling doit rester actif.
  static const _kPollingStatuses = {
    'ACCEPTED',
    'HANDED_OVER',
    'IN_TRANSIT',
    'ARRIVED',
  };

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
    if (_kPollingStatuses.contains(_bid.status)) {
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
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    DonyBottomSheet.show<void>(
      context,
      title: l.bidDetailCardDeclinedTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            l.bidDetailCardDeclinedHint,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
      stickyBottom: DonyButton(
        label: l.bidDetailChangeCommissionCard,
        onPressed: () {
          context.pop();
          context.push('/payments/commission-method');
        },
      ),
    );
  }

  void _showWalletInsufficientSheet(
    BuildContext context,
    acs.BidWalletInsufficient state,
  ) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    DonyBottomSheet.show<void>(
      context,
      title: l.bidDetailInsufficientBalanceTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, line) in commissionShortfallLines(
            l,
            breakdown: state.breakdown,
            requiredCommission: state.requiredCommission,
            availableBalance: state.availableBalance,
            currency: state.currency,
          ).indexed) ...[
            if (i > 0) const SizedBox(height: 4),
            Text(
              line,
              style: i == 0
                  ? Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: cs.onSurface)
                  : Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            l.bidDetailInsufficientBalanceHint,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
      stickyBottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyButton(
            label: l.bidDetailTopupWallet,
            onPressed: () async {
              context.pop();
              // /topup/method est le point d'entrée correct : il compose le
              // WalletTopupMethodSelection attendu en extra par
              // /topup/amount, qui crasherait sans lui.
              final recharged = await context.push<bool>(
                '/payments/wallet/topup/method',
              );
              if ((recharged ?? false) && context.mounted) {
                context.read<BidAcceptanceBloc>().add(
                  ace.BidAcceptRequested(state.bidId),
                );
              }
            },
          ),
          if (state.hasCard) ...[
            const SizedBox(height: 8),
            DonyButton(
              label: l.bidDetailPayByCard,
              variant: DonyButtonVariant.secondary,
              onPressed: () {
                context.pop();
                context.read<BidAcceptanceBloc>().add(
                  ace.BidAcceptWithCardRequested(state.bidId),
                );
              },
            ),
          ] else ...[
            const SizedBox(height: 8),
            DonyButton(
              label: l.bidDetailAddCard,
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
    final l = context.l10n;

    return BlocListener<BidAcceptanceBloc, acs.BidAcceptanceState>(
      listener: (context, state) {
        if (state is acs.BidAccepted) {
          DonySnackbar.show(
            context,
            message: l.bidDetailAcceptedSetHandoverWindow,
            type: DonySnackbarType.success,
          );
          context.read<BidBloc>().add(BidDetailRequested(_bid.id));
        } else if (state is acs.BidWalletInsufficient) {
          _showWalletInsufficientSheet(context, state);
        } else if (state is acs.BidFailed) {
          final message = state.displayMessage(context.l10n);
          if (state.cardDeclined) {
            _showCardDeclinedSheet(context, message);
          } else {
            DonySnackbar.show(
              context,
              message: message,
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
              message: l.bidDetailNoShowReportedSnackbar,
            );
            context.read<BidBloc>().add(BidDetailRequested(_bid.id));
          } else if (state is DeliveryNoShowReported) {
            DonySnackbar.show(
              context,
              message: l.bidDetailDeliveryNoShowReportedSnackbar,
            );
            context.read<BidBloc>().add(BidDetailRequested(_bid.id));
          } else if (state is DeliveryNoShowContested) {
            DonySnackbar.show(
              context,
              message: l.bidDetailContestSentSnackbar,
              type: DonySnackbarType.success,
            );
            context.read<BidBloc>().add(BidDetailRequested(_bid.id));
          } else if (state is NoShowContested) {
            DonySnackbar.show(
              context,
              message: l.bidDetailContestSentSnackbar,
              type: DonySnackbarType.success,
            );
            context.read<BidBloc>().add(BidDetailRequested(_bid.id));
          } else if (state is NoShowConfirmed) {
            DonySnackbar.show(
              context,
              message: l.bidDetailNoShowConfirmedSnackbar,
            );
            context.read<BidBloc>().add(BidDetailRequested(_bid.id));
          } else if (state is CancelledAfterHandover) {
            DonySnackbar.show(
              context,
              message: l.bidDetailCancelledAfterHandoverSnackbar,
            );
            context.read<BidBloc>().add(BidDetailRequested(_bid.id));
          } else if (state is ReturnConfirmed) {
            DonySnackbar.show(
              context,
              message: l.bidDetailReturnConfirmedSnackbar,
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
                    message: l.bidDetailAcceptedSnackbar,
                    type: DonySnackbarType.success,
                  );
                } else if (state is BidRejected) {
                  _bid = state.bid;
                  DonySnackbar.show(
                    context,
                    message: l.bidDetailRejectedSnackbar,
                  );
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                } else if (state is BidPresenceConfirmed) {
                  _bid = state.bid;
                  DonySnackbar.show(
                    context,
                    message: l.bidDetailPresenceConfirmedSnackbar,
                    type: DonySnackbarType.success,
                  );
                } else if (state is BidCancelled) {
                  _refreshTimer?.cancel();
                  _bid = state.bid;
                  DonySnackbar.show(
                    context,
                    message: l.bidDetailCancelledSnackbar,
                  );
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                } else if (state is BidDeleted) {
                  DonySnackbar.show(
                    context,
                    message: l.bidDetailDeletedSnackbar,
                  );
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                } else if (state is BidNotFound) {
                  _refreshTimer?.cancel();
                  DonySnackbar.show(
                    context,
                    message: l.bidDetailNotFoundSnackbar,
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
                  // Restart timer if bid transitioned to a still-live status
                  // (statut vivant : passe à COMPLETED dès le retrait par le
                  // destinataire).
                  if (_kPollingStatuses.contains(state.bid.status) &&
                      _refreshTimer == null) {
                    _refreshTimer = Timer.periodic(
                      const Duration(seconds: 10),
                      (_) {
                        if (mounted) {
                          context.read<BidBloc>().add(
                            BidDetailRequested(_bid.id),
                          );
                        }
                      },
                    );
                  } else if (!_kPollingStatuses.contains(state.bid.status)) {
                    _refreshTimer?.cancel();
                    _refreshTimer = null;
                  }
                } else if (state is BidError) {
                  if (_skeletonLoading) {
                    _skeletonLoading = false;
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  }
                  ErrorPresenter.show(context, state.error);
                }
              },
              builder: (context, state) {
                final isLoading = state is BidLoading;
                final authState = context.read<AuthBloc>().state;
                // Résoudre l'utilisateur courant depuis AuthAuthenticated ET
                // AuthProfileUpdated (émis après édition profil / upload photo) :
                // sans ce dernier, l'expéditeur était traité comme voyageur après
                // une mise à jour de profil → mauvais body (carte EXPÉDITEUR au lieu
                // de VOYAGEUR), mauvaise sticky bar et menu options.
                final currentUser = authState is AuthAuthenticated
                    ? authState.user
                    : authState is AuthProfileUpdated
                    ? authState.user
                    : null;
                final isSender =
                    currentUser != null && currentUser.id == _bid.senderId;

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
                      if (isSender && _bid.trackingToken != null)
                        IconButton(
                          icon: DonyIcon('share-2', color: cs.onSurface),
                          tooltip: l.bidDetailShareTracking,
                          onPressed: () => shareTrackingLink(
                            _bid,
                            sharePositionOrigin: sharePositionOriginFor(
                              context,
                            ),
                          ),
                        ),
                      if (isSender)
                        IconButton(
                          icon: DonyIcon(
                            'ellipsis-vertical',
                            color: cs.onSurface,
                          ),
                          tooltip: l.bidDetailOptionsTitle,
                          onPressed: () =>
                              showSenderOptionsSheet(context, _bid),
                        ),
                      if (!isSender)
                        IconButton(
                          icon: DonyIcon(
                            'ellipsis-vertical',
                            color: cs.onSurface,
                          ),
                          tooltip: l.bidDetailOptionsTitle,
                          onPressed: () =>
                              showTravelerOptionsSheet(context, _bid),
                        ),
                    ],
                  ),
                  body: _skeletonLoading
                      ? const DonyDetailSkeleton()
                      : isSender
                      ? SenderDetailBody(bid: _bid)
                      : TravelerDetailBody(bid: _bid),
                  bottomNavigationBar: isSender
                      ? (SenderStickyBar.hasAction(_bid)
                            ? ListenableBuilder(
                                listenable: Listenable.merge([
                                  _existingPaymentNotifier,
                                  _paymentLoadedNotifier,
                                ]),
                                builder: (context, _) => SenderStickyBar(
                                  bid: _bid,
                                  isLoading: isLoading,
                                  existingPayment:
                                      _existingPaymentNotifier.value,
                                  paymentLoaded: _paymentLoadedNotifier.value,
                                  onPaymentReturned: () {
                                    context.read<BidBloc>().add(
                                      BidDetailRequested(_bid.id),
                                    );
                                    _loadPaymentStatus();
                                  },
                                ),
                              )
                            : null)
                      : (TravelerStickyBar.hasAction(_bid)
                            ? TravelerStickyBar(bid: _bid, isLoading: isLoading)
                            : null),
                );
              },
            ), // BlocConsumer<BidBloc>
          ), // BlocListener<ConversationOpenBloc>
        ), // BlocListener<RatingBloc>
      ), // BlocListener<CancellationBloc>
    ); // BlocListener<BidAcceptanceBloc>
  }
}
