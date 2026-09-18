import 'dart:async';

import 'package:dony/core/currency/active_currency.dart';
import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_keypad.dart';
import 'package:dony/features/payments/bloc/payment_sheet_bloc.dart';
import 'package:dony/features/payments/presentation/widgets/dony_payment_sheet.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_state.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_mobile_money_awaiting_args.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Minimum de recharge, exprimé en EUR quelle que soit la devise active : en
/// dessous, Stripe refuse le PaymentIntent (montant minimum par devise). On
/// convertit systématiquement vers l'EUR via `unitsPerEur` pour bloquer côté
/// client avant l'appel réseau, plutôt que de laisser Stripe renvoyer une
/// erreur.
///
/// Ne s'applique jamais au mobile money (voir [WalletTopupAmountScreen.
/// mobileMoneyPhoneNumber]) : le backend n'expose aucune borne min/max pour
/// ce rail, une borne devinée ici serait fausse. Le serveur reste seul
/// décideur (422 `topup-amount-out-of-range`).
const double _minTopupEur = 5.0;

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

  const WalletTopupAmountScreen({
    super.key,
    required this.paymentMethod,
    this.mobileMoneyPhoneNumber,
    this.mobileMoneyCurrency,
  });

  @override
  State<WalletTopupAmountScreen> createState() =>
      _WalletTopupAmountScreenState();
}

