import 'dart:async';

import 'package:dony/core/currency/active_currency.dart';
import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/phone/phone_last_digits.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_properties.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_keypad.dart';
import 'package:dony/features/payments/bloc/payment_sheet_bloc.dart';
import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:dony/features/payments/presentation/widgets/dony_payment_sheet.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_state.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_mobile_money_awaiting_args.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Minimum de recharge, exprimé en EUR quelle que soit la devise active : en
/// dessous, Stripe refuse le PaymentIntent (montant minimum par devise). On
/// convertit systématiquement vers l'EUR via `unitsPerEur` pour bloquer côté
/// client avant l'appel réseau, plutôt que de laisser Stripe renvoyer une
/// erreur.
///
/// Ne s'applique jamais au mobile money : ce rail suit les bornes réelles de
/// l'opérateur ([WalletTopupAmountScreen.mobileMoneyOperator]), le serveur
/// restant seul décideur (422 `topup-amount-out-of-range`).
const double _minTopupEur = 5.0;

/// Chiffres de la partie entière acceptés par le montant mobile money. Une
/// limite de saisie, pas une borne métier : les bornes de l'opérateur
/// viennent du catalogue des pays (`minAmount`/`maxAmount`).
const int _customAmountMaxDigits = 7;

class WalletTopupAmountScreen extends StatefulWidget {
  final String paymentMethod;

  /// Numéro payeur déjà confirmé à l'étape précédente — non nul quand
  /// [paymentMethod] vaut `'MOBILE_MONEY'`.
  final String? mobileMoneyPhoneNumber;

  /// Devise renvoyée par le catalogue d'opérateurs — non nulle quand
  /// [paymentMethod] vaut `'MOBILE_MONEY'`. Remplace la devise active pour
  /// cet écran : le solde est toujours crédité dans la devise de
  /// l'opérateur, jamais dans la devise préférée de l'utilisateur.
  final String? mobileMoneyCurrency;

  /// Opérateur choisi sur l'écran Recharger : rappelé en haut de la carte
  /// (« Depuis Orange Money ••56 ») et source des bornes de montant. `null`
  /// dans l'ancien parcours (back sans catalogue des pays) : le nom vient
  /// alors du catalogue d'opérateurs du cubit, sans bornes.
  final MobileMoneyOperator? mobileMoneyOperator;

  const WalletTopupAmountScreen({
    super.key,
    required this.paymentMethod,
    this.mobileMoneyPhoneNumber,
    this.mobileMoneyCurrency,
    this.mobileMoneyOperator,
  });

  @override
  State<WalletTopupAmountScreen> createState() =>
      _WalletTopupAmountScreenState();
}

class _WalletTopupAmountScreenState extends State<WalletTopupAmountScreen> {
  // setState toléré ici : état UI local (saisie montant + devise résolue).
  String _rawAmount = '';

  /// Mobile money : montant saisi au clavier (« Autre montant » ou tap sur
  /// le montant, FLUTTER-CF) plutôt que choisi parmi les montants proposés.
  bool _customAmount = false;

  /// Montant mobile money, saisi directement dans la carte. Un montant
  /// proposé le remplit aussi.
  final TextEditingController _customController = TextEditingController();
  final FocusNode _customFocus = FocusNode();

  /// Opérateur qui paie, rappelé en haut de la carte : `null` s'il est
  /// inconnu (la ligne est alors masquée).
  ({String label, String brand})? _payingOperator;

  /// Devise réelle du wallet (source de vérité serveur), chargée à
  /// l'ouverture. `ActiveCurrency.current` (cache Hive d'une préférence
  /// générale, jamais synchronisée avec `wallet.currency`) sert uniquement
  /// de repli le temps du chargement — jamais figée sur EUR par défaut pour
  /// un utilisateur dont le wallet est dans une autre devise.
  SupportedCurrency? _walletCurrency;

  /// Raccourcis de montant adaptés à la devise : 10/20/50/100 n'a aucun sens
  /// en franc CFA (100 F CFA ≈ 0,15 €). Une devise sans décimale reçoit donc
  /// des montants entiers plausibles pour elle.
  List<int> get _quickAmounts => _currency.minorUnit == 0
      ? const [1000, 2000, 5000, 10000]
      : const [10, 20, 50, 100];

