import 'dart:async';

import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/phone/normalize_payer_phone.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/payments/bloc/payer_account_cubit.dart';
import 'package:dony/features/payments/bloc/payer_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:dony/features/payments/presentation/widgets/mobile_money_networks_checklist.dart';
import 'package:dony/features/payments/presentation/widgets/payer_account_section.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_availability_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_state.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_method_selection.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_mobile_money_awaiting_args.dart';
import 'package:dony/features/payments/wallet/presentation/widgets/wallet_topup_code_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Écran de choix de la méthode de recharge du portefeuille — carte bancaire
/// (Stripe) ou mobile money (Orange Money, MTN MoMo via pawaPay).
///
/// Le [WalletTopupMobileMoneyCubit] utilisé par la section mobile money est
/// fourni par un ancêtre (`BlocProvider` posé au niveau de la route dans
/// `router.dart`) : ce même écran reste monté (empilé, pas dépilé) tant que
/// l'écran de montant puis d'attente sont poussés par-dessus, donc la même
/// instance survit à tout le parcours de recharge — c'est elle qui est
/// transmise en aval via [WalletTopupMethodSelection.cubit], jamais une
/// nouvelle (le sondage démarré par `initiate()` ne doit jamais être perdu).
///
/// En mobile money, le bloc « compte qui paie » ([PayerAccountSection], lu
/// dans le [PayerAccountCubit] posé par la route) demande pays, opérateur
/// puis numéro. Sur un back sans catalogue des pays (état `legacy`), l'écran
/// garde l'ancien champ numéro et sa liste d'opérateurs
/// ([_MobileMoneySection]).
///
/// À l'ouverture, une recharge mobile money encore ouverte côté serveur (app
/// fermée pendant l'attente) est reprise : son écran d'attente s'ouvre
/// directement, au lieu du 409 « recharge déjà en cours » au paiement.

