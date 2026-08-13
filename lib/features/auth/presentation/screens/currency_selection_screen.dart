import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/currency_onboarding_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class CurrencySelectionScreen extends StatelessWidget {
  const CurrencySelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hPadding = DonyLayout.hPadding(context);

    return BlocConsumer<CurrencyOnboardingCubit, CurrencyOnboardingState>(
      listener: (context, state) {
        if (state is CurrencyOnboardingSuccess) {
          context.go('/auth/referral-code');
        } else if (state is CurrencyOnboardingError) {
          DonySnackbar.show(
            context,
            message: state.message,
            type: DonySnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        final isSaving = state is CurrencyOnboardingSaving;
        final selectedCode = isSaving ? state.currencyCode : null;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: DonyLayout.constrained(
              context,
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPadding),
                child: Column(
                  children: [
                    const SizedBox(height: DonySpacing.md),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: DonyStepPill(
                        current: 3,
                        total: 4,
                        label: 'Devise',
                      ),
                    ),
                    Expanded(
                      child: _CurrencyList(
                        isSaving: isSaving,
                        selectedCode: selectedCode,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.md),
                    DonyButton(
                      label: 'Passer pour l’instant',
                      variant: DonyButtonVariant.ghost,
                      isLoading: isSaving && selectedCode == null,
                      onPressed: isSaving
                          ? null
                          : () =>
                                context.read<CurrencyOnboardingCubit>().skip(),
                    ),
                    SizedBox(
                      height:
                          DonySpacing.xl + MediaQuery.paddingOf(context).bottom,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CurrencyList extends StatelessWidget {
  const _CurrencyList({required this.isSaving, required this.selectedCode});

  final bool isSaving;
  final String? selectedCode;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: DonySpacing.xxl),
        _Entrance(
          delay: Duration.zero,
          reduceMotion: reduceMotion,
          child: Text(
            'Quelle devise veux-tu utiliser ?',
            style: tt.headlineLarge?.copyWith(color: cs.onSurface),
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        _Entrance(
          delay: const Duration(milliseconds: 70),
          reduceMotion: reduceMotion,
          child: Text(
            'Pour garantir les correspondances strictes, tu verras et paieras uniquement des trajets dans cette devise. Tu pourras la modifier plus tard dans Réglages.',
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: DonySpacing.xl),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: DonySpacing.base),
            itemCount: SupportedCurrency.values.length,
            separatorBuilder: (_, _) => const SizedBox(height: DonySpacing.sm),
            itemBuilder: (context, index) {
              final currency = SupportedCurrency.values[index];
              return _Entrance(
                delay: Duration(milliseconds: 120 + (index * 45)),
                reduceMotion: reduceMotion,
                child: _CurrencyTile(
                  currency: currency,
                  isSaving: isSaving,
                  isSelected: selectedCode == currency.code,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CurrencyTile extends StatelessWidget {
  const _CurrencyTile({
    required this.currency,
    required this.isSaving,
    required this.isSelected,
  });

  final SupportedCurrency currency;
  final bool isSaving;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final label = isSelected
        ? 'Devise sélectionnée : ${currency.displayName}, ${currency.code}, ${currency.symbol}. Enregistrement en cours.'
        : 'Sélectionner ${currency.displayName}, ${currency.code}, ${currency.symbol}';

    return Semantics(
      button: true,
      selected: isSelected,
      enabled: !isSaving,
      label: label,
      child: DonyCard(
        onTap: isSaving
            ? null
            : () =>
                  context.read<CurrencyOnboardingCubit>().select(currency.code),
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kDonyMinTapTarget),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currency.displayName,
                      style: tt.titleLarge?.copyWith(color: cs.onSurface),
                    ),
                    const SizedBox(height: DonySpacing.xxs),
                    Text(
                      currency.code,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DonySpacing.base),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currency.symbol,
                    style: tt.titleLarge?.copyWith(color: cs.onSurface),
                  ),
                  const SizedBox(height: DonySpacing.xxs),
                  AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 250),
                    child: isSelected
                        ? Row(
                            key: const ValueKey('saving'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: cs.primary,
                                ),
                              ),
                              const SizedBox(width: DonySpacing.xs),
                              Text(
                                'Enregistrement',
                                style: tt.labelMedium?.copyWith(
                                  color: cs.primary,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            key: const ValueKey('choose'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.radio_button_unchecked,
                                color: cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: DonySpacing.xs),
                              Text(
                                'Choisir',
                                style: tt.labelMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Entrance extends StatelessWidget {
  const _Entrance({
    required this.child,
    required this.delay,
    required this.reduceMotion,
  });

  final Widget child;
  final Duration delay;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) return child;
    return child
        .animate(delay: delay)
        .fadeIn(duration: 280.ms, curve: Curves.easeOutCubic)
        .slideY(
          begin: 0.035,
          end: 0,
          duration: 280.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
