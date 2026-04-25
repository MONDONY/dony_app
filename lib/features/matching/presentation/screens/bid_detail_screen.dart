import 'package:dony/app/theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/payments/data/models/payment_model.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class BidDetailScreen extends StatelessWidget {
  final BidModel bid;

  const BidDetailScreen({super.key, required this.bid});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<BidBloc>(),
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
  PaymentModel? _existingPayment;
  bool _paymentLoaded = false;

  @override
  void initState() {
    super.initState();
    _bid = widget.initialBid;
    context.read<BidBloc>().add(BidDetailRequested(_bid.id));
    _loadPaymentStatus();
  }

  Future<void> _loadPaymentStatus() async {
    if (_bid.status != 'ACCEPTED') return;
    try {
      final payment = await getIt<PaymentRepository>().getPaymentForBid(_bid.id);
      if (mounted) setState(() { _existingPayment = payment; _paymentLoaded = true; });
    } catch (_) {
      if (mounted) setState(() => _paymentLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BidBloc, BidState>(
      listener: (context, state) {
        if (state is BidAccepted) {
          setState(() => _bid = state.bid);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Demande acceptée ! Définissez maintenant la fenêtre de remise.'),
              backgroundColor: kSuccess,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.push('/bids/${_bid.id}/handover', extra: _bid);
        } else if (state is BidRejected) {
          setState(() => _bid = state.bid);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Demande refusée.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.pop();
        } else if (state is BidPresenceConfirmed) {
          setState(() => _bid = state.bid);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Présence confirmée !'),
              backgroundColor: kSuccess,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state is BidCancelled) {
          setState(() => _bid = state.bid);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Demande annulée.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state is BidDeleted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Demande supprimée.',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500)),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          context.pop();
        } else if (state is BidDetailLoaded) {
          final previousBidId = _bid.id;
          setState(() {
            _bid = state.bid;
            // Réinitialiser le statut paiement si c'est un bid différent
            if (state.bid.id != previousBidId) {
              _existingPayment = null;
              _paymentLoaded = false;
            }
          });
          // Recharger le statut paiement si le bid est ACCEPTED et pas encore chargé
          if (state.bid.status == 'ACCEPTED' && !_paymentLoaded) {
            _loadPaymentStatus();
          }
        } else if (state is BidError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: kError,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is BidLoading;
        final authState = context.read<AuthBloc>().state;
        final isSender = authState is AuthAuthenticated && authState.user.id == _bid.senderId;
        
        return Scaffold(
          backgroundColor: kBackground,
          appBar: AppBar(
            backgroundColor: kSurface,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 20, color: kGreenPrimary),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'Détail de la demande',
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700, fontSize: 18, color: kTextPrimary),
            ),
            centerTitle: false,
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: kBorder),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusBanner(bid: _bid),
                const SizedBox(height: 20),
                _CorridorCard(bid: _bid),
                if (isSender) ...[
                  const SizedBox(height: 16),
                  _TripDetailsCard(bid: _bid),
                ],
                const SizedBox(height: 16),
                if (!isSender) _SenderCard(bid: _bid),
                if (!isSender) const SizedBox(height: 16),
                _PackageCard(bid: _bid),
                const SizedBox(height: 16),
                _RecipientCard(bid: _bid),
                const SizedBox(height: 16),
                _DisclaimerCard(bid: _bid),
                if (_bid.handoverLocation != null) ...[
                  const SizedBox(height: 16),
                  _HandoverCard(bid: _bid),
                ],
              ],
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
          ),
          bottomNavigationBar: (isSender && (_bid.status == 'PENDING' || _bid.status == 'ACCEPTED'))
              ? _SenderActionBar(bid: _bid, isLoading: isLoading, existingPayment: _existingPayment, paymentLoaded: _paymentLoaded)
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
                              DateTime.now().add(const Duration(hours: 1)))
                          ? _ConfirmPresenceBar(bid: _bid, isLoading: isLoading)
                          : null,
        );
      },
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final BidModel bid;
  const _StatusBanner({required this.bid});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (bid.status) {
      case 'ACCEPTED':
        color = kSuccess;
        label = 'Demande acceptée';
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'REJECTED':
        color = kError;
        label = 'Demande refusée';
        icon = Icons.cancel_outlined;
        break;
      case 'CANCELLED':
        color = kTextSecondary;
        label = 'Demande annulée';
        icon = Icons.block_outlined;
        break;
      default:
        color = kWarning;
        label = 'En attente de réponse';
        icon = Icons.hourglass_empty_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600, fontSize: 14, color: color)),
        ],
      ),
    );
  }
}

