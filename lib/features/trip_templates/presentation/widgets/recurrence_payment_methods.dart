import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// La carte peut-elle être proposée sur les trajets d'une récurrence ?
///
/// Même règle que la publication d'un trajet simple (`prix_conditions_step`) :
/// devise éligible d'abord, puis compte Stripe Connect terminé. Sans
/// [StripeAccountBloc] dans l'arbre (tests isolés), la carte est réputée
/// indisponible : rien n'est alors refusé au nom du voyageur.
bool recurrenceCardAvailable(
  StripeAccountState? stripeState,
  SupportedCurrency currency,
) =>
    currency.isStripeEligible &&
    stripeState is StripeAccountReady &&
    stripeState.accountStatus.isComplete;

/// « Modes de paiement acceptés » d'un trajet récurrent (FLUTTER-FT).
///
/// Comme sur un trajet simple : la carte est cochée par défaut et décochable
/// quand elle est disponible, avec le même texte d'aide une fois décochée. Il
/// reste toujours un moyen de paiement : sans la carte, les espèces sont
/// imposées et verrouillées.
///
/// Les deux [ValueNotifier] appartiennent à l'écran parent, qui les libère.
class RecurrencePaymentMethods extends StatelessWidget {
  const RecurrencePaymentMethods({
    super.key,
    required this.currency,
    required this.cardWanted,
    required this.cashWanted,
  });

  final SupportedCurrency currency;
  final ValueNotifier<bool> cardWanted;
  final ValueNotifier<bool> cashWanted;

  @override
  Widget build(BuildContext context) {
    final stripeBloc = context.read<StripeAccountBloc?>();
    if (stripeBloc == null) return _buildCard(context, null);
    return BlocBuilder<StripeAccountBloc, StripeAccountState>(
      bloc: stripeBloc,
      builder: _buildCard,
    );
  }

  Widget _buildCard(BuildContext context, StripeAccountState? stripeState) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final available = recurrenceCardAvailable(stripeState, currency);
    final checking = stripeState is StripeAccountLoading;
    final notConfigured =
        currency.isStripeEligible &&
        !available &&
        !checking &&
        (stripeState?.connectAvailableInCountry ?? false);

    return ListenableBuilder(
      listenable: Listenable.merge([cardWanted, cashWanted]),
      builder: (context, _) {
        final cardOn = available && cardWanted.value;
        final cashLocked = !cardOn;
        final cashOn = cashLocked || cashWanted.value;
        // Material plutôt qu'un fond décoré : les interrupteurs y peignent
        // leur retour de toucher, coins arrondis compris.
        return Material(
          key: const Key('recurrence-payment-methods'),
          color: cs.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.card),
            side: BorderSide(color: cs.outline),
          ),
          child: Column(
            children: [
              SwitchListTile(
                key: const Key('recurrence-payment-card'),
                value: cardOn,
                onChanged: checking
                    ? null
                    : available
                    ? (wanted) {
                        cardWanted.value = wanted;
                        if (!wanted && !cashWanted.value) {
                          DonySnackbar.show(
                            context,
                            message: l.tripPublishPaymentMethodRequired,
                          );
                        }
                      }
                    : notConfigured
                    ? (_) => context.push('/connect/onboarding/intro')
                    : (_) => DonySnackbar.show(
                        context,
                        message: l.tripPublishCardUnavailableSubtitle,
                      ),
                activeThumbColor: cs.primary,
                title: Row(
                  children: [
                    DonyIcon(
                      'credit-card',
                      size: 18,
                      color: available ? null : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: DonySpacing.sm),
                    Flexible(
                      child: Text(
                        l.tripPublishCardPaymentTitle,
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: available ? cs.onSurface : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  available
                      ? l.tripPublishCardPaymentSubtitle
                      : checking
                      ? l.tripPublishCardCheckingSubtitle
                      : notConfigured
                      ? l.tripPublishCardNotConfiguredSubtitle
                      : l.tripPublishCardUnavailableSubtitle,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              // Carte disponible mais décochée : même texte d'aide que sur un
              // trajet simple, pour dire ce que le voyageur perd.
              if (available)
                AnimatedSize(
                  duration: 200.ms,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: cardOn
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(
                            DonySpacing.base,
                            0,
                            DonySpacing.base,
                            DonySpacing.md,
                          ),
                          child: Text(
                            l.tripPublishCardOffHelp,
                            key: const Key('recurrence-card-off-help'),
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ).animate().fadeIn(duration: 200.ms),
                        ),
                ),
              Divider(height: 1, color: cs.outlineVariant),
              SwitchListTile(
                key: const Key('recurrence-payment-cash'),
                value: cashOn,
                // Verrouillées sans la carte, les espèces restent un
                // interrupteur actif à l'œil : un toucher explique pourquoi.
                onChanged: cashLocked
                    ? (_) => DonySnackbar.show(
                        context,
                        message: l.tripPublishCashLockedExplanation,
                      )
                    : (v) => cashWanted.value = v,
                activeThumbColor: cs.primary,
                title: Row(
                  children: [
                    const DonyIcon('banknote', size: 18),
                    const SizedBox(width: DonySpacing.sm),
                    Flexible(
                      child: Text(
                        l.tripPublishCashLabel,
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  cashLocked
                      ? l.tripPublishCashLockedSubtitle
                      : l.tripPublishCashSubtitle,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
