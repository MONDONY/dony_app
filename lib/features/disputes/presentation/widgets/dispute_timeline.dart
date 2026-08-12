import 'package:dony/core/design/tokens/color_tokens.dart'; // DonyStatusColors extension
import 'package:dony/features/disputes/data/models/dispute_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DisputeTimeline extends StatelessWidget {
  const DisputeTimeline({super.key, required this.dispute});
  final DisputeModel dispute;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final df = DateFormat('d MMM yyyy', 'fr');
    final resolved = dispute.isResolved;

    Widget step({
      required Color dotColor,
      bool hollow = false,
      bool last = false,
      required String title,
      required String subtitle,
      Color? titleColor,
    }) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  color: hollow ? Colors.transparent : dotColor,
                  border: hollow ? Border.all(color: cs.outlineVariant, width: 2) : null,
                  shape: BoxShape.circle,
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: cs.outlineVariant),
                ),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: last ? 0 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700, color: titleColor)),
                    Text(subtitle,
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        step(
          dotColor: cs.primary,
          title: 'Litige ouvert',
          subtitle:
              dispute.myRole == 'SENDER'
                  ? "${df.format(dispute.createdAt)} · vous avez contesté l'absence du voyageur"
                  : "${df.format(dispute.createdAt)} · l'expéditeur a contesté une absence à la remise",
        ),
        step(
          dotColor: resolved ? cs.primary : cs.warning,
          title: 'En instruction',
          subtitle: resolved
              ? 'examiné par l\'équipe Yadony'
              : 'en cours d\'examen par l\'équipe Yadony',
        ),
        step(
          dotColor: cs.success,
          hollow: !resolved,
          last: true,
          title: resolved ? 'Décision rendue' : 'Décision',
          titleColor: resolved ? null : cs.onSurfaceVariant,
          subtitle: resolved && dispute.resolvedAt != null
              ? df.format(dispute.resolvedAt!)
              : 'sous 72 h',
        ),
      ]),
    );
  }
}