class _SenderCard extends StatelessWidget {
  final BidModel bid;
  const _SenderCard({required this.bid});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Expéditeur',
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: kGreenLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.person_rounded, color: kGreenPrimary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bid.resolvedSenderName,
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700, fontSize: 16, color: kTextPrimary),
                ),
                if (bid.senderName != null && bid.senderName!.isNotEmpty && bid.senderPhone != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_rounded, size: 12, color: kTextSecondary),
                        const SizedBox(width: 4),
                        Text(
                          bid.senderPhone!,
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: kTextSecondary),
                        ),
                      ],
                    ),
                  ),
                Text(
                  'Demande soumise le ${DateFormat('dd/MM/yyyy à HH:mm').format(bid.createdAt)}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kTextSecondary),
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
          const SizedBox(height: 10),
          _InfoRow(label: 'Description', value: bid.description),
          const SizedBox(height: 10),
          _InfoRow(label: 'Poids', value: '${bid.weightKg} kg'),
          const SizedBox(height: 10),
          _InfoRow(label: 'Valeur déclarée', value: '${bid.declaredValueEur.toStringAsFixed(2)} €'),
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
          const SizedBox(height: 10),
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
    return _Card(
      title: 'Responsabilité légale',
      child: Row(
        children: [
          const Icon(Icons.verified_outlined, color: kSuccess, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              bid.disclaimerSignedAt != null
                  ? 'Disclaimer signé le ${DateFormat('dd/MM/yyyy à HH:mm').format(bid.disclaimerSignedAt!)}'
                  : 'Disclaimer signé',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: kTextSecondary),
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
            const SizedBox(height: 10),
            _InfoRow(
              label: 'Début',
              value: DateFormat('dd/MM/yyyy HH:mm').format(bid.handoverWindowStart!),
            ),
          ],
          if (bid.handoverWindowEnd != null) ...[
            const SizedBox(height: 10),
            _InfoRow(
              label: 'Fin',
              value: DateFormat('dd/MM/yyyy HH:mm').format(bid.handoverWindowEnd!),
            ),
          ],
          const SizedBox(height: 10),
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
    // LocalTime serializes as "HH:mm:ss", show only HH:mm
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
            const SizedBox(height: 10),
            _InfoRow(
              label: 'Heure de départ',
              value: _formatTime(bid.departureTime),
            ),
          ],
          if (bid.arrivalTime != null) ...[
            const SizedBox(height: 10),
            _InfoRow(
              label: 'Heure d\'arrivée',
              value: _formatTime(bid.arrivalTime),
            ),
          ],
          if (bid.pricePerKg != null) ...[
            const SizedBox(height: 10),
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

class _CorridorCard extends StatelessWidget {
  final BidModel bid;
  const _CorridorCard({required this.bid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F4C75), Color(0xFF3282B8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              bid.departureCity ?? '—',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Icon(Icons.arrow_forward_rounded,
                color: Colors.white70, size: 24),
          ),
          Expanded(
            child: Text(
              bid.arrivalCity ?? '—',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800),
            ),
          ),
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
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary,
                  letterSpacing: 0.5)),
          const SizedBox(height: 12),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: kTextHint)),
        ),
        Expanded(
          child: Text(value,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
        ),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  final BidModel bid;
  final bool isLoading;
  const _ActionBar({required this.bid, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kSurface,
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : () => _showRejectDialog(context),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Refuser'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kError,
                side: const BorderSide(color: kError),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isLoading
                  ? null
                  : () => context.read<BidBloc>().add(BidAcceptRequested(bid.id)),
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_rounded),
              label: const Text('Accepter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kSuccess,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Refuser la demande',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Souhaitez-vous indiquer une raison à l\'expéditeur ?',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: kTextSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Raison (optionnelle)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: kTextHint),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Annuler',
                style: GoogleFonts.plusJakartaSans(color: kTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<BidBloc>().add(
                    BidRejectRequested(bid.id,
                        reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim()),
                  );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: kError, foregroundColor: Colors.white, elevation: 0),
            child: Text('Confirmer le refus',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
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
      color: kSurface,
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      child: ElevatedButton.icon(
        onPressed: isLoading
            ? null
            : () => context.read<BidBloc>().add(BidConfirmPresenceRequested(bid.id)),
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.location_on_rounded),
        label: const Text('Confirmer ma présence'),
        style: ElevatedButton.styleFrom(
          backgroundColor: kGreenPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _EscrowBadge extends StatelessWidget {
  final double amount;
  const _EscrowBadge({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: kSuccess.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kSuccess.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_rounded, color: kSuccess, size: 18),
          const SizedBox(width: 8),
          Text(
            'Paiement sécurisé — ${amount.toStringAsFixed(2)} €',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600, fontSize: 14, color: kSuccess),
          ),
        ],
      ),
    );
  }
}

class _SenderActionBar extends StatelessWidget {
  final BidModel bid;
  final bool isLoading;
  final PaymentModel? existingPayment;
  final bool paymentLoaded;
  const _SenderActionBar({required this.bid, required this.isLoading, this.existingPayment, this.paymentLoaded = false});

