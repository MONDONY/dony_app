import 'package:dony/app/theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
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

  @override
  void initState() {
    super.initState();
    _bid = widget.initialBid;
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
                _SenderCard(bid: _bid),
                const SizedBox(height: 16),
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
          bottomNavigationBar: _bid.status == 'PENDING' && !isSender
              ? _ActionBar(bid: _bid, isLoading: isLoading)
              : _bid.status == 'ACCEPTED' && !_bid.voyageurConfirmed && !isSender
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
                  bid.senderName ?? 'Expéditeur anonyme',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700, fontSize: 16, color: kTextPrimary),
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
