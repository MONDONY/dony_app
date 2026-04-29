import 'dart:async';

import 'package:share_plus/share_plus.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/payments/data/models/payment_model.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/presentation/widgets/qr_code_card.dart';
import 'package:dony/core/constants/city_airport_codes.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/presentation/widgets/cancellation_dialog.dart';
import 'package:dony/features/matching/presentation/widgets/route_map_components.dart';
import 'package:intl/intl.dart';

class BidDetailScreen extends StatelessWidget {
  final BidModel bid;

  const BidDetailScreen({super.key, required this.bid});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<BidBloc>()),
        BlocProvider(create: (_) => getIt<TrackingBloc>()),
      ],
      child: _BidDetailView(initialBid: bid),
    );
  }
}

class _BidDetailView extends StatefulWidget {
  final BidModel initialBid;
  const _BidDetailView({required this.initialBid});

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
    if (_bid.status == 'ACCEPTED' || _bid.status == 'IN_TRANSIT') {
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
    if (_bid.status == 'REJECTED' || _bid.status == 'CANCELLED') return;
    try {
      final payment = await getIt<PaymentRepository>().getPaymentForBid(_bid.id);
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
    final tt = Theme.of(context).textTheme;

    return BlocConsumer<BidBloc, BidState>(
      listener: (context, state) {
        if (state is BidAccepted) {
          _bid = state.bid;
          DonySnackbar.show(context,
              message: 'Demande acceptée ! Définissez maintenant la fenêtre de remise.',
              type: DonySnackbarType.success);
          context.push('/bids/${_bid.id}/handover', extra: _bid);
        } else if (state is BidRejected) {
          _bid = state.bid;
          DonySnackbar.show(context, message: 'Demande refusée.');
          context.pop();
        } else if (state is BidPresenceConfirmed) {
          _bid = state.bid;
          DonySnackbar.show(context, message: 'Présence confirmée !', type: DonySnackbarType.success);
        } else if (state is BidCancelled) {
          _refreshTimer?.cancel();
          _bid = state.bid;
          DonySnackbar.show(
            context,
            message: 'Demande annulée. L\'expéditeur sera remboursé.',
            type: DonySnackbarType.info,
          );
          context.pop();
        } else if (state is BidDeleted) {
          DonySnackbar.show(context, message: 'Demande supprimée.');
          context.pop();
        } else if (state is BidDetailLoaded) {
          final previousBidId = _bid.id;
          _bid = state.bid;
          _skeletonLoading = false;
          if (state.bid.id != previousBidId) {
            _existingPaymentNotifier.value = null;
            _paymentLoadedNotifier.value = false;
          }
          if ((state.bid.status == 'PENDING' || state.bid.status == 'ACCEPTED') &&
              !_paymentLoadedNotifier.value) {
            _loadPaymentStatus();
          }
          // Restart timer if bid transitioned to IN_TRANSIT
          if ((state.bid.status == 'ACCEPTED' || state.bid.status == 'IN_TRANSIT')
              && _refreshTimer == null) {
            _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
              if (mounted) context.read<BidBloc>().add(BidDetailRequested(_bid.id));
            });
          } else if (state.bid.status != 'ACCEPTED' && state.bid.status != 'IN_TRANSIT') {
            _refreshTimer?.cancel();
            _refreshTimer = null;
          }
        } else if (state is BidError) {
          if (_skeletonLoading) {
            _skeletonLoading = false;
            context.pop();
          }
          DonySnackbar.show(context, message: state.message, type: DonySnackbarType.error);
        }
      },
      builder: (context, state) {
        final isLoading = state is BidLoading;
        final authState = context.read<AuthBloc>().state;
        final isSender =
            authState is AuthAuthenticated && authState.user.id == _bid.senderId;

        // Derive bid code from tracking number or id
        final bidCode = _bid.trackingNumber ?? _bid.id.substring(0, 6).toUpperCase();

        // Compute corridor codes for display
        final depCity = _bid.departureCity ?? 'Paris';
        final arrCity = _bid.arrivalCity ?? 'Dakar';
        final depCode = cityAirportCode(depCity, departure: true);
        final arrCode = cityAirportCode(arrCity, departure: false);

        return Scaffold(
          backgroundColor: DonyColors.bg,
          appBar: AppBar(
            backgroundColor: DonyColors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  size: 20, color: DonyColors.primary),
              onPressed: () => context.pop(),
              tooltip: 'Retour',
            ),
            title: Text(
              'Mon colis #$bidCode',
              style: tt.headlineLarge,
            ),
            centerTitle: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.share_rounded,
                    color: DonyColors.ink900),
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
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: DonyColors.neutral200),
            ),
          ),
          body: _skeletonLoading
              ? const Center(
                  child: CircularProgressIndicator(color: DonyColors.primary))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.lg,
                    DonySpacing.lg,
                    DonySpacing.lg,
                    100,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status badge below title
                      _StatusBadge(bid: _bid),
                      const SizedBox(height: DonySpacing.base),

                      // Route map card
                      RouteMapCard(
                        departureCode: depCode,
                        arrivalCode: arrCode,
                        departureCity: depCity,
                        arrivalCity: arrCity,
                      ),
                      const SizedBox(height: DonySpacing.base),

                      // Traveler card (visible to sender when accepted or completed)
                      if (isSender &&
                          (_bid.status == 'ACCEPTED' ||
                              _bid.status == 'COMPLETED')) ...[
                        _TravelerCard(bid: _bid),
                        const SizedBox(height: DonySpacing.base),
                      ],

                      // Tracking number card
                      if (_bid.trackingNumber != null) ...[
                        _TrackingNumberCard(trackingNumber: _bid.trackingNumber!),
                        const SizedBox(height: DonySpacing.base),
                      ],

                      // Sender card (visible to traveler)
                      if (!isSender) ...[
                        _SenderCard(bid: _bid),
                        const SizedBox(height: DonySpacing.base),
                      ],

                      // Trip details (visible to sender)
                      if (isSender) ...[
                        _TripDetailsCard(bid: _bid),
                        const SizedBox(height: DonySpacing.base),
                      ],

                      // Package card
                      _PackageCard(bid: _bid),
                      const SizedBox(height: DonySpacing.base),

                      // Recipient card
                      _RecipientCard(bid: _bid),
                      const SizedBox(height: DonySpacing.base),

                      // Disclaimer
                      _DisclaimerCard(bid: _bid),

                      // Handover window
                      if (_bid.handoverLocation != null) ...[
                        const SizedBox(height: DonySpacing.base),
                        _HandoverCard(bid: _bid),
                      ],

                      // QR code (sender, accepted)
                      if (isSender &&
                          _bid.status == 'ACCEPTED' &&
                          _bid.trackingNumber != null) ...[
                        const SizedBox(height: DonySpacing.base),
                        QrCodeCard(bidId: _bid.id),
                      ],

                      // Tracking link
                      if (_bid.status == 'ACCEPTED' &&
                          _bid.trackingToken != null) ...[
                        const SizedBox(height: DonySpacing.base),
                        _TrackingLinkCard(bid: _bid),
                      ],

                      // Confirmation code (sender)
                      if (isSender &&
                          _bid.status == 'ACCEPTED' &&
                          _bid.confirmationCode != null) ...[
                        const SizedBox(height: DonySpacing.base),
                        _ConfirmationCodeCard(code: _bid.confirmationCode!),
                      ],

                      // Timeline section ("ÉTAPES")
                      if (_bid.status == 'COMPLETED' ||
                          _bid.status == 'DELIVERED') ...[
                        const SizedBox(height: DonySpacing.xl),
                        _StepsSection(bid: _bid),
                      ],

                      // Timeline button
                      if (_bid.status == 'ACCEPTED') ...[
                        const SizedBox(height: DonySpacing.base),
                        _TimelineButton(bid: _bid),
                      ],

                      // Payment release row
                      if (_bid.status == 'COMPLETED') ...[
                        const SizedBox(height: DonySpacing.base),
                        _PaymentReleaseCard(bid: _bid),
                      ],

                      // Cancel section (traveler only, ACCEPTED or IN_TRANSIT)
                      if (!isSender &&
                          (_bid.status == 'ACCEPTED' ||
                              _bid.status == 'IN_TRANSIT')) ...[
                        const SizedBox(height: DonySpacing.xl),
                        _TravelerCancelSection(bid: _bid, isLoading: isLoading),
                      ],
                    ],
                  ).animate().fadeIn(duration: 300.ms).slideY(
                      begin: 0.04, curve: Curves.easeOutCubic),
                ),
          bottomNavigationBar: (isSender &&
                  (_bid.status == 'PENDING' || _bid.status == 'ACCEPTED'))
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
                              DateTime.now().isAfter(_bid.handoverWindowStart!
                                  .subtract(const Duration(hours: 4))) &&
                              DateTime.now().isBefore(_bid.handoverWindowEnd ??
                                  DateTime.now()
                                      .add(const Duration(hours: 1)))
                          ? _ConfirmPresenceBar(bid: _bid, isLoading: isLoading)
                          : null,
        );
      },
    );
  }

}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final BidModel bid;
  const _StatusBadge({required this.bid});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    Color color;
    String label;

    switch (bid.status) {
      case 'ACCEPTED':
        color = DonyColors.success;
        label = '● Accepté';
        break;
      case 'REJECTED':
        color = DonyColors.error;
        label = '● Refusé';
        break;
      case 'COMPLETED':
        color = DonyColors.success;
        label = '● Livré';
        break;
      case 'CANCELLED':
        color = DonyColors.neutral400;
        label = '● Annulé';
        break;
      case 'IN_TRANSIT':
        color = DonyColors.primary;
        label = '● En transit';
        break;
      default:
        color = DonyColors.warning;
        label = '● En attente';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        style: tt.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Traveler card ─────────────────────────────────────────────────────────────

class _TravelerCard extends StatelessWidget {
  final BidModel bid;
  const _TravelerCard({required this.bid});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final name = bid.travelerName ?? 'Voyageur';

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VOYAGEUR',
            style: tt.labelSmall?.copyWith(
              color: DonyColors.neutral400,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          Row(
            children: [
              DonyAvatar(name: name, size: DonyAvatarSize.md, verified: true),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: DonySpacing.sm),
                        // KYC badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DonySpacing.sm,
                            vertical: DonySpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: DonyColors.primarySoft,
                            borderRadius: BorderRadius.circular(DonyRadius.full),
                          ),
                          child: Text(
                            'KYC',
                            style: tt.labelSmall?.copyWith(
                              color: DonyColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '★ — · ${bid.travelerPhone != null ? 'Vérifié' : '—'}',
                      style: tt.bodySmall?.copyWith(color: DonyColors.neutral400),
                    ),
                  ],
                ),
              ),
              // Phone button
              _IconActionButton(
                icon: Icons.phone_rounded,
                onTap: () {},
              ),
              const SizedBox(width: DonySpacing.sm),
              // Chat button
              _IconActionButton(
                icon: Icons.chat_bubble_outline_rounded,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DonyRadius.full),
          border: Border.all(color: DonyColors.primary),
        ),
        child: Icon(icon, color: DonyColors.primary, size: 18),
      ),
    );
  }
}

