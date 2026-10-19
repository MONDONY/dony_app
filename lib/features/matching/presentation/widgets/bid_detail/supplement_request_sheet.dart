import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_request_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/parcel_photo_picker.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Issue de la feuille « Demander un supplément ».
enum SupplementRequestResult {
  /// Le serveur a créé la demande.
  requested,

  /// La demande n'est plus possible pour ce colis (erreur déjà affichée).
  closed,
}

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
Future<void> openSupplementRequestSheet(
  BuildContext context,
  BidModel bid,
) async {
  BidBloc? bidBloc;
  try {
    bidBloc = context.read<BidBloc>();
  } on ProviderNotFoundException {
    bidBloc = null;
  }
  final result = await SupplementRequestSheet.show(context, bid: bid);
  if (result == null || !context.mounted) return;
  bidBloc?.add(BidDetailRequested(bid.id));
  if (result == SupplementRequestResult.requested) {
    DonySnackbar.show(
      context,
      message: context.l10n.supplementRequestSent,
      type: DonySnackbarType.success,
    );
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
  }) {
    final l = context.l10n;
    return DonyBottomSheet.show<SupplementRequestResult>(
      context,
      analyticsName: 'bid/supplement-request',
      title: l.supplementRequestTitle,
      wrapper: (child) => BlocProvider(
        create: (_) => getIt<SupplementRequestCubit>()..load(bid),
        child: child,
      ),
      stickyBottom: BlocBuilder<SupplementRequestCubit, SupplementRequestState>(
        builder: (ctx, state) {
          final gross = state.quote?.grossAmount;
          final currency = state.options?.currency ?? bid.currency;
          return DonyButton(
            label: gross != null && state.amountInRange
                ? ctx.l10n.supplementRequestSubmitAmount(
                    formatSupplementAmount(gross, currency),
                  )
                : ctx.l10n.supplementRequestSubmit,
            isLoading: state.isSubmitting,
            onPressed: state.canSubmit
                ? ctx.read<SupplementRequestCubit>().submit
                : null,
          );
        },
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
        Navigator.of(context).pop(SupplementRequestResult.requested);
      case SupplementRequestStatus.closed:
        ErrorPresenter.show(context, state.error);
        Navigator.of(context).pop(SupplementRequestResult.closed);
      case SupplementRequestStatus.failure:
        ErrorPresenter.show(context, state.error);
      case SupplementRequestStatus.photoFailed:
        DonySnackbar.show(
          context,
          message: context.l10n.parcelRefusalPhotoFailed,
          type: DonySnackbarType.error,
        );
      case SupplementRequestStatus.loading ||
          SupplementRequestStatus.loadFailed ||
          SupplementRequestStatus.editing ||
          SupplementRequestStatus.submitting:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return BlocListener<SupplementRequestCubit, SupplementRequestState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
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
                          enabled: !state.isSubmitting,
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
                  enabled: !state.isSubmitting,
                ),
                const SizedBox(height: DonySpacing.lg),
                DonyRadioGroup<BidSupplementReason>(
                  label: l.supplementRequestReasonLabel,
                  value: state.reason,
                  onChanged: (reason) {
                    if (reason != null) cubit.selectReason(reason);
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
                  enabled: !state.isSubmitting,
                ),
                const SizedBox(height: DonySpacing.lg),
                ParcelPhotoPicker(
                  title: l.supplementRequestPhotoLabel,
                  help: l.supplementRequestPhotoHelp,
                  photoPath: state.photoPath,
                  busy: state.isSubmitting,
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
                  ),
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
  });

  final double net;
  final double commission;
  final double gross;
  final String currency;

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
          row(l.supplementRecapGross, gross, strong: true),
        ],
      ),
    );
  }
}
