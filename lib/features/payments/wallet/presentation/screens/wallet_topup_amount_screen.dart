import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/core/widgets/dony_keypad.dart';
import 'package:dony/features/payments/bloc/payment_sheet_bloc.dart';
import 'package:dony/features/payments/presentation/widgets/dony_payment_sheet.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class WalletTopupAmountScreen extends StatefulWidget {
  final String paymentMethod;

  const WalletTopupAmountScreen({super.key, required this.paymentMethod});

  @override
  State<WalletTopupAmountScreen> createState() =>
      _WalletTopupAmountScreenState();
}

class _WalletTopupAmountScreenState extends State<WalletTopupAmountScreen> {
  // setState toléré ici : état UI local (saisie montant uniquement).
  String _rawAmount = '';

  static const _quickAmounts = [10, 20, 50, 100];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(getIt<AnalyticsService>().logEvent(AnalyticsEvents.walletTopupStarted));
    });
  }

  double get _amount =>
      _rawAmount.isEmpty ? 0.0 : (double.tryParse(_rawAmount) ?? 0.0);

  String get _methodLabel => switch (widget.paymentMethod) {
        'STRIPE' => 'Carte bancaire',
        'WAVE' => 'Wave',
        'ORANGE_MONEY' => 'Orange Money',
        _ => widget.paymentMethod,
      };

  void _onDigit(String d) {
    // Max 6 chiffres, pas de 0 en tête
    if (_rawAmount.length >= 6) {
      return;
    }
    if (_rawAmount.isEmpty && d == '0') {
      return;
    }
    setState(() => _rawAmount += d);
  }

  void _onDelete() {
    if (_rawAmount.isEmpty) {
      return;
    }
    setState(
      () => _rawAmount = _rawAmount.substring(0, _rawAmount.length - 1),
    );
  }

  void _setQuickAmount(int amount) {
    setState(() => _rawAmount = amount.toString());
  }

  String get _displayAmount {
    if (_rawAmount.isEmpty) {
      return '0';
    }
    return _rawAmount;
  }

  /// Présente la DonyPaymentSheet avec le clientSecret renvoyé par le
  /// backend. Après confirmation, le webhook Stripe `payment_intent.succeeded`
  /// (metadata wallet_topup=true) crédite le wallet côté serveur — il suffit
  /// donc de revenir au wallet, qui recharge son solde.
  Future<void> _presentStripePaymentSheet(
    BuildContext context,
    String clientSecret,
  ) async {
    await DonyPaymentSheet.show(
      context,
      config: PaymentSheetConfig(
        clientSecret: clientSecret,
        amountEur: _amount,
        // Le backend ne déclare pas PayPal sur le PaymentIntent de recharge
        // wallet — le bouton PayPal reste donc masqué (dégradation propre).
        paymentMethodTypes: const [],
      ),
      contextLabel: 'Recharge de votre solde dony',
      onSuccess: () {
        if (!context.mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (routeContext) => DonySuccessScreen(
            mascotteType: DonyMascotteType.securise,
            title: 'Recharge réussie !',
            subtitle: 'Ton solde sera crédité dans un instant.',
            ctaLabel: 'Voir mon solde',
            onCta: () {
              Navigator.of(routeContext).pop(); // ferme DonySuccessScreen
              // pop(true) plutôt que go() : préserve la pile de navigation (le
              // bouton retour du wallet continue de fonctionner) et signale au
              // wallet qu'il doit recharger son solde (crédité de façon
              // asynchrone via webhook).
              context.pop(true);
            },
            // Le bouton fermer (X) par défaut navigue directement vers /home
            // sans repasser par pop(true) — le wallet, strictement dépendant
            // du bool renvoyé par le push (`ok != true` → pas de refresh),
            // resterait alors avec un solde périmé. On capture le router
            // AVANT les pops (routeContext est dépilé par le premier pop, la
            // classe de bug est la même que le fix bid-payé feb86b71), puis
            // on préserve le contrat bool avant de quitter vers /home.
            onClose: () {
              final router = GoRouter.of(routeContext);
              Navigator.of(routeContext).pop();
              context.pop(true);
              router.go('/home');
            },
            analyticsContext: 'wallet_topup',
          ),
        ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return BlocListener<WalletBloc, WalletState>(
      listener: (context, state) {
        if (state is WalletTopupStripeReady) {
          _presentStripePaymentSheet(context, state.clientSecret);
        } else if (state is WalletTopupRedirectReady) {
          launchUrl(
            Uri.parse(state.redirectUrl),
            mode: LaunchMode.externalApplication,
          );
        } else if (state is WalletError) {
          DonySnackbar.show(
            context,
            message: state.message,
            type: DonySnackbarType.error,
          );
        } else if (state is WalletLoaded) {
          // Rechargement réussi → retour au wallet
          context.pop(true);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: DonyColors.blue700,
          foregroundColor: DonyColors.neutral0,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          leading: IconButton(
            icon: const DonyIcon('arrow-left', size: 20),
            tooltip: 'Retour',
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Recharger · Étape 2/2',
            style: tt.headlineLarge?.copyWith(
              color: DonyColors.neutral0,
              fontSize: 17,
            ),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(4),
            child: _StepProgressBar(value: 1.0, color: DonyColors.blue300),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  DonySpacing.lg,
                  DonySpacing.xxl,
                  DonySpacing.lg,
                  DonySpacing.xl,
                ),
                child: Column(
                  children: [
                    // ── Montant affiché ───────────────────────────────────────
                    _AmountDisplay(displayAmount: _displayAmount)
                        .animate()
                        .fadeIn(duration: 250.ms)
                        .slideY(begin: -0.05, curve: Curves.easeOutCubic),

                    const SizedBox(height: DonySpacing.xl),

                    // ── Raccourcis rapides ────────────────────────────────────
                    _QuickAmountRow(
                      amounts: _quickAmounts,
                      currentAmount: _amount,
                      onSelect: _setQuickAmount,
                    )
                        .animate(delay: 60.ms)
                        .fadeIn(duration: 250.ms)
                        .slideY(begin: 0.04, curve: Curves.easeOutCubic),

                    const SizedBox(height: DonySpacing.xxl),

                    // ── Clavier numérique ─────────────────────────────────────
                    DonyKeypad(
                      onDigit: _onDigit,
                      onDelete: _onDelete,
                    ),
                  ],
                ),
              ),
            ),

            // ── Sticky bottom CTA ─────────────────────────────────────────────
            _StickyButton(
              amount: _amount,
              methodLabel: _methodLabel,
              paymentMethod: widget.paymentMethod,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Amount display ───────────────────────────────────────────────────────────

class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({required this.displayAmount});

  final String displayAmount;

  @override
  Widget build(BuildContext context) {
    final isEmpty = displayAmount == '0';
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              displayAmount,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -2,
                    color: isEmpty ? cs.onSurface.withValues(alpha: 0.3) : cs.onSurface,
                  ),
            ),
            const SizedBox(width: DonySpacing.xs),
            Text(
              '€',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: isEmpty
                        ? cs.onSurface.withValues(alpha: 0.3)
                        : cs.primary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          'Montant à recharger',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

// ─── Quick amount row ─────────────────────────────────────────────────────────

class _QuickAmountRow extends StatelessWidget {
  const _QuickAmountRow({
    required this.amounts,
    required this.currentAmount,
    required this.onSelect,
  });

  final List<int> amounts;
  final double currentAmount;
  final void Function(int) onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Wrap(
      spacing: DonySpacing.sm,
      runSpacing: DonySpacing.sm,
      alignment: WrapAlignment.center,
      children: amounts.map((a) {
        final isActive = currentAmount == a.toDouble();
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isActive ? DonyColors.blue50 : cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.full),
            border: Border.all(
              color: isActive ? cs.primary : cs.outline,
              width: isActive ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: () => onSelect(a),
            borderRadius: BorderRadius.circular(DonyRadius.full),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.base,
                vertical: DonySpacing.sm,
              ),
              child: Text(
                '$a €',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: isActive ? cs.primary : cs.onSurfaceVariant,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Sticky bottom CTA ────────────────────────────────────────────────────────

class _StickyButton extends StatelessWidget {
  const _StickyButton({
    required this.amount,
    required this.methodLabel,
    required this.paymentMethod,
  });

  final double amount;
  final String methodLabel;
  final String paymentMethod;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletBloc, WalletState>(
      builder: (context, state) {
        final isLoading = state is WalletLoading;
        final canSubmit = amount >= 1 && !isLoading;

        final label = isLoading
            ? 'Traitement en cours…'
            : amount < 1
                ? 'Entrez un montant'
                : 'Recharger ${amount.toInt()} € via $methodLabel';

        return Padding(
          padding: EdgeInsets.fromLTRB(
            DonySpacing.lg,
            0,
            DonySpacing.lg,
            MediaQuery.paddingOf(context).bottom + DonySpacing.lg,
          ),
          child: DonyButton(
            label: label,
            isLoading: isLoading,
            onPressed: canSubmit
                ? () => context.read<WalletBloc>().add(
                      WalletTopupRequested(
                        amount: amount,
                        paymentMethod: paymentMethod,
                      ),
                    )
                : null,
          ),
        );
      },
    );
  }
}

// ─── Progress bar (shared) ────────────────────────────────────────────────────

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
