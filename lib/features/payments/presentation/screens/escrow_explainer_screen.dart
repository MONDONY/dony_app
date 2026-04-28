import 'package:dony/core/design/design_system.dart';
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

    return Scaffold(
      backgroundColor: DonyColors.bg,
      appBar: AppBar(
        backgroundColor: DonyColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: DonyColors.ink900,
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Garde de confiance',
          style: tt.headlineLarge,
        ),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: DonyColors.grey200),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.lg, DonySpacing.xl, DonySpacing.lg, DonySpacing.huge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Amount card ──────────────────────────────────────────
            _AmountCard(amount: _amountStr, travelerName: travelerName),

            const SizedBox(height: DonySpacing.xl),

            // ── How it works ─────────────────────────────────────────
            Text(
              'COMMENT ÇA MARCHE',
              style: tt.labelMedium?.copyWith(
                color: DonyColors.grey400,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: DonySpacing.base),
            _HowItWorksCard(amount: _amountStr, travelerName: travelerName),

            const SizedBox(height: DonySpacing.xl),

            // ── Insurance card ───────────────────────────────────────
            _InsuranceCard(),

            const SizedBox(height: DonySpacing.xxl),

            // ── CTA ──────────────────────────────────────────────────
            DonyButton(
              label: 'Voir le suivi',
              onPressed: () {
                if (bidId != null) {
                  context.go('/bids/$bidId');
                } else {
                  context.pop();
                }
              },
            ),
          ],
        ),
      ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BLOQUÉS EN ESCROW',
            style: tt.labelMedium?.copyWith(
              color: DonyColors.grey400,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(amount, style: tt.displayLarge?.copyWith(color: DonyColors.ink900)),
              const SizedBox(width: DonySpacing.xs),
              Text(' €', style: tt.headlineMedium?.copyWith(color: DonyColors.ink900)),
            ],
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            'Pour $travelerName · libérés à la remise',
            style: tt.bodySmall?.copyWith(color: DonyColors.grey400),
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

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.grey200),
      ),
      child: Column(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            _StepRow(step: steps[i]),
            if (i < steps.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: DonySpacing.xl + DonySpacing.xs),
                child: Container(
                  width: 2,
                  height: DonySpacing.base,
                  color: DonyColors.grey200,
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Circle indicator
        Container(
          width: DonySpacing.icon,
          height: DonySpacing.icon,
          decoration: BoxDecoration(
            color: step.done ? DonyColors.green400 : Colors.transparent,
            shape: BoxShape.circle,
            border: step.done
                ? null
                : Border.all(color: DonyColors.grey400, width: 2),
          ),
          child: Center(
            child: step.done
                ? const Icon(Icons.check_rounded, color: DonyColors.white, size: DonySpacing.iconSm)
                : Text(
                    '${step.stepNumber}',
                    style: tt.labelMedium?.copyWith(color: DonyColors.grey400),
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
                style: tt.bodySmall?.copyWith(color: DonyColors.grey400),
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
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: DonyColors.green50,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.green400),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: DonyColors.green400, size: DonySpacing.iconSm),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: tt.bodySmall?.copyWith(color: DonyColors.ink900),
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
