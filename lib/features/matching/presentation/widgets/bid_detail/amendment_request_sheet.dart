import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_properties.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_request_cubit.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_pay_button.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_request_sheet.dart';
import 'package:dony/features/payments/bloc/payment_sheet_bloc.dart';
import 'package:dony/features/payments/presentation/widgets/dony_payment_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Pas d'un appui sur « + » / « − » du sélecteur de kilos.
const double _kgStep = 0.5;

/// Feuille « Modifier mon colis » : l'expéditeur d'un colis accepté ajoute des
/// kilos ou des articles de la grille du voyageur et choisit le moyen de payer
/// la différence. Le total vient du serveur ; l'expéditeur ne voit jamais le
/// net ni la commission.
///
/// Le formulaire vit dans [AmendmentRequestCubit] ; le bouton du
/// `stickyBottom` ([_AmendmentActions]) lit sa validité, soumet et pilote la
/// feuille de paiement de la carte.
class AmendmentRequestSheet extends StatelessWidget {
  const AmendmentRequestSheet({super.key, required this.bid});

  final BidModel bid;

  /// Rend `true` quand le colis doit être relu (demande envoyée, ou modification
  /// devenue impossible), `false` si la feuille est fermée sans effet.
  static Future<bool> show(
    BuildContext context, {
    required BidModel bid,
    SupplementPaymentAuthorizer? authorize,
    SupplementPaymentSheetPresenter? presentSheet,
  }) async {
    final l = context.l10n;
    final result = await DonyBottomSheet.show<bool>(
      context,
      analyticsName: 'bid/amendment-request',
      title: l.amendmentSheetTitle,
      // Le glissement vers le bas ferme sans consulter `PopScope` : il
      // laisserait partir la feuille pendant l'envoi. La croix, la barrière
      // et le retour respectent le garde.
      enableDrag: false,
      wrapper: (child) => BlocProvider(
        create: (_) => getIt<AmendmentRequestCubit>()..load(bid),
        child: child,
      ),
      stickyBottom: _AmendmentActions(
        bid: bid,
        authorize: authorize ?? defaultSupplementAuthorize,
        presentSheet: presentSheet ?? DonyPaymentSheet.show,
      ),
      child: AmendmentRequestSheet(bid: bid),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // Pas de fermeture pendant la vérification, la création ou la
    // confirmation : la demande partirait sans suite.
    return BlocBuilder<AmendmentRequestCubit, AmendmentRequestState>(
      buildWhen: (prev, curr) => prev.isBusy != curr.isBusy,
      builder: (context, guard) => PopScope(
        canPop: !guard.isBusy,
        child: _Content(bid: bid),
      ),
    );
  }
}

String _travelerName(BuildContext context, BidModel bid) =>
    bid.travelerName ?? context.l10n.bidDetailSenderTravelerFallback;

String _kgText(BuildContext context, double kg) =>
    NumberFormat('0.#', Localizations.localeOf(context).toString()).format(kg);

class _Content extends StatelessWidget {
  const _Content({required this.bid});

