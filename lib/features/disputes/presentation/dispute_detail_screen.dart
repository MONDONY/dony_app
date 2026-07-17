import 'dart:async';

import 'package:dony/core/design/design_system.dart';

import 'package:dony/core/design/tokens/color_tokens.dart'; // DonyStatusColors extension
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/disputes/data/models/dispute_model.dart';
import 'package:dony/features/disputes/presentation/utils/dispute_labels.dart';
import 'package:dony/features/disputes/presentation/widgets/dispute_status_chip.dart';
import 'package:dony/features/disputes/presentation/widgets/dispute_timeline.dart';
import 'package:dony/features/matching/presentation/utils/city_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class DisputeDetailScreen extends StatefulWidget {
  const DisputeDetailScreen({super.key, required this.dispute});
  final DisputeModel dispute;

  @override
  State<DisputeDetailScreen> createState() => _DisputeDetailScreenState();
}

class _DisputeDetailScreenState extends State<DisputeDetailScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(getIt<AnalyticsService>().logEvent(
      AnalyticsEvents.disputeDetailOpened,
      properties: {'status': widget.dispute.status},
    ));
  }

  String _euro(int cents) =>
      '${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';

  @override
  Widget build(BuildContext context) {
    final d = widget.dispute;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final dep = d.departureCity;
    final arr = d.arrivalCity;
    final showAmount = d.resolutionType == 'GUARANTEE_PAID' &&
        d.isBeneficiary &&
        d.guaranteeAmountCents != null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: const DonyAppBarBackButton(),
        title: const Text('Litige'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Head-card contexte ─────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border.all(color: cs.outlineVariant),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(disputeTypeLabel(d.type),
                            style: tt.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      DisputeStatusChip(status: d.status),
                    ],
                  ),
                  if (dep != null && arr != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${cityFlag(dep) ?? ''} $dep → $arr ${cityFlag(arr) ?? ''}'
                          .trim(),
                      style:
                          tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (d.otherPartyName != null)
                        '${d.myRole == 'SENDER' ? 'Voyageur' : 'Expéditeur'} : ${d.otherPartyName}'
                      else
                        'Envoi supprimé',
                      if (d.weightKg != null)
                        'Envoi ${d.weightKg!.toStringAsFixed(d.weightKg! % 1 == 0 ? 0 : 1)} kg',
                    ].join(' · '),
                    style:
                        tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),

            // ── Bandeau gel (en cours seulement) ───────────────────
            if (d.refundFrozen && d.isOpen) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Remboursement gelé le temps de l\'instruction — l\'équipe dony tranche sous 72 h ouvrées.',
                      style: tt.bodySmall?.copyWith(
                          color: cs.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ),
            ],

            // ── Timeline ───────────────────────────────────────────
            const SizedBox(height: 20),
            Text('SUIVI',
                style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1)),
            const SizedBox(height: 8),
            DisputeTimeline(dispute: d),

            // ── Décision (résolu seulement) ────────────────────────
            if (d.isResolved) ...[
              const SizedBox(height: 20),
              Text('DÉCISION',
                  style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 4, color: cs.success),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.isBeneficiary
                                ? 'Résolu en votre faveur'
                                : 'Litige résolu',
                            style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: cs.success),
                          ),
                          if (d.resolutionNote != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .scaffoldBackgroundColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(d.resolutionNote!,
                                  style: tt.bodySmall?.copyWith(height: 1.5)),
                            ),
                          ],
                          if (showAmount) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Indemnisation versée',
                                    style: tt.bodyMedium),
                                Text(_euro(d.guaranteeAmountCents!),
                                    style: tt.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: cs.success)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── CTA support ────────────────────────────────────────
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/profile/help/contact'),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: const Text('Contacter le support'),
              ),
            ),
          ],
        )
            .animate()
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.04, curve: Curves.easeOutCubic),
      ),
    );
  }
}
