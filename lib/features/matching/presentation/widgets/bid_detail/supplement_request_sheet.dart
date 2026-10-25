import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_request_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/models/supplement_commission_unfunded.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/parcel_photo_picker.dart';
import 'package:dony/features/payments/presentation/payment_auth.dart';
import 'package:dony/features/payments/wallet/presentation/commission_funding_options.dart';
import 'package:dony/features/payments/wallet/presentation/commission_shortfall_text.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Issue de la feuille « Demander un supplément ».
enum SupplementRequestResult {
  /// Le serveur a créé la demande.
  requested,

  /// Espèces : demande créée, commission encore en traitement chez la
  /// banque (le webhook tranchera).
  commissionProcessing,

  /// La demande n'est plus possible pour ce colis (erreur déjà affichée).
  closed,

  /// Espèces, solde insuffisant : le voyageur veut recharger son solde.
  topUp,

  /// Espèces : le voyageur veut enregistrer une carte commission.
  addCard,
}

/// Vérification locale avant un appel qui prélève la commission
/// (`requirePaymentAuth` par défaut).
typedef SupplementRequestAuthorizer = Future<bool> Function(BuildContext);

/// `requirePaymentAuth` avec les services de l'app.
Future<bool> defaultSupplementAuthorize(BuildContext context) =>
    requirePaymentAuth(
      context,
      authService: getIt<LocalAuthService>(),
      userPrefs: getIt<HiveService>().userPrefs,
    );

/// Montant formaté dans la devise du colis, sans décimales inutiles.
String formatSupplementAmount(double amount, String currency) =>
    CurrencyFormatter.format(
      amount,
      SupportedCurrency.fromCodeOrDefault(currency),
      compact: true,
    );

/// Ouvre la feuille « Demander un supplément » puis, si la demande aboutit
/// ou n'est plus possible, recharge le détail d'envoi ([BidBloc] de l'écran,
/// s'il est là). Une demande envoyée est annoncée d'une snackbar.
///
/// Espèces : « Recharger » ou « Ajouter une carte » referment la feuille
/// (la navigation part de l'écran, pas de la feuille) ; au retour d'une
/// recharge réussie ou de l'écran de la carte, la feuille se rouvre.
Future<void> openSupplementRequestSheet(
  BuildContext context,
  BidModel bid, {
  SupplementRequestAuthorizer? authorize,
}) async {
  BidBloc? bidBloc;
  try {
    bidBloc = context.read<BidBloc>();
  } on ProviderNotFoundException {
    bidBloc = null;
  }
  final result = await SupplementRequestSheet.show(
    context,
    bid: bid,
    authorize: authorize,
  );
  if (!context.mounted) return;
  if (result == null) {
    // Feuille fermée sans issue (croix, barrière, retour) : une demande a pu
    // être créée et sa commission débitée juste avant ; la fiche le montre.
    bidBloc?.add(BidDetailRequested(bid.id));
    return;
  }
  switch (result) {
    case SupplementRequestResult.topUp:
      // /topup/method compose la sélection attendue par /topup/amount.
      final recharged = await context.push<bool>(
        '/payments/wallet/topup/method',
      );
      if ((recharged ?? false) && context.mounted) {
        await openSupplementRequestSheet(context, bid, authorize: authorize);
      }
    case SupplementRequestResult.addCard:
      await context.push<void>('/payments/commission-method');
      if (context.mounted) {
        await openSupplementRequestSheet(context, bid, authorize: authorize);
      }
    case SupplementRequestResult.requested:
      bidBloc?.add(BidDetailRequested(bid.id));
      DonySnackbar.show(
        context,
        message: context.l10n.supplementRequestSent,
        type: DonySnackbarType.success,
      );
    case SupplementRequestResult.commissionProcessing:
      bidBloc?.add(BidDetailRequested(bid.id));
      DonySnackbar.show(
        context,
        message: context.l10n.supplementCommissionProcessing,
      );
    case SupplementRequestResult.closed:
      bidBloc?.add(BidDetailRequested(bid.id));
  }
}

