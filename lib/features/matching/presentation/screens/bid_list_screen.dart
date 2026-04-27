import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class BidListScreen extends StatelessWidget {
  final String announcementId;

  const BidListScreen({super.key, required this.announcementId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<BidBloc>()..add(BidListRequested(announcementId)),
      child: _BidListView(announcementId: announcementId),
    );
  }
}

class _BidListView extends StatelessWidget {
  final String announcementId;
  const _BidListView({required this.announcementId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DonyColors.grey50,
      appBar: AppBar(
        backgroundColor: DonyColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20, color: DonyColors.green400),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Demandes reçues',
          style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 18, color: DonyColors.ink900),
        ),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: DonyColors.grey100),
        ),
      ),
      body: BlocConsumer<BidBloc, BidState>(
        listener: (context, state) {
          if (state is BidDeleted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Demande supprimée.',
                  style: GoogleFonts.sora(fontWeight: FontWeight.w500)),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ));
            context.read<BidBloc>().add(BidListRequested(announcementId));
          } else if (state is BidError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.message,
                  style: GoogleFonts.sora(fontWeight: FontWeight.w500)),
              backgroundColor: DonyColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ));
            // Ne pas retry automatiquement — l'utilisateur doit agir explicitement
          }
        },
        builder: (context, state) {
          if (state is BidLoading) {
            return const Center(child: CircularProgressIndicator(color: DonyColors.green400));
          }
          if (state is BidListLoaded) {
            if (state.bids.isEmpty) {
              return _EmptyView();
            }
            return _BidList(bids: state.bids);
          }
          if (state is BidError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: DonyColors.grey200),
                  const SizedBox(height: 12),
                  Text(state.message,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.sora(fontSize: 14, color: DonyColors.grey400)),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () =>
                        context.read<BidBloc>().add(BidListRequested(announcementId)),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _BidList extends StatelessWidget {
  final List<BidModel> bids;
  const _BidList({required this.bids});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      itemCount: bids.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final bid = bids[i];
        final card = _BidCard(bid: bid)
            .animate(delay: Duration(milliseconds: i * 60))
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);

        if (bid.status != 'REJECTED') return card;

        return Dismissible(
          key: ValueKey(bid.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(
              color: DonyColors.error,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.delete_outline_rounded,
                    color: Colors.white, size: 28),
                const SizedBox(height: 4),
                Text('Supprimer',
                    style: GoogleFonts.sora(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          confirmDismiss: (_) async {
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: Text('Supprimer cette demande',
                    style: GoogleFonts.sora(
                        fontWeight: FontWeight.w700, fontSize: 17)),
                content: Text(
                    'Cette demande refusée sera retirée définitivement de votre liste.',
                    style: GoogleFonts.sora(
                        fontSize: 14, color: DonyColors.grey400)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('Annuler',
                        style: GoogleFonts.sora(
                            color: DonyColors.grey400,
                            fontWeight: FontWeight.w600)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: DonyColors.error,
                        foregroundColor: Colors.white,
                        elevation: 0),
                    child: Text('Supprimer',
                        style: GoogleFonts.sora(
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ) ??
                false;
          },
          onDismissed: (_) =>
              context.read<BidBloc>().add(BidTravelerDismissRequested(bid.id)),
          child: card,
        );
      },
    );
  }
}

class _BidCard extends StatelessWidget {
  final BidModel bid;
  const _BidCard({required this.bid});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(bid.status);
    final statusLabel = _statusLabel(bid.status);

    return GestureDetector(
      onTap: () => context.push('/bids/${bid.id}', extra: bid),
      child: Container(
        decoration: BoxDecoration(
          color: DonyColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DonyColors.grey100),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: DonyColors.green100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_outline_rounded, color: DonyColors.green400, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bid.resolvedSenderName,
                        style: GoogleFonts.sora(
                            fontWeight: FontWeight.w600, fontSize: 14, color: DonyColors.ink900),
                      ),
                      if (bid.senderName != null && bid.senderName!.isNotEmpty && bid.senderPhone != null)
                        Text(
                          bid.senderPhone!,
                          style: GoogleFonts.sora(fontSize: 12, color: DonyColors.grey400),
                        ),
                      Text(
                        DateFormat('dd MMM yyyy').format(bid.createdAt),
                        style: GoogleFonts.sora(fontSize: 12, color: DonyColors.grey400),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.sora(
                        fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: DonyColors.grey100, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(label: 'Poids', value: '${bid.weightKg} kg'),
                const SizedBox(width: 24),
                _Stat(label: 'Valeur', value: '${bid.declaredValueEur.toStringAsFixed(0)} €'),
                const SizedBox(width: 24),
                _Stat(label: 'Catégorie', value: bid.contentCategory ?? '—'),
              ],
            ),
            if (bid.status == 'PENDING') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: DonyColors.grey200),
                  const SizedBox(width: 4),
                  Text(
                    'Voir le détail et répondre',
                    style: GoogleFonts.sora(
                        fontSize: 12, color: DonyColors.green400, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ACCEPTED':
        return DonyColors.success;
      case 'REJECTED':
        return DonyColors.error;
      case 'CANCELLED':
        return DonyColors.grey400;
      default:
        return DonyColors.warning;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'ACCEPTED':
        return 'Accepté';
      case 'REJECTED':
        return 'Refusé';
      case 'COMPLETED':
        return 'Livré';
      case 'CANCELLED':
        return 'Annulé';
      default:
        return 'En attente';
    }
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.sora(fontSize: 11, color: DonyColors.grey200, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.sora(fontSize: 13, color: DonyColors.ink900, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: DonyColors.green100, borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.inbox_outlined, color: DonyColors.green400, size: 36),
            ),
            const SizedBox(height: 16),
            Text('Aucune demande',
                style: GoogleFonts.sora(
                    fontSize: 18, fontWeight: FontWeight.w700, color: DonyColors.ink900)),
            const SizedBox(height: 8),
            Text('Partagez votre annonce pour recevoir des demandes d\'expéditeurs.',
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(fontSize: 14, color: DonyColors.grey400)),
          ],
        ),
      ),
    );
  }
}

