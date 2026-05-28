import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class WalletTopupMethodScreen extends StatefulWidget {
  const WalletTopupMethodScreen({super.key});

  @override
  State<WalletTopupMethodScreen> createState() =>
      _WalletTopupMethodScreenState();
}

class _WalletTopupMethodScreenState extends State<WalletTopupMethodScreen> {
  // setState toléré ici : état UI local (sélection de méthode uniquement).
  String? _selected;

  static const _methods = [
    _MethodDef(
      icon: Icons.credit_card_rounded,
      label: 'Carte bancaire',
      subtitle: 'Via Stripe · Visa, Mastercard',
      value: 'STRIPE',
    ),
    _MethodDef(
      icon: Icons.waves_rounded,
      label: 'Wave',
      subtitle: 'Paiement Mobile Money',
      value: 'WAVE',
    ),
    _MethodDef(
      icon: Icons.signal_cellular_alt_rounded,
      label: 'Orange Money',
      subtitle: 'Paiement Mobile Money',
      value: 'ORANGE_MONEY',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: DonyColors.blue700,
        foregroundColor: DonyColors.neutral0,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          tooltip: 'Retour',
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Recharger · Étape 1/2',
          style: tt.headlineLarge?.copyWith(
            color: DonyColors.neutral0,
            fontSize: 17,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: _StepProgressBar(value: 0.5, color: DonyColors.blue300),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.xl,
                DonySpacing.lg,
                DonySpacing.xxl,
              ),
              children: [
                Text(
                  'MÉTHODE DE RECHARGE',
                  style: tt.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: DonySpacing.md),
                ...List.generate(_methods.length, (i) {
                  final m = _methods[i];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: i < _methods.length - 1 ? DonySpacing.sm : 0,
                    ),
                    child: _MethodCard(
                      def: m,
                      isSelected: _selected == m.value,
                      onTap: () => setState(() => _selected = m.value),
                    )
                        .animate(delay: (60 * i).ms)
                        .fadeIn(duration: 250.ms)
                        .slideY(begin: 0.04, curve: Curves.easeOutCubic),
                  );
                }),
              ],
            ),
          ),
          // ── Sticky bottom CTA ─────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              DonySpacing.lg,
              0,
              DonySpacing.lg,
              MediaQuery.paddingOf(context).bottom + DonySpacing.lg,
            ),
            child: DonyButton(
              label: 'Suivant → Montant',
              onPressed: _selected == null
                  ? null
                  : () => context.push(
                        '/payments/wallet/topup/amount',
                        extra: _selected,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Progress bar ─────────────────────────────────────────────────────────────

class _StepProgressBar extends StatelessWidget {
  const _StepProgressBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: LinearProgressIndicator(
        value: value,
        backgroundColor: DonyColors.blue900,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

// ─── Method definition ────────────────────────────────────────────────────────

class _MethodDef {
  const _MethodDef({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final String value;
}

// ─── Method card ──────────────────────────────────────────────────────────────

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.def,
    required this.isSelected,
    required this.onTap,
  });

  final _MethodDef def;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: isSelected,
      label: def.label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: isSelected ? DonyColors.blue50 : cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(
              color: isSelected ? cs.primary : cs.outline,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: DonyColors.blue500.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base,
            vertical: DonySpacing.md + 2,
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: DonySpacing.icon,
                height: DonySpacing.icon,
                decoration: BoxDecoration(
                  color: isSelected ? DonyColors.blue100 : DonyColors.neutral100,
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                ),
                child: Icon(
                  def.icon,
                  color: isSelected ? cs.primary : cs.onSurfaceVariant,
                  size: 20,
                ),
              ),
              const SizedBox(width: DonySpacing.base),
              // Labels
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      def.label,
                      style: tt.titleLarge?.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      def.subtitle,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Radio indicator
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  key: ValueKey(isSelected),
                  color: isSelected ? cs.primary : cs.outline,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
