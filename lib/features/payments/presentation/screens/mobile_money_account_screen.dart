import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_bloc.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_event.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_payout_account.dart';
import 'package:dony/features/payments/presentation/widgets/payout_account_label.dart';
import 'package:dony/features/payments/presentation/widgets/payout_account_sheets.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Chemin de l'écran d'ajout (et de changement de numéro) d'un compte.
const mobileMoneyPayoutAccountAddPath = '/payments/mobile-money/account/add';

/// Comptes de versement mobile money du voyageur, un par opérateur et par
/// pays. Accessible depuis « Moi » › ARGENT › « Versement mobile money », la
/// publication d'un trajet et celle d'une demande.
///
/// Liste groupée « VOS COMPTES » (pastille, opérateur, numéro masqué, pays,
/// menu ⋯ « Changer de numéro » / « Retirer »), ligne « Ajouter un compte »,
/// encart de la règle de versement et, pour un compte repris de l'ancien
/// contrat, encart des réseaux qu'il acceptait aussi.
///
/// Un compte sur lequel un colis payé attend son versement ne se retire ni
/// ne change de numéro : le menu ouvre alors la feuille « compte bloqué ».
/// Le back refuse aussi (409), ce qui ouvre la même feuille.
///
/// En repli sur l'ancien contrat (back sans `/accounts`), un seul compte :
/// pas d'ajout tant qu'il existe.
class MobileMoneyAccountScreen extends StatefulWidget {
  const MobileMoneyAccountScreen({super.key});

  @override
  State<MobileMoneyAccountScreen> createState() =>
      _MobileMoneyAccountScreenState();
}

class _MobileMoneyAccountScreenState extends State<MobileMoneyAccountScreen> {
  /// Compte du dernier retrait envoyé : un 409 « bloqué » affiche son nombre
  /// de colis en attente. Simple mémoire, jamais affichée : pas de setState.
  MobileMoneyPayoutAccount? _removing;

  MobileMoneyAccountBloc get _bloc => context.read<MobileMoneyAccountBloc>();

  Future<void> _add() async {
    final changed = await context.push<bool>(mobileMoneyPayoutAccountAddPath);
    _reloadIfChanged(changed);
  }

  Future<void> _changeNumber(MobileMoneyPayoutAccount account) async {
    if (account.isLocked) {
      await PayoutAccountLockedSheet.show(
        context,
        pendingPayouts: account.pendingPayouts,
      );
      return;
    }
    final uri = Uri(
      path: mobileMoneyPayoutAccountAddPath,
      queryParameters: {
        'account': account.id,
        'provider': account.provider,
        if (account.country.isNotEmpty) 'country': account.country,
      },
    );
    final changed = await context.push<bool>(uri.toString());
    _reloadIfChanged(changed);
  }

  Future<void> _remove(MobileMoneyPayoutAccount account, String label) async {
    if (account.isLocked) {
      await PayoutAccountLockedSheet.show(
        context,
        pendingPayouts: account.pendingPayouts,
      );
      return;
    }
    final confirmed = await PayoutAccountRemoveSheet.show(
      context,
      account: account,
      label: label,
    );
    if (confirmed != true || !mounted) return;
    _removing = account;
    _bloc.add(MobileMoneyAccountRemoveRequested(account));
  }

  /// Refus d'une écriture. Sur un 409 « bloqué », la liste lue paraissait à
  /// jour mais un colis attend : elle est relue pour que la ligne passe
  /// bloquée avec le vrai nombre de colis, puis la feuille s'ouvre.
  void _onWriteFailed(BuildContext context, MobileMoneyAccountState state) {
    final error = (state as MobileMoneyAccountActionFailed).error;
    if (isPayoutAccountLocked(error)) {
      _bloc.add(const MobileMoneyAccountsRequested());
    }
    presentPayoutAccountFailure(
      context,
      error,
      pendingPayouts: _removing?.pendingPayouts ?? 0,
    );
  }

