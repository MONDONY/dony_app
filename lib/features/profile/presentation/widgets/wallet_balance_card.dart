import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Carte « Solde » de la section ARGENT — remplace l'ancienne tuile
/// « Mon portefeuille » (sous-titre statique « Solde & recharges ») par le
/// solde réel, avec un accès direct à la recharge.
///
/// La devise n'est jamais codée en dur : elle vient de [WalletModel.currency]
/// (déduite du pays de l'utilisateur pour l'instant, modifiable par lui plus
/// tard — cf. le repère visuel en pointillés à côté du code devise).
class WalletBalanceCard extends StatelessWidget {
  const WalletBalanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletBloc, WalletState>(
      builder: (context, state) {
        return switch (state) {
          WalletLoaded(:final wallet) => _LoadedCard(
            balance: wallet.balance,
            currency: wallet.currency,
          ),
          WalletError() => _ErrorCard(
            onRetry: () =>
                context.read<WalletBloc>().add(WalletLoadRequested()),
          ),
          _ => const _LoadingCard(),
        };
      },
    );
  }
}

// ─── Carte chargée ──────────────────────────────────────────────────────────

class _LoadedCard extends StatelessWidget {
  const _LoadedCard({required this.balance, required this.currency});

  final double balance;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final amountFmt = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: '',
      decimalDigits: 2,
    );

    return _CardShell(
      onTap: () => context.push('/payments/wallet'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DonyIcon(
                'wallet',
                color: Colors.white.withValues(alpha: 0.75),
                size: 15,
              ),
              const SizedBox(width: DonySpacing.xs),
              Text(
                'Solde',
                style: tt.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: DonySpacing.xxs),
              _CurrencyBadge(currency: currency, style: tt.bodySmall),
            ],
          ),
          const SizedBox(height: DonySpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                amountFmt.format(balance).trim(),
                style: tt.displayLarge?.copyWith(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: DonySpacing.xs),
              _CurrencyBadge(currency: currency, style: tt.titleMedium),
            ],
          )
              .animate()
              .fadeIn(duration: 250.ms)
              .slideY(begin: 0.08, curve: Curves.easeOutCubic),
          const SizedBox(height: DonySpacing.md),
          _RechargeButton(previousBalance: balance),
        ],
      ),
    );
  }
}

class _CurrencyBadge extends StatelessWidget {
  const _CurrencyBadge({required this.currency, this.style});

  final String currency;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ),
          child: Text(
            currency,
            style: style?.copyWith(
              color: Colors.white.withValues(alpha: 0.70),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 2),
        DonyIcon(
          'chevron-down',
          color: Colors.white.withValues(alpha: 0.55),
          size: 11,
        ),
      ],
    );
  }
}

class _RechargeButton extends StatelessWidget {
  const _RechargeButton({required this.previousBalance});

  final double previousBalance;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Recharger le portefeuille',
      child: InkWell(
        borderRadius: BorderRadius.circular(DonyRadius.md),
        onTap: () async {
          final ok = await context.push<bool>('/payments/wallet/topup/method');
          if (ok != true || !context.mounted) {
            return;
          }
          // Le crédit Stripe arrive de façon asynchrone via webhook : on poll
          // le solde jusqu'à ce qu'il dépasse l'ancien (même pattern que
          // l'écran portefeuille).
          context.read<WalletBloc>().add(
            WalletRefreshAfterTopupRequested(previousBalance),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm + 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(DonyRadius.md),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const DonyIcon('plus', color: Colors.white, size: 16),
              const SizedBox(width: DonySpacing.xs),
              Text(
                'Recharger',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── États loading / erreur ─────────────────────────────────────────────────

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      onTap: () => context.push('/payments/wallet'),
      child: const SizedBox(
        height: 88,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return _CardShell(
      onTap: () => context.push('/payments/wallet'),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Solde indisponible',
              style: tt.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
          IconButton(
            onPressed: onRetry,
            icon: const DonyIcon('refresh-cw', color: Colors.white, size: 18),
            tooltip: 'Réessayer',
          ),
        ],
      ),
    );
  }
}

// ─── Coquille commune (dégradé, radius, shadow, tap) ────────────────────────

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [DonyColors.blue700, DonyColors.blue500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(DonyRadius.card),
          boxShadow: [
            BoxShadow(
              color: DonyColors.blue500.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          splashColor: Colors.white.withValues(alpha: 0.12),
          highlightColor: Colors.white.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.all(DonySpacing.base),
            child: child,
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }
}
