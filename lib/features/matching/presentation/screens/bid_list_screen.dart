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
      child: const _BidListView(),
    );
  }
}

class _BidListView extends StatelessWidget {
  const _BidListView();

  @override
  Widget build(BuildContext context) {
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
          'Demandes reçues',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18, color: kTextPrimary),
        ),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: kBorder),
        ),
      ),
      body: BlocBuilder<BidBloc, BidState>(
        builder: (context, state) {
          if (state is BidLoading) {
            return const Center(child: CircularProgressIndicator(color: kGreenPrimary));
          }
          if (state is BidError) {
            return _ErrorView(
              message: state.message,
              onRetry: () => context.read<BidBloc>().add(
                    BidListRequested(
                      (context.read<BidBloc>().state is BidListLoaded)
                          ? (context.read<BidBloc>().state as BidListLoaded).bids.first.announcementId
                          : '',
                    ),
                  ),
            );
          }
          if (state is BidListLoaded) {
            if (state.bids.isEmpty) {
              return _EmptyView();
            }
            return _BidList(bids: state.bids);
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
      itemBuilder: (context, i) => _BidCard(bid: bids[i])
          .animate(delay: Duration(milliseconds: i * 60))
          .fadeIn(duration: 300.ms)
          .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
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
          color: kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
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
                    color: kGreenLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_outline_rounded, color: kGreenPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bid.senderName ?? 'Expéditeur',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600, fontSize: 14, color: kTextPrimary),
                      ),
                      Text(
                        DateFormat('dd MMM yyyy').format(bid.createdAt),
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kTextSecondary),
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
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: kBorder, height: 1),
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
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: kTextHint),
                  const SizedBox(width: 4),
                  Text(
                    'Voir le détail et répondre',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: kGreenPrimary, fontWeight: FontWeight.w600),
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
        return kSuccess;
      case 'REJECTED':
        return kError;
      case 'CANCELLED':
        return kTextSecondary;
      default:
        return kWarning;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'ACCEPTED':
        return 'Accepté';
      case 'REJECTED':
        return 'Refusé';
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
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kTextHint, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: kTextPrimary, fontWeight: FontWeight.w600)),
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
              decoration: BoxDecoration(color: kGreenLight, borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.inbox_outlined, color: kGreenPrimary, size: 36),
            ),
            const SizedBox(height: 16),
            Text('Aucune demande',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 18, fontWeight: FontWeight.w700, color: kTextPrimary)),
            const SizedBox(height: 8),
            Text('Partagez votre annonce pour recevoir des demandes d\'expéditeurs.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: kTextSecondary)),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: kError, size: 48),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: kTextSecondary)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(backgroundColor: kGreenPrimary, foregroundColor: kSurface),
            ),
          ],
        ),
      ),
    );
  }
}