  final BidModel bid;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AmendmentRequestCubit, AmendmentRequestState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.options != curr.options ||
          prev.addedKg != curr.addedKg ||
          prev.items != curr.items ||
          prev.method != curr.method,
      builder: (context, state) {
        final options = state.options;
        if (state.status == AmendmentRequestStatus.loading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: DonySpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (options == null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: DonySpacing.base),
            child: Text(
              context.l10n.amendmentSheetLoadFailed,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        final readOnly = state.isBusy;
        return Padding(
          padding: const EdgeInsets.only(bottom: DonySpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (options.pricePerKgDisplay != null) ...[
                _KilosSection(
                  bid: bid,
                  options: options,
                  kg: state.addedKg,
                  readOnly: readOnly,
                ),
                const SizedBox(height: DonySpacing.lg),
              ],
              if (options.gridItems.isNotEmpty) ...[
                _ItemsSection(
                  bid: bid,
                  options: options,
                  quantities: state.items,
                  readOnly: readOnly,
                ),
                const SizedBox(height: DonySpacing.lg),
              ],
              _MethodSection(
                bid: bid,
                options: options,
                selected: state.method,
                readOnly: readOnly,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.sm),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: cs.onSurfaceVariant,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Bouton carré « − » / « + » de 44 pt.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.iconAsset,
    required this.tooltip,
    required this.onPressed,
  });

  final String iconAsset;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.md),
            side: BorderSide(color: cs.outline),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(DonyRadius.md),
            onTap: onPressed,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: DonyIcon(iconAsset, size: 20, color: cs.primary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KilosSection extends StatelessWidget {
  const _KilosSection({
    required this.bid,
    required this.options,
    required this.kg,
    required this.readOnly,
  });

  final BidModel bid;
  final AmendmentOptions options;
  final double kg;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<AmendmentRequestCubit>();
    final price = formatSupplementAmount(
      options.pricePerKgDisplay ?? 0,
      options.currency,
    );
    final free = options.availableKg;
    final atMax = free != null && kg + _kgStep > free;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(
          free == null
              ? l.amendmentSheetKgLabelOpen(price)
              : l.amendmentSheetKgLabel(price, _kgText(context, free)),
        ),
        Row(
          children: [
            _StepButton(
              iconAsset: 'minus',
              tooltip: l.amendmentQuantityLess,
              onPressed: readOnly || kg <= 0
                  ? null
                  : () => cubit.setKg(kg - _kgStep),
            ),
            Expanded(
              child: Text(
                l.amendmentSheetKgValue(_kgText(context, kg)),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            _StepButton(
              iconAsset: 'plus',
              tooltip: l.amendmentQuantityMore,
              onPressed: readOnly || atMax
                  ? null
                  : () => cubit.setKg(kg + _kgStep),
            ),
          ],
        ),
      ],
    );
  }
}

class _ItemsSection extends StatelessWidget {
  const _ItemsSection({
    required this.bid,
    required this.options,
    required this.quantities,
    required this.readOnly,
  });

  final BidModel bid;
  final AmendmentOptions options;
  final Map<String, int> quantities;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<AmendmentRequestCubit>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(
          l.amendmentSheetItemsLabel(_travelerName(context, bid).toUpperCase()),
        ),
        for (final item in options.gridItems)
          Builder(
            builder: (context) {
              final qty = quantities[item.id] ?? 0;
              final on = qty > 0;
              return Row(
                children: [
                  Expanded(
                    child: Semantics(
                      checked: on,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(DonyRadius.md),
                        onTap: readOnly
                            ? null
                            : () => cubit.setItemQuantity(item.id, on ? 0 : 1),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: on ? cs.primary : null,
                                  border: Border.all(
                                    color: on ? cs.primary : cs.outline,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: on
                                    ? const Center(
                                        child: DonyIcon(
                                          'check',
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: DonySpacing.md),
                              Expanded(
                                child: Text(item.label, style: tt.bodyMedium),
                              ),
                              Text(
                                formatSupplementAmount(
                                  item.unitPriceDisplay,
                                  options.currency,
                                ),
                                style: tt.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (on) ...[
                    const SizedBox(width: DonySpacing.sm),
                    _StepButton(
                      iconAsset: 'minus',
                      tooltip: l.amendmentQuantityLess,
                      onPressed: readOnly
                          ? null
                          : () => cubit.setItemQuantity(item.id, qty - 1),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '$qty',
                        textAlign: TextAlign.center,
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _StepButton(
                      iconAsset: 'plus',
                      tooltip: l.amendmentQuantityMore,
                      onPressed: readOnly
                          ? null
                          : () => cubit.setItemQuantity(item.id, qty + 1),
                    ),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }
}

class _MethodSection extends StatelessWidget {
  const _MethodSection({
    required this.bid,
    required this.options,
    required this.selected,
    required this.readOnly,
  });

  final BidModel bid;
  final AmendmentOptions options;
  final BidPaymentMethod? selected;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<AmendmentRequestCubit>();
    final methods = [
      for (final m in options.paymentMethods)
        if (m == BidPaymentMethod.stripe ||
            m == BidPaymentMethod.cash ||
            m == BidPaymentMethod.mobileMoney)
          m,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l.amendmentSheetPayLabel),
        Row(
          children: [
            for (var i = 0; i < methods.length; i++) ...[
              if (i > 0) const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: _MethodTile(
                  label: switch (methods[i]) {
                    BidPaymentMethod.stripe => l.amendmentRailCard,
                    BidPaymentMethod.cash => l.amendmentRailCash,
                    _ => l.amendmentRailMobileMoney,
                  },
                  iconAsset: switch (methods[i]) {
                    BidPaymentMethod.stripe => 'credit-card',
                    BidPaymentMethod.cash => 'banknote',
                    _ => 'smartphone',
                  },
                  selected: methods[i] == selected,
                  onTap: readOnly ? null : () => cubit.selectMethod(methods[i]),
                ),
              ),
            ],
          ],
        ),
        if (selected == BidPaymentMethod.cash &&
            bid.paymentMethod == BidPaymentMethod.stripe) ...[
          const SizedBox(height: DonySpacing.md),
          DonyStatusBanner(
            type: DonyStatusBannerType.info,
            message: l.amendmentCashNoteCardParcel,
          ),
        ],
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.label,
    required this.iconAsset,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String iconAsset;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = selected ? cs.primary : cs.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? cs.primaryContainer : cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          side: BorderSide(
            color: selected ? cs.primary : cs.outline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.sm,
                vertical: DonySpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DonyIcon(iconAsset, size: 18, color: fg),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
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

/// Total et bouton du `stickyBottom`. Il vit hors du contenu défilant, lit le
/// cubit de la feuille (fourni par `wrapper`) et enchaîne la vérification
/// locale, la création et la feuille de paiement pour la carte.
class _AmendmentActions extends StatelessWidget {
  const _AmendmentActions({
    required this.bid,
    required this.authorize,
    required this.presentSheet,
  });

  final BidModel bid;
  final SupplementPaymentAuthorizer authorize;
  final SupplementPaymentSheetPresenter presentSheet;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AmendmentRequestCubit, AmendmentRequestState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: _onState,
      builder: (context, state) {
        final l = context.l10n;
        final tt = Theme.of(context).textTheme;
        final cs = Theme.of(context).colorScheme;
        if (state.status == AmendmentRequestStatus.loadFailed) {
          return DonyButton(
            label: l.commonRetry,
            variant: DonyButtonVariant.secondary,
            onPressed: () => context.read<AmendmentRequestCubit>().load(bid),
          );
        }
        final currency = state.options?.currency ?? bid.currency;
        final quote = state.grossQuote;
        final amount = quote == null
            ? null
            : formatSupplementAmount(quote, currency);
        final card = state.method == BidPaymentMethod.stripe;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  l.amendmentTotalLabel,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const Spacer(),
                Text(
                  amount ?? '—',
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DonySpacing.sm),
            DonyButton(
              label: card && amount != null
                  ? l.amendmentSubmitCard(amount)
                  : l.amendmentSubmit(_travelerName(context, bid)),
              iconAsset: switch (state.method) {
                BidPaymentMethod.stripe => 'lock',
                _ => null,
              },
              isLoading: state.isBusy,
              onPressed: state.canSubmit
                  ? () => unawaited(_submit(context, card))
                  : null,
            ),
          ],
        );
      },
    );
  }

  Future<void> _submit(BuildContext context, bool card) async {
    final cubit = context.read<AmendmentRequestCubit>();
    if (!card) {
      await cubit.submit();
      return;
    }
    // Bouton verrouillé pendant l'invite : un double tap n'en ouvre pas deux.
    if (!cubit.beginAuthorization()) return;
    final authenticated = await authorize(context);
    if (!authenticated || !context.mounted) {
      cubit.authorizationDenied();
      if (!authenticated && context.mounted) {
        DonySnackbar.show(
          context,
          message: context.l10n.paymentNotConfirmedSnackbar,
          type: DonySnackbarType.error,
        );
      }
      return;
    }
    await cubit.submit();
  }

  void _onState(BuildContext context, AmendmentRequestState state) {
    switch (state.status) {
      case AmendmentRequestStatus.readyToAuthorize:
        unawaited(_presentSheet(context, state));
      case AmendmentRequestStatus.sent:
        DonySnackbar.show(
          context,
          message: context.l10n.amendmentSentSnackbar(
            _travelerName(context, bid),
          ),
          type: DonySnackbarType.success,
        );
        Navigator.of(context).pop(true);
      case AmendmentRequestStatus.closed:
        ErrorPresenter.show(context, state.error);
        Navigator.of(context).pop(true);
      case AmendmentRequestStatus.failure:
        ErrorPresenter.show(context, state.error);
      case AmendmentRequestStatus.loading ||
          AmendmentRequestStatus.loadFailed ||
          AmendmentRequestStatus.editing ||
          AmendmentRequestStatus.quoting ||
          AmendmentRequestStatus.submitting ||
          AmendmentRequestStatus.confirming:
        break;
    }
  }

  /// Carte : la feuille de paiement bloque le montant (capture manuelle),
  /// puis le serveur confirme et présente la demande au voyageur.
  Future<void> _presentSheet(
    BuildContext context,
    AmendmentRequestState state,
  ) async {
    final cubit = context.read<AmendmentRequestCubit>();
    final checkout = state.checkout!;
    await presentSheet(
      context,
      config: PaymentSheetConfig(
        clientSecret: checkout.clientSecret!,
        amountEur: checkout.amendment.grossAmount,
        currencyCode: checkout.amendment.currency,
        paymentMethodTypes: checkout.paymentMethodTypes,
        analyticsContext: AnalyticsPaymentContext.bidAmendment,
      ),
      contextLabel: context.l10n.amendmentPaymentContextLabel,
      // AUCUNE garde de montage : la confirmation ne dépend d'aucun
      // BuildContext et doit partir même si l'écran se ferme.
      onSuccess: () async => cubit.cardAuthorized(),
    );
    // Après un paiement, `cardAuthorized` a déjà quitté cet état. Sinon la
    // feuille a été fermée sans bloquer le montant : la demande est annulée.
    unawaited(cubit.authorizationAbandoned());
  }
}