// ── Steps section ─────────────────────────────────────────────────────────────

class _StepsSection extends StatelessWidget {
  final BidModel bid;
  const _StepsSection({required this.bid});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    // Static example steps matching maquette for COMPLETED bids
    final steps = [
      _StepData(
        label: 'Colis remis',
        detail: 'Aujourd\'hui · 14:32',
        completed: true,
        isDelivery: false,
      ),
      _StepData(
        label: 'Embarquement CDG',
        detail: 'Auj. · 09:18 · SAS B 38, Charles-de-Gaulle',
        completed: true,
        isDelivery: false,
      ),
      _StepData(
        label: 'Arrivé Dakar',
        detail: 'Auj. · 14:08 · DSS',
        completed: true,
        isDelivery: false,
      ),
      _StepData(
        label: 'Livraison confirmée',
        detail: 'Auj. · 14:32 · Code ✓',
        completed: true,
        isDelivery: true,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ÉTAPES',
          style: tt.labelMedium?.copyWith(
            color: DonyColors.neutral400,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: DonySpacing.md),
        ...steps.asMap().entries.map((entry) {
          final i = entry.key;
          final step = entry.value;
          final isLast = i == steps.length - 1;
          return _StepItem(step: step, isLast: isLast, index: i);
        }),
      ],
    );
  }
}

