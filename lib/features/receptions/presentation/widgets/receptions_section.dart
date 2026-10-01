import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/presentation/widgets/shipment_card.dart';
import 'package:dony/features/receptions/bloc/receptions_cubit.dart';
import 'package:dony/features/receptions/data/models/reception.dart';
import 'package:dony/features/tracking/presentation/widgets/route_label.dart';
import 'package:dony/features/tracking/presentation/widgets/shipment_progress_bar.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Route de l'écran d'un colis à recevoir.
String receptionRoute(String bidId) => '/receptions/$bidId';

/// « Colis à recevoir », au-dessus de « Mes envois » dans l'onglet Suivi.
///
/// Invisible tant qu'il n'y a rien à montrer : premier chargement, échec
/// (back antérieur au lot 2 compris) et liste vide. La plupart des
/// utilisateurs ne reçoivent jamais de colis, la section ne doit pas leur
/// coûter de place.
class ReceptionsSection extends StatelessWidget {
  const ReceptionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    return BlocBuilder<ReceptionsCubit, ReceptionsState>(
      builder: (context, state) {
        if (state is! ReceptionsLoaded || state.receptions.isEmpty) {
          return const SizedBox.shrink();
        }
        final receptions = state.receptions;
        return Column(
          key: const Key('receptions-section'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text.rich(
              TextSpan(
                text: l.receptionsSectionTitle,
                children: [
                  TextSpan(
                    text: '  ${receptions.length}',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              style: tt.headlineMedium,
            ),
            const SizedBox(height: DonySpacing.sm),
            for (final reception in receptions)
              Padding(
                padding: const EdgeInsets.only(bottom: DonySpacing.sm),
                child: _ReceptionRow(reception: reception),
              ),
            const SizedBox(height: DonySpacing.lg),
          ],
        );
      },
    );
  }
}

class _ReceptionRow extends StatelessWidget {
  const _ReceptionRow({required this.reception});

  final Reception reception;

  Future<void> _open(BuildContext context) async {
    final cubit = context.read<ReceptionsCubit>();
    await context.push<bool>(receptionRoute(reception.bidId));
    // Confirmé ou refusé depuis l'écran : la liste suit, sans chargement
    // visible.
    if (context.mounted) await cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final from = reception.departureCity;
    final to = reception.arrivalCity;
    final sender = reception.senderFirstName;
    final titleStyle = tt.titleLarge?.copyWith(fontWeight: FontWeight.w700);
    final pending = reception.isPending;
    final moving =
        reception.bidStatus == 'HANDED_OVER' || // i18n-ignore — statut back
        reception.bidStatus == 'IN_TRANSIT'; // i18n-ignore — statut back

    return DonyPressable(
      key: Key('reception-row-${reception.bidId}'),
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.base),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: pending ? cs.warning : cs.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: from != null && to != null
                      ? RouteLabel(from: from, to: to, style: titleStyle)
                      : Text(
                          reception.trackingNumber ??
                              reception.recipientName ??
                              l.receptionDetailTitle,
                          style: titleStyle,
                        ),
                ),
                const SizedBox(width: DonySpacing.sm),
                if (pending)
                  _PendingChip(label: l.receptionsPendingChip)
                else
                  Text(
                    l.receptionsRowStep(reception.bidStatus),
                    style: tt.labelLarge?.copyWith(
                      color: moving ? DonyColors.terra700 : cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if (sender != null) ...[
              const SizedBox(height: DonySpacing.xxs),
              Text(
                l.receptionsRowFrom(sender),
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            if (!pending) ...[
              const SizedBox(height: DonySpacing.md),
              ShipmentProgressBar(
                step: shipmentStepFor(reception.bidStatus) ?? 1,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PendingChip extends StatelessWidget {
  const _PendingChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: cs.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        style: tt.labelMedium?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