  void _openOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SenderOptionsSheet(bid: bid, outerContext: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = bid.status == 'PENDING';

    return Container(
      color: kSurface,
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      child: Row(
        children: [
          // Bouton "..." options — toujours visible
          SizedBox(
            width: 52,
            height: 52,
            child: OutlinedButton(
              onPressed: () => _openOptions(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: kTextSecondary,
                side: const BorderSide(color: kBorder),
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Icon(Icons.more_horiz_rounded, size: 22),
            ),
          ),

          if (bid.status == 'ACCEPTED') ...[
            const SizedBox(width: 12),
            Expanded(
              child: !paymentLoaded
                  ? Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: kBorder,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: kTextSecondary),
                        ),
                      ),
                    )
                  : existingPayment != null &&
                          existingPayment!.bidId == bid.id &&
                          (existingPayment!.status == 'ESCROW' ||
                              existingPayment!.status == 'PENDING')
                      ? _EscrowBadge(amount: existingPayment!.amount)
                      : ElevatedButton.icon(
                          onPressed: () =>
                              context.push('/payments/pay', extra: bid),
                          icon: const Icon(Icons.lock_rounded, size: 18),
                          label: const Text('Payer mon envoi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGreenPrimary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
            ),
          ],

          if (isPending) ...[
            const SizedBox(width: 12),
            // Annuler la demande — seulement pour PENDING
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : () => _showCancelDialog(context),
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.block_rounded, size: 18),
                label: const Text('Annuler la demande'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kError,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Annuler la demande',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text(
            'Voulez-vous vraiment annuler votre demande d\'envoi ? Cette action est définitive.',
            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: kTextSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Non',
                style: GoogleFonts.plusJakartaSans(color: kTextSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<BidBloc>().add(BidCancelRequested(bid.id));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: kError, foregroundColor: Colors.white, elevation: 0),
            child: Text('Oui, annuler',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Options bottom sheet (expéditeur) ────────────────────────────────────────

class _SenderOptionsSheet extends StatelessWidget {
  final BidModel bid;
  final BuildContext outerContext;

  const _SenderOptionsSheet({required this.bid, required this.outerContext});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: kBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text(
            'Options',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 18, fontWeight: FontWeight.w700, color: kTextPrimary),
          ),
          const SizedBox(height: 16),

          // Signaler
          _OptionTile(
            icon: Icons.flag_outlined,
            iconColor: kError,
            iconBg: const Color(0xFFFFEBEE),
            label: 'Signaler ce trajet',
            subtitle: 'Signaler un problème au support Dony',
            onTap: () {
              Navigator.pop(context);
              _showReportSheet(outerContext);
            },
          ),

          const SizedBox(height: 8),

          // Contacter le voyageur (bientôt)
          _OptionTile(
            icon: Icons.chat_bubble_outline_rounded,
            iconColor: kGreenPrimary,
            iconBg: kGreenLight,
            label: 'Contacter le voyageur',
            subtitle: 'Messagerie — bientôt disponible',
            disabled: true,
            onTap: null,
          ),

          const SizedBox(height: 8),

          // Supprimer (seulement si terminé / refusé / annulé)
          if (bid.status == 'COMPLETED' ||
              bid.status == 'REJECTED' ||
              bid.status == 'CANCELLED') ...[
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              iconColor: kError,
              iconBg: const Color(0xFFFFEBEE),
              label: 'Supprimer cette demande',
              subtitle: 'Retirer définitivement de votre historique',
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(outerContext);
              },
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  void _showReportSheet(BuildContext context) {
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
            color: kSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.of(ctx).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: kBorder, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text('Signaler ce trajet',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Votre signalement sera traité par l\'équipe Dony.',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, color: kTextSecondary)),
              const SizedBox(height: 16),
              ...reasons.map((r) => RadioListTile<String>(
                    value: r,
                    groupValue: selected,
                    onChanged: (v) => setSheetState(() => selected = v),
                    title: Text(r,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    activeColor: kGreenPrimary,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  )),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: selected == null
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Signalement envoyé. Merci !',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w500)),
                              backgroundColor: kSuccess,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kError,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Envoyer le signalement',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Supprimer cette demande',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text(
            'Cette demande sera définitivement supprimée de votre historique.',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 14, color: kTextSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler',
                style: GoogleFonts.plusJakartaSans(
                    color: kTextSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<BidBloc>().add(BidDeleteRequested(bid.id));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: kError,
                foregroundColor: Colors.white,
                elevation: 0),
            child: Text('Supprimer',
                style:
                    GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Barre voyageur — demande refusée ─────────────────────────────────────────

class _TravelerRejectedBar extends StatelessWidget {
  final BidModel bid;
  final bool isLoading;
  const _TravelerRejectedBar({required this.bid, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kSurface,
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : () => _showDeleteDialog(context),
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.delete_outline_rounded, size: 18),
        label: const Text('Supprimer cette demande'),
        style: ElevatedButton.styleFrom(
          backgroundColor: kError,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Supprimer cette demande',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text(
            'Cette demande refusée sera retirée définitivement de votre liste.',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 14, color: kTextSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler',
                style: GoogleFonts.plusJakartaSans(
                    color: kTextSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<BidBloc>().add(BidTravelerDismissRequested(bid.id));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: kError,
                foregroundColor: Colors.white,
                elevation: 0),
            child: Text('Supprimer',
                style:
                    GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

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
    return Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: iconBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: kTextSecondary),
                    ),
                  ],
                ),
              ),
              if (!disabled)
                const Icon(Icons.chevron_right_rounded,
                    color: kTextHint, size: 18),
              if (disabled)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kBorder,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Bientôt',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kTextSecondary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