/// Contenu de la feuille : suggestions, montant, motif, précisions, photo
/// obligatoire et récapitulatif (net, commission, total expéditeur). Le
/// formulaire vit dans [SupplementRequestCubit] ; le bouton du
/// `stickyBottom` lit sa validité et soumet. Seuls les contrôleurs des champs
/// texte vivent ici.
class SupplementRequestSheet extends StatefulWidget {
  const SupplementRequestSheet({super.key, required this.bid});

  final BidModel bid;

  static Future<SupplementRequestResult?> show(
    BuildContext context, {
    required BidModel bid,
    SupplementRequestAuthorizer? authorize,
  }) {
    final l = context.l10n;
    return DonyBottomSheet.show<SupplementRequestResult>(
      context,
      analyticsName: 'bid/supplement-request',
      title: l.supplementRequestTitle,
      // Le glissement vers le bas ferme sans consulter `PopScope` : il
      // laisserait partir la feuille pendant l'envoi (demande créée, commission
      // débitée, 3DS jamais présentée). La croix, la barrière et le retour
      // passent par `maybePop` et respectent le garde de l'envoi.
      enableDrag: false,
      wrapper: (child) => BlocProvider(
        create: (_) => getIt<SupplementRequestCubit>()..load(bid),
        child: child,
      ),
      stickyBottom: SupplementRequestActions(
        bid: bid,
        authorize: authorize ?? defaultSupplementAuthorize,
      ),
      child: SupplementRequestSheet(bid: bid),
    );
  }

  @override
  State<SupplementRequestSheet> createState() => _SupplementRequestSheetState();
}