  /// Relit la liste au retour d'un écran qui l'a changée, sauf pendant une
  /// écriture : sa propre relecture suit.
  void _reloadIfChanged(bool? changed) {
    if (changed != true || !mounted) return;
    final state = _bloc.state;
    if (state is MobileMoneyAccountLoaded && state.submitting) return;
    _bloc.add(const MobileMoneyAccountsRequested());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        actions: const [DonyFeedbackButton()],
        leading: const DonyAppBarBackButton(),
        title: Text(l.mobileMoneyAccountTitle, style: tt.headlineMedium),
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
        child: BlocConsumer<MobileMoneyAccountBloc, MobileMoneyAccountState>(
          listenWhen: (previous, current) =>
              previous != current && current is MobileMoneyAccountActionFailed,
          listener: _onWriteFailed,
          builder: (context, state) {
            final data = state.data;
            if (data != null) {
              return _AccountsBody(
                data: data,
                submitting:
                    state is MobileMoneyAccountLoaded && state.submitting,
                onAdd: _add,
                onChangeNumber: _changeNumber,
                onRemove: _remove,
              );
            }
            if (state is MobileMoneyAccountError) {
              return DonyEmptyState(
                type: DonyEmptyStateType.error,
                title: l.mobileMoneyAccountLoadError,
                actionLabel: l.commonRetry,
                onAction: () => _bloc.add(const MobileMoneyAccountsRequested()),
              );
            }
            return Center(child: CircularProgressIndicator(color: cs.primary));
          },
        ),
      ),
    );
  }
}

/// Apparition d'une ligne : fondu et léger glissé, 250 ms, décalés de 60 ms
/// par rang, coupés quand la réduction du mouvement est active. La clé de
/// l'appelant garde l'entrée des lignes déjà affichées.
Widget _enter(BuildContext context, Widget child, int index) {
  if (MediaQuery.disableAnimationsOf(context)) return child;
  return child
      .animate(delay: (60 * index).ms)
      .fadeIn(duration: 250.ms, curve: Curves.easeOutCubic)
      .slideY(
        begin: 0.04,
        end: 0,
        duration: 250.ms,
        curve: Curves.easeOutCubic,
      );
}

class _AccountsBody extends StatelessWidget {
  const _AccountsBody({
    required this.data,
    required this.submitting,
    required this.onAdd,
    required this.onChangeNumber,
    required this.onRemove,
  });

  final MobileMoneyPayoutAccounts data;
  final bool submitting;
  final VoidCallback onAdd;
  final ValueChanged<MobileMoneyPayoutAccount> onChangeNumber;
  final void Function(MobileMoneyPayoutAccount account, String label) onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accounts = data.accounts;
    // Ancien contrat : un seul compte possible tant qu'il existe.
    final canAdd = !(data.legacy && accounts.isNotEmpty);
    final labels = [for (final a in accounts) payoutAccountLabel(a, accounts)];
    final suggested = data.suggested.map((s) => s.label).toSet().toList();

