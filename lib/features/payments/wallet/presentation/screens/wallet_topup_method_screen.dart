import 'dart:async';

import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/phone/normalize_payer_phone.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:dony/features/payments/presentation/widgets/mobile_money_networks_checklist.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_state.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_method_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Écran de choix de la méthode de recharge du portefeuille — carte bancaire
/// (Stripe) ou mobile money (Orange Money, Wave, MTN MoMo via pawaPay).
///
/// Le [WalletTopupMobileMoneyCubit] utilisé par la section mobile money est
/// fourni par un ancêtre (`BlocProvider` posé au niveau de la route dans
/// `router.dart`) : ce même écran reste monté (empilé, pas dépilé) tant que
/// l'écran de montant puis d'attente sont poussés par-dessus, donc la même
/// instance survit à tout le parcours de recharge — c'est elle qui est
/// transmise en aval via [WalletTopupMethodSelection.cubit], jamais une
/// nouvelle (le sondage démarré par `initiate()` ne doit jamais être perdu).
class WalletTopupMethodScreen extends StatefulWidget {
  const WalletTopupMethodScreen({super.key});

  @override
  State<WalletTopupMethodScreen> createState() =>
      _WalletTopupMethodScreenState();
}

class _WalletTopupMethodScreenState extends State<WalletTopupMethodScreen> {
  // setState toléré ici : état UI local (sélection de méthode uniquement).
  String? _selected;

  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();

  /// Dernier numéro pour lequel `loadProviders` a été demandé : évite de
  /// relancer un appel identique à chaque perte de focus si le champ n'a pas
  /// changé depuis.
  String? _lastLoadedPhone;

