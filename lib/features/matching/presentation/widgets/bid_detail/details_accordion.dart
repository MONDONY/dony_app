import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/quick_actions_row.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Accordéon « Plus de détails » — contient 4 sections :
///   1. FENÊTRE DE REMISE
///   2. TRAJET
///   3. LIEN DE SUIVI (si trackingToken != null)
///   4. RESPONSABILITÉ LÉGALE
///
/// NOTE : ce widget est un [StatefulWidget] pour gérer l'état UI `_open`
/// (pattern AnimatedSize standard). Ce setState local ne gère que l'ouverture/
/// fermeture de l'accordéon — aucun état métier.
class DetailsAccordion extends StatefulWidget {
  final BidModel bid;

  const DetailsAccordion({super.key, required this.bid});

  @override
  State<DetailsAccordion> createState() => _DetailsAccordionState();
}

class _DetailsAccordionState extends State<DetailsAccordion> {
  bool _open = false;

  BidModel get bid => widget.bid;

  String _formatHandoverDate(DateTime? d) {
    if (d == null) {
      return '—';
    }
    try {
      return DateFormat('dd/MM/yyyy HH:mm', 'fr').format(d.toLocal());
    } catch (_) {
      return DateFormat('dd/MM/yyyy HH:mm').format(d.toLocal());
    }
  }

  String _formatDepartureDate(DateTime? d) {
    if (d == null) {
      return '—';
    }
    try {
      return DateFormat('EEE dd MMM yyyy', 'fr').format(d);
    } catch (_) {
      return DateFormat('dd/MM/yyyy').format(d);
    }
  }

  void _toggle() {
    HapticFeedback.lightImpact();
    setState(() => _open = !_open);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          InkWell(
            onTap: _toggle,
            borderRadius: _open
                ? const BorderRadius.vertical(top: Radius.circular(DonyRadius.card))
                : BorderRadius.circular(DonyRadius.card),
            child: Padding(
              padding: const EdgeInsets.all(DonySpacing.base),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Plus de détails',
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Body ───────────────────────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity, height: 0)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DonySpacing.base,
                      0,
                      DonySpacing.base,
                      DonySpacing.base,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(color: cs.outline, height: 1),
                        const SizedBox(height: DonySpacing.md),
                        // Section 1 — FENÊTRE DE REMISE
                        const _SectionLabel(label: 'FENÊTRE DE REMISE'),
                        const SizedBox(height: DonySpacing.sm),
                        InfoRow(
                          label: 'Lieu',
                          value: bid.handoverLocation ?? '—',
                        ),
                        if (bid.handoverWindowStart != null) ...[
                          const SizedBox(height: DonySpacing.sm),
                          InfoRow(
                            label: 'Début',
                            value: _formatHandoverDate(bid.handoverWindowStart),
                          ),
                        ],
                        if (bid.handoverWindowEnd != null) ...[
                          const SizedBox(height: DonySpacing.sm),
                          InfoRow(
                            label: 'Fin',
                            value: _formatHandoverDate(bid.handoverWindowEnd),
                          ),
                        ],
                        const SizedBox(height: DonySpacing.sm),
                        InfoRow(
                          label: 'Présence confirmée',
                          value: bid.voyageurConfirmed ? 'Oui ✓' : 'Non encore',
                        ),
                        const SizedBox(height: DonySpacing.md),
                        Divider(color: cs.outline, height: 1),
                        const SizedBox(height: DonySpacing.md),
                        // Section 2 — TRAJET
                        const _SectionLabel(label: 'TRAJET'),
                        const SizedBox(height: DonySpacing.sm),
                        InfoRow(
                          label: 'Date de départ',
                          value: _formatDepartureDate(bid.departureDate),
                        ),
                        if (bid.pricePerKg != null && bid.pricePerKg! > 0) ...[
                          const SizedBox(height: DonySpacing.sm),
                          // Prix affiché à l'expéditeur = net × commission (incluse)
                          InfoRow(
                            label: 'Tarif par kg',
                            value:
                                '${formatKgPrice(netToSenderPrice(bid.pricePerKg!))} €',
                          ),
                        ],
                        // Section 3 — LIEN DE SUIVI (conditionnel)
                        if (bid.trackingToken != null) ...[
                          const SizedBox(height: DonySpacing.md),
                          Divider(color: cs.outline, height: 1),
                          const SizedBox(height: DonySpacing.md),
                          const _SectionLabel(label: 'LIEN DE SUIVI'),
                          const SizedBox(height: DonySpacing.sm),
                          _TrackingUrlRow(bid: bid),
                        ],
                        const SizedBox(height: DonySpacing.md),
                        Divider(color: cs.outline, height: 1),
                        const SizedBox(height: DonySpacing.md),
                        // Section 4 — RESPONSABILITÉ LÉGALE
                        const _SectionLabel(label: 'RESPONSABILITÉ LÉGALE'),
                        const SizedBox(height: DonySpacing.sm),
                        _DisclaimerRow(bid: bid),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Text(
      label,
      style: tt.labelMedium?.copyWith(
        color: cs.onSurfaceVariant,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ── Tracking URL row ──────────────────────────────────────────────────────────

class _TrackingUrlRow extends StatelessWidget {
  final BidModel bid;
  const _TrackingUrlRow({required this.bid});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final url = trackingPublicUrl(bid.trackingToken!);

    return Row(
      children: [
        Icon(Icons.link_rounded, color: cs.primary, size: 16),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Text(
            url,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy_rounded, size: 16),
          tooltip: 'Copier le lien',
          color: cs.primary,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
            DonySnackbar.show(
              context,
              message: 'Lien copié',
              type: DonySnackbarType.success,
            );
          },
        ),
      ],
    );
  }
}

// ── Disclaimer row ────────────────────────────────────────────────────────────

class _DisclaimerRow extends StatelessWidget {
  final BidModel bid;
  const _DisclaimerRow({required this.bid});

  String _disclaimerLabel() {
    final signed = bid.disclaimerSignedAt;
    if (signed == null) {
      return 'Disclaimer signé';
    }
    try {
      return 'Disclaimer signé le ${DateFormat('dd/MM/yyyy à HH:mm', 'fr').format(signed.toLocal())}';
    } catch (_) {
      return 'Disclaimer signé le ${DateFormat('dd/MM/yyyy HH:mm').format(signed.toLocal())}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.verified_outlined, color: cs.success, size: 20),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Text(
            _disclaimerLabel(),
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