/// Pause de saisie après laquelle les opérateurs du numéro sont chargés
/// (ancien parcours, état `legacy`).
@visibleForTesting
const walletTopupPhoneDebounceDelay = Duration(milliseconds: 700);

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

  /// Chargement des opérateurs dès que la saisie marque une pause : sur le
  /// pavé téléphone iOS, rien n'invite à quitter le champ, et le bouton
  /// restait grisé sans explication (Sentry FLUTTER-8B).
  Timer? _phoneDebounce;

  /// En dessous, le numéro est forcément incomplet : inutile d'interroger
  /// le serveur à chaque chiffre.
  static const _minPhoneDigits = 8;

  static _MethodDef _cardMethod(AppLocalizations l) => _MethodDef(
    iconAsset: 'credit-card',
    label: l.walletTopupMethodCard,
    subtitle: l.walletTopupMethodCardSubtitle,
    value:
        'STRIPE', // i18n-ignore : code de méthode de paiement envoyé au serveur
  );

  static _MethodDef _mobileMoneyMethod(AppLocalizations l) => _MethodDef(
    iconAsset: 'smartphone',
    label: l.paymentMethodMobileMoney,
    subtitle: l.walletTopupMethodMobileMoneySubtitle,
    value: 'MOBILE_MONEY',
  );

  @override
  void initState() {
    super.initState();
    _phoneFocusNode.addListener(_onPhoneFocusChange);
    unawaited(_resumePendingTopup());
  }

  /// Reprend la recharge mobile money encore en attente, s'il y en a une, et
  /// ouvre son écran d'attente. Le numéro n'est connu que masqué : pas de
  /// « Renvoyer une demande » sur une recharge reprise.
  ///
  /// La réponse peut arriver tard : la reprise n'a lieu que si l'écran est
  /// toujours au sommet et que rien n'a été lancé sur le cubit (sinon deux
  /// écrans d'attente s'empileraient, par exemple depuis l'écran du montant).
  Future<void> _resumePendingTopup() async {
    final cubit = context.read<WalletTopupMobileMoneyCubit>();
    final resumed = await cubit.resumePending(
      shouldResume: () =>
          mounted &&
          (ModalRoute.of(context)?.isCurrent ?? false) &&
          (cubit.state is WalletTopupMobileMoneyIdle ||
              cubit.state is WalletTopupMobileMoneyProvidersReady),
    );
    if (!resumed || !mounted) return;
    final state = cubit.state;
    if (state is! WalletTopupMobileMoneyAwaiting) return;
    unawaited(
      context.push(
        '/payments/wallet/topup/mobile-money/awaiting',
        extra: WalletTopupMobileMoneyAwaitingArgs(
          cubit: cubit,
          phoneNumber: null,
          amount: state.amount ?? 0,
        ),
      ),
    );
  }

  void _onPhoneFocusChange() {
    if (_phoneFocusNode.hasFocus) return;
    final normalized = normalizePayerPhone(_phoneController.text);
    if (normalized == null || normalized.isEmpty) return;
    _requestProviders(normalized);
  }

  void _onPhoneChanged(String value) {
    _phoneDebounce?.cancel();
    final normalized = normalizePayerPhone(value);
    if (normalized == null) return;
    final digits = normalized.replaceAll(RegExp(r'\D'), '');
    if (digits.length < _minPhoneDigits) return;
    _phoneDebounce = Timer(walletTopupPhoneDebounceDelay, () {
      if (mounted) _requestProviders(normalized);
    });
  }

  /// Le catalogue affiché correspond-il encore à [phoneNumber] ? Seuls les
  /// deux états qui PORTENT ce catalogue comptent : après un `Failed`, une
  /// erreur ou un `reset()` (« Payer avec un autre numéro »), il n'y a plus
  /// rien à l'écran et ressaisir le même numéro doit relancer le
  /// chargement.
  bool _hasCatalogFor(String phoneNumber, WalletTopupMobileMoneyState state) {
    if (phoneNumber != _lastLoadedPhone) return false;
    return state is WalletTopupMobileMoneyProvidersReady ||
        state is WalletTopupMobileMoneyProvidersLoading;
  }

  /// Ne relance jamais `loadProviders` pendant qu'une recharge est déjà en
  /// cours d'initiation ou de sondage sur ce cubit — sans quoi le catalogue
  /// rechargé (et son `ProvidersLoading` synchrone) écraserait visuellement
  /// l'écran d'attente d'une recharge déjà lancée pour ce même cubit.
  void _requestProviders(String phoneNumber) {
    final cubit = context.read<WalletTopupMobileMoneyCubit>();
    final busy =
        cubit.state is WalletTopupMobileMoneyInitiating ||
        cubit.state is WalletTopupMobileMoneyAwaiting ||
        cubit.state is WalletTopupMobileMoneyOverdue;
    if (busy) return;
    if (_hasCatalogFor(phoneNumber, cubit.state)) return;
    _lastLoadedPhone = phoneNumber;
    cubit.loadProviders(phoneNumber);
  }

  /// Le cubit est revenu à [WalletTopupMobileMoneyIdle] (« Payer avec un
  /// autre numéro » depuis l'écran d'attente) alors que le numéro saisi est
  /// toujours là : recharge le catalogue pour que cet écran redevienne
  /// utilisable sans geste supplémentaire.
  void _reloadAfterReset() {
    final normalized = normalizePayerPhone(_phoneController.text);
    if (normalized == null || normalized.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _requestProviders(normalized);
    });
  }

  @override
  void dispose() {
    _phoneDebounce?.cancel();
    _phoneFocusNode.removeListener(_onPhoneFocusChange);
    _phoneFocusNode.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool _canProceed(
    WalletTopupMobileMoneyState mobileMoneyState,
    PayerAccountState payer,
  ) {
    if (_selected == null) return false;
    if (_selected != 'MOBILE_MONEY') return true;
    if (payer.status == PayerAccountStatus.legacy) {
      return mobileMoneyState is WalletTopupMobileMoneyProvidersReady &&
          mobileMoneyState.selectedProvider != null;
    }
    return _payerComplete(payer);
  }

  /// Pays, opérateur et numéro reconnu : de quoi passer au montant.
  static bool _payerComplete(PayerAccountState payer) =>
      payer.canProceed &&
      payer.country != null &&
      payer.operator != null &&
      payer.e164 != null;

  /// Le bouton du bas et le choix entre ancien et nouveau bloc ne dépendent
  /// que de ces valeurs : la frappe du numéro ne reconstruit pas l'écran.
  static bool _payerChangesScreen(
    PayerAccountState previous,
    PayerAccountState current,
  ) =>
      previous.status != current.status ||
      previous.unavailableCountry != current.unavailableCountry ||
      (previous.country == null) != (current.country == null) ||
      _payerComplete(previous) != _payerComplete(current);

  /// Pays « Bientôt » retenu : le bouton du bas propose la carte bancaire.
  bool _offersCard(PayerAccountState payer) =>
      _selected == 'MOBILE_MONEY' &&
      payer.status == PayerAccountStatus.ready &&
      payer.country == null &&
      payer.unavailableCountry != null;

  void _onSwitchToCard() {
    context.read<PayerAccountCubit>().switchToCardTapped();
    setState(() => _selected = 'STRIPE');
  }

  Future<void> _onNext(WalletTopupMobileMoneyState mobileMoneyState) async {
    final selected = _selected;
    if (selected == null) return;
    // Lu au toucher : l'écran ne se reconstruit pas à chaque frappe.
    final payer = context.read<PayerAccountCubit>().state;

    final WalletTopupMethodSelection selection;
    if (selected != 'MOBILE_MONEY') {
      selection = WalletTopupMethodSelection(method: selected);
    } else if (payer.status == PayerAccountStatus.legacy) {
      selection = WalletTopupMethodSelection(
        method: selected,
        phoneNumber: normalizePayerPhone(_phoneController.text),
        currency: (mobileMoneyState as WalletTopupMobileMoneyProvidersReady)
            .catalog
            .currency,
        cubit: context.read<WalletTopupMobileMoneyCubit>(),
      );
    } else {
      final operator = payer.operator!;
      // Aucun catalogue n'est chargé dans ce parcours : le cubit de recharge
      // reçoit l'opérateur choisi, que `initiate()` enverra au back.
      final cubit = context.read<WalletTopupMobileMoneyCubit>()
        ..useOperator(operator.code);
      selection = WalletTopupMethodSelection(
        method: selected,
        phoneNumber: payer.e164,
        currency: payer.country!.currency,
        cubit: cubit,
        operator: operator,
      );
    }

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

  Future<void> _onRedeemCode() async {
    final redemption = await WalletTopupCodeSheet.show(context);
    if (redemption == null || !mounted) return;
    final amount = CurrencyFormatter.format(
      redemption.amount,
      SupportedCurrency.fromCodeOrDefault(redemption.currency),
    );
    DonySnackbar.show(
      context,
      message: context.l10n.walletTopupCodeSuccess(amount),
      type: DonySnackbarType.success,
    );
    // Même contrat qu'une recharge : l'appelant rafraîchit le solde.
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    // La tuile mobile money n'existe que si le backend déployé sert ce rail
    // (sonde lancée à l'ouverture de la route) : sur une prod gelée avant le
    // lot 2, l'écran reste celui d'avant, carte bancaire seule.
    // `null` tant que la sonde n'a pas répondu : la place de la ligne est
    // réservée pour que les lignes suivantes ne sautent pas à la réponse.
    final mobileMoneyAvailability = context
        .watch<WalletTopupMobileMoneyAvailabilityCubit>()
        .state;

    return BlocConsumer<
      WalletTopupMobileMoneyCubit,
      WalletTopupMobileMoneyState
    >(
      // Cet écran reste monté sous l'écran de montant et sous l'écran
      // d'attente : sans filtre, il présenterait une deuxième fois les
      // erreurs d'initiation que ces écrans montrent déjà (ErrorPresenter
      // ne déduplique pas). Seules les erreurs qu'il a lui-même provoquées
      // (chargement du catalogue) le concernent — celles qui viennent d'un
      // `Initiating` appartiennent à l'écran du dessus.
      listenWhen: (previous, current) {
        if (current is WalletTopupMobileMoneyError) {
          return previous is! WalletTopupMobileMoneyInitiating;
        }
        return current is WalletTopupMobileMoneyConfirmed ||
            current is WalletTopupMobileMoneyIdle;
      },
      listener: (context, state) {
        switch (state) {
          case final WalletTopupMobileMoneyError e:
            unawaited(ErrorPresenter.show(context, e.error));
          case final WalletTopupMobileMoneyConfirmed s:
            // Recharge réussie : pays, opérateur et numéro préremplis la
            // prochaine fois (sans effet dans l'ancien parcours). Pas pour une
            // recharge reprise : son numéro n'est connu que masqué, et le
            // compte prérempli sur cet écran n'est pas forcément le sien.
            if (!s.resumed) {
              unawaited(context.read<PayerAccountCubit>().rememberSuccess());
            }
            // Filet de sécurité : si l'écran d'attente n'est plus là quand
            // la confirmation arrive (retour arrière), personne d'autre ne
            // l'annoncerait et l'utilisateur croirait à un échec alors que
            // son argent est débité et crédité. La garde `isCurrent` évite
            // la double navigation quand l'écran d'attente est encore au
            // sommet : c'est lui qui emmène au portefeuille.
            final route = ModalRoute.of(context);
            if (route == null || !route.isCurrent) return;
            context.go('/payments/wallet', extra: {'topupConfirmed': s.status});
          case WalletTopupMobileMoneyIdle():
            _reloadAfterReset();
          default:
        }
      },
      builder: (context, mobileMoneyState) {
        return BlocBuilder<PayerAccountCubit, PayerAccountState>(
          buildWhen: _payerChangesScreen,
          builder: (context, payer) => _buildScaffold(
            context,
            mobileMoneyAvailability: mobileMoneyAvailability,
            mobileMoneyState: mobileMoneyState,
            payer: payer,
          ),
        );
      },
    );
  }

  /// Entrée d'une ligne : fondu et léger glissé décalés de 60 ms, coupés
  /// quand la réduction du mouvement est active.
  Widget _enter(BuildContext context, Widget child, int index) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return child
        .animate(delay: (60 * index).ms)
        .fadeIn(duration: 250.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }

  Widget _buildScaffold(
    BuildContext context, {
    required bool? mobileMoneyAvailability,
    required WalletTopupMobileMoneyState mobileMoneyState,
    required PayerAccountState payer,
  }) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final legacyPayer = payer.status == PayerAccountStatus.legacy;
    final offersCard = _offersCard(payer);

    _MethodCard methodRow(_MethodDef m) => _MethodCard(
      def: m,
      isSelected: _selected == m.value,
      onTap: () => setState(() => _selected = m.value),
    );

    // Mobile money en tête (maquettes v3), puis la carte bancaire et le
    // code. Chaque ligne garde sa clé : une ligne qui apparaît ne rejoue
    // pas l'entrée des autres.
    final rows = <(Key, Widget)>[
      if (mobileMoneyAvailability == null)
        (
          const ValueKey('MOBILE_MONEY-pending'),
          _PendingMethodRow(child: methodRow(_mobileMoneyMethod(l))),
        )
      else if (mobileMoneyAvailability)
        (const ValueKey('MOBILE_MONEY'), methodRow(_mobileMoneyMethod(l))),
      (const ValueKey('STRIPE'), methodRow(_cardMethod(l))),
      (const ValueKey('CODE'), _CodeEntryTile(onTap: _onRedeemCode)),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        actions: const [DonyFeedbackButton()],
        backgroundColor: DonyColors.blue700,
        foregroundColor: DonyColors.neutral0,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        leading: const DonyAppBarBackButton(),
        title: Text(
          l.walletTopupMethodTitle,
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
                Padding(
                  padding: const EdgeInsets.only(
                    left: DonySpacing.xs,
                    bottom: DonySpacing.sm,
                  ),
                  child: Text(
                    l.walletTopupMethodSectionLabel,
                    style: tt.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                // Moyens de recharge regroupés dans une même carte, lignes
                // séparées : mobile money, carte bancaire, code de recharge.
                DonyCard(
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(DonyRadius.card),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < rows.length; i++) ...[
                          if (i > 0)
                            const Divider(
                              height: 1,
                              indent: DonySpacing.base + _kRowIconSize,
                            ),
                          KeyedSubtree(
                            key: rows[i].$1,
                            child: _enter(context, rows[i].$2, i),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_selected == 'MOBILE_MONEY')
                  if (legacyPayer)
                    _MobileMoneySection(
                          phoneController: _phoneController,
                          phoneFocusNode: _phoneFocusNode,
                          onPhoneChanged: _onPhoneChanged,
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
                        .slideY(begin: 0.03, curve: Curves.easeOutCubic)
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: DonySpacing.xl),
                      child: _enter(context, const PayerAccountSection(), 0),
                    ),
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
            child: offersCard
                ? DonyButton(
                    label: l.walletTopupSwitchToCard,
                    variant: DonyButtonVariant.secondary,
                    onPressed: _onSwitchToCard,
                  )
                : DonyButton(
                    label: l.walletTopupMethodNextCta,
                    onPressed: _canProceed(mobileMoneyState, payer)
                        ? () => _onNext(mobileMoneyState)
                        : null,
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Section mobile money (numéro + opérateurs) ────────────────────────────

class _MobileMoneySection extends StatelessWidget {
  const _MobileMoneySection({
    required this.phoneController,
    required this.phoneFocusNode,
    required this.onPhoneChanged,
    required this.state,
    required this.onRetry,
  });

  final TextEditingController phoneController;
  final FocusNode phoneFocusNode;
  final ValueChanged<String> onPhoneChanged;
  final WalletTopupMobileMoneyState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Jamais de devise nommée avant de la connaître : tant que le catalogue
    // n'est pas chargé, la phrase disparaît plutôt que d'annoncer un
    // « F CFA » deviné (l'opérateur peut être en XAF, et le back reste seul
    // décideur). Le code ISO, comme sur l'écran de montant et l'écran
    // d'attente, plutôt que le symbole.
    final currencyCode = state is WalletTopupMobileMoneyProvidersReady
        ? SupportedCurrency.fromCode(
            (state as WalletTopupMobileMoneyProvidersReady).catalog.currency,
          )?.code
        : null;

    return Padding(
      padding: const EdgeInsets.only(top: DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonyTextField(
            key: const Key('wallet-topup-payer-phone-field'),
            controller: phoneController,
            focusNode: phoneFocusNode,
            label: l.mobileMoneyPayingNumberLabel,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onChanged: onPhoneChanged,
            onSubmitted: (_) => phoneFocusNode.unfocus(),
          ),
          if (currencyCode != null) ...[
            const SizedBox(height: DonySpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DonyIcon('smartphone', size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: DonySpacing.xs),
                Expanded(
                  child: Text(
                    l.walletTopupMethodCurrencyNotice(currencyCode),
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: DonySpacing.base),
          switch (state) {
            WalletTopupMobileMoneyProvidersLoading() =>
              const MobileMoneyNetworksSkeleton(),
            final WalletTopupMobileMoneyProvidersReady s
                when s.catalog.isEmpty =>
              DonyStatusBanner(
                type: DonyStatusBannerType.warning,
                message: l.walletTopupMethodNoNetworks,
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
              message: ErrorPresenter.resolve(
                e.error,
                l10n: context.l10n,
              ).message,
              action: TextButton(
                onPressed: onRetry,
                child: Text(l.commonRetry),
              ),
            ),
            // Rien n'est encore chargé : dire quoi faire, plutôt que de
            // laisser un bouton grisé sans explication.
            WalletTopupMobileMoneyIdle() => Text(
              l.walletTopupMethodPhoneHint,
              key: const Key('wallet-topup-phone-hint'),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
        // La tuile « Tous les réseaux » du widget partagé (pensé pour une
        // sélection multiple) coche plusieurs réseaux à la fois : ambigu
        // pour un choix exclusif, ce geste ne change donc rien plutôt que
        // de retenir arbitrairement le premier réseau du catalogue.
        if (added.length > 1) return;
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

// ─── Ligne de moyen de recharge ──────────────────────────────────────────────

/// Côté de la pastille d'icône des lignes de moyen (alignement du séparateur).
const double _kRowIconSize = 36;

/// Une ligne radio de la carte « moyen » : pastille d'icône, nom, détail,
/// rond coché à droite.
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 160);

    return Semantics(
      button: true,
      selected: isSelected,
      label: def.label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOut,
            // Teintes dérivées du thème : un blue50 en dur passait sous le
            // texte clair du thème sombre, illisible (Sentry FLUTTER-8B).
            decoration: BoxDecoration(
              color: isSelected
                  ? Color.alphaBlend(
                      cs.primary.withValues(alpha: 0.06),
                      cs.surface,
                    )
                  : cs.surface,
            ),
            constraints: const BoxConstraints(
              minHeight: kDonyMinTapTarget + 16,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.md,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOut,
                  width: _kRowIconSize,
                  height: _kRowIconSize,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? cs.primary.withValues(alpha: 0.14)
                        : cs.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: def.iconAsset != null
                      ? DonyIcon(
                          def.iconAsset!,
                          color: isSelected ? cs.primary : cs.onSurfaceVariant,
                          size: 18,
                        )
                      : Icon(
                          def.icon,
                          color: isSelected ? cs.primary : cs.onSurfaceVariant,
                          size: 18,
                        ),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        def.label,
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
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
                const SizedBox(width: DonySpacing.sm),
                AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 150),
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
      ),
    );
  }
}

/// Place réservée de la ligne mobile money pendant la sonde : la vraie
/// ligne, invisible, donne la hauteur exacte, et une silhouette immobile
/// l'occupe. Ni toucher ni lecture d'écran.
class _PendingMethodRow extends StatelessWidget {
  const _PendingMethodRow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Stack(
          children: [
            Visibility(
              visible: false,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: child,
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.base,
                ),
                child: Row(
                  children: [
                    Container(
                      width: _kRowIconSize,
                      height: _kRowIconSize,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: DonySpacing.md),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(110, 12),
                        const SizedBox(height: DonySpacing.sm),
                        bar(160, 10),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tuile « J'ai un code de recharge » ──────────────────────────────────────

/// Ouvre la saisie d'un code de recharge. Pas une méthode radio : le montant
/// vient du code, donc pas d'écran de montant. Dernière ligne de la carte
/// « moyen ».
class _CodeEntryTile extends StatelessWidget {
  const _CodeEntryTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: l.walletTopupCodeTileTitle,
      child: Material(
        color: cs.surface,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: kDonyMinTapTarget + 16,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.base,
                vertical: DonySpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: _kRowIconSize,
                    height: _kRowIconSize,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: DonyIcon(
                      'gift',
                      color: cs.onSurfaceVariant,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: DonySpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.walletTopupCodeTileTitle,
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.walletTopupCodeTileSubtitle,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  DonyIcon(
                    'chevron-right',
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