class _StepData {
  final String label;
  final String detail;
  final bool completed;
  final bool isDelivery;

  const _StepData({
    required this.label,
    required this.detail,
    required this.completed,
    required this.isDelivery,
  });
}

class _StepItem extends StatelessWidget {
  final _StepData step;
  final bool isLast;
  final int index;

  const _StepItem(
      {required this.step, required this.isLast, required this.index});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final color = step.isDelivery ? DonyColors.success : DonyColors.primary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: step.completed ? color : DonyColors.neutral200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    step.completed ? Icons.check_rounded : Icons.circle_outlined,
                    color: DonyColors.white,
                    size: 16,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: DonyColors.neutral200,
                      margin: const EdgeInsets.symmetric(
                          vertical: DonySpacing.xs),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: isLast ? 0 : DonySpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: tt.titleSmall?.copyWith(
                      color: step.completed
                          ? DonyColors.ink900
                          : DonyColors.neutral400,
                    ),
                  ),
                  Text(
                    step.detail,
                    style: tt.bodySmall?.copyWith(color: DonyColors.neutral400),
                  ),
                  const SizedBox(height: DonySpacing.sm),
                ],
              ),
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

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.neutral200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fonds libérés à ${bid.travelerName ?? 'Ibrahima'}',
                  style: tt.bodyMedium?.copyWith(color: DonyColors.ink900),
                ),
                Text(
                  'Reçu disponible · ${bid.pricePerKg != null ? (bid.pricePerKg! * bid.weightKg * 0.88).toStringAsFixed(2) : '—'} €',
                  style: tt.bodySmall?.copyWith(color: DonyColors.neutral400),
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
              color: DonyColors.primarySoft,
              borderRadius: BorderRadius.circular(DonyRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: DonyColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: DonySpacing.xs),
                Text(
                  'Reçu',
                  style: tt.labelSmall?.copyWith(
                    color: DonyColors.success,
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

// ── Existing cards (preserved, design-token-ified) ───────────────────────────

class _SenderCard extends StatelessWidget {
  final BidModel bid;
  const _SenderCard({required this.bid});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return _Card(
      title: 'Expéditeur',
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: DonyColors.blue100,
              borderRadius: BorderRadius.circular(DonyRadius.lg),
            ),
            child: const Icon(Icons.person_rounded,
                color: DonyColors.primary, size: 24),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bid.resolvedSenderName,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DonyColors.ink900,
                  ),
                ),
                if (bid.senderName != null &&
                    bid.senderName!.isNotEmpty &&
                    bid.senderPhone != null)
                  Row(
                    children: [
                      const Icon(Icons.phone_rounded,
                          size: 12, color: DonyColors.neutral400),
                      const SizedBox(width: DonySpacing.xs),
                      Text(
                        bid.senderPhone!,
                        style: tt.bodySmall?.copyWith(color: DonyColors.neutral400),
                      ),
                    ],
                  ),
                Text(
                  'Demande soumise le ${DateFormat('dd/MM/yyyy à HH:mm').format(bid.createdAt)}',
                  style: tt.bodySmall?.copyWith(color: DonyColors.neutral400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final BidModel bid;
  const _PackageCard({required this.bid});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Colis',
      child: Column(
        children: [
          _InfoRow(label: 'Catégorie', value: bid.contentCategory ?? '—'),
          const SizedBox(height: DonySpacing.sm),
          _InfoRow(label: 'Description', value: bid.description),
          const SizedBox(height: DonySpacing.sm),
          _InfoRow(label: 'Poids', value: '${bid.weightKg} kg'),
          const SizedBox(height: DonySpacing.sm),
          _InfoRow(
              label: 'Valeur déclarée',
              value: '${bid.declaredValueEur.toStringAsFixed(2)} €'),
        ],
      ),
    );
  }
}

class _RecipientCard extends StatelessWidget {
  final BidModel bid;
  const _RecipientCard({required this.bid});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Destinataire',
      child: Column(
        children: [
          _InfoRow(label: 'Nom', value: bid.recipientName ?? '—'),
          const SizedBox(height: DonySpacing.sm),
          _InfoRow(label: 'Téléphone', value: bid.recipientPhone ?? '—'),
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
    return _Card(
      title: 'Responsabilité légale',
      child: Row(
        children: [
          const Icon(Icons.verified_outlined, color: DonyColors.success, size: 20),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              bid.disclaimerSignedAt != null
                  ? 'Disclaimer signé le ${DateFormat('dd/MM/yyyy à HH:mm').format(bid.disclaimerSignedAt!)}'
                  : 'Disclaimer signé',
              style: tt.bodySmall?.copyWith(color: DonyColors.neutral400),
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
    return _Card(
      title: 'Fenêtre de remise',
      child: Column(
        children: [
          _InfoRow(label: 'Lieu', value: bid.handoverLocation ?? '—'),
          if (bid.handoverWindowStart != null) ...[
            const SizedBox(height: DonySpacing.sm),
            _InfoRow(
              label: 'Début',
              value: DateFormat('dd/MM/yyyy HH:mm')
                  .format(bid.handoverWindowStart!),
            ),
          ],
          if (bid.handoverWindowEnd != null) ...[
            const SizedBox(height: DonySpacing.sm),
            _InfoRow(
              label: 'Fin',
              value: DateFormat('dd/MM/yyyy HH:mm')
                  .format(bid.handoverWindowEnd!),
            ),
          ],
          const SizedBox(height: DonySpacing.sm),
          _InfoRow(
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
    return _Card(
      title: 'Détails du trajet',
      child: Column(
        children: [
          _InfoRow(
            label: 'Date de départ',
            value: _formatDate(bid.departureDate),
          ),
          if (bid.departureTime != null) ...[
            const SizedBox(height: DonySpacing.sm),
            _InfoRow(
              label: 'Heure de départ',
              value: _formatTime(bid.departureTime),
            ),
          ],
          if (bid.arrivalTime != null) ...[
            const SizedBox(height: DonySpacing.sm),
            _InfoRow(
              label: 'Heure d\'arrivée',
              value: _formatTime(bid.arrivalTime),
            ),
          ],
          if (bid.pricePerKg != null) ...[
            const SizedBox(height: DonySpacing.sm),
            _InfoRow(
              label: 'Tarif par kg',
              value: '${bid.pricePerKg!.toStringAsFixed(2)} €',
            ),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.neutral200),
      ),
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: tt.labelMedium?.copyWith(
              color: DonyColors.neutral400,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: tt.bodySmall?.copyWith(color: DonyColors.neutral400),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: tt.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: DonyColors.ink900,
            ),
          ),
        ),
      ],
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
    return Container(
      color: DonyColors.white,
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.base,
        DonySpacing.lg,
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
                foregroundColor: DonyColors.error,
                side: const BorderSide(color: DonyColors.error),
                padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DonyRadius.lg)),
              ),
            ),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: FilledButton.icon(
              onPressed: isLoading
                  ? null
                  : () => context
                      .read<BidBloc>()
                      .add(BidAcceptRequested(bid.id)),
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: DonyColors.white),
                    )
                  : const Icon(Icons.check_rounded),
              label: const Text('Accepter'),
              style: FilledButton.styleFrom(
                backgroundColor: DonyColors.success,
                foregroundColor: DonyColors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DonyRadius.lg)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Refuser la demande', style: tt.headlineMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Souhaitez-vous indiquer une raison à l\'expéditeur ?',
              style: tt.bodySmall?.copyWith(color: DonyColors.neutral400),
            ),
            const SizedBox(height: DonySpacing.md),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Raison (optionnelle)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DonyRadius.md)),
                hintStyle: tt.bodySmall?.copyWith(color: DonyColors.neutral400),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: Text('Annuler',
                style: tt.bodyMedium?.copyWith(color: DonyColors.neutral400)),
          ),
          FilledButton(
            onPressed: () {
              ctx.pop();
              context.read<BidBloc>().add(BidRejectRequested(bid.id,
                  reason: reasonCtrl.text.trim().isEmpty
                      ? null
                      : reasonCtrl.text.trim()));
            },
            style: FilledButton.styleFrom(
              backgroundColor: DonyColors.error,
              foregroundColor: DonyColors.white,
              elevation: 0,
            ),
            child: Text('Confirmer le refus',
                style: tt.labelLarge?.copyWith(color: DonyColors.white)),
          ),
        ],
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
    return Container(
      color: DonyColors.white,
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.base,
        DonySpacing.lg,
        MediaQuery.of(context).padding.bottom + DonySpacing.base,
      ),
      child: DonyButton(
        label: 'Confirmer ma présence',
        icon: Icons.location_on_rounded,
        onPressed: isLoading
            ? null
            : () => context
                .read<BidBloc>()
                .add(BidConfirmPresenceRequested(bid.id)),
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
    final (IconData icon, Color color, String label) = _resolve();

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

  (IconData, Color, String) _resolve() {
    final amount = payment.amount.toStringAsFixed(2);
    return switch (payment.status) {
      'RELEASED' => (
          Icons.check_circle_rounded,
          DonyColors.success,
          'Voyageur payé — $amount €',
        ),
      'REFUNDED' => (
          Icons.replay_rounded,
          DonyColors.neutral400,
          'Remboursé — $amount €',
        ),
      'FAILED' => (
          Icons.error_outline_rounded,
          DonyColors.error,
          'Paiement échoué',
        ),
      _ when bidStatus == 'PENDING' => (
          Icons.lock_clock_rounded,
          DonyColors.warning,
          'Paiement sécurisé · En attente du voyageur',
        ),
      _ when bidStatus == 'ACCEPTED' => (
          Icons.lock_rounded,
          DonyColors.success,
          'Paiement sécurisé — $amount €',
        ),
      _ => (
          Icons.lock_rounded,
          DonyColors.success,
          'Paiement sécurisé — $amount €',
        ),
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
      backgroundColor: Colors.transparent,
      builder: (_) => _SenderOptionsSheet(bid: bid, outerContext: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DonyColors.white,
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.base,
        DonySpacing.lg,
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
                foregroundColor: DonyColors.neutral400,
                side: const BorderSide(color: DonyColors.neutral200),
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DonyRadius.lg)),
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
                        color: DonyColors.neutral100,
                        borderRadius: BorderRadius.circular(DonyRadius.lg),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: DonyColors.neutral400),
                        ),
                      ),
                    )
                  : existingPayment != null
                      ? _EscrowBadge(
                          payment: existingPayment!, bidStatus: bid.status)
                      : FilledButton.icon(
                          onPressed: () =>
                              context.push('/payments/pay', extra: bid),
                          icon: const Icon(Icons.lock_rounded, size: 18),
                          label: const Text('Payer mon envoi'),
                          style: FilledButton.styleFrom(
                            backgroundColor: DonyColors.primary,
                            foregroundColor: DonyColors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                vertical: DonySpacing.md),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(DonyRadius.lg)),
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
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        0,
        DonySpacing.lg,
        bottomPad + DonySpacing.xl,
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
                  color: DonyColors.neutral200,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('Options', style: tt.headlineMedium),
          const SizedBox(height: DonySpacing.base),
          _OptionTile(
            icon: Icons.flag_outlined,
            iconColor: DonyColors.error,
            iconBg: DonyColors.errorLight,
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
            iconColor: DonyColors.primary,
            iconBg: DonyColors.blue100,
            label: 'Contacter le voyageur',
            subtitle: 'Messagerie — bientôt disponible',
            disabled: true,
            onTap: null,
          ),
          const SizedBox(height: DonySpacing.sm),
          if (bid.status == 'PENDING') ...[
            _OptionTile(
              icon: Icons.block_rounded,
              iconColor: DonyColors.error,
              iconBg: DonyColors.errorLight,
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
              iconColor: DonyColors.error,
              iconBg: DonyColors.errorLight,
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
    final reasons = [
      'Informations fausses sur le trajet',
      'Comportement inapproprié',
      'Tentative d\'arnaque',
      'Autre',
    ];
    String? selected;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: DonyColors.white,
            borderRadius: BorderRadius.vertical(
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
                    color: DonyColors.neutral200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Signaler ce trajet', style: tt.headlineMedium),
              const SizedBox(height: DonySpacing.xs),
              Text(
                'Votre signalement sera traité par l\'équipe Dony.',
                style: tt.bodySmall?.copyWith(color: DonyColors.neutral400),
              ),
              const SizedBox(height: DonySpacing.base),
              ...reasons.map((r) => RadioListTile<String>(
                    value: r,
                    groupValue: selected,
                    onChanged: (v) => setSheetState(() => selected = v),
                    title: Text(r, style: tt.bodyMedium),
                    activeColor: DonyColors.primary,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  )),
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
                            content: Text('Signalement envoyé. Merci !',
                                style: tt.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w500)),
                            backgroundColor: DonyColors.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(DonyRadius.sm)),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.sheet)),
        title: Text('Annuler la demande', style: tt.headlineMedium),
        content: Text(
          'Voulez-vous vraiment annuler votre demande d\'envoi ? Cette action est définitive.',
          style: tt.bodySmall?.copyWith(color: DonyColors.neutral400),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: Text('Non',
                style: tt.bodyMedium?.copyWith(color: DonyColors.neutral400)),
          ),
          FilledButton(
            onPressed: () {
              ctx.pop();
              context.read<BidBloc>().add(BidCancelRequested(bid.id));
            },
            style: FilledButton.styleFrom(
              backgroundColor: DonyColors.error,
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.sheet)),
        title: Text('Supprimer cette demande', style: tt.headlineMedium),
        content: Text(
          'Cette demande sera définitivement supprimée de votre historique.',
          style: tt.bodySmall?.copyWith(color: DonyColors.neutral400),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: Text('Annuler',
                style: tt.bodyMedium?.copyWith(color: DonyColors.neutral400)),
          ),
          FilledButton(
            onPressed: () {
              ctx.pop();
              context.read<BidBloc>().add(BidDeleteRequested(bid.id));
            },
            style: FilledButton.styleFrom(
              backgroundColor: DonyColors.error,
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
    return Container(
      color: DonyColors.white,
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.base,
        DonySpacing.lg,
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
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.sheet)),
        title: Text('Supprimer cette demande', style: tt.headlineMedium),
        content: Text(
          'Cette demande refusée sera retirée définitivement de votre liste.',
          style: tt.bodySmall?.copyWith(color: DonyColors.neutral400),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: Text('Annuler',
                style: tt.bodyMedium?.copyWith(color: DonyColors.neutral400)),
          ),
          FilledButton(
            onPressed: () {
              ctx.pop();
              context.read<BidBloc>().add(BidTravelerDismissRequested(bid.id));
            },
            style: FilledButton.styleFrom(
              backgroundColor: DonyColors.error,
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

// ── Tracking number card ──────────────────────────────────────────────────────

class _TrackingNumberCard extends StatelessWidget {
  final String trackingNumber;
  const _TrackingNumberCard({required this.trackingNumber});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NUMÉRO DE SUIVI',
            style: tt.labelMedium?.copyWith(
              color: DonyColors.neutral400,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DonySpacing.sm),
                decoration: BoxDecoration(
                  color: DonyColors.blue100,
                  borderRadius: BorderRadius.circular(DonyRadius.sm),
                ),
                child: const Icon(Icons.local_shipping_outlined,
                    color: DonyColors.primary, size: 20),
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Text(
                  trackingNumber,
                  style: tt.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded,
                    color: DonyColors.primary, size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: trackingNumber));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Numéro copié !',
                          style: tt.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500)),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DonyRadius.sm)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                tooltip: 'Copier',
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            'Partagez ce numéro avec votre destinataire pour qu\'il puisse suivre le colis.',
            style: tt.bodySmall?.copyWith(color: DonyColors.neutral400, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ── Timeline button ───────────────────────────────────────────────────────────

class _TimelineButton extends StatelessWidget {
  final BidModel bid;
  const _TimelineButton({required this.bid});

  String get _corridor {
    final dep = bid.departureCity ?? '';
    final arr = bid.arrivalCity ?? '';
    return dep.isNotEmpty && arr.isNotEmpty ? '$dep → $arr' : 'Suivi du colis';
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () => context.push('/tracking/${bid.id}/timeline', extra: _corridor),
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.base),
        decoration: BoxDecoration(
          color: DonyColors.blue100,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: DonyColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(DonySpacing.sm),
              decoration: BoxDecoration(
                color: DonyColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(DonyRadius.sm),
              ),
              child: const Icon(Icons.timeline_rounded,
                  color: DonyColors.primary, size: 20),
            ),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Suivi en temps réel',
                    style: tt.titleSmall?.copyWith(color: DonyColors.ink900),
                  ),
                  Text(
                    'Consulter l\'historique des scans',
                    style: tt.bodySmall?.copyWith(color: DonyColors.neutral400),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: DonyColors.primary, size: 20),
          ],
        ),
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
    return Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(DonySpacing.md),
          decoration: BoxDecoration(
            color: DonyColors.neutral100,
            borderRadius: BorderRadius.circular(DonyRadius.lg),
            border: Border.all(color: DonyColors.neutral200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DonySpacing.sm),
                decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(DonyRadius.sm)),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: tt.titleSmall?.copyWith(color: DonyColors.ink900),
                    ),
                    Text(
                      subtitle,
                      style: tt.bodySmall?.copyWith(color: DonyColors.neutral400),
                    ),
                  ],
                ),
              ),
              if (!disabled)
                const Icon(Icons.chevron_right_rounded,
                    color: DonyColors.neutral400, size: 18),
              if (disabled)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.sm,
                    vertical: DonySpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: DonyColors.neutral200,
                    borderRadius: BorderRadius.circular(DonyRadius.sm),
                  ),
                  child: Text(
                    'Bientôt',
                    style: tt.labelSmall?.copyWith(color: DonyColors.neutral400),
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
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LIEN DE SUIVI',
            style: tt.labelMedium?.copyWith(
              color: DonyColors.neutral400,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          Container(
            padding: const EdgeInsets.all(DonySpacing.md),
            decoration: BoxDecoration(
              color: DonyColors.neutral100,
              borderRadius: BorderRadius.circular(DonyRadius.sm),
              border: Border.all(color: DonyColors.neutral200),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded,
                    color: DonyColors.primary, size: 16),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: Text(
                    _trackingUrl,
                    style: tt.bodySmall?.copyWith(color: DonyColors.neutral400),
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
                        content: Text('Lien copié',
                            style: tt.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500)),
                        backgroundColor: DonyColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(DonyRadius.sm)),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: Text('Copier',
                      style:
                          tt.titleSmall?.copyWith(color: DonyColors.primary)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DonyColors.primary,
                    side: const BorderSide(color: DonyColors.primary),
                    padding: const EdgeInsets.symmetric(
                        vertical: DonySpacing.md),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DonyRadius.md)),
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
                  label: Text('Partager',
                      style:
                          tt.titleSmall?.copyWith(color: DonyColors.white)),
                  style: FilledButton.styleFrom(
                    backgroundColor: DonyColors.primary,
                    foregroundColor: DonyColors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        vertical: DonySpacing.md),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DonyRadius.md)),
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

