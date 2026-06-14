import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EscrowExplainerScreen extends StatelessWidget {
  final double amount;
  final String travelerName;
  final String? bidId;

  const EscrowExplainerScreen({
    super.key,
    required this.amount,
    required this.travelerName,
    this.bidId,
  });

  String get _amountStr =>
      amount.toStringAsFixed(2).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const DonyAppBar(title: 'Garde de confiance'),
      body: Builder(builder: (context) {
        final h = DonyLayout.hPadding(context);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(h, DonySpacing.xl, h, DonySpacing.huge),
          child: DonyLayout.constrained(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Amount card ──────────────────────────────────────────
                _AmountCard(amount: _amountStr, travelerName: travelerName),

                const SizedBox(height: DonySpacing.xl),

                // ── How it works ─────────────────────────────────────────
                Text(
                  'COMMENT ÇA MARCHE',
                  style: tt.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: DonySpacing.base),
                _HowItWorksCard(amount: _amountStr, travelerName: travelerName),

                const SizedBox(height: DonySpacing.xl),

                // ── Insurance card ───────────────────────────────────────
                const _InsuranceCard(),

                const SizedBox(height: DonySpacing.xxl),

                // ── CTA ──────────────────────────────────────────────────
                DonyButton(
                  label: 'Voir le suivi',
                  onPressed: () {
                    if (bidId != null) {
                      context.push('/bids/$bidId');
                    } else {
                      context.pop();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ── Amount card ──────────────────────────────────────────────────────────────

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.amount, required this.travelerName});

  final String amount;
  final String travelerName;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return DonyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BLOQUÉS EN ESCROW',
            style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(amount, style: tt.displayLarge?.copyWith(color: cs.onSurface)),
              const SizedBox(width: DonySpacing.xs),
              Text(' €', style: tt.headlineMedium?.copyWith(color: cs.onSurface)),
            ],
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            'Pour $travelerName · libérés à la remise',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── How it works card ────────────────────────────────────────────────────────

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard({required this.amount, required this.travelerName});

  final String amount;
  final String travelerName;

  @override
  Widget build(BuildContext context) {
    final steps = [
      _Step(
        done: true,
        title: 'Vous payez',
        description:
            'Vos $amount € sont bloqués chez Stripe Connect, pas chez $travelerName.',
      ),
      const _Step(
        done: true,
        title: 'Ibrahima livre',
        description:
            'Il scanne le QR à chaque étape. Vous suivez en direct.',
      ),
      const _Step(
        done: true,
        title: 'Fatou confirme',
        description:
            'Elle scanne le QR (ou tape le code à 4 chiffres) à la remise.',
      ),
      _Step(
        done: false,
        stepNumber: 4,
        title: 'Ibrahima est payé',
        description: 'Les $amount € sont libérés. Sous 24h sur son IBAN.',
      ),
    ];

    return DonyCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            Padding(
              padding: const EdgeInsets.all(DonySpacing.base),
              child: _StepRow(step: steps[i]),
            ),
            if (i < steps.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: DonySpacing.xl + DonySpacing.xs),
                child: Builder(
                  builder: (context) => Container(
                    width: 2,
                    height: DonySpacing.base,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Step {
  final bool done;
  final int? stepNumber;
  final String title;
  final String description;

  const _Step({
    required this.done,
    required this.title,
    required this.description,
    this.stepNumber,
  });
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});
  final _Step step;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Circle indicator — DonyIconContainer pour les étapes validées,
        // Container natif pour les étapes numérotées (DonyIconContainer ne
        // supporte pas de contenu texte).
        if (step.done)
          DonyIconContainer(
            iconAsset: 'check',
            size: DonyIconContainerSize.md,
            backgroundColor: cs.primary,
            iconColor: cs.surface,
            borderRadius: DonyRadius.full,
          )
        else
          Container(
            width: DonySpacing.icon,
            height: DonySpacing.icon,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: cs.onSurfaceVariant, width: 2),
            ),
            child: Center(
              child: Text(
                '${step.stepNumber}',
                style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ),
        const SizedBox(width: DonySpacing.md),
        // Text content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(step.title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: DonySpacing.xxs),
              Text(
                step.description,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Insurance card ───────────────────────────────────────────────────────────

class _InsuranceCard extends StatelessWidget {
  const _InsuranceCard();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.primary),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonyIcon('shield', color: cs.primary, size: DonySpacing.iconSm),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: tt.bodySmall?.copyWith(color: cs.onSurface),
                children: const [
                  TextSpan(text: "Si le colis n'arrive pas, on vous rembourse "),
                  TextSpan(
                    text: 'jusqu\'à 200 €',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' via le fonds de garantie.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
