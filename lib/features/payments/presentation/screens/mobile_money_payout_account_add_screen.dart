import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_bloc.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_event.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';
import 'package:dony/features/payments/bloc/payer_account_cubit.dart';
import 'package:dony/features/payments/bloc/payer_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_payout_account.dart';
import 'package:dony/features/payments/presentation/widgets/payer_account_section.dart';
import 'package:dony/features/payments/presentation/widgets/payout_account_sheets.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// « Ajouter un compte » de versement, ou « Changer de numéro » d'un compte
/// existant ([accountId] non nul).
///
/// Même bloc pays, opérateur, numéro que la recharge (`PayerAccountSection`,
/// catalogue des versements, sans préremplissage). À l'ajout, les opérateurs
/// déjà enregistrés sont grisés « Ajouté ». Au changement de numéro, pays et
/// opérateur du compte sont imposés ([fixed], sinon lus dans la liste) : seul
/// le numéro se saisit.
///
/// « Continuer » ouvre la relecture du numéro ; « Oui, c'est mon numéro »
/// envoie l'écriture au BLoC. Réussite : l'écran se ferme en rendant `true`
/// (la liste se relit). Refus : la saisie reste, la feuille « compte
/// bloqué » s'ouvre sur un 409 `mobile-money-account-locked`, un message
/// sinon.
class MobileMoneyPayoutAccountAddScreen extends StatefulWidget {
  const MobileMoneyPayoutAccountAddScreen({
    super.key,
    this.accountId,
    this.fixed,
  });

  final String? accountId;
  final FixedPayerAccount? fixed;

  bool get isNumberChange => accountId != null;

  @override
  State<MobileMoneyPayoutAccountAddScreen> createState() =>
      _MobileMoneyPayoutAccountAddScreenState();
}