  static const _methods = [
    _MethodDef(
      iconAsset: 'credit-card',
      label: 'Carte bancaire',
      subtitle: 'Via Stripe · Visa, Mastercard',
      value: 'STRIPE',
    ),
    _MethodDef(
      iconAsset: 'smartphone',
      label: 'Mobile money',
      subtitle: 'Orange Money, Wave, MTN MoMo',
      value: 'MOBILE_MONEY',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _phoneFocusNode.addListener(_onPhoneFocusChange);
  }

  void _onPhoneFocusChange() {
    if (_phoneFocusNode.hasFocus) return;
    final normalized = normalizePayerPhone(_phoneController.text);
    if (normalized == null || normalized.isEmpty) return;
    if (normalized == _lastLoadedPhone) return;
    _requestProviders(normalized);
  }

  /// Ne relance jamais `loadProviders` pendant qu'une recharge est déjà en
  /// cours d'initiation ou de sondage sur ce cubit — sans quoi le catalogue
  /// rechargé (et son `ProvidersLoading` synchrone) écraserait visuellement
  /// l'écran d'attente d'une recharge déjà lancée pour ce même cubit.
  void _requestProviders(String phoneNumber) {
    final cubit = context.read<WalletTopupMobileMoneyCubit>();
    final busy =
        cubit.state is WalletTopupMobileMoneyInitiating ||
        cubit.state is WalletTopupMobileMoneyAwaiting;
    if (busy) return;
    _lastLoadedPhone = phoneNumber;
    cubit.loadProviders(phoneNumber);
  }

  @override
  void dispose() {
    _phoneFocusNode.removeListener(_onPhoneFocusChange);
    _phoneFocusNode.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool _canProceed(WalletTopupMobileMoneyState mobileMoneyState) {
    if (_selected == null) return false;
    if (_selected != 'MOBILE_MONEY') return true;
    return mobileMoneyState is WalletTopupMobileMoneyProvidersReady &&
        mobileMoneyState.selectedProvider != null;
  }

  Future<void> _onNext(WalletTopupMobileMoneyState mobileMoneyState) async {
    final selected = _selected;
    if (selected == null) return;

    final selection = selected == 'MOBILE_MONEY'
        ? WalletTopupMethodSelection(
            method: selected,
            phoneNumber: normalizePayerPhone(_phoneController.text),
            provider: (mobileMoneyState as WalletTopupMobileMoneyProvidersReady)
                .selectedProvider,
            currency: mobileMoneyState.catalog.currency,
            cubit: context.read<WalletTopupMobileMoneyCubit>(),
          )
        : WalletTopupMethodSelection(method: selected);

    // Propage le succès (true) jusqu'au wallet pour qu'il recharge son
    // solde une fois la recharge effectuée.
    final ok = await context.push<bool>(
      '/payments/wallet/topup/amount',
      extra: selection,
    );
    if (ok == true && mounted) {
      context.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return BlocConsumer<
      WalletTopupMobileMoneyCubit,
      WalletTopupMobileMoneyState
    >(
      listenWhen: (previous, current) => current is WalletTopupMobileMoneyError,
      listener: (context, state) {
        if (state is WalletTopupMobileMoneyError) {
          unawaited(ErrorPresenter.show(context, state.error));
        }
      },
      builder: (context, mobileMoneyState) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: DonyColors.blue700,
            foregroundColor: DonyColors.neutral0,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            centerTitle: false,
            leading: const DonyAppBarBackButton(),
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
                        padding: const EdgeInsets.only(bottom: DonySpacing.sm),
                        child:
                            _MethodCard(
                                  def: m,
                                  isSelected: _selected == m.value,
                                  onTap: () =>
                                      setState(() => _selected = m.value),
                                )
                                .animate(delay: (60 * i).ms)
                                .fadeIn(duration: 250.ms)
                                .slideY(
                                  begin: 0.04,
                                  curve: Curves.easeOutCubic,
                                ),
                      );
                    }),
                    if (_selected == 'MOBILE_MONEY')
                      _MobileMoneySection(
                            phoneController: _phoneController,
                            phoneFocusNode: _phoneFocusNode,
                            state: mobileMoneyState,
                            onRetry: () {
                              final normalized = normalizePayerPhone(
                                _phoneController.text,
                              );
                              if (normalized != null && normalized.isNotEmpty) {
                                _requestProviders(normalized);
                              }
                            },
                          )
                          .animate()
                          .fadeIn(duration: 200.ms)
                          .slideY(begin: 0.03, curve: Curves.easeOutCubic),
                  ],
                ),
              ),
              // ── Sticky bottom CTA ─────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                  DonySpacing.lg,
                  0,
                  DonySpacing.lg,
                  MediaQuery.paddingOf(context).bottom + DonySpacing.lg,
                ),
                child: DonyButton(
                  label: 'Suivant → Montant',
                  onPressed: _canProceed(mobileMoneyState)
                      ? () => _onNext(mobileMoneyState)
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Section mobile money (numéro + opérateurs) ────────────────────────────

class _MobileMoneySection extends StatelessWidget {
  const _MobileMoneySection({
    required this.phoneController,
    required this.phoneFocusNode,
    required this.state,
    required this.onRetry,
  });

  final TextEditingController phoneController;
  final FocusNode phoneFocusNode;
  final WalletTopupMobileMoneyState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final currencySymbol = state is WalletTopupMobileMoneyProvidersReady
        ? SupportedCurrency.fromCode(
                (state as WalletTopupMobileMoneyProvidersReady)
                    .catalog
                    .currency,
              )?.symbol ??
              'F CFA'
        : 'F CFA';

    return Padding(
      padding: const EdgeInsets.only(top: DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonyTextField(
            key: const Key('wallet-topup-payer-phone-field'),
            controller: phoneController,
            focusNode: phoneFocusNode,
            label: 'Numéro qui paie',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: DonySpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DonyIcon('smartphone', size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: DonySpacing.xs),
              Expanded(
                child: Text(
                  'Le solde est crédité en $currencySymbol, la devise de '
                  "l'opérateur.",
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.base),
          switch (state) {
            WalletTopupMobileMoneyProvidersLoading() =>
              const MobileMoneyNetworksSkeleton(),
            final WalletTopupMobileMoneyProvidersReady s
                when s.catalog.isEmpty =>
              const DonyStatusBanner(
                type: DonyStatusBannerType.warning,
                message: 'Aucun réseau mobile money disponible pour ce numéro.',
              ),
            final WalletTopupMobileMoneyProvidersReady s =>
              _SingleProviderSelector(
                key: const Key('wallet-topup-providers-selector'),
                catalog: s.catalog,
                selected: s.selectedProvider,
                onSelect: (code) => context
                    .read<WalletTopupMobileMoneyCubit>()
                    .selectProvider(code),
              ),
            final WalletTopupMobileMoneyError e => DonyStatusBanner(
              type: DonyStatusBannerType.error,
              message: ErrorPresenter.resolve(e.error).message,
              action: TextButton(
                onPressed: onRetry,
                child: const Text('Réessayer'),
              ),
            ),
            _ => const SizedBox.shrink(),
          },
        ],
      ),
    );
  }
}

/// Adapte [MobileMoneyNetworksChecklist] — conçue pour une sélection
/// multiple (réseaux acceptés par un voyageur) — à un choix exclusif d'un
/// seul opérateur pour payer : cocher un réseau remplace la sélection
/// précédente, décocher le seul réseau coché vide la sélection.
class _SingleProviderSelector extends StatefulWidget {
  const _SingleProviderSelector({
    super.key,
    required this.catalog,
    required this.selected,
    required this.onSelect,
  });

  final MobileMoneyProviderCatalog catalog;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  State<_SingleProviderSelector> createState() =>
      _SingleProviderSelectorState();
}

class _SingleProviderSelectorState extends State<_SingleProviderSelector> {
  late final ValueNotifier<Set<String>> _selection = ValueNotifier(
    widget.selected == null ? {} : {widget.selected!},
  );

  @override
  void didUpdateWidget(covariant _SingleProviderSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _selection.value = widget.selected == null ? {} : {widget.selected!};
    }
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileMoneyNetworksChecklist(
      catalog: widget.catalog,
      selection: _selection,
      onChanged: (next) {
        final added = next.difference(_selection.value);
        final chosen = added.isNotEmpty
            ? added.first
            : (next.length == 1 ? next.first : null);
        _selection.value = chosen == null ? {} : {chosen};
        widget.onSelect(chosen);
      },
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
    required this.label,
    required this.subtitle,
    required this.value,
    this.iconAsset,
  }) : icon = null;

  final IconData? icon;
  final String? iconAsset;
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
                  color: isSelected
                      ? DonyColors.blue100
                      : DonyColors.neutral100,
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                ),
                child: def.iconAsset != null
                    ? DonyIcon(
                        def.iconAsset!,
                        color: isSelected ? cs.primary : cs.onSurfaceVariant,
                        size: 20,
                      )
                    : Icon(
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
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              // Radio indicator
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: DonyIcon(
                  isSelected ? 'circle-dot' : 'circle',
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
