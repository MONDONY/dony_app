import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/bloc/request_sender_cubit.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/presentation/package_request_labels.dart';
import 'package:dony/features/package_request/presentation/widgets/sender_public_profile_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Expéditeur de la demande, en tête de la fiche publique côté voyageur
/// (FLUTTER-GF) : avatar, nom, note et nombre d'avis. Le tap ouvre le même
/// résumé de profil que la carte de la liste de recherche.
///
/// Lit [RequestSenderCubit] : squelette pendant le chargement, rien quand le
/// profil est masqué (compte bloqué, 404) ou illisible.
class RequestSenderRow extends StatelessWidget {
  const RequestSenderRow({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RequestSenderCubit, RequestSenderState>(
      builder: (context, state) {
        final child = switch (state) {
          RequestSenderLoading() => const _SenderRowSkeleton(
            key: Key('request-sender-skeleton'),
          ),
          RequestSenderLoaded(:final sender) => _SenderRowContent(
            key: const Key('request-sender-row'),
            sender: sender,
          ),
          RequestSenderHidden() => const SizedBox(
            key: Key('request-sender-hidden'),
            width: double.infinity,
          ),
        };
        // La ligne disparaît en se repliant plutôt qu'en sautant, et le
        // contenu remplace le squelette en fondu.
        return AnimatedSize(
          duration: DonyDuration.base,
          curve: DonyCurve.easeOut,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: DonyDuration.base,
            switchInCurve: DonyCurve.enter,
            switchOutCurve: DonyCurve.exit,
            child: child,
          ),
        );
      },
    );
  }
}

/// Hauteur commune du squelette et de la ligne : le fondu ne décale rien.
const double _kRowMinHeight = 56;

class _SenderRowContent extends StatelessWidget {
  const _SenderRowContent({super.key, required this.sender});

  final SenderPublicProfile sender;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final raw = sender.displayName;
    final name = (raw == null || raw.trim().isEmpty)
        ? senderFallbackName(l)
        : raw;
    const tabular = [FontFeature.tabularFigures()];

    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.base),
      child: Semantics(
        button: true,
        label: l.requestPublicSenderRowSemantics(name),
        excludeSemantics: true,
        child: Material(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          child: InkWell(
            borderRadius: BorderRadius.circular(DonyRadius.card),
            onTap: () {
              context.read<RequestSenderCubit>().trackOpened();
              showSenderPublicProfileSheet(context, sender);
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _kRowMinHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.md,
                  vertical: DonySpacing.sm,
                ),
                child: Row(
                  children: [
                    DonyAvatar(
                      name: name,
                      imageUrl: sender.avatarUrl,
                      size: DonyAvatarSize.sm,
                      verified: sender.kycVerified,
                    ),
                    const SizedBox(width: DonySpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            key: const Key('request-sender-name'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (sender.totalRatings > 0)
                            Row(
                              children: [
                                DonyIcon('star', size: 12, color: cs.warning),
                                const SizedBox(width: 2),
                                Text(
                                  sender.averageRating.toStringAsFixed(1),
                                  style: tt.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                    fontFeatures: tabular,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    ' · ${reviewCountLabel(l, sender.totalRatings)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontFeatures: tabular,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              l.requestSenderNewMember,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: DonySpacing.sm),
                    DonyIcon(
                      'chevron-right',
                      size: 16,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SenderRowSkeleton extends StatelessWidget {
  const _SenderRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.base),
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: _kRowMinHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.md,
            vertical: DonySpacing.sm,
          ),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(DonyRadius.card),
          ),
          child: const DonyShimmer(
            child: Row(
              children: [
                DonySkeletonCircle(diameter: 32),
                SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DonySkeletonBox(width: 120),
                      SizedBox(height: DonySpacing.xs),
                      DonySkeletonBox(width: 80, height: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