// ── Confirmation code card ────────────────────────────────────────────────────

class _ConfirmationCodeCard extends StatelessWidget {
  final String code;
  const _ConfirmationCodeCard({required this.code});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CODE DE CONFIRMATION',
            style: tt.labelMedium?.copyWith(
              color: DonyColors.neutral400,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: DonySpacing.lg),
            decoration: BoxDecoration(
              color: DonyColors.blue100,
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: Text(
              code,
              textAlign: TextAlign.center,
              style: tt.displayLarge?.copyWith(
                color: DonyColors.blue700,
                letterSpacing: 12,
              ),
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Code copié',
                      style: tt.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500)),
                  backgroundColor: DonyColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DonyRadius.sm)),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
              decoration: BoxDecoration(
                border: Border.all(color: DonyColors.primary),
                borderRadius: BorderRadius.circular(DonyRadius.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.copy_rounded,
                      size: 16, color: DonyColors.primary),
                  const SizedBox(width: DonySpacing.sm),
                  Text(
                    'Copier le code',
                    style: tt.titleSmall?.copyWith(color: DonyColors.primary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          Container(
            padding: const EdgeInsets.all(DonySpacing.sm),
            decoration: BoxDecoration(
              color: DonyColors.warningLight,
              borderRadius: BorderRadius.circular(DonyRadius.sm),
              border: Border.all(color: DonyColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: DonyColors.warning),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: Text(
                    'Transmettez ce code au destinataire par vos propres moyens (SMS, WhatsApp…). Le voyageur devra le saisir à la livraison.',
                    style: tt.bodySmall
                        ?.copyWith(color: DonyColors.neutral400, height: 1.4),
                  ),
                ),
              ],
            ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ANNULATION',
          style: tt.labelMedium?.copyWith(
            color: DonyColors.neutral400,
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
    final reason =
        await CancellationDialog.show(context, isInTransit: isInTransit);
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