  bool get _isMobileMoney => widget.paymentMethod == 'MOBILE_MONEY';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        getIt<AnalyticsService>().logEvent(
          AnalyticsEvents.walletTopupStarted,
          properties: {
            'method': _isMobileMoney
                ? AnalyticsPaymentMethod.mobileMoney
                : AnalyticsPaymentMethod.card,
          },
        ),
      );
    });
    // Le mobile money n'AFFICHE jamais la devise du wallet (c'est celle du
    // catalogue d'opérateurs, déjà connue via
    // [widget.mobileMoneyCurrency]), mais il a besoin de la connaître pour
    // avertir quand l'opérateur crédite une autre devise que la devise
    // active — un solde qui arriverait alors verrouillé.
    unawaited(_loadWalletCurrency());
    if (_isMobileMoney) _payingOperator = _resolvePayingOperator();
    _customFocus.addListener(_onCustomFocusChanged);
  }

  /// Opérateur choisi sur l'écran Recharger, sinon (ancien parcours) celui
  /// coché dans le catalogue d'opérateurs du cubit. Lu une fois : l'état du
  /// cubit change dès le paiement.
  ({String label, String brand})? _resolvePayingOperator() {
    final operator = widget.mobileMoneyOperator;
    if (operator != null) {
      return (label: operator.label, brand: operator.brand);
    }
    final state = context.read<WalletTopupMobileMoneyCubit>().state;
    if (state is! WalletTopupMobileMoneyProvidersReady) return null;
    for (final option in state.catalog.providers) {
      if (option.code == state.selectedProvider) {
        final cut = option.code.indexOf('_');
        return (
          label: option.label,
          brand: (cut < 0 ? option.code : option.code.substring(0, cut))
              .toUpperCase(),
        );
      }
    }
    return null;
  }

  @override
  void dispose() {
    _customFocus
      ..removeListener(_onCustomFocusChanged)
      ..dispose();
    _customController.dispose();
    super.dispose();
  }

  /// Les bornes de l'opérateur s'affichent dès que le montant est en cours
  /// de saisie.
  void _onCustomFocusChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadWalletCurrency() async {
    try {
      final wallet = await getIt<WalletRepository>().getBalance();
      if (!mounted) return;
      setState(() {
        _walletCurrency = SupportedCurrency.fromCodeOrDefault(wallet.currency);
      });
    } catch (_) {
      // Échec silencieux : le repli (ActiveCurrency.current ?? EUR) reste
      // affiché plutôt que de bloquer l'écran de recharge pour une info
      // secondaire — la devise réelle sera revalidée côté serveur à la
      // soumission.
    }
  }

  double get _amount =>
      _rawAmount.isEmpty ? 0.0 : (double.tryParse(_rawAmount) ?? 0.0);

  // Comparaison sur un code de méthode de paiement transmis par l'appelant :
  // donnée, jamais affichée brute.
  String _methodLabel(AppLocalizations l) => switch (widget.paymentMethod) {
    'STRIPE' => l.walletTopupMethodCard, // i18n-ignore
    _ => widget.paymentMethod,
  };

  SupportedCurrency get _currency => _isMobileMoney
      ? SupportedCurrency.fromCodeOrDefault(widget.mobileMoneyCurrency)
      : _activeCurrency ?? SupportedCurrency.eur;

  /// Devise active du portefeuille : celle du serveur dès qu'elle est
  /// chargée, sinon le cache de préférence. `null` tant qu'aucune des deux
  /// n'est connue — on ne devine alors rien, et aucun avertissement de
  /// devise n'est affiché.
  SupportedCurrency? get _activeCurrency =>
      _walletCurrency ?? ActiveCurrency.current;

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
    setState(() => _rawAmount = _rawAmount.substring(0, _rawAmount.length - 1));
  }

  /// Montant proposé touché : il remplit le montant (mobile money).
  void _setQuickAmount(int amount) {
    setState(() {
      _rawAmount = amount.toString();
      _customAmount = false;
      _customController.text = _groupDigits(_rawAmount);
    });
  }

  /// « Autre montant » : repart d'un montant vide et ouvre le clavier
  /// numérique sur le montant.
  void _selectCustomAmount() {
    setState(() {
      _customAmount = true;
      _rawAmount = '';
      _customController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _customFocus.requestFocus();
    });
  }

  void _onCustomAmountChanged(String value) {
    setState(() {
      _customAmount = true;
      _rawAmount = value.replaceAll(' ', '').replaceAll(',', '.');
    });
  }

  /// Chiffres groupés par trois (« 12 500 ») pour une devise sans centimes.
  static String _groupDigits(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// Saisie limitée à un montant plausible pour la devise : entier groupé
  /// par trois chiffres pour le F CFA (pas de centimes), deux décimales au
  /// plus sinon. Un caractère refusé laisse la saisie inchangée.
  TextInputFormatter _customAmountFormatter(SupportedCurrency currency) {
    if (currency.minorUnit == 0) {
      final allowed = RegExp(r'^[\d ]*$');
      return TextInputFormatter.withFunction((oldValue, newValue) {
        if (!allowed.hasMatch(newValue.text)) return oldValue;
        final digits = newValue.text.replaceAll(' ', '');
        if (digits.length > _customAmountMaxDigits) return oldValue;
        final grouped = _groupDigits(digits);
        return TextEditingValue(
          text: grouped,
          selection: TextSelection.collapsed(offset: grouped.length),
        );
      });
    }
    final pattern = RegExp(
      '^\\d{0,$_customAmountMaxDigits}([.,]\\d{0,${currency.minorUnit}})?\$',
    );
    return TextInputFormatter.withFunction(
      (oldValue, newValue) =>
          pattern.hasMatch(newValue.text) ? newValue : oldValue,
    );
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
    final l = context.l10n;
    await DonyPaymentSheet.show(
      context,
      config: PaymentSheetConfig(
        clientSecret: clientSecret,
        amountEur: _amount,
        currencyCode: _currency.code,
        // Le backend ne déclare pas PayPal sur le PaymentIntent de recharge
        // wallet — le bouton PayPal reste donc masqué (dégradation propre).
        paymentMethodTypes: const [],
        analyticsContext: AnalyticsPaymentContext.walletTopup,
      ),
      contextLabel: l.walletTopupPaymentContextLabel,
      onSuccess: () {
        // Recharge carte réellement payée (le solde est crédité ensuite par
        // le webhook Stripe).
        unawaited(
          getIt<AnalyticsService>().logEvent(
            AnalyticsEvents.walletTopupCompleted,
            properties: {
              'method': AnalyticsPaymentMethod.card,
              'currency': _currency.code,
              'amount_bracket': analyticsAmountBracket(_amount),
            },
          ),
        );
        if (!context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (routeContext) => DonySuccessScreen(
              mascotteType: DonyMascotteType.securise,
              title: l.walletTopupSuccessTitle,
              subtitle: l.walletTopupSuccessSubtitle,
              ctaLabel: l.walletTopupSuccessCta,
              onCta: () => _leaveAfterSuccess(routeContext, context),
              // Le bouton fermer (X) suit le même chemin que le CTA. Il allait
              // auparavant vers /home juste après les pops : l'écran de choix
              // de méthode, encore monté, se dépilait à son tour en retard
              // (`pop(true)` sur le `true` reçu) pendant que `go` réécrivait
              // la pile, et l'appelant (« À traiter », règlement de
              // commission) relançait l'action qu'il attendait de ce `true`
              // depuis un écran en train de disparaître (FLUTTER-7N).
              onClose: () => _leaveAfterSuccess(routeContext, context),
              analyticsContext: 'wallet_topup',
            ),
          ),
        );
      },
    );
  }

  /// Ferme l'écran de succès puis cet écran de montant avec `true` : préserve
  /// la pile (le retour de l'appelant continue de fonctionner) et signale à
  /// l'appelant qu'il doit recharger son solde (crédité de façon asynchrone
  /// via webhook) ou relancer l'action qui attendait la recharge.
  void _leaveAfterSuccess(BuildContext successContext, BuildContext context) {
    Navigator.of(successContext).pop(); // ferme DonySuccessScreen
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    // Chemin Stripe intact (parcours et tests inchangés) : la branche mobile
    // money vit entièrement dans _buildMobileMoney, avec son propre bloc
    // (WalletTopupMobileMoneyCubit) — jamais WalletBloc, absent de l'arbre
    // pour cette méthode de paiement.
    return _isMobileMoney ? _buildMobileMoney(context) : _buildStripe(context);
  }

  Widget _buildStripe(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    return BlocListener<WalletBloc, WalletState>(
      listener: (context, state) {
        if (state is WalletTopupStripeReady) {
          _presentStripePaymentSheet(context, state.clientSecret);
        } else if (state is WalletError) {
          // Jamais state.message brut : c'est le detail backend, qui peut
          // relayer le message anglais brut de Stripe (ex. "20 Fr converts
          // to approximately €0.03") — toujours en euro, quelle que soit la
          // devise active de l'utilisateur. ErrorPresenter retombe sur un
          // message générique français, sans référence à une devise.
          // `state.error` et non `state.message` : passer la String perdait le
          // code métier (ErrorPresenter re-wrappe alors en NetworkException
          // sans code), et l'ErrorCatalog retombait toujours sur son message
          // générique — les entrées dédiées ne servaient à rien.
          unawaited(ErrorPresenter.show(context, state.error));
        } else if (state is WalletLoaded &&
            (ModalRoute.of(context)?.isCurrent ?? false)) {
          // Rechargement réussi → retour au wallet. Seulement si cet écran
          // est au premier plan : `context.pop` dépile la route du dessus,
          // et sous l'écran de succès il fermerait celui-ci au lieu de
          // l'écran de montant (une route de trop).
          context.pop(true);
        }
      },
      child: Scaffold(
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
            l.walletTopupAmountTitle,
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
                    _AmountDisplay(
                          displayAmount: _displayAmount,
                          currency: _currency,
                        )
                        .animate()
                        .fadeIn(duration: 250.ms)
                        .slideY(begin: -0.05, curve: Curves.easeOutCubic),

                    const SizedBox(height: DonySpacing.xl),

                    Text(
                      l.walletTopupCreditNotice(_currency.code),
                      textAlign: TextAlign.center,
                      style: tt.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),

                    // ── Raccourcis rapides ────────────────────────────────────
                    _QuickAmountRow(
                          amounts: _quickAmounts,
                          currentAmount: _amount,
                          currency: _currency,
                          onSelect: _setQuickAmount,
                        )
                        .animate(delay: 60.ms)
                        .fadeIn(duration: 250.ms)
                        .slideY(begin: 0.04, curve: Curves.easeOutCubic),

                    const SizedBox(height: DonySpacing.xxl),

                    // ── Clavier numérique ─────────────────────────────────────
                    DonyKeypad(onDigit: _onDigit, onDelete: _onDelete),
                  ],
                ),
              ),
            ),

            // ── Sticky bottom CTA ─────────────────────────────────────────────
            _StickyButton(
              amount: _amount,
              methodLabel: _methodLabel(l),
              paymentMethod: widget.paymentMethod,
              currency: _currency,
            ),
          ],
        ),
      ),
    );
  }

  /// Étape 2/2 mobile money, liée à [WalletTopupMobileMoneyCubit] (jamais
  /// [WalletBloc]) : carte du montant (compte qui paie, montant saisi au
  /// clavier numérique, devise, portefeuille crédité ou bornes de
  /// l'opérateur), montants proposés et « Autre montant » (FLUTTER-CF).
  /// `initiate()` déclenche la recharge ; la transition vers
  /// [WalletTopupMobileMoneyAwaiting] pousse l'écran d'attente en remplaçant
  /// cet écran dans la pile (`pushReplacement`) : un `pop()` depuis
  /// l'attente revient directement à l'écran Recharger.
  Widget _buildMobileMoney(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final currency = _currency;
    final phoneNumber = widget.mobileMoneyPhoneNumber ?? '';
    final minAmount = widget.mobileMoneyOperator?.minAmount;
    final maxAmount = widget.mobileMoneyOperator?.maxAmount;
    final outOfBounds =
        _amount > 0 &&
        ((minAmount != null && _amount < minAmount) ||
            (maxAmount != null && _amount > maxAmount));

    return BlocListener<
      WalletTopupMobileMoneyCubit,
      WalletTopupMobileMoneyState
    >(
      listenWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType,
      listener: (context, state) {
        switch (state) {
          case final WalletTopupMobileMoneyAwaiting s:
            // Une recharge déjà ouverte côté serveur (409) est reprise à la
            // place : son montant est celui du serveur et son numéro n'est
            // connu que masqué (pas de « Renvoyer une demande »).
            context.pushReplacement(
              '/payments/wallet/topup/mobile-money/awaiting',
              extra: WalletTopupMobileMoneyAwaitingArgs(
                cubit: context.read<WalletTopupMobileMoneyCubit>(),
                phoneNumber: s.resumed ? null : phoneNumber,
                amount: s.amount ?? _amount,
              ),
            );
          case final WalletTopupMobileMoneyError e:
            unawaited(ErrorPresenter.show(context, e.error));
          default:
        }
      },
      child: Scaffold(
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
            l.walletTopupAmountTitle,
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
                  DonySpacing.xl,
                  DonySpacing.lg,
                  DonySpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _enter(
                      context,
                      _mobileMoneyAmountCard(
                        context,
                        currency: currency,
                        phoneNumber: phoneNumber,
                        minAmount: minAmount,
                        maxAmount: maxAmount,
                        outOfBounds: outOfBounds,
                      ),
                      0,
                    ),
                    const SizedBox(height: DonySpacing.base),
                    _enter(
                      context,
                      _QuickAmountRow(
                        amounts: _quickAmounts,
                        currentAmount: _customAmount ? -1 : _amount,
                        currency: currency,
                        onSelect: _setQuickAmount,
                        customLabel: l.walletTopupCustomAmountChip,
                        customActive: _customAmount,
                        onCustom: _selectCustomAmount,
                      ),
                      1,
                    ),
                  ],
                ),
              ),
            ),
            _MobileMoneyStickyButton(
              amount: _amount,
              currency: currency,
              phoneNumber: phoneNumber,
              custom: _customAmount,
              outOfBounds: outOfBounds,
            ),
          ],
        ),
      ),
    );
  }

  /// Entrée d'un bloc : fondu et léger glissé décalés de 60 ms, coupés quand
  /// la réduction du mouvement est active.
  Widget _enter(BuildContext context, Widget child, int index) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return child
        .animate(delay: (60 * index).ms)
        .fadeIn(duration: 250.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }

  /// Carte du montant : compte qui paie (et « Changer »), montant saisi au
  /// clavier numérique avec sa devise, puis une ligne : portefeuille crédité,
  /// ou bornes de l'opérateur pendant la saisie et hors bornes.
  Widget _mobileMoneyAmountCard(
    BuildContext context, {
    required SupportedCurrency currency,
    required String phoneNumber,
    required double? minAmount,
    required double? maxAmount,
    required bool outOfBounds,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final activeCurrency = _activeCurrency;

    // Bornes publiées par l'opérateur : les deux, ou celle qui existe.
    final boundsText = switch ((minAmount, maxAmount)) {
      (final double min, final double max) => l.walletTopupAmountBounds(
        CurrencyFormatter.formatAmountOnly(min, currency),
        CurrencyFormatter.format(max, currency),
      ),
      (final double min, null) => l.walletTopupAmountAtLeast(
        CurrencyFormatter.format(min, currency),
      ),
      (null, final double max) => l.walletTopupAmountAtMost(
        CurrencyFormatter.format(max, currency),
      ),
      (null, null) => null,
    };
    final showBounds =
        boundsText != null &&
        (_customAmount || _customFocus.hasFocus || outOfBounds);
    // La recharge crédite le portefeuille de la devise de l'opérateur,
    // jamais le portefeuille actif : une seule ligne le dit, complétée quand
    // les deux diffèrent. Devises nommées par leur symbole court (F CFA, €).
    final creditedLine =
        activeCurrency != null && activeCurrency.code != currency.code
        ? l.walletTopupCreditedLineUnchanged(
            currency.symbol,
            activeCurrency.symbol,
          )
        : l.walletTopupCreditedLine(currency.symbol);
    final operator = _payingOperator;

    return DonyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (operator != null)
            Row(
              children: [
                DonyBrandMark(brand: operator.brand, size: 20),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: Text(
                    l.walletTopupFromAccount(
                      operator.label,
                      phoneLastDigits(phoneNumber),
                    ),
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.pop(),
                  child: Text(l.walletTopupChangeAccount),
                ),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: l.walletTopupAmountLabel,
                  child: TextField(
                    key: const Key('wallet-topup-custom-amount-field'),
                    controller: _customController,
                    focusNode: _customFocus,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: currency.minorUnit > 0,
                    ),
                    textInputAction: TextInputAction.done,
                    inputFormatters: [_customAmountFormatter(currency)],
                    onChanged: _onCustomAmountChanged,
                    style: tt.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    cursorColor: cs.primary,
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: tt.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      filled: false,
                      isCollapsed: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.md,
                  vertical: DonySpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                ),
                child: Text(
                  currency.symbol,
                  style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            showBounds ? boundsText : creditedLine,
            style: tt.bodySmall?.copyWith(
              color: showBounds && outOfBounds ? cs.error : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sticky bottom CTA (mobile money) ─────────────────────────────────────────

class _MobileMoneyStickyButton extends StatelessWidget {
  const _MobileMoneyStickyButton({
    required this.amount,
    required this.currency,
    required this.phoneNumber,
    required this.custom,
    required this.outOfBounds,
  });

  final double amount;
  final SupportedCurrency currency;
  final String phoneNumber;

  /// Montant saisi au clavier : seul ce drapeau part dans l'analytics,
  /// jamais le montant.
  final bool custom;

  /// Montant hors des bornes de l'opérateur : paiement impossible, la carte
  /// du montant affiche les bornes.
  final bool outOfBounds;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<
      WalletTopupMobileMoneyCubit,
      WalletTopupMobileMoneyState
    >(
      builder: (context, state) {
        final l = context.l10n;
        final isLoading = state is WalletTopupMobileMoneyInitiating;
        final canSubmit =
            amount > 0 && !outOfBounds && !isLoading && phoneNumber.isNotEmpty;

        final label = isLoading
            ? l.walletTopupProcessing
            : amount <= 0
            ? l.walletTopupEnterAmount
            : l.walletTopupPayAmount(
                // Un montant saisi peut porter des centimes (devise qui en
                // a) : ne jamais les tronquer dans le libellé du paiement.
                amount == amount.truncateToDouble()
                    ? '${amount.toInt()}'
                    : amount.toStringAsFixed(currency.minorUnit),
                currency.symbol,
              );

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
                ? () => context.read<WalletTopupMobileMoneyCubit>().initiate(
                    amount: amount,
                    phoneNumber: phoneNumber,
                    custom: custom,
                  )
                : null,
          ),
        );
      },
    );
  }
}

// ─── Amount display ───────────────────────────────────────────────────────────

class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({required this.displayAmount, required this.currency});

  final String displayAmount;
  final SupportedCurrency currency;

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
                color: isEmpty
                    ? cs.onSurface.withValues(alpha: 0.3)
                    : cs.onSurface,
              ),
            ),
            const SizedBox(width: DonySpacing.xs),
            Text(
              currency.symbol,
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
          context.l10n.walletTopupAmountLabel,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
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
    required this.currency,
    required this.onSelect,
    this.customLabel,
    this.customActive = false,
    this.onCustom,
  });

  final List<int> amounts;
  final double currentAmount;
  final SupportedCurrency currency;
  final void Function(int) onSelect;

  /// Puce « Autre montant », en dernier, quand [onCustom] est fourni.
  final String? customLabel;
  final bool customActive;
  final VoidCallback? onCustom;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DonySpacing.sm,
      runSpacing: DonySpacing.sm,
      alignment: WrapAlignment.center,
      children: [
        for (final a in amounts)
          _AmountChip(
            label: '$a ${currency.symbol}',
            isActive: currentAmount == a.toDouble(),
            onTap: () => onSelect(a),
          ),
        if (onCustom != null && customLabel != null)
          _AmountChip(
            key: const Key('wallet-topup-custom-amount-chip'),
            label: customLabel!,
            isActive: customActive,
            onTap: onCustom!,
          ),
      ],
    );
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: isActive,
      child: AnimatedContainer(
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kDonyMinTapTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.base,
                vertical: DonySpacing.sm,
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isActive ? cs.primary : cs.onSurfaceVariant,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sticky bottom CTA ────────────────────────────────────────────────────────

class _StickyButton extends StatelessWidget {
  const _StickyButton({
    required this.amount,
    required this.methodLabel,
    required this.paymentMethod,
    required this.currency,
  });

  final double amount;
  final String methodLabel;
  final String paymentMethod;
  final SupportedCurrency currency;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletBloc, WalletState>(
      builder: (context, state) {
        final l = context.l10n;
        final isLoading = state is WalletLoading;
        final amountInEur = amount / currency.unitsPerEur;
        final belowMinimum = amount > 0 && amountInEur < _minTopupEur;
        final canSubmit = amount > 0 && !belowMinimum && !isLoading;

        final label = isLoading
            ? l.walletTopupProcessing
            : amount <= 0
            ? l.walletTopupEnterAmount
            : belowMinimum
            ? l.walletTopupBelowMinimum(
                CurrencyFormatter.format(
                  _minTopupEur * currency.unitsPerEur,
                  currency,
                ),
              )
            : l.walletTopupViaMethod(
                '${amount.toInt()}',
                currency.symbol,
                methodLabel,
              );

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
                      currencyCode: currency.code,
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
