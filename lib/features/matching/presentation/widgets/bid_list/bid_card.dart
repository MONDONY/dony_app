import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/utils/text_search.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ── Status constants ──────────────────────────────────────────────────────────
const _kPending = 'PENDING';
const _kPaymentEscrowed = 'PAYMENT_ESCROWED';

// ─────────────────────────────────────────────────────────────────────────────
// BidCard — carte de demande (partagée entre la liste « Acceptées » et l'écran
// « À traiter »). Affiche les actions Refuser/Accepter quand le bid est en
// attente ET que les callbacks sont fournis ; sinon un badge de statut.
// ─────────────────────────────────────────────────────────────────────────────

class BidCard extends StatelessWidget {
  final BidModel bid;
  final bool isProcessing;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  /// Tap sur la carte. Par défaut, ouvre le détail du bid. Surchargé par les
  /// écrans qui doivent rafraîchir leur liste au retour du détail (où le statut
  /// du bid peut changer via accept/refus/scan).
  final VoidCallback? onTap;

  /// Requête de recherche courante — pour le surlignage. Vide hors recherche.
  final String query;

  const BidCard({
    super.key,
    required this.bid,
    required this.isProcessing,
    this.onAccept,
    this.onReject,
    this.onTap,
    this.query = '',
  });

  bool get _isPending =>
      bid.status == _kPending || bid.status == _kPaymentEscrowed;
  bool get _isPaymentEscrowed => bid.status == _kPaymentEscrowed;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final amount = bid.totalAmountEur != null
        ? formatPriceIn(bid.totalAmountEur!, bid.currency)
        : bid.pricePerKg != null
        ? formatPriceIn((bid.weightKg ?? 0) * bid.pricePerKg!, bid.currency)
        : '-';
    final content = bid.contentCategory ?? bid.description;
    // Catégories déclarées, découpées : on n'affiche que la première + un
    // « +N » pour le reste (le détail liste tout). Évite le débordement de la
    // ligne quand plusieurs catégories sont cochées.
    final categories =
        bid.contentCategory
            ?.split(',')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList() ??
        const <String>[];
    final hasTracking =
        bid.trackingNumber != null && bid.trackingNumber!.isNotEmpty;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(DonyRadius.card),
        onTap: onTap ?? () => context.push('/bids/${bid.id}', extra: bid),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
          ),
          padding: const EdgeInsets.all(DonySpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Ligne 1 : avatar + identité + montant ──────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DonyAvatar(
                    name: bid.resolvedSenderName,
                    imageUrl: bid.senderAvatarUrl,
                  ),
                  const SizedBox(width: DonySpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HighlightedText(
                          text: bid.resolvedSenderName,
                          query: query,
                          style: tt.titleLarge,
                        ),
                        if (hasTracking) ...[
                          const SizedBox(height: DonySpacing.xxs),
                          _HighlightedText(
                            text: 'N° ${bid.trackingNumber}',
                            query: query,
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'MONTANT',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: DonySpacing.xxs),
                      Text(
                        amount,
                        style: tt.titleLarge?.copyWith(color: cs.primary),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.md),

              // ── Ligne 2 : pastilles méta ───────────────────────────
              Wrap(
                spacing: DonySpacing.sm,
                runSpacing: DonySpacing.sm,
                children: [
                  _MetaPill(
                    iconAsset: 'scale',
                    label: bid.weightKg != null
                        ? '${bid.weightKg!.toStringAsFixed(0)} kg'
                        : bid.pricingMode == BidPricingMode.grid
                        ? 'Forfait'
                        : '-',
                  ),
                  if (categories.isNotEmpty) ...[
                    _MetaPill(iconAsset: 'package', label: categories.first),
                    if (categories.length > 1)
                      _MetaPill(label: '+${categories.length - 1}'),
                  ] else if (content != null && content.isNotEmpty)
                    _ContentDescriptionPill(label: content),
                ],
              ),
              const SizedBox(height: DonySpacing.md),

              Divider(color: cs.outline, height: 1),
              const SizedBox(height: DonySpacing.md),

              // ── Bas : actions OU badge de statut ───────────────────
              if (_isPending && onAccept != null && onReject != null) ...[
                _PaymentHint(isCash: !_isPaymentEscrowed),
                const SizedBox(height: DonySpacing.sm),
                _PendingActions(
                  isProcessing: isProcessing,
                  onAccept: onAccept!,
                  onReject: onReject!,
                ),
              ] else
                Align(
                  alignment: Alignment.centerLeft,
                  child: _StatusDot(status: bid.status),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HighlightedText — texte avec terme de recherche surligné
// ─────────────────────────────────────────────────────────────────────────────

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;

  const _HighlightedText({required this.text, required this.query, this.style});

  @override
  Widget build(BuildContext context) {
    final q = normalizeSearch(query.trim());
    if (q.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    // normalizeSearch préserve la longueur → les index sont valides sur `text`.
    final idx = normalizeSearch(text).indexOf(q);
    if (idx < 0 || idx + q.length > text.length) {
      return Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    final cs = Theme.of(context).colorScheme;
    final highlight = (style ?? const TextStyle()).copyWith(
      backgroundColor: cs.warningLight,
      color: cs.onSurface,
      fontWeight: FontWeight.w800,
    );
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, idx)),
          TextSpan(text: text.substring(idx, idx + q.length), style: highlight),
          TextSpan(text: text.substring(idx + q.length)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MetaPill — pastille discrète (poids, contenu)
// ─────────────────────────────────────────────────────────────────────────────

class _MetaPill extends StatelessWidget {
  final String? iconAsset;
  final String label;

  const _MetaPill({required this.label, this.iconAsset});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconAsset != null) ...[
            DonyIcon(iconAsset!, size: 13, color: cs.onSurfaceVariant),
            const SizedBox(width: DonySpacing.xs),
          ],
          Text(
            label,
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ContentDescriptionPill — pastille contenu quand le bid n'a pas de catégories
// mais une description libre : bornée en largeur + ellipsis, jamais d'overflow.
// ─────────────────────────────────────────────────────────────────────────────

class _ContentDescriptionPill extends StatelessWidget {
  final String label;
  const _ContentDescriptionPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.sm,
          vertical: DonySpacing.xs,
        ),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(DonyRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyIcon('package', size: 13, color: cs.onSurfaceVariant),
            const SizedBox(width: DonySpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PendingActions — Refuser + Accepter
// ─────────────────────────────────────────────────────────────────────────────

class _PendingActions extends StatelessWidget {
  final bool isProcessing;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _PendingActions({
    required this.isProcessing,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DonyButton(
            label: 'Refuser',
            variant: DonyButtonVariant.ghost,
            onPressed: isProcessing ? null : onReject,
          ),
        ),
        const SizedBox(width: DonySpacing.md),
        Expanded(
          child: DonyButton(
            label: 'Accepter',
            isLoading: isProcessing,
            onPressed: isProcessing ? null : onAccept,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PaymentHint — bandeau « en attente de votre réponse » sur les bids en attente.
// Carte (escrow) : « 💳 Paiement reçu ». Cash : « 💵 Paiement en espèces ».
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentHint extends StatelessWidget {
  final bool isCash;
  const _PaymentHint({required this.isCash});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final iconAsset = isCash ? 'banknote' : 'lock';
    final label = isCash
        ? '💵 Paiement en espèces : en attente de votre réponse'
        : '💳 Paiement reçu : en attente de votre réponse';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.warningLight,
        borderRadius: BorderRadius.circular(DonyRadius.sm),
      ),
      child: Row(
        children: [
          DonyIcon(iconAsset, size: 14, color: cs.warning),
          const SizedBox(width: DonySpacing.xs),
          Flexible(
            child: Text(
              label,
              style: tt.labelMedium?.copyWith(color: cs.warning),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatusDot — badge « point coloré » (statuts post-acceptation)
// ─────────────────────────────────────────────────────────────────────────────

class _StatusDot extends StatelessWidget {
  final String status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final (Color color, Color bg, String label) = switch (status) {
      'ACCEPTED' => (cs.success, cs.successLight, 'Accepté'),
      'HANDED_OVER' => (cs.primary, cs.primaryContainer, 'En route'),
      'IN_TRANSIT' => (cs.info, cs.infoLight, 'En transit'),
      'COMPLETED' => (cs.success, cs.successLight, 'Livré'),
      'NO_SHOW' => (cs.warning, cs.warningLight, 'Absent'),
      'PARCEL_REFUSED' => (cs.error, cs.errorLight, 'Colis refusé'),
      'CANCELLED' => (
        cs.onSurfaceVariant,
        cs.surfaceContainerHighest,
        'Annulé',
      ),
      _ => (cs.onSurfaceVariant, cs.surfaceContainerHighest, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: DonySpacing.xs + 2),
          Text(label, style: tt.labelMedium?.copyWith(color: color)),
        ],
      ),
    );
  }
}