class _WalletTopupAmountScreenState extends State<WalletTopupAmountScreen> {
  // setState toléré ici : état UI local (saisie montant + devise résolue).
  String _rawAmount = '';

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
        getIt<AnalyticsService>().logEvent(AnalyticsEvents.walletTopupStarted),
      );
    });
    // Le mobile money n'AFFICHE jamais la devise du wallet (c'est celle du
    // catalogue d'opérateurs, déjà connue via
    // [widget.mobileMoneyCurrency]), mais il a besoin de la connaître pour
    // avertir quand l'opérateur crédite une autre devise que la devise
    // active — un solde qui arriverait alors verrouillé.
    unawaited(_loadWalletCurrency());
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

  String get _methodLabel => switch (widget.paymentMethod) {
    'STRIPE' => 'Carte bancaire',
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
        currencyCode: _currency.code,
        // Le backend ne déclare pas PayPal sur le PaymentIntent de recharge
        // wallet — le bouton PayPal reste donc masqué (dégradation propre).
        paymentMethodTypes: const [],
      ),
      contextLabel: 'Recharge de votre solde Yadony',
      onSuccess: () {
        if (!context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
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
          ),
        );
      },
    );
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
          leading: const DonyAppBarBackButton(),
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
                    _AmountDisplay(
                          displayAmount: _displayAmount,
                          currency: _currency,
                        )
                        .animate()
                        .fadeIn(duration: 250.ms)
                        .slideY(begin: -0.05, curve: Curves.easeOutCubic),

                    const SizedBox(height: DonySpacing.xl),

                    Text(
                      'Le solde Yadony sera crédité en ${_currency.code} après confirmation.',
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
              methodLabel: _methodLabel,
              paymentMethod: widget.paymentMethod,
              currency: _currency,
            ),
          ],
        ),
      ),
    );
  }

  /// Étape 2/2 mobile money : mêmes `_AmountDisplay`/`_QuickAmountRow`/
  /// `DonyKeypad` que Stripe, mais liés à [WalletTopupMobileMoneyCubit]
  /// (jamais [WalletBloc]). `initiate()` déclenche la recharge ; la
  /// transition vers [WalletTopupMobileMoneyAwaiting] pousse l'écran
  /// d'attente en remplaçant cet écran de montant dans la pile
  /// (`pushReplacement`) — un `pop()` depuis l'attente revient alors
  /// directement à l'écran de choix, pas à cet écran de montant.
  Widget _buildMobileMoney(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final currency = _currency;
    final activeCurrency = _activeCurrency;
    final phoneNumber = widget.mobileMoneyPhoneNumber ?? '';

    return BlocListener<
      WalletTopupMobileMoneyCubit,
      WalletTopupMobileMoneyState
    >(
      listenWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType,
      listener: (context, state) {
        switch (state) {
          case WalletTopupMobileMoneyAwaiting():
            context.pushReplacement(
              '/payments/wallet/topup/mobile-money/awaiting',
              extra: WalletTopupMobileMoneyAwaitingArgs(
                cubit: context.read<WalletTopupMobileMoneyCubit>(),
                phoneNumber: phoneNumber,
                amount: _amount,
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
          backgroundColor: DonyColors.blue700,
          foregroundColor: DonyColors.neutral0,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          leading: const DonyAppBarBackButton(),
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
                    _AmountDisplay(
                          displayAmount: _displayAmount,
                          currency: currency,
                        )
                        .animate()
                        .fadeIn(duration: 250.ms)
                        .slideY(begin: -0.05, curve: Curves.easeOutCubic),

                    const SizedBox(height: DonySpacing.xl),

                    Text(
                      'Le solde Yadony sera crédité en ${currency.code} après confirmation.',
                      textAlign: TextAlign.center,
                      style: tt.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (currency.minorUnit == 0) ...[
                      const SizedBox(height: DonySpacing.xs),
                      Text(
                        'Le ${currency.symbol} ne connaît pas les centimes : '
                        'indique un montant entier.',
                        textAlign: TextAlign.center,
                        style: tt.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    // La recharge crédite le portefeuille de la devise de
                    // l'opérateur, jamais le portefeuille actif : on nomme
                    // la destination avant de payer, montant compris.
                    if (activeCurrency != null &&
                        activeCurrency.code != currency.code) ...[
                      const SizedBox(height: DonySpacing.base),
                      DonyStatusBanner(
                        key: const Key('wallet-topup-currency-mismatch'),
                        type: DonyStatusBannerType.info,
                        iconAsset: 'wallet',
                        // Avant toute saisie, pas de « crédité de 0 F CFA ».
                        message:
                            'Ton portefeuille ${currency.displayName} sera '
                            'crédité ${_amount > 0 ? 'de ${CurrencyFormatter.format(_amount, currency)}' : 'du montant que tu saisis'}. '
                            'Ton portefeuille ${activeCurrency.displayName} '
                            'ne bouge pas.',
                      ),
                    ],

                    _QuickAmountRow(
                          amounts: _quickAmounts,
                          currentAmount: _amount,
                          currency: currency,
                          onSelect: _setQuickAmount,
                        )
                        .animate(delay: 60.ms)
                        .fadeIn(duration: 250.ms)
                        .slideY(begin: 0.04, curve: Curves.easeOutCubic),

                    const SizedBox(height: DonySpacing.xxl),

                    DonyKeypad(onDigit: _onDigit, onDelete: _onDelete),
                  ],
                ),
              ),
            ),
            _MobileMoneyStickyButton(
              amount: _amount,
              currency: currency,
              phoneNumber: phoneNumber,
            ),
          ],
        ),
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
  });

  final double amount;
  final SupportedCurrency currency;
  final String phoneNumber;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<
      WalletTopupMobileMoneyCubit,
      WalletTopupMobileMoneyState
    >(
      builder: (context, state) {
        final isLoading = state is WalletTopupMobileMoneyInitiating;
        final canSubmit = amount > 0 && !isLoading && phoneNumber.isNotEmpty;

        final label = isLoading
            ? 'Traitement en cours…'
            : amount <= 0
            ? 'Entrez un montant'
            : 'Payer ${amount.toInt()} ${currency.symbol}';

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
          'Montant à recharger',
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
  });

  final List<int> amounts;
  final double currentAmount;
  final SupportedCurrency currency;
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
                '$a ${currency.symbol}',
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
        final isLoading = state is WalletLoading;
        final amountInEur = amount / currency.unitsPerEur;
        final belowMinimum = amount > 0 && amountInEur < _minTopupEur;
        final canSubmit = amount > 0 && !belowMinimum && !isLoading;

        final label = isLoading
            ? 'Traitement en cours…'
            : amount <= 0
            ? 'Entrez un montant'
            : belowMinimum
            ? 'Minimum ${CurrencyFormatter.format(_minTopupEur * currency.unitsPerEur, currency)}'
            : 'Recharger ${amount.toInt()} ${currency.symbol} via $methodLabel';

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