class _MobileMoneyPayoutAccountAddScreenState
    extends State<MobileMoneyPayoutAccountAddScreen> {
  // Mémoires de réglage du composant, jamais affichées : pas de setState.
  bool _configured = false;
  bool _restricted = false;
  Set<String>? _lastAllowed;

  PayerAccountCubit get _payer => context.read<PayerAccountCubit>();
  MobileMoneyAccountBloc get _bloc => context.read<MobileMoneyAccountBloc>();

  @override
  void initState() {
    super.initState();
    final fixed = widget.fixed;
    if (!widget.isNumberChange) {
      unawaited(_payer.configure());
      _configured = true;
      _syncRestriction();
    } else if (fixed != null) {
      unawaited(_payer.configure(fixed: fixed));
      _configured = true;
    } else {
      _configureFromList();
    }
  }

  /// Compte visé par le changement de numéro, dans la dernière liste lue.
  MobileMoneyPayoutAccount? _accountIn(MobileMoneyPayoutAccounts? data) {
    final id = widget.accountId;
    if (id == null || data == null) return null;
    for (final account in data.accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  /// Changement de numéro sans pays dans l'adresse : pays et opérateur sont
  /// pris dans la liste, dès qu'elle est lue.
  void _configureFromList() {
    if (_configured) return;
    final account = _accountIn(_bloc.state.data);
    if (account == null) return;
    _configured = true;
    unawaited(
      _payer.configure(
        fixed: (country: account.country, operator: account.provider),
      ),
    );
  }

  /// Ajout : tous les opérateurs du catalogue des versements, moins ceux
  /// pour lesquels un compte existe déjà (grisés « Ajouté »). Posé dès que le
  /// catalogue et la liste sont connus, reposé quand l'un d'eux change.
  void _syncRestriction() {
    if (widget.isNumberChange) return;
    final countries = _payer.state.countries;
    final data = _bloc.state.data;
    if (countries == null || data == null) return;
    final added = {for (final a in data.accounts) a.provider};
    final allowed = added.isEmpty
        ? null
        : {
            for (final country in countries.available)
              for (final operator in country.operators)
                if (!added.contains(operator.code)) operator.code,
          };
    if (_restricted && setEquals(allowed, _lastAllowed)) return;
    _restricted = true;
    _lastAllowed = allowed;
    _payer.restrictOperators(allowed);
  }

  static bool _writable(MobileMoneyAccountState state) =>
      (state is MobileMoneyAccountLoaded && !state.submitting) ||
      state is MobileMoneyAccountActionFailed;

  Future<void> _continue() async {
    final payer = _payer.state;
    final operator = payer.operator;
    final country = payer.country;
    final e164 = payer.e164;
    if (operator == null || country == null || e164 == null) return;
    final account = _accountIn(_bloc.state.data);
    if (widget.isNumberChange && account == null) return;

    final confirmed = await PayoutNumberReviewSheet.show(
      context,
      operator: operator,
      countryCode: country.country,
      e164: e164,
    );
    if (confirmed != true || !mounted || !_writable(_bloc.state)) return;
    _bloc.add(
      account != null
          ? MobileMoneyAccountNumberChangeRequested(
              account: account,
              phoneNumber: e164,
            )
          : MobileMoneyAccountAddRequested(
              phoneNumber: e164,
              provider: operator.code,
            ),
    );
  }

  void _onWriteOutcome(BuildContext context, MobileMoneyAccountState state) {
    if (state is MobileMoneyAccountActionDone) {
      context.pop(true);
    } else if (state is MobileMoneyAccountActionFailed) {
      unawaited(
        presentPayoutAccountFailure(
          context,
          state.error,
          pendingPayouts: _accountIn(state.data)?.pendingPayouts ?? 0,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return MultiBlocListener(
      listeners: [
        BlocListener<PayerAccountCubit, PayerAccountState>(
          listenWhen: (previous, current) =>
              previous.countries != current.countries,
          listener: (_, _) => _syncRestriction(),
        ),
        BlocListener<MobileMoneyAccountBloc, MobileMoneyAccountState>(
          listenWhen: (previous, current) => previous.data != current.data,
          listener: (_, _) {
            _configureFromList();
            _syncRestriction();
          },
        ),
        BlocListener<MobileMoneyAccountBloc, MobileMoneyAccountState>(
          listenWhen: (previous, current) =>
              previous != current &&
              (current is MobileMoneyAccountActionDone ||
                  current is MobileMoneyAccountActionFailed),
          listener: _onWriteOutcome,
        ),
      ],
      child: Scaffold(
        backgroundColor: cs.surfaceContainerLowest,
        appBar: AppBar(
          actions: const [DonyFeedbackButton()],
          leading: const DonyAppBarBackButton(),
          title: Text(
            widget.isNumberChange
                ? l.mobileMoneyPayoutAccountChangeNumber
                : l.mobileMoneyPayoutAccountAdd,
            style: tt.headlineMedium,
          ),
          backgroundColor: cs.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: cs.outline),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
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
                    _ListNotice(
                      accountGone: (data) =>
                          widget.isNumberChange && _accountIn(data) == null,
                    ),
                    BlocBuilder<PayerAccountCubit, PayerAccountState>(
                      buildWhen: (previous, current) =>
                          (previous.status == PayerAccountStatus.legacy) !=
                          (current.status == PayerAccountStatus.legacy),
                      builder: (context, payer) {
                        if (payer.status == PayerAccountStatus.legacy) {
                          // Back sans catalogue des versements : rien à
                          // saisir ici.
                          return DonyStatusBanner(
                            type: DonyStatusBannerType.error,
                            message: l.errorGenericTitle,
                            action: TextButton(
                              onPressed: () => _payer.load(),
                              child: Text(l.commonRetry),
                            ),
                          );
                        }
                        return _reveal(
                          context,
                          PayerAccountSection(
                            sectionLabel: l.mobileMoneyPayoutSectionLabel,
                            disallowedOperatorLabel: l.mobileMoneyOperatorAdded,
                            notAllowedMessage:
                                l.mobileMoneyOperatorAlreadyAdded,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DonySpacing.lg,
                  DonySpacing.sm,
                  DonySpacing.lg,
                  DonySpacing.lg,
                ),
                child:
                    BlocBuilder<
                      MobileMoneyAccountBloc,
                      MobileMoneyAccountState
                    >(
                      builder: (context, state) =>
                          BlocBuilder<PayerAccountCubit, PayerAccountState>(
                            builder: (context, payer) {
                              final submitting =
                                  state is MobileMoneyAccountLoaded &&
                                  state.submitting;
                              final ready =
                                  payer.canProceed &&
                                  _writable(state) &&
                                  (!widget.isNumberChange ||
                                      _accountIn(state.data) != null);
                              return DonyButton(
                                key: const Key('payout-add-continue'),
                                label: l.commonContinue,
                                isLoading: submitting,
                                onPressed: ready ? _continue : null,
                              );
                            },
                          ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Apparition du bloc : fondu et léger glissé, 250 ms, coupés quand la
/// réduction du mouvement est active.
Widget _reveal(BuildContext context, Widget child) {
  if (MediaQuery.disableAnimationsOf(context)) return child;
  return child
      .animate()
      .fadeIn(duration: 250.ms, curve: Curves.easeOutCubic)
      .slideY(
        begin: 0.04,
        end: 0,
        duration: 250.ms,
        curve: Curves.easeOutCubic,
      );
}

/// Bandeau au-dessus du formulaire : liste des comptes illisible (avec
/// « Réessayer »), ou compte à changer qui n'existe plus.
class _ListNotice extends StatelessWidget {
  const _ListNotice({required this.accountGone});

  final bool Function(MobileMoneyPayoutAccounts data) accountGone;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BlocBuilder<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      builder: (context, state) {
        final data = state.data;
        final Widget? banner;
        if (data == null && state is MobileMoneyAccountError) {
          banner = DonyStatusBanner(
            type: DonyStatusBannerType.error,
            message: l.mobileMoneyAccountLoadError,
            action: TextButton(
              onPressed: () => context.read<MobileMoneyAccountBloc>().add(
                const MobileMoneyAccountsRequested(),
              ),
              child: Text(l.commonRetry),
            ),
          );
        } else if (data != null && accountGone(data)) {
          banner = DonyStatusBanner(
            type: DonyStatusBannerType.warning,
            message: l.mobileMoneyPayoutAccountGone,
          );
        } else {
          banner = null;
        }
        if (banner == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: DonySpacing.lg),
          child: banner,
        );
      },
    );
  }
}