class _SupplementRequestSheetState extends State<SupplementRequestSheet> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _detailsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(_onAmountChanged);
    _detailsCtrl.addListener(_onDetailsChanged);
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_onAmountChanged);
    _detailsCtrl.removeListener(_onDetailsChanged);
    _amountCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  void _onAmountChanged() =>
      context.read<SupplementRequestCubit>().amountChanged(_amountCtrl.text);

  void _onDetailsChanged() => context
      .read<SupplementRequestCubit>()
      .reasonTextChanged(_detailsCtrl.text);

  /// Puce choisie : le champ affiche son montant, sans symbole.
  void _pickSuggestion(SupplementSuggestion suggestion, String currency) {
    context.read<SupplementRequestCubit>().selectSuggestion(suggestion);
    final text = CurrencyFormatter.formatAmountOnly(
      suggestion.unitNet,
      SupportedCurrency.fromCodeOrDefault(currency),
    );
    _amountCtrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _onStateChanged(BuildContext context, SupplementRequestState state) {
    switch (state.status) {
      case SupplementRequestStatus.success:
        Navigator.of(context).pop(
          state.created?.status == BidSupplementStatus.commissionPending
              ? SupplementRequestResult.commissionProcessing
              : SupplementRequestResult.requested,
        );
      case SupplementRequestStatus.closed:
        ErrorPresenter.show(context, state.error);
        Navigator.of(context).pop(SupplementRequestResult.closed);
      case SupplementRequestStatus.failure:
        ErrorPresenter.show(context, state.error);
      case SupplementRequestStatus.commissionRetry:
        // 3DS abandonnée : pas d'erreur serveur, un message neutre. Débit
        // sans réponse : l'erreur du catalogue.
        if (state.error == null) {
          DonySnackbar.show(
            context,
            message: context.l10n.supplementCommissionAuthInterrupted,
            type: DonySnackbarType.error,
          );
        } else {
          ErrorPresenter.show(context, state.error);
        }
      case SupplementRequestStatus.photoFailed:
        DonySnackbar.show(
          context,
          message: context.l10n.parcelRefusalPhotoFailed,
          type: DonySnackbarType.error,
        );
      // Solde insuffisant, carte manquante : expliqués dans la feuille.
      case SupplementRequestStatus.loading ||
          SupplementRequestStatus.loadFailed ||
          SupplementRequestStatus.editing ||
          SupplementRequestStatus.authorizing ||
          SupplementRequestStatus.submitting ||
          SupplementRequestStatus.unfunded ||
          SupplementRequestStatus.cardMissing:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pas de fermeture (croix, barrière, retour) pendant la vérification ou
    // l'envoi : la demande et le débit de la commission partiraient sans
    // suite (3DS jamais présentée, fiche jamais relue).
    return BlocBuilder<SupplementRequestCubit, SupplementRequestState>(
      buildWhen: (prev, curr) => prev.isBusy != curr.isBusy,
      builder: (context, guard) =>
          PopScope(canPop: !guard.isBusy, child: _content(context)),
    );
  }

  Widget _content(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return BlocListener<SupplementRequestCubit, SupplementRequestState>(
      // Une vérification locale refusée rend l'état d'avant : son erreur a
      // déjà été montrée, rien à rejouer.
      listenWhen: (prev, curr) =>
          prev.status != curr.status &&
          prev.status != SupplementRequestStatus.authorizing,
      listener: _onStateChanged,
      child: BlocBuilder<SupplementRequestCubit, SupplementRequestState>(
        builder: (context, state) {
          final cubit = context.read<SupplementRequestCubit>();
          final options = state.options;
          if (state.status == SupplementRequestStatus.loading) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: DonySpacing.xxl),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (options == null) {
            return _LoadFailed(onRetry: () => cubit.load(widget.bid));
          }
          final currency = options.currency;
          final min = formatSupplementAmount(options.minNet, currency);
          final max = formatSupplementAmount(options.maxNet, currency);
          final otherReason = state.reason == BidSupplementReason.other;
          return Padding(
            padding: const EdgeInsets.only(bottom: DonySpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.supplementRequestIntro,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                if (options.suggestions.isNotEmpty) ...[
                  const SizedBox(height: DonySpacing.lg),
                  Text(
                    l.supplementRequestSuggestionsLabel,
                    style: tt.titleSmall?.copyWith(color: cs.onSurface),
                  ),
                  const SizedBox(height: DonySpacing.sm),
                  Wrap(
                    spacing: DonySpacing.sm,
                    runSpacing: DonySpacing.sm,
                    children: [
                      for (final s in options.suggestions)
                        DonyChip(
                          label: _suggestionLabel(l, s, currency),
                          selected: identical(state.suggestion, s),
                          enabled: !state.isLocked,
                          onTap: () => _pickSuggestion(s, currency),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: DonySpacing.lg),
                DonyTextField(
                  controller: _amountCtrl,
                  label: l.supplementRequestAmountLabel(
                    SupportedCurrency.symbolOf(currency),
                  ),
                  hint: l.supplementRequestAmountHint(min, max),
                  requiredLabel: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]')),
                  ],
                  errorText: state.amountOutOfRange
                      ? l.supplementRequestAmountOutOfRange(min, max)
                      : null,
                  enabled: !state.isLocked,
                ),
                const SizedBox(height: DonySpacing.lg),
                DonyRadioGroup<BidSupplementReason>(
                  label: l.supplementRequestReasonLabel,
                  value: state.reason,
                  onChanged: (reason) {
                    if (reason != null && !state.isLocked) {
                      cubit.selectReason(reason);
                    }
                  },
                  options: [
                    DonyRadioOption(
                      value: BidSupplementReason.gridItem,
                      label: l.supplementReasonGridItem,
                      subtitle: l.supplementReasonGridItemHint,
                    ),
                    DonyRadioOption(
                      value: BidSupplementReason.extraWeight,
                      label: l.supplementReasonExtraWeight,
                    ),
                    DonyRadioOption(
                      value: BidSupplementReason.other,
                      label: l.supplementReasonOther,
                    ),
                  ],
                ),
                const SizedBox(height: DonySpacing.base),
                DonyTextField(
                  controller: _detailsCtrl,
                  label: l.supplementRequestDetailsLabel,
                  hint: otherReason
                      ? l.supplementRequestDetailsRequiredHint
                      : l.supplementRequestDetailsHint,
                  requiredLabel: otherReason,
                  maxLines: 3,
                  minLines: 2,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(
                      kSupplementReasonTextMaxLength,
                    ),
                  ],
                  enabled: !state.isLocked,
                ),
                const SizedBox(height: DonySpacing.lg),
                ParcelPhotoPicker(
                  title: l.supplementRequestPhotoLabel,
                  help: l.supplementRequestPhotoHelp,
                  photoPath: state.photoPath,
                  busy: state.isLocked,
                  onTake: cubit.takePhoto,
                  onRemove: cubit.removePhoto,
                ),
                if (state.quote case final quote? when state.amountInRange) ...[
                  const SizedBox(height: DonySpacing.lg),
                  SupplementAmountsRecap(
                    net: quote.netAmount,
                    commission: quote.commissionAmount,
                    gross: quote.grossAmount,
                    currency: quote.currency,
                    cash: state.isCash,
                  ),
                ],
                if (state.isCash) ...[
                  const SizedBox(height: DonySpacing.lg),
                  SupplementCommissionSourcePicker(state: state),
                ],
                const SizedBox(height: DonySpacing.lg),
                DonyStatusBanner(
                  type: DonyStatusBannerType.info,
                  message: l.supplementRequestNotice,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _suggestionLabel(
    AppLocalizations l,
    SupplementSuggestion s,
    String currency,
  ) {
    final amount = formatSupplementAmount(s.unitNet, currency);
    final label = s.label?.trim();
    return s.isGridItem && label != null && label.isNotEmpty
        ? l.supplementRequestSuggestionItem(label, amount)
        : l.supplementRequestSuggestionKg(amount);
  }
}

/// Options introuvables : message et « Réessayer ».
class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.lg),
      child: DonyStatusBanner(
        type: DonyStatusBannerType.error,
        message: l.supplementRequestLoadFailed,
        action: TextButton(onPressed: onRetry, child: Text(l.commonRetry)),
      ),
    );
  }
}

/// Récapitulatif d'un supplément vu par le voyageur : son net, la commission
/// Yadony et le total payé par l'expéditeur. Jamais montré à l'expéditeur.
class SupplementAmountsRecap extends StatelessWidget {
  const SupplementAmountsRecap({
    super.key,
    required this.net,
    required this.commission,
    required this.gross,
    required this.currency,
    this.cash = false,
  });

  final double net;
  final double commission;
  final double gross;
  final String currency;

  /// Colis payé en espèces : le total est remis en main propre.
  final bool cash;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    Widget row(String label, double amount, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: (strong ? tt.titleSmall : tt.bodyMedium)?.copyWith(
                color: strong ? cs.onSurface : cs.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            formatSupplementAmount(amount, currency),
            style: (strong ? tt.titleSmall : tt.bodyMedium)?.copyWith(
              color: cs.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.lg),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          row(l.supplementRecapNet, net),
          row(l.supplementRecapCommission, commission),
          Divider(height: DonySpacing.md, color: cs.outline),
          row(
            cash ? l.supplementRecapGrossCash : l.supplementRecapGross,
            gross,
            strong: true,
          ),
        ],
      ),
    );
  }
}

/// Boutons du `stickyBottom` de la feuille de demande. Espèces : la
/// vérification locale (`requirePaymentAuth`) passe avant l'envoi et avant
/// « Réessayer le paiement », qui prélèvent la commission. Solde
/// insuffisant : « Recharger » ; carte manquante : « Ajouter une carte »
/// (la feuille se referme, l'écran navigue puis la rouvre).
class SupplementRequestActions extends StatelessWidget {
  const SupplementRequestActions({
    super.key,
    required this.bid,
    required this.authorize,
  });

  final BidModel bid;
  final SupplementRequestAuthorizer authorize;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupplementRequestCubit, SupplementRequestState>(
      builder: (context, state) {
        final l = context.l10n;
        final cubit = context.read<SupplementRequestCubit>();
        if (state.awaitingCommission) {
          return DonyButton(
            key: const Key('supplement-commission-retry-btn'),
            label: l.supplementCommissionRetry,
            iconAsset: 'refresh-cw',
            isLoading: state.isBusy,
            onPressed: state.isBusy
                ? null
                : () => _authorizeThen(context, cubit, cubit.retryCommission),
          );
        }
        final gross = state.quote?.grossAmount;
        final currency = state.options?.currency ?? bid.currency;
        final unfunded = state.status == SupplementRequestStatus.unfunded
            ? state.unfunded
            : null;
        final offerAddCard =
            state.status == SupplementRequestStatus.cardMissing ||
            (unfunded != null && !unfunded.hasCard);
        final submit = DonyButton(
          key: const Key('supplement-submit-btn'),
          label: gross != null && state.amountInRange
              ? l.supplementRequestSubmitAmount(
                  formatSupplementAmount(gross, currency),
                )
              : l.supplementRequestSubmit,
          isLoading: state.isBusy,
          onPressed: state.canSubmit
              ? (state.isCash
                    ? () => _authorizeThen(context, cubit, cubit.submit)
                    : cubit.submit)
              : null,
        );
        if (unfunded == null && !offerAddCard) return submit;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            submit,
            if (unfunded != null) ...[
              const SizedBox(height: DonySpacing.sm),
              DonyButton(
                key: const Key('supplement-topup-btn'),
                label: commissionTopupLabel(
                  l,
                  tripCurrency: commissionTripCurrency(
                    bidCurrency: unfunded.bidCurrency,
                    breakdown: unfunded.breakdown,
                    currency: unfunded.currency,
                  ),
                  fallback: l.bidDetailTopupWallet,
                ),
                variant: DonyButtonVariant.secondary,
                iconAsset: 'wallet',
                onPressed: state.isBusy
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pop(SupplementRequestResult.topUp),
              ),
            ],
            if (offerAddCard) ...[
              const SizedBox(height: DonySpacing.sm),
              DonyButton(
                key: const Key('supplement-add-card-btn'),
                label: l.bidDetailAddCard,
                variant: DonyButtonVariant.secondary,
                iconAsset: 'credit-card',
                onPressed: state.isBusy
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pop(SupplementRequestResult.addCard),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _authorizeThen(
    BuildContext context,
    SupplementRequestCubit cubit,
    Future<void> Function() action,
  ) async {
    // Bouton désactivé pendant l'invite : un double tap n'en ouvre pas deux.
    if (!cubit.beginAuthorization()) return;
    final authenticated = await authorize(context);
    if (!context.mounted) {
      cubit.authorizationDenied();
      return;
    }
    if (!authenticated) {
      cubit.authorizationDenied();
      DonySnackbar.show(
        context,
        message: context.l10n.paymentNotConfirmedSnackbar,
        type: DonySnackbarType.error,
      );
      return;
    }
    await action();
  }
}

/// Espèces : d'où prélever la commission du supplément (solde ou carte
/// commission), avec, après un refus, ce qui manque et les autres
/// portefeuilles capables de couvrir le reste. Les boutons d'action restent
/// dans le `stickyBottom` ([SupplementRequestActions]).
class SupplementCommissionSourcePicker extends StatelessWidget {
  const SupplementCommissionSourcePicker({super.key, required this.state});

  final SupplementRequestState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cubit = context.read<SupplementRequestCubit>();
    final unfunded = state.unfunded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.supplementCommissionSourceTitle,
          style: tt.titleSmall?.copyWith(color: cs.onSurface),
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          l.supplementCommissionSourceHelp,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        if (state.awaitingCommission) ...[
          const SizedBox(height: DonySpacing.md),
          DonyStatusBanner(
            type: DonyStatusBannerType.warning,
            message: l.supplementCommissionRetryNotice,
          ),
        ] else ...[
          if (state.status == SupplementRequestStatus.unfunded &&
              unfunded != null) ...[
            const SizedBox(height: DonySpacing.md),
            DonyStatusBanner(
              type: DonyStatusBannerType.warning,
              message: CommissionSourceRadios.unfundedMessage(l, unfunded),
            ),
          ],
          if (state.status == SupplementRequestStatus.cardMissing) ...[
            const SizedBox(height: DonySpacing.md),
            DonyStatusBanner(
              type: DonyStatusBannerType.warning,
              message: l.supplementCommissionCardMissing,
            ),
          ],
          const SizedBox(height: DonySpacing.sm),
          CommissionSourceRadios(
            source: state.commissionSource,
            fundingCurrency: state.fundingCurrency,
            unfunded: unfunded,
            locked: state.isLocked,
            onSelected: cubit.selectCommissionSource,
          ),
        ],
      ],
    );
  }
}

/// Choix de la source de la commission (solde, autre portefeuille converti
/// au taux du jour, carte), partagé par le supplément et la modification de
/// colis. Sans état : l'appelant porte la sélection.
class CommissionSourceRadios extends StatelessWidget {
  const CommissionSourceRadios({
    super.key,
    required this.source,
    required this.fundingCurrency,
    required this.unfunded,
    required this.locked,
    required this.onSelected,
  });

  final SupplementCommissionSource source;
  final String? fundingCurrency;

  /// Dernier refus « solde insuffisant » : ses `alternatives` sont proposées.
  final SupplementCommissionUnfunded? unfunded;
  final bool locked;
  final void Function(
    SupplementCommissionSource source, {
    String? fundingCurrency,
  })
  onSelected;

  static const _walletKey = 'wallet';
  static const _cardKey = 'card';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final selected = switch (source) {
      SupplementCommissionSource.card => _cardKey,
      SupplementCommissionSource.wallet => fundingCurrency ?? _walletKey,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DonyRadioGroup<String>(
          value: selected,
          onChanged: (key) {
            if (key == null || locked) return;
            if (key == _cardKey) {
              onSelected(SupplementCommissionSource.card);
            } else {
              onSelected(
                SupplementCommissionSource.wallet,
                fundingCurrency: key == _walletKey ? null : key,
              );
            }
          },
          options: [
            DonyRadioOption(
              value: _walletKey,
              label: l.supplementCommissionSourceWallet,
              subtitle: l.supplementCommissionSourceWalletHint,
            ),
            for (final alternative in unfunded?.alternatives ?? const [])
              DonyRadioOption(
                value: alternative.currency,
                label: l.supplementCommissionSourceWalletCurrency(
                  alternative.currency,
                ),
                subtitle: l.walletShortfallAlternativeApprox(
                  formatPriceIn(
                    alternative.requiredAmount,
                    alternative.currency,
                  ),
                ),
              ),
            DonyRadioOption(
              value: _cardKey,
              label: l.supplementCommissionSourceCard,
              subtitle: l.supplementCommissionSourceCardHint,
            ),
          ],
        ),
        if (unfunded?.alternatives.isNotEmpty ?? false)
          Text(
            l.walletShortfallRateDisclaimer,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
      ],
    );
  }

  /// Texte du bandeau « solde insuffisant » (ce qui manque, puis la marche à
  /// suivre).
  static String unfundedMessage(
    AppLocalizations l,
    SupplementCommissionUnfunded unfunded,
  ) => [
    ...commissionShortfallLines(
      l,
      breakdown: unfunded.breakdown,
      requiredCommission: unfunded.requiredCommission,
      availableBalance: unfunded.availableBalance,
      currency: unfunded.currency,
    ),
    l.supplementCommissionUnfundedHint,
  ].join('\n');
}
