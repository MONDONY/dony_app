import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';

class SameAddressAnnouncementsSheet extends StatelessWidget {
  const SameAddressAnnouncementsSheet({
    super.key,
    required this.addressLabel,
    required this.announcements,
    required this.onTap,
    this.currentUserId,
  });

  final String addressLabel;
  final List<AnnouncementModel> announcements;
  final ValueChanged<AnnouncementModel> onTap;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final maxListHeight = MediaQuery.of(context).size.height * 0.55;
    return Container(
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        0,
        DonySpacing.lg,
        MediaQuery.of(context).viewPadding.bottom + DonySpacing.lg,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(DonyRadius.sheet)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
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
          // Address header
          Row(
            children: [
              Icon(Icons.place_rounded, size: 18, color: cs.primary),
              const SizedBox(width: DonySpacing.xs),
              Expanded(
                child: Text(
                  addressLabel,
                  style: tt.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            '${announcements.length} voyageur${announcements.length > 1 ? "s" : ""} disponible${announcements.length > 1 ? "s" : ""} à cette adresse',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.md),
          // List of TravelerCard — same card as the list view
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxListHeight),
            child: BlocBuilder<BidBloc, BidState>(
              buildWhen: (prev, curr) =>
                  curr is BidListLoaded || prev is BidListLoaded,
              builder: (context, bidState) {
                final activeBids = bidState.activeBidsByAnnouncement();
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: announcements.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: DonySpacing.md),
                  itemBuilder: (_, i) {
                    final a = announcements[i];
                    final isOwn = currentUserId != null &&
                        a.travelerId == currentUserId;
                    final existingBid = activeBids[a.id];
                    return TravelerCard(
                      announcement: a,
                      index: i,
                      isOwnAnnouncement: isOwn,
                      existingBidStatus: existingBid?.status,
                      onTap: isOwn
                          ? null
                          : existingBid != null
                              ? () {
                                  Navigator.of(context, rootNavigator: true)
                                      .pop();
                                  context.push(
                                    '/bids/${existingBid.id}',
                                    extra: existingBid,
                                  );
                                }
                              : () => onTap(a),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