    return Column(
      children: [
        // Hauteur fixe : la barre qui apparaît pendant une écriture ne
        // décale pas la liste.
        SizedBox(
          height: 2,
          child: submitting
              ? LinearProgressIndicator(minHeight: 2, color: cs.primary)
              : null,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              DonySpacing.xxl,
            ),
            children: [
              if (accounts.isEmpty)
                DonyCard(
                  padding: const EdgeInsets.all(DonySpacing.base),
                  child: Text(
                    l.mobileMoneyPayoutAccountsEmpty,
                    style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.only(
                    left: DonySpacing.xs,
                    bottom: DonySpacing.sm,
                  ),
                  child: Text(
                    l.mobileMoneyPayoutAccountsSectionLabel,
                    style: tt.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                DonyCard(
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(DonyRadius.card),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < accounts.length; i++) ...[
                          if (i > 0) const _RowDivider(),
                          KeyedSubtree(
                            key: ValueKey('payout-account-${accounts[i].id}'),
                            child: _enter(
                              context,
                              _AccountRow(
                                account: accounts[i],
                                label: labels[i],
                                enabled: !submitting,
                                onChangeNumber: () =>
                                    onChangeNumber(accounts[i]),
                                onRemove: () =>
                                    onRemove(accounts[i], labels[i]),
                              ),
                              i,
                            ),
                          ),
                        ],
                        if (canAdd) ...[
                          const _RowDivider(),
                          _AddRow(enabled: !submitting, onTap: onAdd),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: DonySpacing.base),
                DonyStatusBanner(
                  type: DonyStatusBannerType.info,
                  message: l.mobileMoneyPayoutAccountsRule(
                    joinList(l, labels.toSet().toList()),
                  ),
                ),
              ],
              if (suggested.isNotEmpty) ...[
                const SizedBox(height: DonySpacing.md),
                DonyStatusBanner(
                  type: DonyStatusBannerType.warning,
                  message: l.mobileMoneyPayoutAccountsSuggested(
                    joinList(l, suggested),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (accounts.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.sm,
              DonySpacing.lg,
              DonySpacing.lg,
            ),
            child: DonyButton(
              key: const Key('payout-account-add-button'),
              label: l.mobileMoneyPayoutAccountAdd,
              onPressed: submitting ? null : onAdd,
            ),
          ),
      ],
    );
  }
}

/// Séparateur aligné sur le texte des lignes (après la pastille).
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => const Divider(
    height: 1,
    indent: DonySpacing.base + _kMarkSize + DonySpacing.md,
  );
}

const double _kMarkSize = 40;

enum _AccountAction { changeNumber, remove }

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.label,
    required this.enabled,
    required this.onChangeNumber,
    required this.onRemove,
  });

  final MobileMoneyPayoutAccount account;
  final String label;
  final bool enabled;
  final VoidCallback onChangeNumber;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final country = account.country.isEmpty
        ? null
        : countryName(l, account.country.toUpperCase());
    final details = country == null
        ? account.msisdnMasked
        : '${account.msisdnMasked} · $country';

    return Padding(
      padding: const EdgeInsets.only(
        left: DonySpacing.base,
        top: DonySpacing.md,
        bottom: DonySpacing.md,
        right: DonySpacing.xs,
      ),
      child: Row(
        children: [
          // La pastille répète l'opérateur : le libellé texte suffit au
          // lecteur d'écran.
          ExcludeSemantics(child: DonyBrandMark(brand: account.brand)),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.xxs),
                  Text(
                    details,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<_AccountAction>(
            key: Key('payout-account-menu-${account.id}'),
            enabled: enabled,
            tooltip: l.mobileMoneyPayoutAccountActions(label),
            icon: DonyIcon('ellipsis', color: cs.onSurfaceVariant, size: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            onSelected: (action) => switch (action) {
              _AccountAction.changeNumber => onChangeNumber(),
              _AccountAction.remove => onRemove(),
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _AccountAction.changeNumber,
                child: Row(
                  children: [
                    const DonyIcon('square-pen', size: 18),
                    const SizedBox(width: DonySpacing.sm),
                    Flexible(
                      child: Text(l.mobileMoneyPayoutAccountChangeNumber),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _AccountAction.remove,
                child: Row(
                  children: [
                    DonyIcon('trash-2', size: 18, color: cs.error),
                    const SizedBox(width: DonySpacing.sm),
                    Flexible(
                      child: Text(
                        l.mobileMoneyPayoutAccountRemove,
                        style: TextStyle(color: cs.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      child: InkWell(
        key: const Key('payout-account-add-row'),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base,
            vertical: DonySpacing.md,
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: _kMarkSize,
                  height: _kMarkSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(_kMarkSize / 4),
                  ),
                  child: DonyIcon('plus', size: 20, color: cs.primary),
                ),
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Text(
                  l.mobileMoneyPayoutAccountAdd,
                  style: tt.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
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
