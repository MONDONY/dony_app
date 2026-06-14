import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/block_user_action.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/ratings/presentation/widgets/rating_list_item.dart';
import 'package:dony/features/ratings/presentation/widgets/rating_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ouvre un modal sheet (90 % écran) affichant le profil complet d'un expéditeur.
void showSenderProfileSheet(BuildContext context, BidModel bid) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider(
      create: (_) => getIt<RatingBloc>()
        ..add(UserRatingsLoadRequested(userId: bid.senderId)),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => _SenderProfileSheet(
          bid: bid,
          scrollController: controller,
        ),
      ),
    ),
  );
}

// ─── Sheet content ────────────────────────────────────────────────────────────

class _SenderProfileSheet extends StatelessWidget {
  const _SenderProfileSheet({
    required this.bid,
    required this.scrollController,
  });

  final BidModel bid;
  final ScrollController scrollController;

  String get _abbreviatedName {
    final name = bid.resolvedSenderName;
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0]} ${parts[1][0]}.';
    }
    return parts[0];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
      ),
      child: Column(
        children: [
          // ── Handle + menu ⋯ ──────────────────────────────────────────────
          SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outline,
                    borderRadius: BorderRadius.circular(DonyRadius.full),
                  ),
                ),
                Positioned(
                  right: DonySpacing.sm,
                  child: IconButton(
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: cs.onSurfaceVariant,
                    ),
                    tooltip: 'Plus d\'options',
                    onPressed: () => showBlockMenu(
                      context,
                      userId: bid.senderId,
                      displayName: _abbreviatedName,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DonySpacing.md),

          // ── Scrollable body ────────────────────────────────────────────────
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                DonySpacing.lg, 0, DonySpacing.lg,
                DonySpacing.xl + MediaQuery.of(context).viewPadding.bottom,
              ),
              children: [
                // Avatar + name + phone
                Center(
                  child: Column(
                    children: [
                      DonyAvatar(
                        name: bid.resolvedSenderName,
                        size: DonyAvatarSize.xl,
                        verified: bid.senderKycVerified,
                        pro: bid.senderIsProAccount,
                      ),
                      const SizedBox(height: DonySpacing.md),
                      Text(
                        _abbreviatedName,
                        style: tt.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: DonySpacing.xs),
                      if (bid.senderPhone != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.phone_rounded,
                              size: 13,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: DonySpacing.xs),
                            Text(
                              bid.senderPhone!,
                              style: tt.bodyMedium
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        )
                      else
                        Text(
                          '📞 Numéro révélé après acceptation',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      if (bid.senderIsProAccount ||
                          bid.senderKiloPro ||
                          bid.senderKycVerified) ...[
                        const SizedBox(height: DonySpacing.sm),
                        Wrap(
                          spacing: DonySpacing.sm,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: [
                            if (bid.senderIsProAccount)
                              _SheetBadge(
                                icon: Icons.star_rounded,
                                label: 'Compte PRO',
                                iconColor: cs.warning,
                                bgColor: cs.warningLight,
                                textColor: cs.warning,
                              ),
                            if (bid.senderKiloPro)
                              const _SheetBadge(
                                icon: Icons.star_rounded,
                                label: 'Kilo Pro',
                                iconColor: DonyColors.amberDark,
                                bgColor: DonyColors.amberLight,
                                textColor: DonyColors.amberDark,
                              ),
                            if (bid.senderKycVerified)
                              _SheetBadge(
                                icon: Icons.verified_rounded,
                                label: 'Identité vérifiée',
                                iconColor: cs.primary,
                                bgColor: cs.primaryContainer,
                                textColor: cs.primary,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: DonySpacing.xl),

                // ── Stats ──────────────────────────────────────────────────
                BlocBuilder<RatingBloc, RatingState>(
                  buildWhen: (p, c) =>
                      c is UserRatingsLoaded || c is RatingInitial,
                  builder: (context, state) {
                    final loaded =
                        state is UserRatingsLoaded ? state : null;
                    final noteValue = loaded != null && loaded.ratingCount > 0
                        ? loaded.averageRating.toStringAsFixed(1)
                        : '–';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: DonySpacing.base,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(DonyRadius.card),
                        border: Border.all(color: cs.outline),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _SheetStat(
                            value: noteValue,
                            label: 'Note',
                            icon: Icons.star_rounded,
                            iconColor: cs.warning,
                          ),
                          Container(width: 1, height: 36, color: cs.outline),
                          _SheetStat(
                            value: bid.senderTotalShipments != null
                                ? '${bid.senderTotalShipments}'
                                : '–',
                            label: 'Envois',
                            iconAsset: 'package',
                            iconColor: cs.primary,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: DonySpacing.xl),

                // ── Évaluations ────────────────────────────────────────────
                Text(
                  'Évaluations',
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: DonySpacing.sm),
                BlocBuilder<RatingBloc, RatingState>(
                  builder: (context, state) {
                    if (state is UserRatingsLoaded) {
                      if (state.ratingCount == 0) {
                        return Text(
                          'Aucune évaluation pour l\'instant.',
                          style: tt.bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RatingSummaryCard(
                            averageRating: state.averageRating,
                            ratingCount: state.ratingCount,
                            distribution: state.distribution,
                          ),
                          const SizedBox(height: DonySpacing.base),
                          ...state.ratings.map((r) => RatingListItem(item: r)),
                          if (state.page < state.totalPages - 1)
                            Center(
                              child: TextButton(
                                onPressed: () =>
                                    context.read<RatingBloc>().add(
                                          UserRatingsLoadRequested(
                                            userId: bid.senderId,
                                            page: state.page + 1,
                                          ),
                                        ),
                                child: const Text('Voir plus'),
                              ),
                            ),
                        ],
                      );
                    }
                    if (state is RatingError) {
                      return Center(
                        child: TextButton.icon(
                          onPressed: () => context.read<RatingBloc>().add(
                                UserRatingsLoadRequested(userId: bid.senderId),
                              ),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Réessayer'),
                        ),
                      );
                    }
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Badge item ───────────────────────────────────────────────────────────────

class _SheetBadge extends StatelessWidget {
  const _SheetBadge({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.bgColor,
    required this.textColor,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color bgColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: DonySpacing.xs),
          Text(
            label,
            style: tt.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat item ────────────────────────────────────────────────────────────────

class _SheetStat extends StatelessWidget {
  const _SheetStat({
    required this.value,
    required this.label,
    required this.iconColor,
    this.icon,
    this.iconAsset,
  }) : assert(icon != null || iconAsset != null);

  final String value;
  final String label;
  final IconData? icon;
  final String? iconAsset;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        iconAsset != null
            ? DonyIcon(iconAsset!, size: 16, color: iconColor)
            : Icon(icon, size: 16, color: iconColor),
        const SizedBox(height: DonySpacing.xs),
        Text(
          value,
          style: tt.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
        Text(
          label,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
